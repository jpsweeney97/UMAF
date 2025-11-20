//
//  SchemaValidationTests.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

import XCTest

@testable import UMAFCore

final class SchemaValidationTests: XCTestCase {

  /// Helper to create a temp directory for test artifacts.
  private func makeTempDir() throws -> URL {
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    return tmpDir
  }

  /// Basic schema-ish check: envelopes produced from Markdown should contain
  /// all top-level keys that umaf_envelope_v0_5.json declares as required.
  func testMarkdownEnvelopeHasAllRequiredTopLevelFields() throws {
    let tmpDir = try makeTempDir()
    let md = """
      # Test Doc

      Hello world.

      - bullet
      """

    let inputURL = tmpDir.appendingPathComponent("schema-test.md")
    try md.data(using: .utf8)!.write(to: inputURL)

    let transformer = UMAFCoreEngine.Transformer()
    let data = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)

    let jsonAny = try JSONSerialization.jsonObject(with: data, options: [])
    guard let obj = jsonAny as? [String: Any] else {
      XCTFail("Envelope was not a JSON object")
      return
    }

    // These mirror the "required" keys in umaf_envelope_v0_5.json
    let requiredKeys = [
      "version",
      "docTitle",
      "docId",
      "createdAt",
      "sourceHash",
      "sourcePath",
      "mediaType",
      "encoding",
      "sizeBytes",
      "lineCount",
      "normalized",
    ]

    for key in requiredKeys {
      XCTAssertNotNil(obj[key], "Envelope is missing required key: \(key)")
    }
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
    let data = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)

    let env = try UMAFNormalization.envelopeV0_5(fromJSONData: data)
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
    let data = try transformer.transformFile(inputURL: inputURL, outputFormat: .jsonEnvelope)

    let env1 = try UMAFNormalization.envelopeV0_5(fromJSONData: data)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(env1)

    let env2 = try UMAFNormalization.envelopeV0_5(fromJSONData: encoded)

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
