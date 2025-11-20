//
//  HTMLAdapter.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  HTMLAdapter.swift
//  UMAFCore
//
//  Adapter for converting HTML into Markdown-ish text.
//
// For now this wraps UMAFCoreEngine.Prework.htmlToMarkdownish, which uses
// regex-based transforms. Later you can plug in SwiftSoup here without
// touching callers.
//

import Foundation

public enum HTMLAdapter {

  /// Convert an HTML document (as a String) to a Markdown-ish representation.
  public static func htmlToMarkdownish(_ html: String) -> String {
    let normalized = UMAFCoreEngine.Prework.normalizeLineEndings(html)
    return UMAFCoreEngine.Prework.htmlToMarkdownish(normalized)
  }
}
