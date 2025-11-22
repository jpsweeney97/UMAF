//
//  CoreModels.swift
//  UMAFCore
//
//  Shared core data models for UMAFCoreEngine.
//

import Foundation

extension UMAFCoreEngine {

  public struct Section: Codable {
    public let heading: String
    public let level: Int
    public let lines: [String]
    public let paragraphs: [String]

    // NEW: Explicit location in the normalized document (0-based indices)
    public let startLineIndex: Int
    public let endLineIndex: Int

    public init(
      heading: String,
      level: Int,
      lines: [String],
      paragraphs: [String],
      startLineIndex: Int = 0,
      endLineIndex: Int = 0
    ) {
      self.heading = heading
      self.level = level
      self.lines = lines
      self.paragraphs = paragraphs
      self.startLineIndex = startLineIndex
      self.endLineIndex = endLineIndex
    }
  }

  public struct Table: Codable {
    public let startLineIndex: Int
    public let header: [String]
    public let rows: [[String]]
  }

  public struct CodeBlock: Codable {
    public let startLineIndex: Int
    public let language: String?
    public let code: String
  }

  public struct Bullet: Codable {
    public let text: String
    public let lineIndex: Int
    public let sectionHeading: String?
    public let sectionLevel: Int?
  }

  public struct FrontMatterEntry: Codable {
    public let key: String
    public let value: String
  }

  public struct Envelope: Codable {
    public let version: String
    public let docTitle: String
    public let docId: String
    public let createdAt: String
    public let sourceHash: String
    public let sourcePath: String
    public let mediaType: String
    public let encoding: String
    public let sizeBytes: Int
    public let lineCount: Int
    public let normalized: String
    public let sections: [Section]
    public let bullets: [Bullet]
    public let frontMatter: [FrontMatterEntry]
    public let tables: [Table]
    public let codeBlocks: [CodeBlock]
  }

  public enum OutputFormat: String, CaseIterable {
    case jsonEnvelope
    case markdown
  }
}
