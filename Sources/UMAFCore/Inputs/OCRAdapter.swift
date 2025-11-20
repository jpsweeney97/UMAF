//
//  OCRAdapter.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  OCRAdapter.swift
//  UMAFCore
//
//  Adapter for extracting text from images using Vision OCR.
//

import Foundation
import Vision

public enum OCRAdapter {

  /// Recognize text from an image file using VNRecognizeTextRequest.
  ///
  /// - Parameters:
  ///   - url: URL to an image file (png, jpeg, tiff, etc.).
  ///   - languageHints: Optional BCP-47 language codes (e.g. ["en-US"]).
  /// - Returns: Recognized text, joined with newlines.
  public static func recognizeText(
    from url: URL,
    languageHints: [String] = ["en-US"]
  ) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if !languageHints.isEmpty {
      request.recognitionLanguages = languageHints
    }

    let handler = VNImageRequestHandler(url: url, options: [:])
    try handler.perform([request])

    guard let observations = request.results, !observations.isEmpty else {
      return ""
    }

    var lines: [String] = []
    lines.reserveCapacity(observations.count)

    for obs in observations {
      if let candidate = obs.topCandidates(1).first {
        lines.append(candidate.string)
      }
    }

    return lines.joined(separator: "\n")
  }

}
