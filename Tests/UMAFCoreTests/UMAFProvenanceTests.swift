import XCTest

@testable import UMAFCore

final class UMAFProvenanceTests: XCTestCase {

  func testPrefixSelectionCoversAdaptersAndPlain() {
    let p = UMAFVersion.provenance
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .markdown),
      "umaf:\(p):markdown"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .pdfkit),
      "umaf:\(p):adapter:pdfkit"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .docx),
      "umaf:\(p):adapter:docx"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .plainText),
      "umaf:\(p):plain-text"
    )
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: .ocr),
      "umaf:\(p):adapter:ocr"
    )

    // html falls under markdown prefix for v0.6.0
    XCTAssertEqual(
      BlockProvenanceV0_5.prefix(for: BlockProvenanceV0_5.source(for: "text/html")),
      "umaf:\(p):markdown"
    )
  }

  func testTableConfidenceRaggedness() {
    let tidy = BlockProvenanceV0_5.provenanceAndConfidence(
      for: .table,
      source: .markdown,
      tableInfo: BlockProvenanceV0_5.TableInfo(headerCount: 2, rowCounts: [2, 2])
    )
    XCTAssertEqual(tidy.confidence, 1.0)
    XCTAssertEqual(tidy.provenance, "umaf:\(UMAFVersion.provenance):markdown:table:pipe")

    let ragged = BlockProvenanceV0_5.provenanceAndConfidence(
      for: .table,
      source: .markdown,
      tableInfo: BlockProvenanceV0_5.TableInfo(headerCount: 2, rowCounts: [2, 3])
    )
    XCTAssertEqual(ragged.confidence, 0.8)
  }
}
