import XCTest

@testable import UMAFCore

final class SemanticParsingTests: XCTestCase {

  func testSemanticParserFindsMarkdownStructures() throws {
    let md = """
      ---
      title: Test Doc
      ---

      # Heading 1

      Hello *world*.

      - bullet one
      - bullet two

      | A | B |
      | - | - |
      | 1 | 2 |

      ```swift
      print("hi")
      ```
      """

    // Create a temp file for the transformer
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString + ".md")
    try md.write(to: tempURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    // Use the Transformer API
    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(inputURL: tempURL, outputFormat: .jsonEnvelope)

    guard case .envelope(let envelope) = result else {
      XCTFail("Expected envelope result")
      return
    }

    // Assert against the envelope's semantic properties
    XCTAssertFalse(envelope.sections.isEmpty, "Expected at least one section")
    XCTAssertEqual(envelope.bullets.count, 2, "Expected two bullets")
    XCTAssertEqual(envelope.frontMatter.count, 1, "Expected one front matter entry")
    XCTAssertEqual(envelope.tables.count, 1, "Expected one table")
    XCTAssertEqual(envelope.codeBlocks.count, 1, "Expected one code block")
  }
}
