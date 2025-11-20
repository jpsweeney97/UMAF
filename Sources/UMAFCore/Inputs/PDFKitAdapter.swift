//
//  PDFKitAdapter.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  PDFKitAdapter.swift
//  UMAFCore
//
//  Adapter for extracting Markdown-ish text from PDFs using PDFKit.
//

import Foundation
import PDFKit

public enum PDFKitAdapter {

  /// Extract a Markdown-ish representation of a PDF document.
  ///
  /// Currently delegates to UMAFCoreEngine.Prework.extractPdfToMarkdownish, which:
  /// - Opens the PDF with PDFKit
  /// - Emits headings per page
  /// - Normalizes line endings
  public static func extractMarkdownish(from url: URL) throws -> String {
    return try UMAFCoreEngine.Prework.extractPdfToMarkdownish(from: url)
  }
}
