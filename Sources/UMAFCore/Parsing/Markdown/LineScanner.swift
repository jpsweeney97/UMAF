//
//  LineScanner.swift
//  UMAFCore
//
//  Markdown line scanning and semantic parsing helpers.
//

import Foundation

public extension UMAFCoreEngine {

  static func canonicalizeMarkdownLines(_ lines: [String]) -> [String] {
    var out: [String] = []
    out.reserveCapacity(lines.count)
    var inFence = false
    var prevBlank = false

    func isListItem(_ s: String) -> Bool {
      let t = s.trimmingCharacters(in: .whitespaces)
      if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") { return true }
      if let dot = t.firstIndex(of: "."), !t[..<dot].isEmpty, t[..<dot].allSatisfy(\.isNumber) {
        let i = t.index(after: dot)
        if i < t.endIndex, t[i] == " " { return true }
      }
      return false
    }

    var i = 0
    while i < lines.count {
      let line = lines[i]
      let leadingTrim = line.trimmingCharacters(in: .whitespaces)

      if leadingTrim.hasPrefix("```") {
        // OPTIMIZATION: Use manual rightTrim
        let fence = rightTrim(line)
        out.append(fence)
        inFence.toggle()
        prevBlank = false
        i += 1
        continue
      }

      if inFence {
        out.append(line)  // keep exact
        prevBlank = false
        i += 1
        continue
      }

      // OPTIMIZATION: Use manual rightTrim
      let rightTrimmed = rightTrim(line)
      let isBlank = rightTrimmed.isEmpty

      if isBlank {
        // Drop blanks *between* list items
        var prevNonBlank: String?
        for cand in out.reversed()
        where !cand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          prevNonBlank = cand
          break
        }
        var nextNonBlank: String?
        var j = i + 1
        while j < lines.count {
          // OPTIMIZATION: Use manual rightTrim for lookahead
          let c = rightTrim(lines[j])
          if c.isEmpty {
            j += 1
            continue
          }
          nextNonBlank = c
          break
        }
        if let p = prevNonBlank, let n = nextNonBlank, isListItem(p), isListItem(n) {
          i += 1
          continue
        }
        if prevBlank {
          i += 1
          continue
        }
        out.append("")
        prevBlank = true
        i += 1
        continue
      }

      out.append(rightTrimmed)
      prevBlank = false
      i += 1
    }

