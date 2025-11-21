import Foundation

/// Create a unique temporary directory for test artifacts.
func makeTempDir() throws -> URL {
  let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
    UUID().uuidString,
    isDirectory: true
  )
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

/// Create a temporary file with provided contents. Optionally supply an extension or filename.
@discardableResult
func makeTempFile(
  contents: String,
  ext: String = "md",
  fileName: String = "sample"
) throws -> URL {
  let dir = try makeTempDir()
  let url = dir.appendingPathComponent("\(fileName).\(ext)")
  try contents.data(using: .utf8)!.write(to: url)
  return url
}
