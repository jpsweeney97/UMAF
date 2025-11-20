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
  var input: String

  @Flag(name: .long, help: "Output a UMAF envelope (JSON).")
  var json: Bool = false

  @Flag(name: .long, help: "Output canonical normalized text (usually Markdown).")
  var normalized: Bool = false

  func run() throws {
    let url = URL(fileURLWithPath: input)
    let engine = UMAFEngine()

    if json {
      let env = try engine.envelope(for: url)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try enc.encode(env)
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data([0x0a]))  // newline
    } else if normalized {
      let text = try engine.normalizedText(for: url)
      FileHandle.standardOutput.write(Data(text.utf8))
      if !text.hasSuffix("\n") {
        FileHandle.standardOutput.write(Data([0x0a]))
      }
    } else {
      // default: emit envelope JSON
      let env = try engine.envelope(for: url)
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try enc.encode(env)
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data([0x0a]))
    }
  }
}
