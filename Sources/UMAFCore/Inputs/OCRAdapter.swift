//
//  OCRAdapter.swift
//  UMAFCore
//
//  Adapter for extracting text from images using Vision OCR.
//

import Foundation

#if canImport(Vision)
import Vision
#endif

public enum OCRAdapter {

  /// Recognize text from an image file using VNRecognizeTextRequest.
  public static func recognizeText(
    from url: URL,
    languageHints: [String] = ["en-US"]
  ) throws -> String {
    #if canImport(Vision)
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
    #else
    // Fallback for Linux / non-Apple platforms
    throw NSError(
        domain: "UMAF", 
        code: 404, 
        userInfo: [NSLocalizedDescriptionKey: "OCR is only supported on macOS/iOS (requires Vision framework)."]
    )
    #endif
  }
}
