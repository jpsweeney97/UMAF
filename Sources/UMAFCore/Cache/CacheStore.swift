//
//  CacheStore.swift
//  UMAFCore
//
//  Simple on-disk cache for UMAF envelopes, keyed by file hash.
//
//  Layout (per directory):
//    <inputDir>/.umaf-cache/index.json      // hash -> CacheEntry
//    <inputDir>/.umaf-cache/<hash>.json    // cached envelope JSON
//

import Foundation
import CryptoKit

public struct CacheEntry: Codable, Hashable {
  public let hash: String
  public let envelopePath: String
  public let createdAt: String

  public init(hash: String, envelopePath: String, createdAt: String) {
    self.hash = hash
    self.envelopePath = envelopePath
    self.createdAt = createdAt
  }
}

public enum CacheStore {

  /// Attempt to load a cached envelope for the given source file URL.
  /// Returns (envelopeData, CacheEntry) on hit, or nil on miss.
  public static func cachedEnvelope(forSourceURL url: URL) -> (Data, CacheEntry)? {
    guard let sourceData = try? Data(contentsOf: url) else { return nil }
    let hash = computeHash(for: sourceData)

    let indexURL = indexURL(forSourceURL: url)
    guard
      let indexData = try? Data(contentsOf: indexURL),
      let index = try? JSONDecoder().decode([String: CacheEntry].self, from: indexData),
      let entry = index[hash]
    else {
      return nil
    }

    let envelopeURL = URL(fileURLWithPath: entry.envelopePath)
    guard let envelopeData = try? Data(contentsOf: envelopeURL) else {
      return nil
    }
    return (envelopeData, entry)
  }

  /// Save an envelope JSON blob to cache for the given source file URL.
  /// Returns the CacheEntry describing the cached path.
  @discardableResult
  public static func saveEnvelopeToCache(
    _ envelopeData: Data,
    forSourceURL url: URL
  ) throws -> CacheEntry {
    let sourceData = try Data(contentsOf: url)
    let hash = computeHash(for: sourceData)

    let cacheDir = cacheDirectory(forSourceURL: url)
    try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let envelopeURL = cacheDir.appendingPathComponent("\(hash).json")
    try envelopeData.write(to: envelopeURL, options: .atomic)

    let createdAt = ISO8601DateFormatter().string(from: Date())
    let entry = CacheEntry(
      hash: hash,
      envelopePath: envelopeURL.path,
      createdAt: createdAt
    )

    let indexURL = self.indexURL(forSourceURL: url)
    var index: [String: CacheEntry] = [:]
    if let existingData = try? Data(contentsOf: indexURL),
       let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: existingData) {
      index = decoded
    }
    index[hash] = entry

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encodedIndex = try encoder.encode(index)
    try encodedIndex.write(to: indexURL, options: .atomic)

    return entry
  }

  // MARK: - Helpers

  private static func cacheDirectory(forSourceURL url: URL) -> URL {
    let dir = url.deletingLastPathComponent()
    return dir.appendingPathComponent(".umaf-cache", isDirectory: true)
  }

  private static func indexURL(forSourceURL url: URL) -> URL {
    return cacheDirectory(forSourceURL: url).appendingPathComponent("index.json")
  }

  private static func computeHash(for data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
