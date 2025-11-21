//
//  LegacyAdapter.swift
//  UMAFCore
//
//  Fallback parser and generator for plain text and legacy formats.
//  Contains logic extracted from UMAFCoreEngine/LineScanner.
//

import Foundation

struct LegacyAdapter {

  // MARK: - Parser

  static func parse(text: String) -> (
    sections: [UMAFCoreEngine.Section],
    bullets: [UMAFCoreEngine.Bullet],
    frontMatter: [UMAFCoreEngine.FrontMatterEntry],
    tables: [UMAFCoreEngine.Table],
    codeBlocks: [UMAFCoreEngine.CodeBlock]
  ) {
    let allLines = text.components(separatedBy: "\n")
    var bullets: [UMAFCoreEngine.Bullet] = []

    for (idx, line) in allLines.enumerated() {
      let trimmedLeft = line.drop(while: { $0 == " " || $0 == "\t" })
      guard let first = trimmedLeft.first else { continue }
      if first == "-" || first == "*" || first == "•" {
        var rest = trimmedLeft.dropFirst()
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        let text = String(rest).trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
          bullets.append(
            UMAFCoreEngine.Bullet(
              text: text, lineIndex: idx, sectionHeading: "Document", sectionLevel: 1))
        }
      }
    }

    let paragraphs = makeParagraphs(from: allLines)
    let sections = [
      UMAFCoreEngine.Section(heading: "Document", level: 1, lines: allLines, paragraphs: paragraphs)
    ]

    return (sections, bullets, [], [], [])
  }

  // MARK: - Generator (Markdown Emitter)

  static func buildMarkdown(
    normalizedPayload: String,
    mediaType: String,
    sections: [UMAFCoreEngine.Section],
    bullets: [UMAFCoreEngine.Bullet],
    frontMatter: [UMAFCoreEngine.FrontMatterEntry],
    tables: [UMAFCoreEngine.Table],
    codeBlocks: [UMAFCoreEngine.CodeBlock]
  ) -> String {
    var lines: [String] = []

    switch mediaType {
    case "text/markdown":
      if frontMatter.isEmpty && sections.isEmpty { return normalizedPayload }

      if !frontMatter.isEmpty {
        lines.append("---")
        for e in frontMatter { lines.append("\(e.key): \(e.value)") }
        lines.append("---")
        lines.append("")
      }

      let effectiveSections: [UMAFCoreEngine.Section] =
        sections.isEmpty
        ? {
          let all = normalizedPayload.components(separatedBy: "\n")
          return [
            UMAFCoreEngine.Section(
              heading: "Document", level: 1, lines: all, paragraphs: makeParagraphs(from: all))
          ]
        }()
        : sections

      let hasComplex = !tables.isEmpty || !codeBlocks.isEmpty

      for (idx, s) in effectiveSections.enumerated() {
        let level = min(max(s.level, 1), 6)
        let prefix = String(repeating: "#", count: level)
        let title = s.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("\(prefix) \(title)")

        if !hasComplex, !s.paragraphs.isEmpty {
          lines.append("")
          for (pIdx, p) in s.paragraphs.enumerated() {
            lines.append(p)
            if pIdx != s.paragraphs.count - 1 { lines.append("") }
          }
        } else if !s.lines.isEmpty {
          lines.append("")
          lines.append(contentsOf: s.lines)
        }

        if idx != effectiveSections.count - 1 { lines.append("") }
      }

      return canonicalizeMarkdownLines(lines).joined(separator: "\n")

    case "application/json":
      let fence = "```"
      return [fence + "json", normalizedPayload, fence].joined(separator: "\n")

    default:
      if let doc = sections.first {
        let level = min(max(doc.level, 1), 6)
        let prefix = String(repeating: "#", count: level)
        let title = doc.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("\(prefix) \(title)")
        lines.append("")

        let docBullets = bullets.filter {
          $0.sectionHeading == "Document" || $0.sectionHeading == nil
        }
        let bulletLineIdx = Set(docBullets.map { $0.lineIndex })
        let bulletIndents: [Int] = docBullets.compactMap {
          guard $0.lineIndex >= 0 && $0.lineIndex < doc.lines.count else { return nil }
          return leadingIndentWidth(of: doc.lines[$0.lineIndex])
        }
        let baseIndent = bulletIndents.min() ?? 0

        var i = 0
        while i < doc.lines.count {
          let line = doc.lines[i]
          let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty

          if bulletLineIdx.contains(i) {
            var j = i
            while j < doc.lines.count, bulletLineIdx.contains(j) {
              if let b = docBullets.first(where: { $0.lineIndex == j }) {
                let raw = doc.lines[j]
                let w = leadingIndentWidth(of: raw)
                let extra = max(w - baseIndent, 0)
                let level = extra / 2
                let indent = String(repeating: "  ", count: level)
                lines.append("\(indent)- \(b.text)")
              }
              j += 1
            }
            lines.append("")
            i = j
            continue
          }

          lines.append(line)
          if isBlank {
            while i + 1 < doc.lines.count
              && doc.lines[i + 1].trimmingCharacters(in: .whitespaces).isEmpty
            {
              i += 1
            }
          }
          i += 1
        }

        return canonicalizeMarkdownLines(lines).joined(separator: "\n")
      } else {
        let fence = "```"
        return [fence + "text", normalizedPayload, fence].joined(separator: "\n")
      }
    }
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

  private static func leadingIndentWidth(of line: String) -> Int {
    var w = 0
    for ch in line { if ch == " " { w += 1 } else if ch == "\t" { w += 2 } else { break } }
    return w
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

    // Manual rightTrim helper
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
