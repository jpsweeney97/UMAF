import XCTest

@testable import UMAFCore

final class UMAFWalkerTask2Tests: XCTestCase {

  // MARK: - Helpers

  private struct OutlineEntry {
    let heading: String
    let level: Int?
    let startLine: Int
    let endLine: Int
  }

  private func projectRootURL(file: StaticString = #filePath) -> URL {
    let fileURL = URL(fileURLWithPath: String(describing: file))
    return
      fileURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func crucibleURL() throws -> URL {
    let url = projectRootURL().appendingPathComponent("crucible/markdown-crucible-v2.md")
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    return url
  }

  private func spanMap(for envelope: UMAFEnvelopeV0_7) -> [String: UMAFSpanV0_7] {
    Dictionary(uniqueKeysWithValues: envelope.spans.map { ($0.id, $0) })
  }

  private func childrenByParent(_ blocks: [UMAFBlockV0_7]) -> [String: [UMAFBlockV0_7]] {
    blocks.reduce(into: [:]) { acc, block in
      guard let parent = block.parentId else { return }
      acc[parent, default: []].append(block)
    }
  }

  private func makeTempFile(with contents: String, ext: String = "md") throws -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("sample.\(ext)")
    try contents.data(using: .utf8)!.write(to: url)
    return url
  }

  private func markdownOutline(from envelope: UMAFEnvelopeV0_7) -> [OutlineEntry] {
    let spans = spanMap(for: envelope)
    return envelope.blocks
      .filter { $0.kind == .section }
      .compactMap { block in
        guard
          let heading = block.heading,
          let span = spans[block.spanId]
        else { return nil }
        return OutlineEntry(
          heading: heading,
          level: block.level,
          startLine: span.startLine,
          endLine: span.endLine
        )
      }
      .sorted { $0.startLine < $1.startLine }
  }

  // MARK: - Tests

  func testSyntheticDocumentStructuralInvariants() throws {
    let md = """
      # Title

      Intro line.

      ## Section 1

      Para one.
      Second line.

      | A | B |
      | - | - |
      | 1 | 2 |

      ```swift
      print("hi")
      ```

      """

    let url = try makeTempFile(with: md)
    let envelope = try UMAFNormalization.envelopeV0_7(fromFileURL: url)
    let spans = spanMap(for: envelope)
    let spanIds = Set(spans.keys)

    // Every block points to a real span.
    for block in envelope.blocks {
      XCTAssertTrue(spanIds.contains(block.spanId), "Block \(block.id) span missing")
    }

    // Spans are within bounds.
    for span in envelope.spans {
      XCTAssertGreaterThanOrEqual(span.startLine, 1)
      XCTAssertLessThanOrEqual(span.endLine, envelope.lineCount)
      XCTAssertLessThanOrEqual(span.startLine, span.endLine)
    }

    // Section blocks form a tree and children are nested and non-overlapping.
    let blockMap = Dictionary(uniqueKeysWithValues: envelope.blocks.map { ($0.id, $0) })
    let children = childrenByParent(envelope.blocks)
    for (parentId, siblings) in children {
      guard let parentBlock = blockMap[parentId], let parentSpan = spans[parentBlock.spanId] else {
        continue
      }
      let ordered = siblings.sorted { (lhs, rhs) -> Bool in
        let lSpan = spans[lhs.spanId]!
        let rSpan = spans[rhs.spanId]!
        if lSpan.startLine == rSpan.startLine { return lSpan.endLine < rSpan.endLine }
        return lSpan.startLine < rSpan.startLine
      }

      var previousEnd: Int?
      for child in ordered {
        guard let childSpan = spans[child.spanId] else { continue }
        XCTAssertLessThanOrEqual(
          parentSpan.startLine, childSpan.startLine, "Parent should start before child")
        XCTAssertGreaterThanOrEqual(
          parentSpan.endLine, childSpan.endLine, "Parent should end after child")

        if let prev = previousEnd {
          XCTAssertGreaterThanOrEqual(
            childSpan.startLine,
            prev + 1,
            "Siblings should not overlap: \(parentId)"
          )
        }
        previousEnd = childSpan.endLine
      }
    }

    // Table blocks align to UMAFCoreEngine.Table ranges.
    let tableRanges: Set<ClosedRange<Int>> = Set(
      envelope.tables.map { table in
        let start = table.startLineIndex + 1
        let total = 2 + table.rows.count
        let end = min(envelope.lineCount, start + total - 1)
        return start...end
      })
    let tableBlockRanges: Set<ClosedRange<Int>> = Set(
      envelope.blocks
        .filter { $0.kind == .table }
        .compactMap { spans[$0.spanId].map { $0.startLine...$0.endLine } })
    XCTAssertEqual(tableRanges, tableBlockRanges)

    // Code blocks align to UMAFCoreEngine.CodeBlock ranges.
    let codeRanges: Set<ClosedRange<Int>> = Set(
      envelope.codeBlocks.map { block in
        let codeLines = block.code.split(separator: "\n", omittingEmptySubsequences: false).count
        let total = codeLines + 2
        let start = block.startLineIndex + 1
        let end = min(envelope.lineCount, start + total - 1)
        return start...end
      })
    let codeBlockRanges: Set<ClosedRange<Int>> = Set(
      envelope.blocks
        .filter { $0.kind == .code }
        .compactMap { spans[$0.spanId].map { $0.startLine...$0.endLine } })
    XCTAssertEqual(codeRanges, codeBlockRanges)
  }

  func testCrucibleHasBlocksForHeadingsTablesAndCode() throws {
    let envelope = try UMAFNormalization.envelopeV0_7(fromFileURL: try crucibleURL())
    let spans = spanMap(for: envelope)

    let sectionBlocks = envelope.blocks.filter { $0.kind == .section }
    XCTAssertGreaterThanOrEqual(sectionBlocks.count, envelope.sections.count)

    let tableBlocks = envelope.blocks.filter { $0.kind == .table }
    XCTAssertGreaterThanOrEqual(tableBlocks.count, envelope.tables.count)

    let codeBlocks = envelope.blocks.filter { $0.kind == .code }
    XCTAssertGreaterThanOrEqual(codeBlocks.count, envelope.codeBlocks.count)

    // Outline reconstruction and setext heading check.
    let outline = markdownOutline(from: envelope)
    guard let setext = outline.first(where: { $0.heading == "Setext Style Heading" }) else {
      XCTFail("Missing Setext Style Heading block")
      return
    }
    XCTAssertEqual(setext.level, 2)

    let lines = envelope.normalized.split(separator: "\n", omittingEmptySubsequences: false)
    guard
      let headingIndex = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "## Setext Style Heading"
      })
    else {
      XCTFail("Could not locate heading line in normalized text")
      return
    }
    let expectedStart = headingIndex + 1
    let section = envelope.sections.first(where: { $0.heading == "Setext Style Heading" })
    let expectedEnd =
      section.map { min(envelope.lineCount, expectedStart + $0.lines.count) }
      ?? envelope.lineCount

    XCTAssertEqual(setext.startLine, expectedStart)
    XCTAssertEqual(setext.endLine, expectedEnd)

    for block in envelope.blocks {
      guard let span = spans[block.spanId] else { continue }
      XCTAssertGreaterThanOrEqual(span.startLine, 1)
      XCTAssertLessThanOrEqual(span.endLine, envelope.lineCount)
    }
  }
}
