import XCTest

@testable import UMAFCore

final class UMAFCoreTests: XCTestCase {

  // MARK: - Helpers

  /// Project root: directory that contains Package.swift.
  private func projectRootURL(file: StaticString = #filePath) -> URL {
    let fileURL = URL(fileURLWithPath: String(describing: file))
    // Tests/UMAFCoreTests/UMAFCoreTests.swift
    // -> Tests/UMAFCoreTests
    // -> Tests
    // -> <project root>
    return
      fileURL
      .deletingLastPathComponent()  // UMAFCoreTests.swift
      .deletingLastPathComponent()  // UMAFCoreTests
      .deletingLastPathComponent()  // Tests -> root
  }

  /// Root crucible file under ./crucible.
  private func crucibleURL() throws -> URL {
    let url = projectRootURL().appendingPathComponent("crucible/markdown-crucible-v2.md")
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: url.path),
      "Expected crucible file at \(url.path)"
    )
    return url
  }

  // MARK: - Basic engine tests

  func testMarkdownToEnvelopeHasRequiredFields() throws {
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

    let md = """
      # Test Doc

      Hello world.

      - bullet
      """

    let inputURL = tmpDir.appendingPathComponent("sample.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let data = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    XCTAssertEqual(json?["version"] as? String, "umaf-0.5.0")
    XCTAssertEqual(json?["mediaType"] as? String, "text/markdown")
    XCTAssertNotNil(json?["normalized"] as? String)
    XCTAssertGreaterThan(json?["lineCount"] as? Int ?? 0, 0)
  }

  func testIdempotentNormalization() throws {
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

    let md = """
      # Title

      A  line with   extra   spaces.

      | A | B |
      | - | - |
      | 1 | 2 |
      """

    let inputURL = tmpDir.appendingPathComponent("idempotent.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let envData = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    let normData = try transformer.transformFile(inputURL: inputURL, outputFormat: .markdown)

    // feed normalized back into the transformer; it should remain stable
    let normalizedPath = tmpDir.appendingPathComponent("normalized.md")
    try normData.write(to: normalizedPath)
    let envData2 = try transformer.transformFile(
      inputURL: normalizedPath,
      outputFormat: .jsonEnvelope
    )

    XCTAssertGreaterThan(envData.count, 0)
    XCTAssertEqual(
      envData.count,
      envData2.count,
      "envelope sizes should match after normalization pass"
    )
  }

  // MARK: - Crucible tests

  /// Full crucible -> envelope should succeed and satisfy basic invariants.
  func testCrucibleMarkdownProducesValidEnvelope() throws {
    let crucible = try crucibleURL()
    let transformer = UMAFCoreEngine.Transformer()
    let data = try transformer.transformFile(inputURL: crucible, outputFormat: .jsonEnvelope)

    let env = try UMAFNormalization.envelopeV0_5(fromJSONData: data)
    XCTAssertEqual(env.version, "umaf-0.5.0")
    XCTAssertGreaterThan(env.lineCount, 0)
    XCTAssertFalse(env.normalized.isEmpty)
  }

  /// Crucible normalization should be *idempotent once normalized*:
  /// running the normalizer again on its own output must produce
  /// byte-identical Markdown.
  func testCrucibleNormalizedIsStableAndConsistent() throws {
    let crucible = try crucibleURL()
    let transformer = UMAFCoreEngine.Transformer()

    // First normalization from the original crucible Markdown
    let norm1Data = try transformer.transformFile(
      inputURL: crucible,
      outputFormat: .markdown
    )
    guard let norm1 = String(data: norm1Data, encoding: .utf8) else {
      XCTFail("Failed to decode first normalized Markdown as UTF-8")
      return
    }

    // Write norm1 to a temp file
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let norm1URL = tmpDir.appendingPathComponent("crucible-normalized.md")
    try norm1Data.write(to: norm1URL)

    // Second normalization, starting from already-normalized Markdown
    let norm2Data = try transformer.transformFile(
      inputURL: norm1URL,
      outputFormat: .markdown
    )
    guard let norm2 = String(data: norm2Data, encoding: .utf8) else {
      XCTFail("Failed to decode second normalized Markdown as UTF-8")
      return
    }

    // Once in canonical form, UMAF must be a fixed point.
    XCTAssertEqual(
      norm1,
      norm2,
      "Crucible normalization should be idempotent once normalized."
    )
  }
}
