//
//  Normalization.swift
//  UMAFCore
//
//  Helpers for building and decoding UMAFEnvelopeV0_5.
//

import Foundation

public enum UMAFNormalization {

  /// Decode a typed UMAFEnvelopeV0_5 from raw JSON data.
  /// This is a thin wrapper around JSONDecoder, so it works with any
  /// JSON that matches the v0.6.0 schema.
  public static func envelopeV0_5(fromJSONData data: Data) throws -> UMAFEnvelopeV0_5 {
    let decoder = JSONDecoder()
    return try decoder.decode(UMAFEnvelopeV0_5.self, from: data)
  }

  /// Convenience: run the UMAFEngine to produce an envelope directly from disk
  /// with structural spans/blocks included.
  public static func envelopeV0_5(fromFileURL url: URL) throws -> UMAFEnvelopeV0_5 {
    let engine = UMAFEngine()
    return try engine.envelope(
      for: url, options: UMAFEngine.Options(includeStructure: true, setStructureFeatureFlag: false))
  }

  /// Ensure there is at least a root span and root block in the envelope.
  /// This is a small, non-destructive normalizer that can be used by UI callers.
  public static func withRootSpanAndBlock(_ envelope: UMAFEnvelopeV0_5) -> UMAFEnvelopeV0_5 {
    UMAFWalkerV0_5.ensureRootSpanAndBlock(envelope)
  }
}
