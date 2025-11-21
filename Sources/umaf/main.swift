import ArgumentParser
import Foundation
import Dispatch
import UMAFCore

@main
struct UMAFCLI: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "umaf",
    abstract: "UMAF – Universal Machine-readable Archive Format CLI"
  )

  @Option(name: .shortAndLong, help: "Path to the input file to transform. Reads from stdin if omitted.")
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

  // Thread-safe state container using NSLock (Linux compatible)
  class BatchState {
    var successCount = 0
    var errorCount = 0
    private let lock = NSLock()

    func addSuccess() {
        lock.lock()
        successCount += 1
        lock.unlock()
    }

    func addError() {
        lock.lock()
        errorCount += 1
        lock.unlock()
    }
  }

  func run() throws {
    if let inDir = inputDir {
      guard let outDir = outputDir else {
        throw ValidationError("Batch mode (--input-dir) requires --output-dir.")
      }
      
      if watch {
        #if os(macOS)
        if #available(macOS 10.10, *) {
          try runWatchMode(inputDir: inDir, outputDir: outDir)
        } else {
          print("Error: Watch mode requires a modern macOS.")
          throw ExitCode.failure
        }
        #else
        print("Error: Watch mode is currently only supported on macOS.")
        throw ExitCode.failure
        #endif
      } else {
        try runBatch(inputDir: inDir, outputDir: outDir)
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

  func runWatchMode(inputDir: String, outputDir: String) throws {
    #if os(macOS)
    print("👀 Watching \(inputDir) for changes...")
    try? runBatch(inputDir: inputDir, outputDir: outputDir, forceIncremental: true)

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
            do {
                try self.runBatch(inputDir: inputDir, outputDir: outputDir, forceIncremental: true)
            } catch {
                print("Error during re-process: \(error)")
            }
        }
        timer?.resume()
    }

    source.setCancelHandler { close(fileDescriptor) }
    source.resume()
    dispatchMain()
    #endif
  }

  func runBatch(inputDir: String, outputDir: String, forceIncremental: Bool = false) throws {
    let fm = FileManager.default
    let inUrl = URL(fileURLWithPath: inputDir)
    let outUrl = URL(fileURLWithPath: outputDir)
    let useCache = incremental || forceIncremental

    if !fm.fileExists(atPath: outputDir) {
      try fm.createDirectory(at: outUrl, withIntermediateDirectories: true)
    }

    let cache = useCache ? IncrementalCache(inputDir: inUrl) : nil

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
        if let cache = cache {
            let path = fileURL.path.replacingOccurrences(of: inUrl.path + "/", with: "")
            if cache.shouldProcess(fileURL: fileURL, relativePath: path) {
                filesToProcess.append(fileURL)
            }
        } else {
            filesToProcess.append(fileURL)
        }
      }
    }

    if filesToProcess.isEmpty {
        print("✨ No changes detected. All files up to date.")
        return
    }

    print("→ Parallel processing \(filesToProcess.count) files...")

    let engine = UMAFEngine()
    let state = BatchState()

    DispatchQueue.concurrentPerform(iterations: filesToProcess.count) { index in
      let fileURL = filesToProcess[index]
      let filename = fileURL.lastPathComponent
      let relativePath = fileURL.path.replacingOccurrences(of: inUrl.path + "/", with: "")
      
      let outFilename: String
      if json { outFilename = filename + ".json" }
      else if normalized { outFilename = filename + ".md" }
      else { outFilename = filename + ".json" }
      
      let destination = outUrl.appendingPathComponent(outFilename)

      do {
        let data = try Data(contentsOf: fileURL)
        let outputData = try processDataToMemory(data: data, sourceURL: fileURL, engine: engine)
        
        try atomicWrite(data: outputData, to: destination)
        
        cache?.didProcess(fileURL: fileURL, relativePath: relativePath)
        state.addSuccess()
      } catch {
        state.addError()
        print("❌ Failed to process \(filename): \(error)")
      }
    }

    cache?.save()

    print("✔ Batch complete. Processed: \(state.successCount), Errors: \(state.errorCount).")
    
    if state.errorCount > 0 {
        throw ExitCode.failure
    }
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
      var env = try engine.envelope(for: sourceURL)
      if dumpStructure {
        env = UMAFNormalization.withRootSpanAndBlock(env)
        var flags = env.featureFlags ?? [:]
        flags["structure"] = true
        env.featureFlags = flags
      }
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
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
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
