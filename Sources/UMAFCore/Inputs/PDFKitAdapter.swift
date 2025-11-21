//
//  PDFKitAdapter.swift
//  UMAFCore
//
//  Adapter for extracting Markdown-ish text from PDFs using PDFKit.
//

import Foundation

#if canImport(PDFKit)
  import PDFKit
#endif

public enum PDFKitAdapter {

  public static func extractMarkdownish(from url: URL) throws -> String {
    #if canImport(PDFKit)
      guard let doc = PDFDocument(url: url) else {
        throw NSError(
          domain: "UMAF", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document."])
      }

      var lines: [String] = []
      for pageIndex in 0..<doc.pageCount {
        guard let page = doc.page(at: pageIndex),
          let s = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
          !s.isEmpty
        else { continue }

        lines.append("# Page \(pageIndex + 1)")
        lines.append("")
        lines.append(contentsOf: s.components(separatedBy: .newlines))
        if pageIndex != doc.pageCount - 1 { lines.append("") }
      }
      return lines.joined(separator: "\n")
    #else
      throw NSError(
        domain: "UMAF",
        code: 404,
        userInfo: [
          NSLocalizedDescriptionKey: "PDF extraction is only supported on macOS (requires PDFKit)."
        ]
      )
    #endif
  }
}
