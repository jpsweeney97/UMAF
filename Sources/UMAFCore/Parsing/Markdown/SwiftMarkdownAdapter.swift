//
//  SwiftMarkdownAdapter.swift
//  UMAFCore
//
//  Parses Markdown using Apple's swift-markdown library.
//  Performs "Inverse Scan" to partition the document, normalizes the text,
//  and realigns all semantic indices to match the normalized output.
//

import Foundation
import Markdown

struct SwiftMarkdownAdapter {

  struct ParseResult {
    let normalizedText: String
    let sections: [UMAFCoreEngine.Section]
    let bullets: [UMAFCoreEngine.Bullet]
    let frontMatter: [UMAFCoreEngine.FrontMatterEntry]
    let tables: [UMAFCoreEngine.Table]
    let codeBlocks: [UMAFCoreEngine.CodeBlock]
  }

  static func parse(text: String) -> ParseResult {
    let document = Document(parsing: text)
    let sourceLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let (frontMatter, fmEndIndex) = parseFrontMatter(sourceLines: sourceLines)

    var headingMap: [Int: Heading] = [:]
    var headingWalker = HeadingCollector()
    headingWalker.visit(document)

    for h in headingWalker.headings {
      guard let r = h.range else { continue }
      let start = r.lowerBound.line - 1
      let end = r.upperBound.line - 1
      for i in start...end {
        headingMap[i] = h
      }
    }

    var sourceExtractor = ElementExtractor(sourceLines: sourceLines)
    sourceExtractor.visit(document)

    var sections: [UMAFCoreEngine.Section] = []
    var normalizedLines: [String] = []
    normalizedLines.reserveCapacity(sourceLines.count + (frontMatter.count * 2) + 8)
    var currentOutputLine = 0

    var outBullets: [UMAFCoreEngine.Bullet] = []
    var outTables: [UMAFCoreEngine.Table] = []
    var outCodeBlocks: [UMAFCoreEngine.CodeBlock] = []

    if !frontMatter.isEmpty {
      normalizedLines.append("---")
      for fm in frontMatter { normalizedLines.append("\(fm.key): \(fm.value)") }
      normalizedLines.append("---")
      normalizedLines.append("")
      currentOutputLine = normalizedLines.count
    }

    var currentHeading = "Document"
    var currentLevel = 1
    var currentBodySourceLines: [String] = []
    var currentBodyStartSourceIndex = 0

    func flushSection(isLast: Bool = false) {
      var trimmedBody = currentBodySourceLines
      var trimTopCount = 0

      while let first = trimmedBody.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
        trimmedBody.removeFirst()
        trimTopCount += 1
      }
      while let last = trimmedBody.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
        trimmedBody.removeLast()
      }

      // Capture Start Index (0-based)
      let sectionStartIndex = currentOutputLine

      let headingLine = String(repeating: "#", count: currentLevel) + " " + currentHeading
      normalizedLines.append(headingLine)

      let sectionLines = [""] + trimmedBody
      normalizedLines.append(contentsOf: sectionLines)

      if !isLast {
        normalizedLines.append("")
      }

      // Capture End Index (0-based index of the last line added)
      let sectionEndIndex = normalizedLines.count - 1

      let bodyStartOutputIndex = currentOutputLine + 2

      let p = UMAFCoreEngine.makeParagraphs(from: trimmedBody)
      sections.append(
        UMAFCoreEngine.Section(
          heading: currentHeading,
          level: currentLevel,
          lines: sectionLines,
          paragraphs: p,
          startLineIndex: sectionStartIndex,
          endLineIndex: sectionEndIndex
        ))

      let effectiveOffset = bodyStartOutputIndex - (currentBodyStartSourceIndex + trimTopCount)
      let sourceBodyRange =
        currentBodyStartSourceIndex..<(currentBodyStartSourceIndex + currentBodySourceLines.count)

      for t in sourceExtractor.tables {
        if sourceBodyRange.contains(t.startLineIndex) {
          if t.startLineIndex >= (currentBodyStartSourceIndex + trimTopCount) {
            let newIndex = t.startLineIndex + effectiveOffset
            outTables.append(
              UMAFCoreEngine.Table(
                startLineIndex: newIndex, header: t.header, rows: t.rows))
          }
        }
      }
      for c in sourceExtractor.codeBlocks {
        if sourceBodyRange.contains(c.startLineIndex) {
          if c.startLineIndex >= (currentBodyStartSourceIndex + trimTopCount) {
            let newIndex = c.startLineIndex + effectiveOffset
            outCodeBlocks.append(
              UMAFCoreEngine.CodeBlock(
                startLineIndex: newIndex, language: c.language, code: c.code))
          }
        }
      }
      for b in sourceExtractor.bullets {
        if sourceBodyRange.contains(b.lineIndex) {
          if b.lineIndex >= (currentBodyStartSourceIndex + trimTopCount) {
            let newIndex = b.lineIndex + effectiveOffset
            outBullets.append(
              UMAFCoreEngine.Bullet(
                text: b.text, lineIndex: newIndex, sectionHeading: currentHeading,
                sectionLevel: currentLevel))
          }
        }
      }

