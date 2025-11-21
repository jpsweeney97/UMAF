//
//  Router.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  Router.swift
//  UMAFCore
//
//  Input router for UMAF.
//  Given a URL, this decides how to normalize the payload and what
//  media types to attach, delegating to the appropriate adapters.
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
      let mediaType = "text/markdown"
      let semanticMediaType = "text/markdown"
      let raw = stringFromData(data)
      let normalized = TextNormalization.normalizeLineEndings(raw)
      return RoutedInput(
        normalizedText: normalized,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )

    case "json":
      let mediaType = "application/json"
      let semanticMediaType = "application/json"
      let raw = stringFromData(data)
      let normalizedText = TextNormalization.normalizeLineEndings(raw)
      let obj = try JSONSerialization.jsonObject(with: Data(normalizedText.utf8))
      let canonical = try JSONSerialization.data(
        withJSONObject: obj,
        options: [.sortedKeys, .prettyPrinted]
      )
      let canonicalText = stringFromData(canonical)
      return RoutedInput(
        normalizedText: canonicalText,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )

    case "html", "htm":
      let mediaType = "text/html"
      let semanticMediaType = "text/markdown"
      let raw = stringFromData(data)
      let markdownish = HTMLAdapter.htmlToMarkdownish(raw)
      return RoutedInput(
        normalizedText: markdownish,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )

    case "rtf", "doc", "docx":
      let mediaType: String
      if ext == "rtf" {
        mediaType = "application/rtf"
      } else {
        mediaType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      }
      let semanticMediaType = "text/plain"
      let extracted = try DOCXAdapter.extractPlainText(usingTextUtilFrom: url)
      let normalized = TextNormalization.normalizeLineEndings(extracted)
      return RoutedInput(
        normalizedText: normalized,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )

    case "pdf":
      let mediaType = "application/pdf"
      let semanticMediaType = "text/markdown"
      let markdownish = try PDFKitAdapter.extractMarkdownish(from: url)
      let normalized = TextNormalization.normalizeLineEndings(markdownish)
      return RoutedInput(
        normalizedText: normalized,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )

    default:
      let mediaType = "text/plain"
      let semanticMediaType = "text/plain"
      let raw = stringFromData(data)
      let normalized = TextNormalization.normalizeLineEndings(raw)
      return RoutedInput(
        normalizedText: normalized,
        mediaType: mediaType,
        semanticMediaType: semanticMediaType
      )
    }
  }

  // MARK: - Helpers

  /// Best-effort String decoding from Data (UTF-8 first, then raw).
  private static func stringFromData(_ data: Data) -> String {
    if let s = String(data: data, encoding: .utf8) {
      return s
    }
    return String(decoding: data, as: UTF8.self)
  }
}
