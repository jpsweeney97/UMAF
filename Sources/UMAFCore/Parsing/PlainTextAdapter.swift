//
//  PlainTextAdapter.swift
//  UMAFCore
//
//  Minimal normalizer for non-Markdown text (plain, JSON, etc.).
//

import Foundation

struct PlainTextAdapter {

  struct ParseResult {
    let normalizedText: String
    let sections: [UMAFCoreEngine.Section]
    let bullets: [UMAFCoreEngine.Bullet]
    let frontMatter: [UMAFCoreEngine.FrontMatterEntry]
    let tables: [UMAFCoreEngine.Table]
    let codeBlocks: [UMAFCoreEngine.CodeBlock]
  }

  /// One-shot parse and normalize for plain content.
  static func parseAndNormalize(text: String, mediaType: String) -> ParseResult {
    var normalizedLines: [String] = []

    // 1. Canonicalize lines (trimming, spacing)
    let rawLines = text.components(separatedBy: "\n")
    let cleanLines = canonicalizeMarkdownLines(rawLines)

    // 2. Build output (Single "Document" section)
    normalizedLines.append("# Document")
    normalizedLines.append("")
    let bodyStartIndex = 2

    normalizedLines.append(contentsOf: cleanLines)

    let normalizedText = normalizedLines.joined(separator: "\n")
    let endLineIndex = normalizedLines.count - 1

    // 3. Extract Bullets (mapped to new indices)
    var bullets: [UMAFCoreEngine.Bullet] = []
    for (idx, line) in cleanLines.enumerated() {
      let trimmedLeft = line.drop(while: { $0 == " " || $0 == "\t" })
      guard let first = trimmedLeft.first else { continue }
      if first == "-" || first == "*" || first == "•" {
        var rest = trimmedLeft.dropFirst()
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        let textVal = String(rest).trimmingCharacters(in: .whitespaces)
        if !textVal.isEmpty {
          bullets.append(
            UMAFCoreEngine.Bullet(
              text: textVal,
              lineIndex: idx + bodyStartIndex,
              sectionHeading: "Document",
              sectionLevel: 1
            )
          )
        }
      }
    }

    let paragraphs = makeParagraphs(from: cleanLines)

    let sectionLines = [""] + cleanLines

    let section = UMAFCoreEngine.Section(
      heading: "Document",
      level: 1,
      lines: sectionLines,
      paragraphs: paragraphs,
      startLineIndex: 0,
      endLineIndex: endLineIndex
    )

    return ParseResult(
      normalizedText: normalizedText,
      sections: [section],
      bullets: bullets,
      frontMatter: [],
      tables: [],
      codeBlocks: []
    )
  }

  // MARK: - Helpers

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
      if line.trimmingCharacters(in: .whitespaces).isEmpty { flush() } else { buffer.append(line) }
    }
    flush()
    return paragraphs
  }

  private static func canonicalizeMarkdownLines(_ lines: [String]) -> [String] {
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

    func rightTrim(_ s: String) -> String {
      var res = s
      while let last = res.last, last == " " || last == "\t" {
        res.removeLast()
      }
      return res
    }

    var i = 0
    while i < lines.count {
      let line = lines[i]
      let leadingTrim = line.trimmingCharacters(in: .whitespaces)

      if leadingTrim.hasPrefix("```") {
        let fence = rightTrim(line)
        out.append(fence)
        inFence.toggle()
        prevBlank = false
        i += 1
        continue
      }

      if inFence {
        out.append(line)
        prevBlank = false
        i += 1
        continue
      }

      let rightTrimmed = rightTrim(line)
      let isBlank = rightTrimmed.isEmpty

      if isBlank {
        var prevNonBlank: String?
        for cand in out.reversed()
        where !cand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          prevNonBlank = cand
          break
        }
        var nextNonBlank: String?
        var j = i + 1
        while j < lines.count {
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
}
