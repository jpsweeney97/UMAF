//
//  MarkdownEngineV2Tests.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

import XCTest

@testable import UMAFCore

final class MarkdownEngineV2Tests: XCTestCase {

  func testEngineV2MatchesLegacyParserForBasicMarkdown() throws {
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

    let legacy = UMAFCoreEngine.parseSemanticStructure(
      from: md,
      mediaType: "text/markdown"
    )

    let v2 = MarkdownEngineV2.parseSemanticStructure(from: md)

    XCTAssertEqual(legacy.sections.count, v2.sections.count, "sections count should match")
    XCTAssertEqual(legacy.bullets.count, v2.bullets.count, "bullets count should match")
    XCTAssertEqual(legacy.frontMatter.count, v2.frontMatter.count, "frontMatter count should match")
    XCTAssertEqual(legacy.tables.count, v2.tables.count, "tables count should match")
    XCTAssertEqual(legacy.codeBlocks.count, v2.codeBlocks.count, "codeBlocks count should match")
  }
}
