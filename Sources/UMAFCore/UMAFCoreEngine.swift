//
//  UMAFCoreEngine.swift
//  Core formatting & semantic engine for UMAF (v0.5)
//

import Crypto
import Foundation

public enum UMAFCoreEngine {

  /// Helper: Find the first heading title in a markdown string
  static func firstMarkdownHeadingTitle(in text: String) -> String? {
    for raw in text.components(separatedBy: "\n") {
      let trimmed = raw.trimmingCharacters(in: .whitespaces)
      guard trimmed.first == "#" else { continue }
      var hashes = 0
      for ch in trimmed { if ch == "#" { hashes += 1 } else { break } }
      guard hashes > 0 else { continue }
      var rest = trimmed.drop(while: { $0 == "#" })
      if rest.first == " " { rest = rest.dropFirst() }
      let title = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
      if !title.isEmpty { return title }
    }
    return nil
  }

  // Expose paragraph maker for SwiftMarkdownAdapter to use
  static func makeParagraphs(from lines: [String]) -> [String] {
    return LegacyAdapter.makeParagraphs(from: lines)
  }

  // MARK: - Transformer

  public struct Transformer {

    public enum Result {
      case envelope(Envelope)
      case markdown(String)
    }

    public init() {}

    public func transformFile(inputURL url: URL, outputFormat: OutputFormat) throws -> Result {
      let data = try Data(contentsOf: url)
      let sizeBytes = data.count
      let routed = try InputRouter.load(from: url, data: data)

      // Parsing Strategy
      let semanticResult:
        (
          normalized: String,
          sections: [Section],
          bullets: [Bullet],
          frontMatter: [FrontMatterEntry],
          tables: [Table],
          codeBlocks: [CodeBlock]
        )

      if routed.semanticMediaType == "text/markdown" {
        // Modern path (SwiftMarkdownAdapter)
        let result = SwiftMarkdownAdapter.parse(text: routed.normalizedText)
        semanticResult = (
          result.normalizedText,
          result.sections,
          result.bullets,
          result.frontMatter,
          result.tables,
          result.codeBlocks
        )
      } else {
        // Legacy path (LegacyAdapter)
        let (sections, bullets, frontMatter, tables, codeBlocks) =
          LegacyAdapter.parse(text: routed.normalizedText)

        let normalized = LegacyAdapter.buildMarkdown(
          normalizedPayload: routed.normalizedText,
          mediaType: routed.semanticMediaType,
          sections: sections,
          bullets: bullets,
          frontMatter: frontMatter,
          tables: tables,
          codeBlocks: codeBlocks
        )

        semanticResult = (normalized, sections, bullets, frontMatter, tables, codeBlocks)
      }

      // Emitting
      switch outputFormat {
      case .jsonEnvelope:
        let envelope = buildEnvelope(
          url: url,
          mediaType: routed.mediaType,
          semanticMediaType: routed.semanticMediaType,
          normalizedPayload: semanticResult.normalized,
          sections: semanticResult.sections,
          bullets: semanticResult.bullets,
          frontMatter: semanticResult.frontMatter,
          tables: semanticResult.tables,
          codeBlocks: semanticResult.codeBlocks,
          sizeBytes: sizeBytes,
          data: data
        )
        return .envelope(envelope)

      case .markdown:
        return .markdown(semanticResult.normalized)
      }
    }

    private func buildEnvelope(
      url: URL,
      mediaType: String,
      semanticMediaType: String,
      normalizedPayload: String,
      sections: [Section],
      bullets: [Bullet],
      frontMatter: [FrontMatterEntry],
      tables: [Table],
      codeBlocks: [CodeBlock],
      sizeBytes: Int,
      data: Data
    ) -> Envelope {
      let baseName = url.deletingPathExtension().lastPathComponent
      let docTitle: String =
        (semanticMediaType == "text/markdown")
        ? (UMAFCoreEngine.firstMarkdownHeadingTitle(in: normalizedPayload) ?? baseName)
        : baseName
      let createdAt = ISO8601DateFormatter().string(
        from: (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date)
          ?? Date()
      )

      let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
      let docId = String(hash.prefix(12))
      // Use a resilient line count from the normalized string
      let lineCount = normalizedPayload.split(separator: "\n", omittingEmptySubsequences: false)
        .count

      return Envelope(
        version: UMAFVersion.string,
        docTitle: docTitle,
        docId: docId,
        createdAt: createdAt,
        sourceHash: hash,
        sourcePath: url.path,
        mediaType: mediaType,
        encoding: "utf-8",
        sizeBytes: sizeBytes,
        lineCount: lineCount,
        normalized: normalizedPayload,
        sections: sections,
        bullets: bullets,
        frontMatter: frontMatter,
        tables: tables,
        codeBlocks: codeBlocks
      )
    }
  }
}
