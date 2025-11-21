//
//  UMAFCoreEngine.swift
//  Core formatting & semantic engine for UMAF (v0.5)
//

import Crypto
import Foundation
import PDFKit

// A tiny namespace so this file never collides with app-local symbols.
public enum UMAFCoreEngine {

  public struct Section: Codable {
    public let heading: String
    public let level: Int
    public let lines: [String]
    public let paragraphs: [String]
  }

  public struct Table: Codable {
    public let startLineIndex: Int
    public let header: [String]
    public let rows: [[String]]
  }

  public struct CodeBlock: Codable {
    public let startLineIndex: Int
    public let language: String?
    public let code: String
  }

  public struct Bullet: Codable {
    public let text: String
    public let lineIndex: Int
    public let sectionHeading: String?
    public let sectionLevel: Int?
  }

  public struct FrontMatterEntry: Codable {
    public let key: String
    public let value: String
  }

  public struct Envelope: Codable {
    public let version: String
    public let docTitle: String
    public let docId: String
    public let createdAt: String
    public let sourceHash: String
    public let sourcePath: String
    public let mediaType: String
    public let encoding: String
    public let sizeBytes: Int
    public let lineCount: Int
    public let normalized: String
    public let sections: [Section]
    public let bullets: [Bullet]
    public let frontMatter: [FrontMatterEntry]
    public let tables: [Table]
    public let codeBlocks: [CodeBlock]
  }

  public enum OutputFormat: String, CaseIterable {
    case jsonEnvelope
    case markdown
  }

  // MARK: - Low-level helpers

