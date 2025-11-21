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

    let parsed = UMAFCoreEngine.parseSemanticStructure(
      from: md,
      mediaType: "text/markdown"
    )

    XCTAssertFalse(parsed.sections.isEmpty, "Expected at least one section")
    XCTAssertEqual(parsed.bullets.count, 2, "Expected two bullets")
    XCTAssertEqual(parsed.frontMatter.count, 1, "Expected one front matter entry")
    XCTAssertEqual(parsed.tables.count, 1, "Expected one table")
    XCTAssertEqual(parsed.codeBlocks.count, 1, "Expected one code block")
  }
}
