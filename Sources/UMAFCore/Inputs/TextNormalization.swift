//
//  TextNormalization.swift
//  UMAFCore
//
//  Simple text normalization helpers shared across adapters.
//

import Foundation

enum TextNormalization {

  static func normalizeLineEndings(_ text: String) -> String {
    var s = text.replacingOccurrences(of: "\r\n", with: "\n")
    s = s.replacingOccurrences(of: "\r", with: "\n")
    return s
  }

  /// Decode UTF-8 once; if decoding fails, fall back to lossy decoding.
  /// Returns (string, wasValidUTF8).
  static func decodeUTF8(_ data: Data) -> (String, Bool) {
    if let s = String(data: data, encoding: .utf8) {
      return (s, true)
    }
    return (String(decoding: data, as: UTF8.self), false)
  }
}
