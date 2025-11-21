import XCTest

@testable import UMAFCore

final class UMAFProvenanceIntegrationTests: XCTestCase {

  private func spanMap(for envelope: UMAFEnvelopeV0_5) -> [String: UMAFSpanV0_5] {
    Dictionary(uniqueKeysWithValues: envelope.spans.map { ($0.id, $0) })
  }

  func testMarkdownProvenanceAndConfidence() throws {
    let md = """
      ---
      title: Demo
      author: Test
      ---

      # ATX Heading

      Intro paragraph.

      Setext Heading
      --------------

      ## Setext Heading

      - bullet one

      | A | B |
      | - | - |
      | 1 | 2 |

      ```swift
      print("hi")
      ```
      """

    let url = try makeTempFile(contents: md)
    let envelope = try UMAFNormalization.envelopeV0_5(fromFileURL: url)
    let spans = spanMap(for: envelope)

    // Headings
    let headingBlocks = envelope.blocks.filter { $0.kind == .section }
    XCTAssertFalse(headingBlocks.isEmpty)
    for block in headingBlocks {
      XCTAssertEqual(block.provenance, "umaf:0.5.0:markdown:heading-atx")
      XCTAssertEqual(block.confidence, 1.0)
    }

    // Bullets
    let bulletBlocks = envelope.blocks.filter { $0.kind == .bullet }
    XCTAssertEqual(bulletBlocks.count, 1)
    XCTAssertEqual(bulletBlocks.first?.provenance, "umaf:0.5.0:markdown:bullet")
    XCTAssertEqual(bulletBlocks.first?.confidence, 1.0)

    // Paragraphs
    let paragraphBlocks = envelope.blocks.filter { $0.kind == .paragraph }
    XCTAssertFalse(paragraphBlocks.isEmpty)
    XCTAssertEqual(paragraphBlocks.first?.provenance, "umaf:0.5.0:markdown:paragraph")
    XCTAssertEqual(paragraphBlocks.first?.confidence, 0.9)

    // Table
    let tableBlocks = envelope.blocks.filter { $0.kind == .table }
    XCTAssertEqual(tableBlocks.count, 1)
    let table = try XCTUnwrap(tableBlocks.first)
    XCTAssertEqual(table.provenance, "umaf:0.5.0:markdown:table:pipe")
    XCTAssertEqual(table.confidence, 1.0)

    // Code
    let codeBlocks = envelope.blocks.filter { $0.kind == .code }
    XCTAssertEqual(codeBlocks.count, 1)
    XCTAssertEqual(codeBlocks.first?.provenance, "umaf:0.5.0:markdown:code:fenced-backtick")
    XCTAssertEqual(codeBlocks.first?.confidence, 1.0)

    // Front matter
    let frontBlocks = envelope.blocks.filter { $0.kind == .frontMatter }
    XCTAssertEqual(frontBlocks.count, 1)
    XCTAssertEqual(frontBlocks.first?.provenance, "umaf:0.5.0:markdown:front-matter:yaml")
    XCTAssertEqual(frontBlocks.first?.confidence, 1.0)

    // All blocks still have valid spans.
    for block in envelope.blocks {
      XCTAssertNotNil(spans[block.spanId])
    }
  }
}
