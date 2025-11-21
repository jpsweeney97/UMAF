import ArgumentParser
import Foundation
import Dispatch
import UMAFCore
import os

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

  // Thread-safe state container
  struct BatchState: Sendable {
    var successCount = 0
    var errorCount = 0
  }

  func run() throws {
    if let inDir = inputDir {
      guard let outDir = outputDir else {
        throw ValidationError("Batch mode (--input-dir) requires --output-dir.")
      }
      try runBatch(inputDir: inDir, outputDir: outDir)
      return
    }

    guard let inputPath = input else {
      throw ValidationError("Either --input or --input-dir must be provided.")
    }
    
    let url = URL(fileURLWithPath: inputPath)
    try processSingleFile(url: url, to: FileHandle.standardOutput)
  }

  func runBatch(inputDir: String, outputDir: String) throws {
    let fm = FileManager.default
    let inUrl = URL(fileURLWithPath: inputDir)
    let outUrl = URL(fileURLWithPath: outputDir)

    if !fm.fileExists(atPath: outputDir) {
      try fm.createDirectory(at: outUrl, withIntermediateDirectories: true)
    }

    print("→ Scanning \(inputDir)...")
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
    guard let enumerator = fm.enumerator(
      at: inUrl,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles]
    ) else {
      throw ValidationError("Could not read input directory.")
    }

    var filesToProcess: [URL] = []
    for case let fileURL as URL in enumerator {
      guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
            resourceValues.isRegularFile == true
      else { continue }

      let ext = fileURL.pathExtension.lowercased()
      if ["md", "txt", "json", "html", "pdf", "docx"].contains(ext) {
        filesToProcess.append(fileURL)
      }
    }

    print("→ Parallel processing \(filesToProcess.count) files...")

    let engine = UMAFEngine()
    // OPTIMIZATION: Use OSAllocatedUnfairLock to protect the state struct
    let state = OSAllocatedUnfairLock(initialState: BatchState())

    DispatchQueue.concurrentPerform(iterations: filesToProcess.count) { index in
      let fileURL = filesToProcess[index]
      let filename = fileURL.lastPathComponent
      
      let outFilename: String
      if json { outFilename = filename + ".json" }
      else if normalized { outFilename = filename + ".md" }
      else { outFilename = filename + ".json" }
      
      let destination = outUrl.appendingPathComponent(outFilename)

      do {
        // Create file (thread-safe because paths are unique)
        if !FileManager.default.createFile(atPath: destination.path, contents: nil) {
             state.withLock { $0.errorCount += 1 }
             // Use a local print to avoid locking just for console output if possible, 
             // but strictly speaking print is not guaranteed atomic. 
             // For CLI tools, occasional interleaved output is acceptable vs locking overhead.
             print("❌ Failed to create output file: \(destination.path)")
             return
        }
        
        let handle = try FileHandle(forWritingTo: destination)
        try processSingleFile(url: fileURL, to: handle, engine: engine)
        try handle.close()
        
        state.withLock { $0.successCount += 1 }
      } catch {
        state.withLock { $0.errorCount += 1 }
        print("❌ Failed to process \(filename): \(error)")
      }
    }

    let finalState = state.withLock { $0 }
    print("✔ Batch complete. Processed \(finalState.successCount) files. Errors: \(finalState.errorCount).")
    
    if finalState.errorCount > 0 {
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
      handle.write(Data([0x0a]))
    } else if normalized {
      let text = try engine.normalizedText(for: url)
      handle.write(Data(text.utf8))
      if !text.hasSuffix("\n") {
        handle.write(Data([0x0a]))
      }
    } else {
      let env = try engine.envelope(for: url)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try enc.encode(env)
      handle.write(data)
      handle.write(Data([0x0a]))
    }
  }
}
