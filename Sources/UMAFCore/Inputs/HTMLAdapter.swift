//
//  HTMLAdapter.swift
//  UMAFCore
//
//  Adapter for converting HTML into Markdown-ish text using SwiftSoup.
//

import Foundation
import SwiftSoup

public enum HTMLAdapter {

  /// Convert an HTML document (as a String) to a Markdown-ish representation.
  public static func htmlToMarkdownish(_ html: String) throws -> String {
    let doc: Document = try SwiftSoup.parse(html)
    guard let body = doc.body() else { return "" }

    let text = try traverse(node: body)
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func traverse(node: Node) throws -> String {
    var text = ""

    for child in node.getChildNodes() {
      if let textNode = child as? TextNode {
        // Decode entities & preserve minimal whitespace logic if needed
        // For now, we just take the text. SwiftSoup handles entity decoding.
        text += textNode.text()
      } else if let element = child as? Element {
        let tagName = element.tagName().lowercased()
        let content = try traverse(node: element)

        switch tagName {
        case "h1":
          text += "\n# \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        case "h2":
          text += "\n## \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        case "h3":
          text += "\n### \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        case "h4", "h5", "h6":
          text += "\n#### \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"

        case "p":
          // Only add newlines if content isn't empty
          let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmed.isEmpty {
            text += "\n\(trimmed)\n\n"
          }

        case "br":
          text += "\n"

        case "li":
          // Simple list handling.
          // Note: This doesn't handle nested indentation perfectly yet,
          // but is far better than regex.
          let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
          text += "- \(trimmed)\n"

        case "ul", "ol":
          // Lists provide their own internal newlines via LI
          text += "\n\(content)\n"

        case "blockquote":
          text += "\n> \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"

        case "code", "pre":
          // Basic code handling
          text += "`\(content)`"

        case "div", "section", "article", "main", "header", "footer":
          // Block containers -> preserve content flow
          text += "\n\(content)\n"

        default:
          // Inline tags (span, strong, em, a) or unknown tags -> flatten content
          text += content
        }
      }
    }

    return text
  }
}
