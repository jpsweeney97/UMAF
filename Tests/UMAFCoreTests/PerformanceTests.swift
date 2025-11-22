import XCTest

@testable import UMAFCore

final class PerformanceTests: XCTestCase {

  func testMarkdownCrucibleParsePerformance() throws {
    let root = projectRootURL()
    let crucible = root.appendingPathComponent("crucible/markdown-crucible-v2.md")
    let text = try String(contentsOf: crucible, encoding: .utf8)

    measure {
      _ = SwiftMarkdownAdapter.parse(text: text)
    }
  }

  // Helper to find project root
  private func projectRootURL(file: StaticString = #filePath) -> URL {
    let fileURL = URL(fileURLWithPath: String(describing: file))
    return
      fileURL
      .deletingLastPathComponent()  // PerformanceTests.swift
      .deletingLastPathComponent()  // UMAFCoreTests
      .deletingLastPathComponent()  // Tests -> root
  }
}
