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

    public func asEnvelopeSection() -> UMAFEnvelopeV0_7.Section {
      UMAFEnvelopeV0_7.Section(heading: heading, level: level, lines: lines, paragraphs: paragraphs)
    }
  }

  public typealias Table = UMAFEnvelopeV0_7.Table
  public typealias CodeBlock = UMAFEnvelopeV0_7.CodeBlock
  public typealias Bullet = UMAFEnvelopeV0_7.Bullet
  public typealias FrontMatterEntry = UMAFEnvelopeV0_7.FrontMatterEntry

  /// Intermediate semantic envelope emitted by adapters before structural spans/blocks are added.
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

    public init(
      version: String,
      docTitle: String,
      docId: String,
      createdAt: String,
      sourceHash: String,
      sourcePath: String,
      mediaType: String,
      encoding: String,
      sizeBytes: Int,
      lineCount: Int,
      normalized: String,
      sections: [Section],
      bullets: [Bullet],
      frontMatter: [FrontMatterEntry],
      tables: [Table],
      codeBlocks: [CodeBlock]
    ) {
      self.version = version
      self.docTitle = docTitle
      self.docId = docId
      self.createdAt = createdAt
      self.sourceHash = sourceHash
      self.sourcePath = sourcePath
      self.mediaType = mediaType
      self.encoding = encoding
      self.sizeBytes = sizeBytes
      self.lineCount = lineCount
      self.normalized = normalized
      self.sections = sections
      self.bullets = bullets
      self.frontMatter = frontMatter
      self.tables = tables
      self.codeBlocks = codeBlocks
    }
  }

  public enum OutputFormat: String, CaseIterable {
    case jsonEnvelope
    case markdown
  }
}
