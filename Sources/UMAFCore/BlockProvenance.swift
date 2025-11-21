import Foundation

/// Stable provenance + confidence taxonomy for UMAF v0.5.0 blocks.
///
/// Notes:
/// - `umaf:0.5.0:markdown` covers native `text/markdown` **and** the
///   HTML→markdownish transforms already applied in normalization.
/// - Setext vs ATX headings are not distinguished in v0.5.0; all detected
///   headings map to `heading-atx`. A future schema/version could split these
///   once the parser surfaces that detail.
enum BlockProvenanceV0_5 {

  enum Source {
    case markdown
    case pdfkit
    case docx
    case plainText
    case ocr
  }

  struct TableInfo {
    let headerCount: Int
    let rowCounts: [Int]
  }

  static func source(for mediaType: String) -> Source {
    let lower = mediaType.lowercased()
    if lower == "application/pdf" { return .pdfkit }
    if lower.contains("openxmlformats") || lower == "application/rtf" { return .docx }
    if lower == "text/plain" { return .plainText }
    if lower.contains("ocr") { return .ocr }
    // text/markdown and html→markdownish share the markdown prefix for v0.5.0.
    return .markdown
  }

  static func prefix(for source: Source) -> String {
    switch source {
    case .markdown: return "umaf:\(UMAFVersion.provenance):markdown"
    case .pdfkit: return "umaf:\(UMAFVersion.provenance):adapter:pdfkit"
    case .docx: return "umaf:\(UMAFVersion.provenance):adapter:docx"
    case .plainText: return "umaf:\(UMAFVersion.provenance):plain-text"
    case .ocr: return "umaf:\(UMAFVersion.provenance):adapter:ocr"
    }
  }

  static func provenanceAndConfidence(
    for kind: UMAFBlockKindV0_5,
    source: Source,
    tableInfo: TableInfo? = nil
  ) -> (provenance: String, confidence: Double) {
    let prefix = prefix(for: source)

    switch kind {
    case .root:
      return ("umaf:\(UMAFVersion.provenance):root", 1.0)

    case .section:
      return ("\(prefix):heading-atx", headingConfidence(for: source))

    case .bullet:
      return ("\(prefix):bullet", bulletConfidence(for: source))

    case .paragraph:
      return ("\(prefix):paragraph", paragraphConfidence(for: source))

    case .table:
      let conf = tableConfidence(for: source, tableInfo: tableInfo)
      return ("\(prefix):table:pipe", conf)

    case .code:
      return ("\(prefix):code:fenced-backtick", 1.0)

    case .frontMatter:
      return ("\(prefix):front-matter:yaml", 1.0)

    case .raw:
      return ("\(prefix):raw", 0.6)
    }
  }

  private static func headingConfidence(for source: Source) -> Double {
    switch source {
    case .markdown: return 1.0
    case .docx: return 0.8
    case .pdfkit: return 0.8
    case .plainText: return 0.8
    case .ocr: return 0.8
    }
  }

  private static func bulletConfidence(for source: Source) -> Double {
    switch source {
    case .markdown: return 1.0
    case .docx: return 0.7
    case .pdfkit: return 0.7
    case .plainText: return 0.7
    case .ocr: return 0.7
    }
  }

  private static func paragraphConfidence(for source: Source) -> Double {
    switch source {
    case .markdown: return 0.9
    case .docx: return 0.8
    case .pdfkit: return 0.8
    case .plainText: return 0.8
    case .ocr: return 0.8
    }
  }

  private static func tableConfidence(for source: Source, tableInfo: TableInfo?) -> Double {
    let ragged: Bool = {
      guard let info = tableInfo else { return false }
      guard info.headerCount > 0 else { return true }
      return info.rowCounts.contains { $0 != info.headerCount }
    }()
    switch source {
    case .markdown:
      return ragged ? 0.8 : 1.0
    case .docx, .pdfkit, .plainText, .ocr:
      return ragged ? 0.8 : 0.9
    }
  }
}