      currentOutputLine = normalizedLines.count
      currentBodySourceLines = []
    }

    let startIndex = fmEndIndex + 1
    currentBodyStartSourceIndex = startIndex

    for i in startIndex..<sourceLines.count {
      if let heading = headingMap[i] {
        if heading.range?.lowerBound.line == (i + 1) {
          if !sections.isEmpty || !currentBodySourceLines.isEmpty || currentHeading != "Document" {
            flushSection()
          }
          currentHeading = heading.plainText
          currentLevel = heading.level
        }
        currentBodyStartSourceIndex = i + 1
      } else {
        currentBodySourceLines.append(sourceLines[i])
      }
    }

    flushSection(isLast: true)

    let finalNormalizedText = normalizedLines.joined(separator: "\n")

    return ParseResult(
      normalizedText: finalNormalizedText,
      sections: sections,
      bullets: outBullets,
      frontMatter: frontMatter,
      tables: outTables,
      codeBlocks: outCodeBlocks
    )
  }

  private static func parseFrontMatter(sourceLines: [String]) -> (
    [UMAFCoreEngine.FrontMatterEntry], Int
  ) {
    guard let first = sourceLines.first?.trimmingCharacters(in: .whitespaces), first == "---" else {
      return ([], -1)
    }
    var entries: [UMAFCoreEngine.FrontMatterEntry] = []
    var endLineIndex = -1
    for (index, line) in sourceLines.enumerated().dropFirst() {
      let t = line.trimmingCharacters(in: .whitespaces)
      if t == "---" {
        endLineIndex = index
        break
      }
      if let colon = t.range(of: ":") {
        let key = String(t[..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
        var val = String(t[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
        if val.count >= 2,
          (val.first == "\"" && val.last == "\"") || (val.first == "'" && val.last == "'")
        {
          val = String(val.dropFirst().dropLast())
        }
        if !key.isEmpty { entries.append(UMAFCoreEngine.FrontMatterEntry(key: key, value: val)) }
      }
    }
    if endLineIndex == -1 { return ([], -1) }
    return (entries, endLineIndex)
  }
}

private struct HeadingCollector: MarkupWalker {
  var headings: [Heading] = []
  mutating func visitHeading(_ heading: Heading) { headings.append(heading) }
}

private struct ElementExtractor: MarkupWalker {
  var bullets: [UMAFCoreEngine.Bullet] = []
  var tables: [UMAFCoreEngine.Table] = []
  var codeBlocks: [UMAFCoreEngine.CodeBlock] = []
  let sourceLines: [String]

  mutating func visitListItem(_ listItem: ListItem) {
    if let para = listItem.children.first(where: { $0 is Paragraph }) as? Paragraph {
      let text = para.plainText
      let lineIdx = (listItem.range?.lowerBound.line ?? 1) - 1
      bullets.append(
        UMAFCoreEngine.Bullet(
          text: text, lineIndex: lineIdx, sectionHeading: nil, sectionLevel: nil))
    }
    descendInto(listItem)
  }
  mutating func visitCodeBlock(_ codeBlock: Markdown.CodeBlock) {
    let lineIdx = (codeBlock.range?.lowerBound.line ?? 1) - 1
    codeBlocks.append(
      UMAFCoreEngine.CodeBlock(
        startLineIndex: lineIdx, language: codeBlock.language, code: codeBlock.code))
  }
  mutating func visitTable(_ table: Markdown.Table) {
    let lineIdx = (table.range?.lowerBound.line ?? 1) - 1
    var headers: [String] = []
    for cell in table.head.cells { headers.append(cell.plainText) }
    var rows: [[String]] = []
    for row in table.body.rows {
      var rowData: [String] = []
      for cell in row.cells { rowData.append(cell.plainText) }
      rows.append(rowData)
    }
    tables.append(UMAFCoreEngine.Table(startLineIndex: lineIdx, header: headers, rows: rows))
  }
}
