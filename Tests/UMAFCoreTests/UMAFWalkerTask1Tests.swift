import XCTest

@testable import UMAFCore

final class UMAFWalkerTask1Tests: XCTestCase {

  private func makeTempFile(with contents: String, ext: String = "md") throws -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("sample.\(ext)")
    try contents.data(using: .utf8)!.write(to: url)
    return url
  }

  func testEnvelopeHasRootSpanAndBlock() throws {
    let md = """
      # Title

      Body line
      """

    let url = try makeTempFile(with: md)
    let envelope = try UMAFNormalization.envelopeV0_7(fromFileURL: url)

    guard let rootSpan = envelope.spans.first(where: { $0.id == "span:root" }) else {
      XCTFail("Expected span:root")
      return
    }
    XCTAssertEqual(rootSpan.startLine, 1)
    XCTAssertEqual(rootSpan.endLine, envelope.lineCount)

    guard let rootBlock = envelope.blocks.first(where: { $0.id == "block:root" }) else {
      XCTFail("Expected block:root")
      return
    }
    XCTAssertEqual(rootBlock.spanId, rootSpan.id)

    let spanIds = Set(envelope.spans.map(\.id))
    for block in envelope.blocks {
      XCTAssertTrue(
        spanIds.contains(block.spanId),
        "Block \(block.id) should reference an existing span"
      )
    }

    for span in envelope.spans {
      XCTAssertGreaterThanOrEqual(span.startLine, 1)
      XCTAssertLessThanOrEqual(span.endLine, envelope.lineCount)
      XCTAssertLessThanOrEqual(span.startLine, span.endLine)
    }
  }
}
