//
//  Envelope.swift
//  UMAFCore
//
//  Strongly-typed UMAF envelope model (v0.7 schema).
//

import Foundation

/// Span of text in the normalized document (1-based lines; 0-based columns).
public struct UMAFSpanV0_7: Codable, Hashable {
  public let id: String
  public let startLine: Int
  public let endLine: Int
  public let startColumn: Int?
  public let endColumn: Int?

  public init(
    id: String,
    startLine: Int,
    endLine: Int,
    startColumn: Int? = nil,
    endColumn: Int? = nil
  ) {
    self.id = id
    self.startLine = startLine
    self.endLine = endLine
    self.startColumn = startColumn
    self.endColumn = endColumn
  }
}

/// High-level kind for a semantic block.
public enum UMAFBlockKindV0_7: String, Codable {
  case root
  case section
  case paragraph
  case bullet
  case table
  case code
  case frontMatter
  case raw
}

/// Logical block in the document, pointing at a `spanId`.
public struct UMAFBlockV0_7: Codable, Hashable {
  public let id: String
  public let kind: UMAFBlockKindV0_7
  public let spanId: String
  public let parentId: String?
  public let level: Int?
  public let heading: String?
  public let language: String?
  public let tableHeader: [String]?
  public let tableRows: [[String]]?
  public let metadata: [String: String]?

  /// Provenance of this block (e.g. rule path, extractor name).
  public let provenance: String

  /// Confidence score in [0, 1].
  public let confidence: Double

  public init(
    id: String,
    kind: UMAFBlockKindV0_7,
    spanId: String,
    parentId: String? = nil,
    level: Int? = nil,
    heading: String? = nil,
    language: String? = nil,
    tableHeader: [String]? = nil,
    tableRows: [[String]]? = nil,
    metadata: [String: String]? = nil,
    provenance: String,
    confidence: Double
  ) {
    self.id = id
    self.kind = kind
    self.spanId = spanId
    self.parentId = parentId
    self.level = level
    self.heading = heading
    self.language = language
    self.tableHeader = tableHeader
    self.tableRows = tableRows
    self.metadata = metadata
    self.provenance = provenance
    self.confidence = confidence
  }
}

/// UMAF envelope v0.7 – strongly-typed view of the JSON envelope.
public struct UMAFEnvelopeV0_7: Codable, Hashable {

  // MARK: - Nested semantic types

  public struct Section: Codable, Hashable {
    public let heading: String
    public let level: Int
    public let lines: [String]
    public let paragraphs: [String]

    public init(
      heading: String,
      level: Int,
      lines: [String],
      paragraphs: [String]
    ) {
      self.heading = heading
      self.level = level
      self.lines = lines
      self.paragraphs = paragraphs
    }
  }

  public struct Bullet: Codable, Hashable {
    public let text: String
    public let lineIndex: Int
    public let sectionHeading: String?
    public let sectionLevel: Int?

    public init(
      text: String,
      lineIndex: Int,
      sectionHeading: String? = nil,
      sectionLevel: Int? = nil
    ) {
      self.text = text
      self.lineIndex = lineIndex
      self.sectionHeading = sectionHeading
      self.sectionLevel = sectionLevel
    }
  }

  public struct FrontMatterEntry: Codable, Hashable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
      self.key = key
      self.value = value
    }
  }

  public struct Table: Codable, Hashable {
    public let startLineIndex: Int
    public let header: [String]
    public let rows: [[String]]

    public init(
      startLineIndex: Int,
      header: [String],
      rows: [[String]]
    ) {
      self.startLineIndex = startLineIndex
      self.header = header
      self.rows = rows
    }
  }

  public struct CodeBlock: Codable, Hashable {
    public let startLineIndex: Int
    public let language: String?
    public let code: String

    public init(
      startLineIndex: Int,
      language: String? = nil,
      code: String
    ) {
      self.startLineIndex = startLineIndex
      self.language = language
      self.code = code
    }
  }

  // MARK: - Core metadata (matches envelope JSON)

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

  // MARK: - Existing semantic fields

  public let sections: [Section]
  public let bullets: [Bullet]
  public let frontMatter: [FrontMatterEntry]
  public let tables: [Table]
  public let codeBlocks: [CodeBlock]

  // MARK: - Structural fields (mandatory in v0.7)

  /// All known spans in the document.
  public var spans: [UMAFSpanV0_7]
  /// All logical blocks, each pointing to a span.
  public var blocks: [UMAFBlockV0_7]
  /// Feature flags toggling optional semantics/fields.
  public var featureFlags: [String: Bool]

  // MARK: - Init

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
    sections: [Section] = [],
    bullets: [Bullet] = [],
    frontMatter: [FrontMatterEntry] = [],
    tables: [Table] = [],
    codeBlocks: [CodeBlock] = [],
    spans: [UMAFSpanV0_7],
    blocks: [UMAFBlockV0_7],
    featureFlags: [String: Bool] = ["structure": true]
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
    self.spans = spans
    self.blocks = blocks
    self.featureFlags = featureFlags
  }

  // MARK: - Codable defaults

  private enum CodingKeys: String, CodingKey {
    case version
    case docTitle
    case docId
    case createdAt
    case sourceHash
    case sourcePath
    case mediaType
    case encoding
    case sizeBytes
    case lineCount
    case normalized
    case sections
    case bullets
    case frontMatter
    case tables
    case codeBlocks
    case spans
    case blocks
    case featureFlags
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try c.decode(String.self, forKey: .version)
    self.docTitle = try c.decode(String.self, forKey: .docTitle)
    self.docId = try c.decode(String.self, forKey: .docId)
    self.createdAt = try c.decode(String.self, forKey: .createdAt)
    self.sourceHash = try c.decode(String.self, forKey: .sourceHash)
    self.sourcePath = try c.decode(String.self, forKey: .sourcePath)
    self.mediaType = try c.decode(String.self, forKey: .mediaType)
    self.encoding = try c.decode(String.self, forKey: .encoding)
    self.sizeBytes = try c.decode(Int.self, forKey: .sizeBytes)
    self.lineCount = try c.decode(Int.self, forKey: .lineCount)
    self.normalized = try c.decode(String.self, forKey: .normalized)

    self.sections = try c.decodeIfPresent([Section].self, forKey: .sections) ?? []
    self.bullets = try c.decodeIfPresent([Bullet].self, forKey: .bullets) ?? []
    self.frontMatter =
      try c.decodeIfPresent([FrontMatterEntry].self, forKey: .frontMatter) ?? []
    self.tables = try c.decodeIfPresent([Table].self, forKey: .tables) ?? []
    self.codeBlocks = try c.decodeIfPresent([CodeBlock].self, forKey: .codeBlocks) ?? []

    self.spans = try c.decode([UMAFSpanV0_7].self, forKey: .spans)
    self.blocks = try c.decode([UMAFBlockV0_7].self, forKey: .blocks)
    self.featureFlags = try c.decode([String: Bool].self, forKey: .featureFlags)
  }
}