  private static func stripOuterQuotes(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'") {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  private static func makeParagraphs(from lines: [String]) -> [String] {
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

  private static func leadingIndentWidth(of line: String) -> Int {
    var w = 0
    for ch in line {
      if ch == " " { w += 1 } else if ch == "\t" { w += 2 } else { break }
    }
    return w
  }

  static func firstMarkdownHeadingTitle(in text: String) -> String? {
    for raw in text.components(separatedBy: "\n") {
      let trimmed = raw.trimmingCharacters(in: .whitespaces)
      guard trimmed.first == "#" else { continue }
      var hashes = 0
      for ch in trimmed {
        if ch == "#" { hashes += 1 } else { break }
      }
      guard hashes > 0 else { continue }
      var rest = trimmed.drop(while: { $0 == "#" })
      if rest.first == " " { rest = rest.dropFirst() }
      let title = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
      if !title.isEmpty { return title }
    }
    return nil
  }

  // OPTIMIZATION: Manual character trim instead of Regex
  private static func rightTrim(_ s: String) -> String {
    var res = s
    while let last = res.last, last == " " || last == "\t" {
      res.removeLast()
    }
    return res
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

  // MARK: - Prework (I/O + conversions)

  enum Prework {
    static func normalizeLineEndings(_ text: String) -> String {
      var s = text.replacingOccurrences(of: "\r\n", with: "\n")
      s = s.replacingOccurrences(of: "\r", with: "\n")
      return s
    }

    // NOTE: This is kept for reference but Router now prefers HTMLAdapter.htmlToMarkdownish
    // which contains the optimized implementation.
    static func htmlToMarkdownish(_ html: String) -> String {
      // Delegate to the optimized adapter if possible, or keep legacy logic here.
      // For safety in this overwrite, we preserve the legacy logic just in case,
      // but Router calls HTMLAdapter anyway.
      var text = normalizeLineEndings(html)
      for br in ["<br>", "<br/>", "<br />", "<BR>", "<BR/>", "<BR />"] {
        text = text.replacingOccurrences(of: br, with: "\n")
      }
      func replaceHeading(tag: String, level: Int) {
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        if let re = try? NSRegularExpression(
          pattern: pattern,
          options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) {
          let range = NSRange(text.startIndex..., in: text)
          let hashes = String(repeating: "#", count: level)
          text = re.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: "\n\(hashes) $1\n\n")
        }
      }
      replaceHeading(tag: "h1", level: 1)
      replaceHeading(tag: "h2", level: 2)
      if let re = try? NSRegularExpression(
        pattern: "<li[^>]*>(.*?)</li>",
        options: [.dotMatchesLineSeparators, .caseInsensitive]
      ) {
        let range = NSRange(text.startIndex..., in: text)
        text = re.stringByReplacingMatches(
          in: text, options: [], range: range, withTemplate: "\n- $1\n")
      }
      if let re = try? NSRegularExpression(pattern: "<[^>]+>", options: [.caseInsensitive]) {
        let range = NSRange(text.startIndex..., in: text)
        text = re.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
      }
      while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractTextWithTextUtil(from url: URL) throws -> String {
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
      p.arguments = ["-convert", "txt", "-stdout", url.path]

      let out = Pipe()
      let err = Pipe()
      p.standardOutput = out
      p.standardError = err

      try p.run()
      p.waitUntilExit()

      guard p.terminationStatus == 0 else {
        let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        throw NSError(
          domain: "UMAF", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "textutil failed: \(msg)"])
      }

      let data = out.fileHandleForReading.readDataToEndOfFile()
      return String(decoding: data, as: UTF8.self)
    }

    static func extractPdfToMarkdownish(from url: URL) throws -> String {
      guard let doc = PDFDocument(url: url) else {
        throw NSError(
          domain: "UMAF", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document."])
      }

      var lines: [String] = []
      for pageIndex in 0..<doc.pageCount {
        guard let page = doc.page(at: pageIndex),
          let s = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
          !s.isEmpty
        else { continue }

        lines.append("# Page \(pageIndex + 1)")
        lines.append("")
        lines.append(contentsOf: s.components(separatedBy: .newlines))
        if pageIndex != doc.pageCount - 1 { lines.append("") }
      }
      return normalizeLineEndings(lines.joined(separator: "\n"))
    }
  }

  // MARK: - Structure parsing

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

  // MARK: - Markdown emitter

  static func buildMarkdownFromSemantic(
    normalizedPayload: String,
    mediaType: String,
    sections: [Section],
    bullets: [Bullet],
    frontMatter: [FrontMatterEntry],
    tables: [Table],
    codeBlocks: [CodeBlock]
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

      let effectiveSections: [Section] =
        sections.isEmpty
        ? {
          let all = normalizedPayload.components(separatedBy: "\n")
          return [
            Section(
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
      return ["```json", normalizedPayload, "```"].joined(separator: "\n")

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
        return ["```text", normalizedPayload, "```"].joined(separator: "\n")
      }
    }
  }

  // MARK: - Transformer (single entry point for CLI and library)

  public struct Transformer {

    public init() {}

    public func transformFile(inputURL url: URL, outputFormat: OutputFormat) throws -> Data {
      // 1) Read bytes (for hashing/size)
      let data = try Data(contentsOf: url)
      let sizeBytes = data.count

      // 2) Route + normalize via InputRouter
      // OPTIMIZATION: Pass data directly, do not re-read from disk
      let routed = try InputRouter.load(from: url, data: data)
      let mediaType = routed.mediaType
      let semanticMediaType = routed.semanticMediaType
      let normalizedPayload = routed.normalizedText

      // 3) Semantic model
      let (sections, bullets, frontMatter, tables, codeBlocks) =
        UMAFCoreEngine.parseSemanticStructure(
          from: normalizedPayload,
          mediaType: semanticMediaType
        )

      // 4) Outputs
      switch outputFormat {
      case .jsonEnvelope:
        // Metadata
        let baseName = url.deletingPathExtension().lastPathComponent
        let docTitle: String =
          (semanticMediaType == "text/markdown")
          ? (UMAFCoreEngine.firstMarkdownHeadingTitle(in: normalizedPayload) ?? baseName)
          : baseName
        let createdAt = ISO8601DateFormatter().string(
          from: (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date)
            ?? Date()
        )

        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let docId = String(hash.prefix(12))
        let lineCount = normalizedPayload.split(separator: "\n", omittingEmptySubsequences: false)
          .count

        let env = Envelope(
          version: "umaf-0.5.0",
          docTitle: docTitle,
          docId: docId,
          createdAt: createdAt,
          sourceHash: hash,
          sourcePath: url.path,
          mediaType: mediaType,
          encoding: "utf-8",
          sizeBytes: sizeBytes,
          lineCount: lineCount,
          normalized: normalizedPayload,
          sections: sections,
          bullets: bullets,
          frontMatter: frontMatter,
          tables: tables,
          codeBlocks: codeBlocks
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(env)

      case .markdown:
        let md = UMAFCoreEngine.buildMarkdownFromSemantic(
          normalizedPayload: normalizedPayload,
          mediaType: semanticMediaType,
          sections: sections,
          bullets: bullets,
          frontMatter: frontMatter,
          tables: tables,
          codeBlocks: codeBlocks
        )
        guard let d = md.data(using: .utf8) else {
          throw NSError(
            domain: "UMAF", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode Markdown as UTF-8."])
        }
        return d
      }
    }
  }
}
