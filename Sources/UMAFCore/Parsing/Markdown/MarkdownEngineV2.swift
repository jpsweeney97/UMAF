//
//  MarkdownEngineV2.swift
//  UMAFCore
//
//  Created by JP Sweeney on 11/19/25.
//

//
//  MarkdownEngineV2.swift
//  UMAFCore
//
//  Thin "engine v2" wrapper for UMAFCoreEngine's semantic Markdown parser.
//  This centralizes the Markdown entrypoint so we can later swap in
//  Swift-Markdown or cmark-gfm without touching callers.
//

import Foundation

public enum MarkdownEngineV2 {

  /// Parse semantic structure from a Markdown document into UMAFCoreEngine's
  /// typed model (sections, bullets, front matter, tables, code blocks).
  ///
  /// For now, this delegates to UMAFCoreEngine.parseSemanticStructure with
  /// mediaType "text/markdown". Future backends (Swift-Markdown, cmark-gfm)
  /// can be swapped in here without changing call sites.
  public static func parseSemanticStructure(
    from markdown: String
  ) -> (
    sections: [UMAFCoreEngine.Section],
    bullets: [UMAFCoreEngine.Bullet],
    frontMatter: [UMAFCoreEngine.FrontMatterEntry],
    tables: [UMAFCoreEngine.Table],
    codeBlocks: [UMAFCoreEngine.CodeBlock]
  ) {
    return UMAFCoreEngine.parseSemanticStructure(
      from: markdown,
      mediaType: "text/markdown"
    )
  }
}
