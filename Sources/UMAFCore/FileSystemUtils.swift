//
//  FileSystemUtils.swift
//  UMAFCore
//
//  Shared file-system helpers for scanning and atomic/streaming writes.
//

import Foundation

public enum UMAFFileSystemUtils {

  /// Lazy sequence over files matching allowed extensions and optional filter.
  public static func scanCandidatesLazy(
    in directory: URL,
    allowedExtensions: [String],
    filter: ((URL) -> Bool)? = nil
  ) -> AnySequence<URL> {
    let allowed = Set(allowedExtensions.map { $0.lowercased() })
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
    return AnySequence {
      guard
        let enumerator = FileManager.default.enumerator(
          at: directory,
          includingPropertiesForKeys: resourceKeys,
          options: [.skipsHiddenFiles]
        )
      else { return AnyIterator<URL> { nil } }

      return AnyIterator {
        while let next = enumerator.nextObject() as? URL {
          guard let resourceValues = try? next.resourceValues(forKeys: Set(resourceKeys)),
            resourceValues.isRegularFile == true
          else { continue }
          let ext = next.pathExtension.lowercased()
          if !allowed.isEmpty && !allowed.contains(ext) { continue }
          if let filter = filter, !filter(next) { continue }
          return next
        }
        return nil
      }
    }
  }

  /// Eager helper built on the lazy scanner.
  public static func scanCandidates(
    in directory: URL,
    allowedExtensions: [String],
    filter: ((URL) -> Bool)? = nil
  ) -> [URL] {
    Array(scanCandidatesLazy(in: directory, allowedExtensions: allowedExtensions, filter: filter))
  }

  /// Atomically write data by streaming in chunks to avoid large copies.
  public static func atomicWriteStream(
    data: Data,
    to url: URL,
    chunkSize: Int = 64 * 1024
  ) throws {
    let tempURL = url.appendingPathExtension("tmp")
    FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
    let handle = try FileHandle(forWritingTo: tempURL)
    var offset = 0
    while offset < data.count {
      let end = min(offset + chunkSize, data.count)
      let slice = data.subdata(in: offset..<end)
      try handle.write(contentsOf: slice)
      offset = end
    }
    try handle.close()
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: tempURL, to: url)
  }
}
