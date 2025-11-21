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
    let tmpDir = try makeTempDir()

    let md = """
      # Test Doc

      Hello world.

      - bullet
      """

    let inputURL = tmpDir.appendingPathComponent("sample.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    guard case .envelope(let env) = result else {
      XCTFail("Expected envelope result")
      return
    }

    XCTAssertEqual(env.version, "umaf-0.5.0")
    XCTAssertEqual(env.mediaType, "text/markdown")
    XCTAssertFalse(env.normalized.isEmpty)
    XCTAssertGreaterThan(env.lineCount, 0)
  }

  func testIdempotentNormalization() throws {
    let tmpDir = try makeTempDir()

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
    let envResult = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    let normResult = try transformer.transformFile(inputURL: inputURL, outputFormat: .markdown)

    guard case .envelope(let env) = envResult else {
      XCTFail("Expected envelope result")
      return
    }
    guard case .markdown(let norm) = normResult else {
      XCTFail("Expected markdown result")
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let envData = try encoder.encode(env)

    // feed normalized back into the transformer; it should remain stable
    let normalizedPath = tmpDir.appendingPathComponent("normalized.md")
    try Data(norm.utf8).write(to: normalizedPath)
    let envResult2 = try transformer.transformFile(
      inputURL: normalizedPath,
      outputFormat: .jsonEnvelope
    )
    guard case .envelope(let env2) = envResult2 else {
      XCTFail("Expected envelope result")
      return
    }
    let envData2 = try encoder.encode(env2)

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
    let result = try transformer.transformFile(inputURL: crucible, outputFormat: .jsonEnvelope)
    guard case .envelope(let coreEnv) = result else {
      XCTFail("Expected envelope result")
      return
    }

    let env = UMAFWalkerV0_5.ensureRootSpanAndBlock(UMAFWalkerV0_5.build(from: coreEnv))
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
    let norm1Result = try transformer.transformFile(
      inputURL: crucible,
      outputFormat: .markdown
    )
    guard case .markdown(let norm1) = norm1Result else {
      XCTFail("Expected markdown result")
      return
    }

    // Write norm1 to a temp file
    let tmpDir = try makeTempDir()
    let norm1URL = tmpDir.appendingPathComponent("crucible-normalized.md")
    try Data(norm1.utf8).write(to: norm1URL)

    // Second normalization, starting from already-normalized Markdown
    let norm2Result = try transformer.transformFile(
      inputURL: norm1URL,
      outputFormat: .markdown
    )
    guard case .markdown(let norm2) = norm2Result else {
      XCTFail("Expected markdown result")
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
