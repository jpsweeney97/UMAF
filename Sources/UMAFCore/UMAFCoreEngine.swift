//
//  UMAFCoreEngine.swift
//  Core formatting & semantic engine for UMAF (v0.5)
//

import Crypto
import Foundation

// A tiny namespace so this file never collides with app-local symbols.
public enum UMAFCoreEngine {

  static func firstMarkdownHeadingTitle(in text: String) -> String? {
    for raw in text.components(separatedBy: "\n") {
      let trimmed = raw.trimmingCharacters(in: .whitespaces)
      guard trimmed.first == "#" else { continue }
      var hashes = 0
      for ch in trimmed {
        if ch == "#" { hashes += 1 } else { break }
      }
      guard hashes > 0 else { continue }
      var rest = trimmed.drop(while: { $0 == "#" })
      if rest.first == " " { rest = rest.dropFirst() }
      let title = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
      if !title.isEmpty { return title }
    }
    return nil
  }

  // MARK: - Markdown emitter

  static func buildMarkdownFromSemantic(
    normalizedPayload: String,
    mediaType: String,
    sections: [Section],
    bullets: [Bullet],
    frontMatter: [FrontMatterEntry],
    tables: [Table],
    codeBlocks: [CodeBlock]
  ) -> String {
    var lines: [String] = []

    switch mediaType {
    case "text/markdown":
      if frontMatter.isEmpty && sections.isEmpty { return normalizedPayload }

      if !frontMatter.isEmpty {
        lines.append("---")
        for e in frontMatter { lines.append("\(e.key): \(e.value)") }
        lines.append("---")
        lines.append("")
      }

      let effectiveSections: [Section] =
        sections.isEmpty
        ? {
          let all = normalizedPayload.components(separatedBy: "\n")
          return [
            Section(
              heading: "Document", level: 1, lines: all, paragraphs: makeParagraphs(from: all))
          ]
        }()
        : sections

      let hasComplex = !tables.isEmpty || !codeBlocks.isEmpty

      for (idx, s) in effectiveSections.enumerated() {
        let level = min(max(s.level, 1), 6)
        let prefix = String(repeating: "#", count: level)
        let title = s.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("\(prefix) \(title)")

        if !hasComplex, !s.paragraphs.isEmpty {
          lines.append("")
          for (pIdx, p) in s.paragraphs.enumerated() {
            lines.append(p)
            if pIdx != s.paragraphs.count - 1 { lines.append("") }
          }
        } else if !s.lines.isEmpty {
          lines.append("")
          lines.append(contentsOf: s.lines)
        }

        if idx != effectiveSections.count - 1 { lines.append("") }
      }

      return canonicalizeMarkdownLines(lines).joined(separator: "\n")

    case "application/json":
      // Using explicit code fence concatenation to avoid copy-paste artifacts
      let fence = "```"
      return [fence + "json", normalizedPayload, fence].joined(separator: "\n")

    default:
      if let doc = sections.first {
        let level = min(max(doc.level, 1), 6)
        let prefix = String(repeating: "#", count: level)
        let title = doc.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("\(prefix) \(title)")
        lines.append("")

        let docBullets = bullets.filter {
          $0.sectionHeading == "Document" || $0.sectionHeading == nil
        }
        let bulletLineIdx = Set(docBullets.map { $0.lineIndex })
        let bulletIndents: [Int] = docBullets.compactMap {
          guard $0.lineIndex >= 0 && $0.lineIndex < doc.lines.count else { return nil }
          return leadingIndentWidth(of: doc.lines[$0.lineIndex])
        }
        let baseIndent = bulletIndents.min() ?? 0

        var i = 0
        while i < doc.lines.count {
          let line = doc.lines[i]
          let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty

          if bulletLineIdx.contains(i) {
            var j = i
            while j < doc.lines.count, bulletLineIdx.contains(j) {
              if let b = docBullets.first(where: { $0.lineIndex == j }) {
                let raw = doc.lines[j]
                let w = leadingIndentWidth(of: raw)
                let extra = max(w - baseIndent, 0)
                let level = extra / 2
                let indent = String(repeating: "  ", count: level)
                lines.append("\(indent)- \(b.text)")
              }
              j += 1
            }
            lines.append("")
            i = j
            continue
          }

          lines.append(line)
          if isBlank {
            while i + 1 < doc.lines.count
              && doc.lines[i + 1].trimmingCharacters(in: .whitespaces).isEmpty
            {
              i += 1
            }
          }
          i += 1
        }

        return canonicalizeMarkdownLines(lines).joined(separator: "\n")
      } else {
        // Explicit fencing again
        let fence = "```"
        return [fence + "text", normalizedPayload, fence].joined(separator: "\n")
      }
    }
  }

  // MARK: - Transformer (single entry point for CLI and library)

  public struct Transformer {

    public enum Result {
      case envelope(Envelope)
      case markdown(String)
    }

    public init() {}

    public func transformFile(inputURL url: URL, outputFormat: OutputFormat) throws -> Result {
      // 1) Read bytes (for hashing/size)
      let data = try Data(contentsOf: url)
      let sizeBytes = data.count

      // 2) Route + normalize via InputRouter
      // OPTIMIZATION: Pass data directly, do not re-read from disk
      let routed = try InputRouter.load(from: url, data: data)
      let mediaType = routed.mediaType
      let semanticMediaType = routed.semanticMediaType
      let normalizedPayload = routed.normalizedText

      // 3) Semantic model
      let (sections, bullets, frontMatter, tables, codeBlocks) =
        UMAFCoreEngine.parseSemanticStructure(
          from: normalizedPayload,
          mediaType: semanticMediaType
        )

      // 4) Outputs
      switch outputFormat {
      case .jsonEnvelope:
        let envelope = buildEnvelope(
          url: url,
          mediaType: mediaType,
          semanticMediaType: semanticMediaType,
          normalizedPayload: normalizedPayload,
          sections: sections,
          bullets: bullets,
          frontMatter: frontMatter,
          tables: tables,
          codeBlocks: codeBlocks,
          sizeBytes: sizeBytes,
          data: data
        )
        return .envelope(envelope)

      case .markdown:
        let md = UMAFCoreEngine.buildMarkdownFromSemantic(
          normalizedPayload: normalizedPayload,
          mediaType: semanticMediaType,
          sections: sections,
          bullets: bullets,
          frontMatter: frontMatter,
          tables: tables,
          codeBlocks: codeBlocks
        )
        return .markdown(md)
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
