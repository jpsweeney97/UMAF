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
}
