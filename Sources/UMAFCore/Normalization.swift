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
  /// JSON that matches the v0.5.0 schema.
  public static func envelopeV0_5(fromJSONData data: Data) throws -> UMAFEnvelopeV0_5 {
    let decoder = JSONDecoder()
    return try decoder.decode(UMAFEnvelopeV0_5.self, from: data)
  }

  /// Convenience: run the UMAFEngine to produce an envelope directly from disk.
  /// This delegates to `UMAFEngine().envelope(for:)`, which also guarantees
  /// the presence of a root span + root block.
  public static func envelopeV0_5(fromFileURL url: URL) throws -> UMAFEnvelopeV0_5 {
    let engine = UMAFEngine()
    return try engine.envelope(for: url)
  }

  /// Ensure there is at least a root span and root block in the envelope.
  /// This is a small, non-destructive normalizer that can be used by UI callers.
  public static func withRootSpanAndBlock(_ envelope: UMAFEnvelopeV0_5) -> UMAFEnvelopeV0_5 {
    var env = envelope

    // If any spans already exist, we assume caller is doing richer work.
    guard env.spans.isEmpty else { return env }

    let rootSpanId = "span:root"
    let rootSpan = UMAFSpanV0_5(
      id: rootSpanId,
      startLine: 1,
      endLine: max(1, env.lineCount),
      startColumn: nil,
      endColumn: nil
    )

    env.spans = [rootSpan]

    if env.blocks.isEmpty {
      let rootBlock = UMAFBlockV0_5(
        id: "block:root",
        kind: .root,
        spanId: rootSpanId,
        parentId: nil,
        level: 1,
        heading: env.docTitle,
        language: nil,
        tableHeader: nil,
        tableRows: nil,
        metadata: ["mediaType": env.mediaType],
        provenance: "umaf:0.5.0:root",
        confidence: 1.0
      )
      env.blocks = [rootBlock]
    }

    return env
  }
}
