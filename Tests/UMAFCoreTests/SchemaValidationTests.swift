//
//  SchemaValidationTests.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

import XCTest

@testable import UMAFCore

final class SchemaValidationTests: XCTestCase {

  /// Basic schema-ish check: envelopes produced from Markdown should contain
  /// all top-level keys that umaf_envelope_v0_7.json declares as required.
  func testMarkdownEnvelopeHasAllRequiredTopLevelFields() throws {
    let tmpDir = try makeTempDir()
    let md = """
      # Test Doc

      Hello world.

      - bullet
      """

    let inputURL = tmpDir.appendingPathComponent("schema-test.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let env = try UMAFEngine().envelope(for: inputURL)

    XCTAssertFalse(env.version.isEmpty)
    XCTAssertFalse(env.docTitle.isEmpty)
    XCTAssertFalse(env.docId.isEmpty)
    XCTAssertFalse(env.createdAt.isEmpty)
    XCTAssertFalse(env.sourceHash.isEmpty)
    XCTAssertFalse(env.sourcePath.isEmpty)
    XCTAssertFalse(env.mediaType.isEmpty)
    XCTAssertFalse(env.encoding.isEmpty)
    XCTAssertGreaterThan(env.sizeBytes, 0)
    XCTAssertGreaterThan(env.lineCount, 0)
    XCTAssertFalse(env.normalized.isEmpty)
    XCTAssertFalse(env.spans.isEmpty)
    XCTAssertFalse(env.blocks.isEmpty)
    XCTAssertEqual(env.featureFlags["structure"], true)
  }

  /// Property-style test: lineCount must equal the number of lines
  /// in `normalized` when split with omittingEmptySubsequences: false.
  func testEnvelopeLineCountMatchesNormalizedContent() throws {
    let tmpDir = try makeTempDir()
    let md = """
      # Title

      First line.

      Second line with  spaces.

      - bullet
      - another bullet
      """

    let inputURL = tmpDir.appendingPathComponent("linecount-test.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    guard case .envelope(let env) = result else {
      XCTFail("Expected envelope result")
      return
    }

    let lines = env.normalized.split(separator: "\n", omittingEmptySubsequences: false)
    XCTAssertEqual(
      env.lineCount,
      lines.count,
      "lineCount (\(env.lineCount)) should equal normalized line count (\(lines.count))"
    )
  }

  /// Property-style test: typed envelope round-trips cleanly through JSONEncoder/Decoder
  /// without losing core metadata.
  func testTypedEnvelopeRoundTripPreservesCoreMetadata() throws {
    let tmpDir = try makeTempDir()
    let md = """
      # Roundtrip

      Some content here.

      | A | B |
      | - | - |
      | 1 | 2 |
      """

    let inputURL = tmpDir.appendingPathComponent("roundtrip.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)
    guard case .envelope(let coreEnv) = result else {
      XCTFail("Expected envelope result")
      return
    }

    let env1 = UMAFWalkerV0_7.ensureRootSpanAndBlock(UMAFWalkerV0_7.build(from: coreEnv))

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(env1)

    let decoder = JSONDecoder()
    let env2 = try decoder.decode(UMAFEnvelopeV0_7.self, from: encoded)

    XCTAssertEqual(env1.version, env2.version)
    XCTAssertEqual(env1.docTitle, env2.docTitle)
    XCTAssertEqual(env1.docId, env2.docId)
    XCTAssertEqual(env1.mediaType, env2.mediaType)
    XCTAssertEqual(env1.encoding, env2.encoding)
    XCTAssertEqual(env1.lineCount, env2.lineCount)
    XCTAssertEqual(env1.sizeBytes, env2.sizeBytes)
    XCTAssertEqual(env1.sourceHash, env2.sourceHash)
  }
}
