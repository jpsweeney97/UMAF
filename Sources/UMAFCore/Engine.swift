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
    let result = try transformer.transformFile(
      inputURL: url,
      outputFormat: .jsonEnvelope
    )
    guard case .envelope(let coreEnvelope) = result else {
      throw UMAFUserError.internalError("Expected envelope output but received markdown.")
    }
    let env = UMAFWalkerV0_5.build(from: coreEnvelope)
    return UMAFWalkerV0_5.ensureRootSpanAndBlock(env)
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
}
