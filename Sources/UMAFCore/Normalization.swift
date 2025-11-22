//
//  Normalization.swift
//  UMAFCore
//
//  Helpers for building and decoding UMAFEnvelopeV0_7.
//

import Foundation

public enum UMAFNormalization {

  /// Decode a typed UMAFEnvelopeV0_7 from raw JSON data.
  /// This is a thin wrapper around JSONDecoder, so it works with any
  /// JSON that matches the v0.7.0 schema.
  public static func envelopeV0_7(fromJSONData data: Data) throws -> UMAFEnvelopeV0_7 {
    let decoder = JSONDecoder()
    return try decoder.decode(UMAFEnvelopeV0_7.self, from: data)
  }

  /// Convenience: run the UMAFEngine to produce an envelope directly from disk
  /// with structural spans/blocks included.
  public static func envelopeV0_7(fromFileURL url: URL) throws -> UMAFEnvelopeV0_7 {
    let engine = UMAFEngine()
    return try engine.envelope(for: url)
  }

  /// Ensure there is at least a root span and root block in the envelope.
  /// This is a small, non-destructive normalizer that can be used by UI callers.
  public static func withRootSpanAndBlock(_ envelope: UMAFEnvelopeV0_7) -> UMAFEnvelopeV0_7 {
    UMAFWalkerV0_7.ensureRootSpanAndBlock(envelope)
  }
}
