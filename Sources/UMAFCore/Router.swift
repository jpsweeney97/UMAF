//
//  Router.swift
//  UMAFCore
//
//  Input router for UMAF. Normalizes input text and assigns media types.
//

import Foundation

public enum InputRouter {

  /// Normalized view of an input file.
  public struct RoutedInput {
    /// Canonicalized text payload (line endings normalized, etc.)
    public let normalizedText: String
    /// Original media type (e.g. application/pdf, text/html).
    public let mediaType: String
    /// Semantic media type used for parsing (e.g. text/markdown).
    public let semanticMediaType: String

    public init(
      normalizedText: String,
      mediaType: String,
      semanticMediaType: String
    ) {
      self.normalizedText = normalizedText
      self.mediaType = mediaType
      self.semanticMediaType = semanticMediaType
    }
  }

  /// Load and normalize an input file, returning text + media types.
  ///
  /// This mirrors UMAFCoreEngine.Transformer's ext-switch logic, but rolls it
  /// into a reusable API so future callers (CLI/app/tests) can share it.
  public static func load(from url: URL, data: Data) throws -> RoutedInput {
    // OPTIMIZATION: Data is passed in, avoiding a redundant read from disk.
    let ext = url.pathExtension.lowercased()

    switch ext {
    case "md":
      let raw = stringFromData(data)
      let normalized = TextNormalization.normalizeLineEndings(raw)
      return makeInput(text: normalized, mediaType: "text/markdown", semanticType: "text/markdown")

    case "json":
      let raw = stringFromData(data)
      let normalizedText = TextNormalization.normalizeLineEndings(raw)
      let obj = try JSONSerialization.jsonObject(with: Data(normalizedText.utf8))
      let canonical = try JSONSerialization.data(
        withJSONObject: obj,
        options: [.sortedKeys, .prettyPrinted]
      )
      let canonicalText = stringFromData(canonical)
      return makeInput(
        text: canonicalText,
        mediaType: "application/json",
        semanticType: "application/json"
      )

    case "html", "htm":
      let raw = stringFromData(data)
      let markdownish = HTMLAdapter.htmlToMarkdownish(raw)
      return makeInput(text: markdownish, mediaType: "text/html", semanticType: "text/markdown")

    case "rtf", "doc", "docx":
      let mediaType =
        (ext == "rtf")
        ? "application/rtf"
        : "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      let extracted = try DOCXAdapter.extractPlainText(usingTextUtilFrom: url)
      let normalized = TextNormalization.normalizeLineEndings(extracted)
      return makeInput(text: normalized, mediaType: mediaType, semanticType: "text/plain")

    case "pdf":
      let markdownish = try PDFKitAdapter.extractMarkdownish(from: url)
      let normalized = TextNormalization.normalizeLineEndings(markdownish)
      return makeInput(
        text: normalized, mediaType: "application/pdf", semanticType: "text/markdown")

    default:
      let raw = stringFromData(data)
      let normalized = TextNormalization.normalizeLineEndings(raw)
      return makeInput(text: normalized, mediaType: "text/plain", semanticType: "text/plain")
    }
  }

  // MARK: - Helpers

  private static func makeInput(
    text: String,
    mediaType: String,
    semanticType: String
  ) -> RoutedInput {
    RoutedInput(
      normalizedText: text,
      mediaType: mediaType,
      semanticMediaType: semanticType
    )
  }

  /// Best-effort String decoding from Data (UTF-8 first, then raw).
  private static func stringFromData(_ data: Data) -> String {
    if let s = String(data: data, encoding: .utf8) {
      return s
    }
    return String(decoding: data, as: UTF8.self)
  }
}
