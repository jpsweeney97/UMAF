import XCTest

@testable import UMAFCore

final class UMAFCLIIntegrationTests: XCTestCase {

  private func projectRootURL(file: StaticString = #filePath) -> URL {
    let fileURL = URL(fileURLWithPath: String(describing: file))
    return
      fileURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func cliURL() -> URL {
    projectRootURL().appendingPathComponent(".build/debug/umaf")
  }

  /// Optionally run Node+AJV schema validation if UMAF_ENABLE_NODE_SCHEMA_VALIDATE=1.
  /// This keeps the Swift CI job independent of Node/npm, while still allowing
  /// strict schema checks locally.
  private func runNodeSchemaValidationIfEnabled(
    envelopeURL: URL,
    projectRootURL root: URL
  ) throws {
    let env = ProcessInfo.processInfo.environment
    guard env["UMAF_ENABLE_NODE_SCHEMA_VALIDATE"] == "1" else {
      // In CI Swift job (default): skip Node-based schema validation.
      return
    }

    let validate = Process()
    validate.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    validate.arguments = [
      "node",
      "scripts/validate2020.mjs",
      "--schema", "spec/umaf-envelope-v0.5.0.json",
      "--data", envelopeURL.path,
      "--strict",
    ]
    validate.currentDirectoryURL = root

    let validateErr = Pipe()
    validate.standardError = validateErr
    validate.standardOutput = Pipe()

    try validate.run()
    validate.waitUntilExit()

    if validate.terminationStatus != 0 {
      let errData = validateErr.fileHandleForReading.readDataToEndOfFile()
      let err = String(data: errData, encoding: .utf8) ?? ""
      XCTFail("Schema validation failed: \(err)")
    }
  }

  func testDumpStructureFlagEmitsStructuralEnvelope() throws {
    let root = projectRootURL()
    let cli = cliURL()
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: cli.path),
      "CLI must be built before running integration test"
    )

    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString + ".json")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)

    // Run UMAF CLI with --json --dump-structure
    let proc = Process()
    proc.executableURL = cli
    proc.arguments = [
      "--input", root.appendingPathComponent("crucible/markdown-crucible-v2.md").path,
      "--json",
      "--dump-structure",
    ]
    proc.currentDirectoryURL = root

    let outHandle = try FileHandle(forWritingTo: outputURL)
    let errPipe = Pipe()
    proc.standardOutput = outHandle
    proc.standardError = errPipe

    try proc.run()
    proc.waitUntilExit()
    outHandle.closeFile()

    if proc.terminationStatus != 0 {
      let err = String(
        data: errPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      )
      XCTFail("CLI failed: \(err ?? "")")
      return
    }

    // Optional: Node + AJV schema validation (only when explicitly enabled).
    try runNodeSchemaValidationIfEnabled(
      envelopeURL: outputURL,
      projectRootURL: root
    )

    // Always: Swift-side structural assertions on UMAFEnvelopeV0_5
    let data = try Data(contentsOf: outputURL)
    let decoder = JSONDecoder()
    let envelope = try decoder.decode(UMAFEnvelopeV0_5.self, from: data)

    XCTAssertEqual(
      envelope.featureFlags?["structure"],
      true,
      "featureFlags.structure should be true when --dump-structure is used"
    )

    let spansById = Dictionary(uniqueKeysWithValues: envelope.spans.map { ($0.id, $0) })

    guard let rootSpan = spansById["span:root"] else {
      XCTFail("Expected span:root to be present in spans")
      return
    }
    XCTAssertEqual(rootSpan.startLine, 1)
    XCTAssertEqual(rootSpan.endLine, envelope.lineCount)

    guard let rootBlock = envelope.blocks.first(where: { $0.id == "block:root" }) else {
      XCTFail("Expected block:root to be present in blocks")
      return
    }
    XCTAssertEqual(rootBlock.kind, .root)
    XCTAssertNil(rootBlock.parentId)
    XCTAssertEqual(rootBlock.spanId, "span:root")

    for block in envelope.blocks {
      XCTAssertNotNil(
        spansById[block.spanId],
        "Block \(block.id) references missing span \(block.spanId)"
      )
    }

    for span in envelope.spans {
      XCTAssertGreaterThanOrEqual(span.startLine, 1)
      XCTAssertLessThanOrEqual(span.endLine, envelope.lineCount)
      XCTAssertLessThanOrEqual(span.startLine, span.endLine)
    }
  }
  func testDumpStructureRequiresJson() throws {
    let root = projectRootURL()
    let cli = cliURL()
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: cli.path),
      "CLI must be built before running integration test"
    )

    let proc = Process()
    proc.executableURL = cli
    proc.arguments = [
      "--input", root.appendingPathComponent("README.md").path,
      "--dump-structure",
    ]
    proc.currentDirectoryURL = root

    let errPipe = Pipe()
    proc.standardOutput = Pipe()
    proc.standardError = errPipe

    try proc.run()
    proc.waitUntilExit()

    XCTAssertNotEqual(
      proc.terminationStatus,
      0,
      "CLI should fail when --dump-structure is used without --json"
    )

    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    let err = String(data: errData, encoding: .utf8) ?? ""
    XCTAssertTrue(
      err.contains("--dump-structure requires --json"),
      "Expected error message about --dump-structure requiring --json, got: \(err)"
    )
  }

}
