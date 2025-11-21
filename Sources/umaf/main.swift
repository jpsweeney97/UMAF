import ArgumentParser
import Foundation
import UMAFCore

@main
struct UMAFCLI: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "umaf",
    abstract: "UMAF – Universal Machine-readable Archive Format CLI"
  )

  @Option(name: .shortAndLong, help: "Path to the input file to transform.")
  var input: String?

  @Option(name: .long, help: "Path to a directory of input files to transform (Batch Mode).")
  var inputDir: String?

  @Option(name: .long, help: "Path to the output directory (required for Batch Mode).")
  var outputDir: String?

  @Flag(name: .long, help: "Output a UMAF envelope (JSON).")
  var json: Bool = false

  @Flag(name: .long, help: "Output canonical normalized text (usually Markdown).")
  var normalized: Bool = false

  @Flag(
    name: .long,
    help: "Populate and emit structural spans/blocks alongside the envelope JSON."
  )
  var dumpStructure: Bool = false

  func run() throws {
    // 1. Batch Mode
    if let inDir = inputDir {
      guard let outDir = outputDir else {
        throw ValidationError("Batch mode (--input-dir) requires --output-dir.")
      }
      try runBatch(inputDir: inDir, outputDir: outDir)
      return
    }

    // 2. Single File Mode
    guard let inputPath = input else {
      throw ValidationError("Either --input or --input-dir must be provided.")
    }
    
    let url = URL(fileURLWithPath: inputPath)
    try processSingleFile(url: url, to: FileHandle.standardOutput)
  }

  /// Process a directory of files serially (avoids process spawn overhead).
  func runBatch(inputDir: String, outputDir: String) throws {
    let fm = FileManager.default
    let inUrl = URL(fileURLWithPath: inputDir)
    let outUrl = URL(fileURLWithPath: outputDir)

    // Create output dir if missing
    if !fm.fileExists(atPath: outputDir) {
      try fm.createDirectory(at: outUrl, withIntermediateDirectories: true)
    }

    let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
    let enumerator = fm.enumerator(
      at: inUrl,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    )!

    let engine = UMAFEngine() // Initialize engine once

    print("→ Batch processing \(inputDir)...")
    var count = 0
    var errors = 0

    for case let fileURL as URL in enumerator {
      guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
            resourceValues.isRegularFile == true
      else { continue }

      // Simple extension filter
      let ext = fileURL.pathExtension.lowercased()
      guard ["md", "txt", "json", "html", "pdf", "docx"].contains(ext) else { continue }

      // Determine output filename
      let filename = fileURL.lastPathComponent
      let outFilename: String
      if json {
        outFilename = filename + ".json"
      } else if normalized {
        outFilename = filename + ".md" // simplify normalization to .md
      } else {
        outFilename = filename + ".json" // default
      }
      
      let destination = outUrl.appendingPathComponent(outFilename)

      // Process
      do {
        // We manually manage the file handle to write to disk
        if !fm.createFile(atPath: destination.path, contents: nil) {
             print("❌ Failed to create output file: \(destination.path)")
             errors += 1
             continue
        }
        let handle = try FileHandle(forWritingTo: destination)
        try processSingleFile(url: fileURL, to: handle, engine: engine)
        try handle.close()
        count += 1
      } catch {
        print("❌ Failed to process \(filename): \(error)")
        errors += 1
      }
    }
    print("✔ Processed \(count) files with \(errors) errors.")
    
    if errors > 0 {
        throw ExitCode.failure
    }
  }

  func processSingleFile(
    url: URL, 
    to handle: FileHandle, 
    engine: UMAFEngine = UMAFEngine()
  ) throws {
    if dumpStructure && !json {
      throw ValidationError("--dump-structure requires --json")
    }

    if json {
      var env = try engine.envelope(for: url)
      if dumpStructure {
        env = UMAFNormalization.withRootSpanAndBlock(env)
        var flags = env.featureFlags ?? [:]
        flags["structure"] = true
        env.featureFlags = flags
      }
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try enc.encode(env)
      handle.write(data)
      handle.write(Data([0x0a]))  // newline
    } else if normalized {
      let text = try engine.normalizedText(for: url)
      handle.write(Data(text.utf8))
      if !text.hasSuffix("\n") {
        handle.write(Data([0x0a]))
      }
    } else {
      // default: emit envelope JSON
      let env = try engine.envelope(for: url)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try enc.encode(env)
      handle.write(data)
      handle.write(Data([0x0a]))
    }
  }
}
