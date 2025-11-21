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
    return try UMAFCoreEngine.Prework.extractPdfToMarkdownish(from: url)
    #else
    throw NSError(
        domain: "UMAF", 
        code: 404, 
        userInfo: [NSLocalizedDescriptionKey: "PDF extraction is only supported on macOS (requires PDFKit)."]
    )
    #endif
  }
}
