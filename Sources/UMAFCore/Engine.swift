//
//  Engine.swift
//  UMAFCore
//
//  UMAFEngine: canonical API for turning files into UMAF envelopes / Markdown.
//

import Foundation

public struct UMAFEngine {

  public struct Options {
    /// Whether to populate spans/blocks on the output envelope.
    public let includeStructure: Bool
    /// When structure is included, optionally set `featureFlags.structure == true`.
    public let setStructureFeatureFlag: Bool

    public init(includeStructure: Bool = false, setStructureFeatureFlag: Bool = false) {
      self.includeStructure = includeStructure
      self.setStructureFeatureFlag = setStructureFeatureFlag
    }
  }

  public init() {}

  /// Build a full UMAF envelope (v0.6) for a file on disk.
  public func envelope(
    for url: URL,
    options: Options = Options()
  ) throws -> UMAFEnvelopeV0_5 {
    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(
      inputURL: url,
      outputFormat: .jsonEnvelope
    )
    guard case .envelope(let coreEnvelope) = result else {
      throw UMAFUserError.internalError("Expected envelope output but received markdown.")
    }
    return makeEnvelope(
      from: coreEnvelope,
      includeStructure: options.includeStructure,
      setStructureFlag: options.setStructureFeatureFlag
    )
  }

  /// Build canonical normalized text (typically Markdown) for a file.
  public func normalizedText(
    for url: URL,
    options: Options = Options()
  ) throws -> String {
    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(
      inputURL: url,
      outputFormat: .markdown
    )
    if case .markdown(let text) = result {
      return text
    }
    throw UMAFUserError.internalError("Expected markdown output but received an envelope.")
  }

  private func makeEnvelope(
    from coreEnvelope: UMAFCoreEngine.Envelope,
    includeStructure: Bool,
    setStructureFlag: Bool
  ) -> UMAFEnvelopeV0_5 {
    if includeStructure {
      var env = UMAFWalkerV0_5.build(from: coreEnvelope)
      env = UMAFWalkerV0_5.ensureRootSpanAndBlock(env)
      if setStructureFlag {
        var flags = env.featureFlags ?? [:]
        flags["structure"] = true
        env.featureFlags = flags
      }
      return env
    }

    let sections = coreEnvelope.sections.map {
      UMAFEnvelopeV0_5.Section(
        heading: $0.heading, level: $0.level, lines: $0.lines, paragraphs: $0.paragraphs)
    }
    let bullets = coreEnvelope.bullets.map {
      UMAFEnvelopeV0_5.Bullet(
        text: $0.text, lineIndex: $0.lineIndex, sectionHeading: $0.sectionHeading,
        sectionLevel: $0.sectionLevel)
    }
    let frontMatter = coreEnvelope.frontMatter.map {
      UMAFEnvelopeV0_5.FrontMatterEntry(key: $0.key, value: $0.value)
    }
    let tables = coreEnvelope.tables.map {
      UMAFEnvelopeV0_5.Table(startLineIndex: $0.startLineIndex, header: $0.header, rows: $0.rows)
    }
    let codeBlocks = coreEnvelope.codeBlocks.map {
      UMAFEnvelopeV0_5.CodeBlock(
        startLineIndex: $0.startLineIndex, language: $0.language, code: $0.code)
    }

    return UMAFEnvelopeV0_5(
      version: coreEnvelope.version,
      docTitle: coreEnvelope.docTitle,
      docId: coreEnvelope.docId,
      createdAt: coreEnvelope.createdAt,
      sourceHash: coreEnvelope.sourceHash,
      sourcePath: coreEnvelope.sourcePath,
      mediaType: coreEnvelope.mediaType,
      encoding: coreEnvelope.encoding,
      sizeBytes: coreEnvelope.sizeBytes,
      lineCount: coreEnvelope.lineCount,
      normalized: coreEnvelope.normalized,
      sections: sections,
      bullets: bullets,
      frontMatter: frontMatter,
      tables: tables,
      codeBlocks: codeBlocks,
      spans: [],
      blocks: [],
      featureFlags: nil
    )
  }
}
