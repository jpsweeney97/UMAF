//
//  CacheStore.swift
//  UMAFCore
//
//  Thread-safe incremental build cache using Swift Actors.
//

import Foundation

public actor IncrementalCache {

  private static let cacheVersion = "1.0.0"

  struct Entry: Codable, Sendable {
    let mtime: TimeInterval
    let size: Int64
    let success: Bool
  }

  struct CacheIndex: Codable, Sendable {
    let version: String
    var entries: [String: Entry]
  }

  private let indexURL: URL
  private var cacheIndex: CacheIndex
  private let fileManager = FileManager.default

  public init(inputDir: URL) {
    // Hash the input path to create a unique cache file for this specific directory.
    // This allows caching multiple projects without collision.
    let inputPathHash =
      inputDir.path.data(using: .utf8)?.base64EncodedString()
      ?? inputDir.lastPathComponent
    let cacheFilename = "umaf-cache-\(inputPathHash).json"

    // Try to use the system user cache directory
    if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
      // Create a subdir for UMAF if it doesn't exist
      let umafCacheDir = cacheDir.appendingPathComponent("dev.umaf.cli")
      try? FileManager.default.createDirectory(at: umafCacheDir, withIntermediateDirectories: true)
      self.indexURL = umafCacheDir.appendingPathComponent(cacheFilename)
    } else {
      // Fallback to local if system cache is unavailable (e.g. weird sandboxing)
      self.indexURL = inputDir.appendingPathComponent(".umaf-cache.json")
    }

    // Call static method to avoid actor isolation violation in init
    self.cacheIndex = IncrementalCache.loadIndex(from: self.indexURL)
  }

  public func shouldProcess(fileURL: URL, relativePath: String) -> Bool {
    guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
      let mtime = attrs[.modificationDate] as? Date,
      let size = attrs[.size] as? Int64
    else { return true }

    guard let cached = cacheIndex.entries[relativePath] else { return true }

    let matches =
      (abs(cached.mtime - mtime.timeIntervalSince1970) < 0.001) && (cached.size == size)
      && cached.success

    return !matches
  }

  public func didProcess(fileURL: URL, relativePath: String) {
    guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
      let mtime = attrs[.modificationDate] as? Date,
      let size = attrs[.size] as? Int64
    else { return }

    let entry = Entry(
      mtime: mtime.timeIntervalSince1970,
      size: size,
      success: true
    )

    cacheIndex.entries[relativePath] = entry
  }

  private static func loadIndex(from url: URL) -> CacheIndex {
    guard let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode(CacheIndex.self, from: data),
      decoded.version == IncrementalCache.cacheVersion
    else {
      return CacheIndex(version: IncrementalCache.cacheVersion, entries: [:])
    }
    return decoded
  }

  public func save() {
    guard let data = try? JSONEncoder().encode(cacheIndex) else { return }
    try? data.write(to: indexURL, options: .atomic)
  }
}
