import XCTest

@testable import UMAFCore

final class HTMLParsingTests: XCTestCase {

  func testNestedHTMLParsing() throws {
    let html = """
      <html>
      <body>
        <h1>Title</h1>
        <div>
          <p>Intro paragraph.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
        </div>
        <h2>Subtitle</h2>
        <p>Nested <strong>bold</strong> text.</p>
      </body>
      </html>
      """

    let markdown = try HTMLAdapter.htmlToMarkdownish(html)

    // Assertions on the Markdown output
    XCTAssertTrue(markdown.contains("# Title"), "H1 should become #")
    XCTAssertTrue(markdown.contains("Intro paragraph."), "Paragraph text preserved")
    XCTAssertTrue(markdown.contains("- Item 1"), "LI should become dash bullet")
    XCTAssertTrue(markdown.contains("## Subtitle"), "H2 should become ##")

    // Check that tags are gone
    XCTAssertFalse(markdown.contains("<h1>"), "Tags should be stripped")
    XCTAssertFalse(markdown.contains("<div>"), "Div tags should be stripped")
  }

  func testMalformedHTMLResilience() throws {
    // Missing closing tags, messy case
    let html = "<H1>Broken</H1 <p>Stuff"

    let markdown = try HTMLAdapter.htmlToMarkdownish(html)

    XCTAssertTrue(markdown.contains("# Broken"))
    XCTAssertTrue(markdown.contains("Stuff"))
  }
}
