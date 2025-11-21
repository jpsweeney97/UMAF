//
//  HTMLAdapter.swift
//  UMAFCore
//
//  Adapter for converting HTML into Markdown-ish text.
//
// Regex-based transforms. Later you can plug in SwiftSoup here without
// touching callers.

import Foundation

public enum HTMLAdapter {

  // OPTIMIZATION: Pre-compile regexes once.
  private static let h1Regex = try! NSRegularExpression(
    pattern: "<h1[^>]*>(.*?)</h1>",
    options: [.dotMatchesLineSeparators, .caseInsensitive]
  )

  private static let h2Regex = try! NSRegularExpression(
    pattern: "<h2[^>]*>(.*?)</h2>",
    options: [.dotMatchesLineSeparators, .caseInsensitive]
  )

  private static let liRegex = try! NSRegularExpression(
    pattern: "<li[^>]*>(.*?)</li>",
    options: [.dotMatchesLineSeparators, .caseInsensitive]
  )

  private static let tagRegex = try! NSRegularExpression(
    pattern: "<[^>]+>",
    options: [.caseInsensitive]
  )

  /// Convert an HTML document (as a String) to a Markdown-ish representation.
  public static func htmlToMarkdownish(_ html: String) -> String {
    var text = TextNormalization.normalizeLineEndings(html)

    // Normalize <br> family
    for br in ["<br>", "<br/>", "<br />", "<BR>", "<BR/>", "<BR />"] {
      text = text.replacingOccurrences(of: br, with: "\n")
    }

    // Apply H1
    let range1 = NSRange(text.startIndex..., in: text)
    text = h1Regex.stringByReplacingMatches(
      in: text, options: [], range: range1, withTemplate: "\n# $1\n\n"
    )

    // Apply H2
    let range2 = NSRange(text.startIndex..., in: text)
    text = h2Regex.stringByReplacingMatches(
      in: text, options: [], range: range2, withTemplate: "\n## $1\n\n"
    )

    // Apply List Items
    let range3 = NSRange(text.startIndex..., in: text)
    text = liRegex.stringByReplacingMatches(
      in: text, options: [], range: range3, withTemplate: "\n- $1\n"
    )

    // Strip remaining tags
    let range4 = NSRange(text.startIndex..., in: text)
    text = tagRegex.stringByReplacingMatches(
      in: text, options: [], range: range4, withTemplate: ""
    )

    while text.contains("\n\n\n") {
      text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