    while out.first == "" { out.removeFirst() }
    while out.last == "" { out.removeLast() }
    return out
  }

  static func parseSemanticStructure(
    from text: String,
    mediaType: String
  ) -> (
    sections: [Section], bullets: [Bullet], frontMatter: [FrontMatterEntry], tables: [Table],
    codeBlocks: [CodeBlock]
  ) {

    if mediaType == "application/json" {
      return ([], [], [], [], [])
    }

    let allLines = text.components(separatedBy: "\n")
    var sections: [Section] = []
    var bullets: [Bullet] = []
    var frontMatter: [FrontMatterEntry] = []
    var startIndex = 0

    // YAML front-matter (Markdown)
    if mediaType == "text/markdown",
      let first = allLines.first?.trimmingCharacters(in: .whitespaces),
      first == "---"
    {
      var i = 1
      while i < allLines.count {
        let t = allLines[i].trimmingCharacters(in: .whitespaces)
        if t == "---" {
          i += 1
          break
        }
        if !t.isEmpty, let colon = t.range(of: ":") {
          let key = String(t[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
          let rawValue = String(t[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
          let value = stripOuterQuotes(rawValue)
          if !key.isEmpty { frontMatter.append(FrontMatterEntry(key: key, value: value)) }
        }
        i += 1
      }
      startIndex = i
    }

    if mediaType != "text/markdown" {
      // Bullets (plain)
      for (idx, line) in allLines.enumerated() {
        let trimmedLeft = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmedLeft.first else { continue }
        if first == "-" || first == "*" || first == "•" {
          var rest = trimmedLeft.dropFirst()
          rest = rest.drop(while: { $0 == " " || $0 == "\t" })
          let text = String(rest).trimmingCharacters(in: .whitespaces)
          if !text.isEmpty {
            bullets.append(
              Bullet(text: text, lineIndex: idx, sectionHeading: "Document", sectionLevel: 1))
          }
        }
      }

      let paragraphs = makeParagraphs(from: allLines)
      sections.append(
        Section(heading: "Document", level: 1, lines: allLines, paragraphs: paragraphs))
      return (sections, bullets, frontMatter, [], [])
    }

    // Markdown parsing (with fences)
    var currentHeading: String?
    var currentLevel: Int = 1
    var currentLines: [String] = []
    var inCodeFence = false
    var codeBlocks: [CodeBlock] = []
    var currentCodeLines: [String] = []
    var currentCodeLanguage: String?
    var currentCodeStartLine: Int?

    func flushSection() {
      if let h = currentHeading {
        sections.append(
          Section(
            heading: h, level: currentLevel, lines: currentLines,
            paragraphs: makeParagraphs(from: currentLines)))
      }
      currentHeading = nil
      currentLevel = 1
      currentLines = []
    }

    for index in startIndex..<allLines.count {
      let line = allLines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.hasPrefix("```") {
        if !inCodeFence {
          inCodeFence = true
          currentCodeLines.removeAll()
          currentCodeStartLine = index
          let rest = trimmed.drop(while: { $0 == "`" || $0 == " " })
          currentCodeLanguage = rest.isEmpty ? nil : String(rest)
        } else {
          inCodeFence = false
          if let start = currentCodeStartLine {
            codeBlocks.append(
              CodeBlock(
                startLineIndex: start,
                language: currentCodeLanguage,
                code: currentCodeLines.joined(separator: "\n")))
          }
          currentCodeLines.removeAll()
          currentCodeLanguage = nil
          currentCodeStartLine = nil
        }
        if currentHeading != nil { currentLines.append(line) }
        continue
      }

      if !inCodeFence {
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
          let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
          let pHeading = currentHeading
          let pLevel = currentHeading != nil ? currentLevel : nil
          bullets.append(
            Bullet(text: text, lineIndex: index, sectionHeading: pHeading, sectionLevel: pLevel))
        }
      }

      if inCodeFence {
        currentCodeLines.append(line)
        if currentHeading != nil { currentLines.append(line) }
        continue
      }

      if trimmed.isEmpty {
        if currentHeading != nil { currentLines.append(line) }
        continue
      }

      if trimmed.first == "#" {
        var count = 0
        for ch in trimmed {
          if ch == "#" { count += 1 } else { break }
        }
        if count > 0 && count <= 6 {
          var rest = trimmed.drop(while: { $0 == "#" })
          if rest.first == " " { rest = rest.dropFirst() }
          let text = String(rest)
          flushSection()
          currentHeading = text
          currentLevel = count
          continue
        }
      }

      if currentHeading != nil { currentLines.append(line) }
    }
    flushSection()

    // Simple table detection
    var detectedTables: [Table] = []
    var i = startIndex
    while i + 1 < allLines.count {
      let headerLine = allLines[i].trimmingCharacters(in: .whitespaces)
      let sepLine = allLines[i + 1].trimmingCharacters(in: .whitespaces)
      if !headerLine.contains("|") || !sepLine.contains("|") {
        i += 1
        continue
      }

      let sepCells =
        sepLine
        .split(separator: "|")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

      guard !sepCells.isEmpty, sepCells.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } })
      else {
        i += 1
        continue
      }

      let headerCells =
        headerLine
        .split(separator: "|")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

      var rows: [[String]] = []
      var j = i + 2
      while j < allLines.count {
        let rowTrim = allLines[j].trimmingCharacters(in: .whitespaces)
        if !rowTrim.contains("|") { break }
        let cells =
          rowTrim
          .split(separator: "|")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
        if cells.isEmpty { break }
        rows.append(cells)
        j += 1
      }

      if !rows.isEmpty {
        detectedTables.append(Table(startLineIndex: i, header: headerCells, rows: rows))
        i = j
      } else {
        i += 1
      }
    }

    return (sections, bullets, frontMatter, detectedTables, codeBlocks)
  }

  static func makeParagraphs(from lines: [String]) -> [String] {
    var paragraphs: [String] = []
    var buffer: [String] = []

    func flush() {
      guard !buffer.isEmpty else { return }

      let nonEmpty = buffer.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      let commonIndent: Int =
        nonEmpty.map { line in
          var count = 0
          for ch in line {
            if ch == " " { count += 1 } else if ch == "\t" { count += 2 } else { break }
          }
          return count
        }.min() ?? 0

      let normalized: [String]
      if commonIndent > 0 {
        normalized = buffer.map { line in
          var c = 0
          var i = line.startIndex
          while i < line.endIndex && c < commonIndent {
            let ch = line[i]
            if ch == " " { c += 1 } else if ch == "\t" { c += 2 } else { break }
            i = line.index(after: i)
          }
          return String(line[i...])
        }
      } else {
        normalized = buffer
      }

      paragraphs.append(normalized.joined(separator: "\n"))
      buffer.removeAll()
    }

    for line in lines {
      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        flush()
      } else {
        buffer.append(line)
      }
    }
    flush()
    return paragraphs
  }

  static func leadingIndentWidth(of line: String) -> Int {
    var w = 0
    for ch in line {
      if ch == " " { w += 1 } else if ch == "\t" { w += 2 } else { break }
    }
    return w
  }
}

private extension UMAFCoreEngine {

  static func stripOuterQuotes(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'") {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  // OPTIMIZATION: Manual character trim instead of Regex
  static func rightTrim(_ s: String) -> String {
    var res = s
    while let last = res.last, last == " " || last == "\t" {
      res.removeLast()
    }
    return res
  }
}
