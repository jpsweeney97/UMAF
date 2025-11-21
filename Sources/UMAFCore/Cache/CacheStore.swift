//
//  CacheStore.swift
//  UMAFCore
//
//  Thread-safe incremental build cache (Linux compatible).
//

import Foundation

public final class IncrementalCache: @unchecked Sendable {
  
  private static let cacheVersion = "1.0.0"

  struct Entry: Codable {
    let mtime: TimeInterval
    let size: Int64
    let success: Bool
  }
  
  struct CacheIndex: Codable {
    let version: String
    var entries: [String: Entry]
  }
  
  private let indexURL: URL
  private var cacheIndex: CacheIndex
  private let lock = NSLock()
  private let fileManager = FileManager.default
  
  public init(inputDir: URL) {
    self.indexURL = inputDir.appendingPathComponent(".umaf-cache.json")
    self.cacheIndex = CacheIndex(version: Self.cacheVersion, entries: [:])
    self.load()
  }
  
  public func shouldProcess(fileURL: URL, relativePath: String) -> Bool {
    guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
          let mtime = attrs[.modificationDate] as? Date,
          let size = attrs[.size] as? Int64
    else { return true }
    
    lock.lock()
    defer { lock.unlock() }
    
    guard let cached = cacheIndex.entries[relativePath] else { return true }
    
    let matches = (abs(cached.mtime - mtime.timeIntervalSince1970) < 0.001) &&
                  (cached.size == size) &&
                  cached.success
    
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
    
    lock.lock()
    defer { lock.unlock() }
    cacheIndex.entries[relativePath] = entry
  }
  
  private func load() {
    guard let data = try? Data(contentsOf: indexURL),
          let decoded = try? JSONDecoder().decode(CacheIndex.self, from: data)
    else { return }
    
    if decoded.version == Self.cacheVersion {
        self.cacheIndex = decoded
    }
  }
  
  public func save() {
    lock.lock()
    defer { lock.unlock() }
    guard let data = try? JSONEncoder().encode(cacheIndex) else { return }
    try? data.write(to: indexURL, options: .atomic)
  }
}
