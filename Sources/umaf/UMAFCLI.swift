import ArgumentParser
import Dispatch
import Foundation
import UMAFCore

// Import Darwin for macOS or Glibc for Linux to access system calls if strictly needed.
#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

@main
struct UMAFCLI: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "umaf",
    abstract: "UMAF – Universal Machine-readable Archive Format CLI"
  )

  @Option(
    name: .shortAndLong, help: "Path to the input file to transform. Reads from stdin if omitted.")
  var input: String?

  @Option(name: .long, help: "Path to a directory of input files to transform (Batch Mode).")
  var inputDir: String?

  @Option(name: .long, help: "Path to the output directory (required for Batch Mode).")
  var outputDir: String?

  @Flag(name: .long, help: "Watch input directory for changes and re-process instantly.")
  var watch: Bool = false

  @Flag(name: .long, help: "Skip files that haven't changed since the last run.")
  var incremental: Bool = false

  @Flag(name: .long, help: "Output a UMAF envelope (JSON).")
  var json: Bool = false

  @Flag(name: .long, help: "Output canonical normalized text (usually Markdown).")
  var normalized: Bool = false

  @Flag(
    name: .long,
    help: "Populate and emit structural spans/blocks alongside the envelope JSON."
  )
  var dumpStructure: Bool = false

  // Thread-safe state container using Actor
  actor BatchState {
    var successCount = 0
    var errorCount = 0

    func addSuccess() { successCount += 1 }
    func addError() { errorCount += 1 }
  }

  mutating func run() async throws {
    if let inDir = inputDir {
      guard let outDir = outputDir else {
        throw ValidationError("Batch mode (--input-dir) requires --output-dir.")
      }

      if watch {
        #if os(macOS)
          if #available(macOS 10.15, *) {
            try await runWatchMode(inputDir: inDir, outputDir: outDir)
          } else {
            print("Error: Watch mode requires a modern macOS.")
            throw ExitCode.failure
          }
        #else
          print("Error: Watch mode is currently only supported on macOS.")
          throw ExitCode.failure
        #endif
      } else {
        try await runBatch(inputDir: inDir, outputDir: outDir)
      }
      return
    }

    // Single File / Stdin Mode
    if let inputPath = input {
      let url = URL(fileURLWithPath: inputPath)
      let data = try Data(contentsOf: url)
      try processData(data: data, sourceURL: url, to: FileHandle.standardOutput)
    } else {
      let data = FileHandle.standardInput.readDataToEndOfFile()
      if data.isEmpty {
        print(UMAFCLI.helpMessage())
        return
      }
      let dummyURL = URL(fileURLWithPath: "stdin.md")
      try processData(data: data, sourceURL: dummyURL, to: FileHandle.standardOutput)
    }
  }

  func runWatchMode(inputDir: String, outputDir: String) async throws {
    #if os(macOS)
      print("👀 Watching \(inputDir) for changes...")
      try? await runBatch(inputDir: inputDir, outputDir: outputDir, forceIncremental: true)

      let inUrl = URL(fileURLWithPath: inputDir)
      let fileDescriptor = open(inUrl.path, O_EVTONLY)

      guard fileDescriptor >= 0 else {
        print("❌ Failed to open directory for watching.")
        throw ExitCode.failure
      }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fileDescriptor,
        eventMask: .write,
        queue: DispatchQueue.global()
      )

      var timer: DispatchSourceTimer?

      source.setEventHandler {
        timer?.cancel()
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer?.schedule(deadline: .now() + 0.2)
        timer?.setEventHandler {
          print("\n🔄 Change detected. Re-processing...")
          Task {
            do {
              try await self.runBatch(
                inputDir: inputDir, outputDir: outputDir, forceIncremental: true)
            } catch {
              print("Error during re-process: \(error)")
            }
          }
        }
        timer?.resume()
      }

      source.setCancelHandler { close(fileDescriptor) }
      source.resume()

      defer {
        timer?.cancel()
        source.cancel()
      }

      while !Task.isCancelled {
        try await Task.sleep(nanoseconds: 1_000_000_000)
      }
    #endif
  }

  func runBatch(inputDir: String, outputDir: String, forceIncremental: Bool = false) async throws {
    let fm = FileManager.default
    let inUrl = URL(fileURLWithPath: inputDir)
    let outUrl = URL(fileURLWithPath: outputDir)
    let useCache = incremental || forceIncremental

    if !fm.fileExists(atPath: outputDir) {
      try fm.createDirectory(at: outUrl, withIntermediateDirectories: true)
    }

    let cache = useCache ? IncrementalCache(inputDir: inUrl) : nil

    print("→ Scanning \(inputDir)...")

    // FIX: Step 1 - Synchronously gather all candidates first.
    // This prevents the non-Sendable enumerator from overlapping with async await calls.
    let allCandidates = scanCandidates(in: inUrl)

    // FIX: Step 2 - Asynchronously filter them using the actor.
    var filesToProcess: [URL] = []
    if let cache = cache {
      for fileURL in allCandidates {
        let relativePath = fileURL.path.replacingOccurrences(of: inUrl.path + "/", with: "")
        if await cache.shouldProcess(fileURL: fileURL, relativePath: relativePath) {
          filesToProcess.append(fileURL)
        }
      }
    } else {
      filesToProcess = allCandidates
    }

    if filesToProcess.isEmpty {
      print("✨ No changes detected. All files up to date.")
      return
    }

    print("→ Parallel processing \(filesToProcess.count) files...")

    let engine = UMAFEngine()
    let state = BatchState()
    let maxConcurrent = max(2, ProcessInfo.processInfo.activeProcessorCount)

    // Capture immutable list for the task group
    let inputs = filesToProcess

    await withTaskGroup(of: Void.self) { group in
      var iterator = inputs.makeIterator()
      var active = 0

      func enqueueAvailable() {
        while active < maxConcurrent, let fileURL = iterator.next() {
          active += 1
          group.addTask {
            let filename = fileURL.lastPathComponent
            let relativePath = fileURL.path.replacingOccurrences(of: inUrl.path + "/", with: "")

            let outFilename: String
            if self.json {
              outFilename = filename + ".json"
            } else if self.normalized {
              outFilename = filename + ".md"
            } else {
              outFilename = filename + ".json"
            }

            let destination = outUrl.appendingPathComponent(outFilename)

            do {
              let data = try Data(contentsOf: fileURL)
              let outputData = try self.processDataToMemory(
                data: data, sourceURL: fileURL, engine: engine)

              try self.atomicWrite(data: outputData, to: destination)

              await cache?.didProcess(fileURL: fileURL, relativePath: relativePath)
              await state.addSuccess()
            } catch {
              await state.addError()
              print("❌ Failed to process \(filename): \(error)")
            }
          }
        }
      }

      enqueueAvailable()
      while await group.next() != nil {
        active -= 1
        enqueueAvailable()
      }
    }

    await cache?.save()

    let success = await state.successCount
    let errors = await state.errorCount
    print("✔ Batch complete. Processed: \(success), Errors: \(errors).")

    if errors > 0 {
      throw ExitCode.failure
    }
  }

  // Helper to isolate the non-Sendable NSDirectoryEnumerator
  func scanCandidates(in directory: URL) -> [URL] {
    let fm = FileManager.default
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
    guard
      let enumerator = fm.enumerator(
        at: directory,
        includingPropertiesForKeys: resourceKeys,
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    var results: [URL] = []
    for case let fileURL as URL in enumerator {
      guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
        resourceValues.isRegularFile == true
      else { continue }

      let ext = fileURL.pathExtension.lowercased()
      if ["md", "txt", "json", "html", "pdf", "docx"].contains(ext) {
        results.append(fileURL)
      }
    }
    return results
  }

  func atomicWrite(data: Data, to url: URL) throws {
    let tempURL = url.appendingPathExtension("tmp")
    try data.write(to: tempURL, options: .atomic)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: tempURL, to: url)
  }

  func processDataToMemory(
    data: Data,
    sourceURL: URL,
    engine: UMAFEngine
  ) throws -> Data {
    if dumpStructure && !json {
      throw ValidationError("--dump-structure requires --json")
    }

    if json {
      let env = try engine.envelope(
        for: sourceURL,
        options: UMAFEngine.Options(
          includeStructure: dumpStructure,
          setStructureFeatureFlag: dumpStructure
        )
      )
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      var out = try enc.encode(env)
      out.append(0x0a)
      return out
    } else if normalized {
      let text = try engine.normalizedText(for: sourceURL)
      var out = Data(text.utf8)
      if !text.hasSuffix("\n") { out.append(0x0a) }
      return out
    } else {
      let env = try engine.envelope(for: sourceURL)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      var out = try enc.encode(env)
      out.append(0x0a)
      return out
    }
  }

  func processData(
    data: Data,
    sourceURL: URL,
    to handle: FileHandle,
    engine: UMAFEngine = UMAFEngine()
  ) throws {
    if sourceURL.path == "stdin.md" {
      let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".md")
      try data.write(to: tmp)
      let outData = try processDataToMemory(data: data, sourceURL: tmp, engine: engine)
      handle.write(outData)
      try? FileManager.default.removeItem(at: tmp)
    } else {
      let outData = try processDataToMemory(data: data, sourceURL: sourceURL, engine: engine)
      handle.write(outData)
    }
  }
}
