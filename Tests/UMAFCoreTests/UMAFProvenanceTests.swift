import XCTest

@testable import UMAFCore

final class UMAFProvenanceTests: XCTestCase {

  func testPrefixSelectionCoversAdaptersAndPlain() {
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .markdown),
      "umaf:0.5.0:markdown"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .pdfkit),
      "umaf:0.5.0:adapter:pdfkit"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .docx),
      "umaf:0.5.0:adapter:docx"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .plainText),
      "umaf:0.5.0:plain-text"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .ocr),
      "umaf:0.5.0:adapter:ocr"
    )

    // html falls under markdown prefix for v0.5.0
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: BlockProvenanceV0_5.source(for: "text/html")),
      "umaf:0.5.0:markdown"
    )
  }

  func testTableConfidenceRaggedness() {
    let tidy = BlockProvenanceV0_5.provenanceAndConfidence(
      for: .table,
      source: .markdown,
      tableInfo: BlockProvenanceV0_5.TableInfo(headerCount: 2, rowCounts: [2, 2])
    )
    XCTAssertEqual(tidy.confidence, 1.0)
    XCTAssertEqual(tidy.provenance, "umaf:0.5.0:markdown:table:pipe")

    let ragged = BlockProvenanceV0_5.provenanceAndConfidence(
      for: .table,
      source: .markdown,
      tableInfo: BlockProvenanceV0_5.TableInfo(headerCount: 2, rowCounts: [2, 3])
    )
    XCTAssertEqual(ragged.confidence, 0.8)
  }
}
