//
//  Engine.swift
//  UMAFCore
//
//  UMAFEngine: canonical API for turning files into UMAF envelopes / Markdown.
//

import Foundation

public struct UMAFEngine {

  public init() {}

  /// Build a full UMAF envelope (v0.7) for a file on disk (structure always included).
  public func envelope(
    for url: URL
  ) throws -> UMAFEnvelopeV0_7 {
    let transformer = UMAFCoreEngine.Transformer()
    let result = try transformer.transformFile(
      inputURL: url,
      outputFormat: .jsonEnvelope
    )
    guard case .envelope(let coreEnvelope) = result else {
      throw UMAFUserError.internalError("Expected envelope output but received markdown.")
    }
    return makeEnvelope(from: coreEnvelope)
  }

  /// Build canonical normalized text (typically Markdown) for a file.
  public func normalizedText(
    for url: URL
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
    from coreEnvelope: UMAFCoreEngine.Envelope
  ) -> UMAFEnvelopeV0_7 {
    var env = UMAFWalkerV0_7.build(from: coreEnvelope)
    env = UMAFWalkerV0_7.ensureRootSpanAndBlock(env)
    var flags = env.featureFlags
    flags["structure"] = true
    env.featureFlags = flags
    return env
  }
}
