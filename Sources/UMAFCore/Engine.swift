//
//  Engine.swift
//  UMAFCore
//
//  UMAFEngine: canonical API for turning files into UMAF envelopes / Markdown.
//

import Foundation

public struct UMAFEngine {

  public struct Options {
    /// Reserved for future toggles (e.g. enable/disable caching, choose diff algo, etc.)
    public init() {}
  }

  public init() {}

  /// Build a full UMAF envelope (v0.5) for a file on disk.
  public func envelope(
    for url: URL,
    options: Options = Options()
  ) throws -> UMAFEnvelopeV0_5 {
    let transformer = UMAFCoreEngine.Transformer()
    let data = try transformer.transformFile(
      inputURL: url,
      outputFormat: .jsonEnvelope
    )
    let env = try UMAFNormalization.envelopeV0_5(fromJSONData: data)
    return UMAFNormalization.withRootSpanAndBlock(env)
  }

  /// Build canonical normalized text (typically Markdown) for a file.
  public func normalizedText(
    for url: URL,
    options: Options = Options()
  ) throws -> String {
    let transformer = UMAFCoreEngine.Transformer()
    let data = try transformer.transformFile(
      inputURL: url,
      outputFormat: .markdown
    )
    guard let s = String(data: data, encoding: .utf8) else {
      throw UMAFUserError.internalError("Failed to decode normalized text as UTF-8.")
    }
    return s
  }
}
