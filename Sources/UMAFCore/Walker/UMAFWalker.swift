// Sources/UMAFCore/Walker/UMAFWalker.swift
import Foundation

enum UMAFWalkerV0_5 {

  private struct StableIDGenerator {
    private var counts: [String: Int] = [:]

    mutating func nextSpan(prefix: String) -> String {
      makeId(prefix: prefix)
    }

    mutating func nextBlock(prefix: String) -> String {
      makeId(prefix: prefix)
    }

    private mutating func makeId(prefix: String) -> String {
      let next = (counts[prefix] ?? 0) + 1
      counts[prefix] = next
      return String(format: "%@:%03d", prefix, next)
    }
  }

  private struct SectionPlacement {
    let section: UMAFCoreEngine.Section
    let startLine: Int
    let endLine: Int
    let hasHeading: Bool
    var spanId: String = ""
    var blockId: String = ""
  }

  private struct CodePlacement {
    let block: UMAFCoreEngine.CodeBlock
    let range: ClosedRange<Int>
  }

  private struct TablePlacement {
    let table: UMAFCoreEngine.Table
    let range: ClosedRange<Int>
  }

  private struct BulletPlacement {
    let bullet: UMAFCoreEngine.Bullet
    let range: ClosedRange<Int>
  }

  private struct FrontMatterPlacement {
    let entries: [UMAFCoreEngine.FrontMatterEntry]
    let range: ClosedRange<Int>
  }

  private enum StructuralItemKind {
    case section(SectionPlacement)
    case table(TablePlacement)
    case code(CodePlacement)
    case bullet(BulletPlacement)
    case frontMatter(FrontMatterPlacement)

    var startLine: Int {
      switch self {
      case .section(let placement): return placement.startLine
      case .table(let placement): return placement.range.lowerBound
      case .code(let placement): return placement.range.lowerBound
      case .bullet(let placement): return placement.range.lowerBound
      case .frontMatter(let placement): return placement.range.lowerBound
      }
    }

    var endLine: Int {
      switch self {
      case .section(let placement): return placement.endLine
      case .table(let placement): return placement.range.upperBound
      case .code(let placement): return placement.range.upperBound
      case .bullet(let placement): return placement.range.upperBound
      case .frontMatter(let placement): return placement.range.upperBound
      }
    }

    var priority: Int {
      switch self {
      case .frontMatter: return 0
      case .section: return 1
      case .table: return 2
      case .code: return 3
      case .bullet: return 4
      }
    }
  }

  private struct StructuralItem {
    let kind: StructuralItemKind
  }

  /// Build a fully-populated UMAFEnvelopeV0_5 from a core envelope.
  static func build(
    from coreEnvelope: UMAFCoreEngine.Envelope,
    routedInput: InputRouter.RoutedInput? = nil
  ) -> UMAFEnvelopeV0_5 {
    _ = routedInput  // Reserved for future mediaType/semanticMediaType tweaks.
    let source = BlockProvenanceV0_5.source(for: coreEnvelope.mediaType)

    let normalizedLines = coreEnvelope.normalized.split(
      separator: "\n",
      omittingEmptySubsequences: false
    ).map(String.init)

    let lineCount = max(1, coreEnvelope.lineCount)

    var spans: [UMAFSpanV0_5] = []
    var blocks: [UMAFBlockV0_5] = []
    var ids = StableIDGenerator()

    let rootSpanId = "span:root"
    let rootSpan = UMAFSpanV0_5(
      id: rootSpanId,
      startLine: 1,
      endLine: lineCount,
      startColumn: nil,
      endColumn: nil
    )
    spans.append(rootSpan)

    let rootBlockId = "block:root"
    let rootBlock = UMAFBlockV0_5(
      id: rootBlockId,
      kind: .root,
      spanId: rootSpanId,
      parentId: nil,
      level: 1,
      heading: coreEnvelope.docTitle,
      language: nil,
      tableHeader: nil,
      tableRows: nil,
      metadata: ["mediaType": coreEnvelope.mediaType],
      provenance: "umaf:0.5.0:root",
      confidence: 1.0
    )
    blocks.append(rootBlock)

    let frontMatterPlacement = Self.frontMatterPlacement(
      lines: normalizedLines,
      entries: coreEnvelope.frontMatter,
      lineCount: lineCount
    )
    let frontMatterLines = frontMatterPlacement.map { Self.lineSet(for: [$0.range]) } ?? Set<Int>()

    let codePlacements = coreEnvelope.codeBlocks.compactMap {
      Self.codePlacement(for: $0, lineCount: lineCount)
    }
    let codeLineSet = Self.lineSet(for: codePlacements.map(\.range))

    let tablePlacements = coreEnvelope.tables.compactMap {
      Self.tablePlacement(for: $0, lineCount: lineCount)
    }
    let tableLineSet = Self.lineSet(for: tablePlacements.map(\.range))

    let bulletPlacements = coreEnvelope.bullets.compactMap {
      Self.bulletPlacement(for: $0, lineCount: lineCount)
    }
    let bulletLineSet = Self.lineSet(for: bulletPlacements.map(\.range))

    let sectionPlacements = Self.sectionPlacements(
      sections: coreEnvelope.sections,
      lines: normalizedLines,
      lineCount: lineCount,
      excludedLines: codeLineSet.union(frontMatterLines)
    )

    var items: [StructuralItem] = []
    if let front = frontMatterPlacement { items.append(StructuralItem(kind: .frontMatter(front))) }
    for section in sectionPlacements { items.append(StructuralItem(kind: .section(section))) }
    for table in tablePlacements { items.append(StructuralItem(kind: .table(table))) }
    for code in codePlacements { items.append(StructuralItem(kind: .code(code))) }
    for bullet in bulletPlacements { items.append(StructuralItem(kind: .bullet(bullet))) }

    items.sort { lhs, rhs in
      if lhs.kind.startLine != rhs.kind.startLine {
        return lhs.kind.startLine < rhs.kind.startLine
      }
      if lhs.kind.priority != rhs.kind.priority {
        return lhs.kind.priority < rhs.kind.priority
      }
      return lhs.kind.endLine < rhs.kind.endLine
    }

    var sectionBlocks: [SectionPlacement] = []

    for item in items {
      switch item.kind {
      case .frontMatter(let placement):
        let spanId = ids.nextSpan(prefix: "span:front")
        let blockId = ids.nextBlock(prefix: "block:front")
        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: placement.range.lowerBound,
          endLine: placement.range.upperBound,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        var metadata: [String: String] = [:]
        for entry in placement.entries { metadata[entry.key] = entry.value }

        let prov = BlockProvenanceV0_5.provenanceAndConfidence(
          for: .frontMatter,
          source: source
        )

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .frontMatter,
          spanId: spanId,
          parentId: rootBlockId,
          level: nil,
          heading: nil,
          language: nil,
          tableHeader: nil,
          tableRows: nil,
          metadata: metadata.isEmpty ? nil : metadata,
          provenance: prov.provenance,
          confidence: prov.confidence
        )
        blocks.append(block)

      case .section(var placement):
        let spanId = ids.nextSpan(prefix: "span:sec")
        let blockId = ids.nextBlock(prefix: "block:sec")
        placement.spanId = spanId
        placement.blockId = blockId

        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: placement.startLine,
          endLine: placement.endLine,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .section,
          spanId: spanId,
          parentId: rootBlockId,
          level: placement.section.level,
          heading: placement.section.heading,
          language: nil,
          tableHeader: nil,
          tableRows: nil,
          metadata: nil,
          provenance: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .section,
            source: source
          ).provenance,
          confidence: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .section,
            source: source
          ).confidence
        )
        blocks.append(block)
        sectionBlocks.append(placement)

      case .table(let placement):
        let spanId = ids.nextSpan(prefix: "span:tbl")
        let blockId = ids.nextBlock(prefix: "block:tbl")
        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: placement.range.lowerBound,
          endLine: placement.range.upperBound,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        let parentId =
          Self.parentSectionId(
            for: placement.range.lowerBound,
            sections: sectionBlocks
          ) ?? rootBlockId

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .table,
          spanId: spanId,
          parentId: parentId,
          level: nil,
          heading: nil,
          language: nil,
          tableHeader: placement.table.header,
          tableRows: placement.table.rows,
          metadata: nil,
          provenance: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .table,
            source: source,
            tableInfo: BlockProvenanceV0_5.TableInfo(
              headerCount: placement.table.header.count,
              rowCounts: placement.table.rows.map(\.count)
            )
          ).provenance,
          confidence: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .table,
            source: source,
            tableInfo: BlockProvenanceV0_5.TableInfo(
              headerCount: placement.table.header.count,
              rowCounts: placement.table.rows.map(\.count)
            )
          ).confidence
        )
        blocks.append(block)

      case .code(let placement):
        let spanId = ids.nextSpan(prefix: "span:code")
        let blockId = ids.nextBlock(prefix: "block:code")
        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: placement.range.lowerBound,
          endLine: placement.range.upperBound,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        let parentId =
          Self.parentSectionId(
            for: placement.range.lowerBound,
            sections: sectionBlocks
          ) ?? rootBlockId

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .code,
          spanId: spanId,
          parentId: parentId,
          level: nil,
          heading: nil,
          language: placement.block.language,
          tableHeader: nil,
          tableRows: nil,
          metadata: nil,
          provenance: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .code,
            source: source
          ).provenance,
          confidence: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .code,
            source: source
          ).confidence
        )
        blocks.append(block)

      case .bullet(let placement):
        let spanId = ids.nextSpan(prefix: "span:bullet")
        let blockId = ids.nextBlock(prefix: "block:bullet")
        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: placement.range.lowerBound,
          endLine: placement.range.upperBound,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        let parentId =
          Self.parentSectionId(
            for: placement.range.lowerBound,
            sections: sectionBlocks
          ) ?? rootBlockId

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .bullet,
          spanId: spanId,
          parentId: parentId,
          level: placement.bullet.sectionLevel,
          heading: placement.bullet.text,
          language: nil,
          tableHeader: nil,
          tableRows: nil,
          metadata: nil,
          provenance: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .bullet,
            source: source
          ).provenance,
          confidence: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .bullet,
            source: source
          ).confidence
        )
        blocks.append(block)
      }
    }

    let paragraphExcluded =
      frontMatterLines
      .union(codeLineSet)
      .union(tableLineSet)
      .union(bulletLineSet)

    for section in sectionBlocks {
      let ranges = Self.paragraphRanges(
        in: section,
        lineCount: lineCount,
        excludedLines: paragraphExcluded
      )
      for range in ranges {
        let spanId = ids.nextSpan(prefix: "span:p")
        let blockId = ids.nextBlock(prefix: "block:p")

        let span = UMAFSpanV0_5(
          id: spanId,
          startLine: range.lowerBound,
          endLine: range.upperBound,
          startColumn: nil,
          endColumn: nil
        )
        spans.append(span)

        let block = UMAFBlockV0_5(
          id: blockId,
          kind: .paragraph,
          spanId: spanId,
          parentId: section.blockId,
          level: nil,
          heading: nil,
          language: nil,
          tableHeader: nil,
          tableRows: nil,
          metadata: nil,
          provenance: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .paragraph,
            source: source
          ).provenance,
          confidence: BlockProvenanceV0_5.provenanceAndConfidence(
            for: .paragraph,
            source: source
          ).confidence
        )
        blocks.append(block)
      }
    }

    let coveredBySpans = Self.lineSet(
      for: spans.filter { $0.id != rootSpanId }.map { $0.startLine...$0.endLine }
    )
    let uncoveredRanges = Self.uncoveredRanges(
      upTo: lineCount,
      coveredLines: coveredBySpans
    )

    for range in uncoveredRanges {
      let spanId = ids.nextSpan(prefix: "span:raw")
      let blockId = ids.nextBlock(prefix: "block:raw")
      let span = UMAFSpanV0_5(
        id: spanId,
        startLine: range.lowerBound,
        endLine: range.upperBound,
        startColumn: nil,
        endColumn: nil
      )
      spans.append(span)

      let parentId =
        Self.parentSectionId(
          for: range.lowerBound,
          sections: sectionBlocks
        ) ?? rootBlockId

      let block = UMAFBlockV0_5(
        id: blockId,
        kind: .raw,
        spanId: spanId,
        parentId: parentId,
        level: nil,
        heading: nil,
        language: nil,
        tableHeader: nil,
        tableRows: nil,
        metadata: nil,
        provenance: BlockProvenanceV0_5.provenanceAndConfidence(
          for: .raw,
          source: source
        ).provenance,
        confidence: BlockProvenanceV0_5.provenanceAndConfidence(
          for: .raw,
          source: source
        ).confidence
      )
      blocks.append(block)
    }

    let sections = coreEnvelope.sections.map {
      UMAFEnvelopeV0_5.Section(
        heading: $0.heading,
        level: $0.level,
        lines: $0.lines,
        paragraphs: $0.paragraphs
      )
    }
    let bullets = coreEnvelope.bullets.map {
      UMAFEnvelopeV0_5.Bullet(
        text: $0.text,
        lineIndex: $0.lineIndex,
        sectionHeading: $0.sectionHeading,
        sectionLevel: $0.sectionLevel
      )
    }
    let frontMatter = coreEnvelope.frontMatter.map {
      UMAFEnvelopeV0_5.FrontMatterEntry(key: $0.key, value: $0.value)
    }
    let tables = coreEnvelope.tables.map {
      UMAFEnvelopeV0_5.Table(startLineIndex: $0.startLineIndex, header: $0.header, rows: $0.rows)
    }
    let codeBlocks = coreEnvelope.codeBlocks.map {
      UMAFEnvelopeV0_5.CodeBlock(
        startLineIndex: $0.startLineIndex, language: $0.language, code: $0.code)
    }

    let envelope = UMAFEnvelopeV0_5(
      version: coreEnvelope.version,
      docTitle: coreEnvelope.docTitle,
      docId: coreEnvelope.docId,
      createdAt: coreEnvelope.createdAt,
      sourceHash: coreEnvelope.sourceHash,
      sourcePath: coreEnvelope.sourcePath,
      mediaType: coreEnvelope.mediaType,
      encoding: coreEnvelope.encoding,
      sizeBytes: coreEnvelope.sizeBytes,
      lineCount: coreEnvelope.lineCount,
      normalized: coreEnvelope.normalized,
      sections: sections,
      bullets: bullets,
      frontMatter: frontMatter,
      tables: tables,
      codeBlocks: codeBlocks,
      spans: spans,
      blocks: blocks,
      featureFlags: nil
    )

    return envelope
  }

  /// Ensure at least a root span + root block exist, without altering other content.
  static func ensureRootSpanAndBlock(_ envelope: UMAFEnvelopeV0_5) -> UMAFEnvelopeV0_5 {
    var env = envelope
    let rootSpanId = "span:root"
    let rootBlockId = "block:root"
    let lineCount = max(1, env.lineCount)

    if env.spans.first(where: { $0.id == rootSpanId }) == nil {
      let rootSpan = UMAFSpanV0_5(
        id: rootSpanId,
        startLine: 1,
        endLine: lineCount,
        startColumn: nil,
        endColumn: nil
      )
      env.spans.insert(rootSpan, at: 0)
    }

    if env.blocks.first(where: { $0.id == rootBlockId }) == nil {
      let block = UMAFBlockV0_5(
        id: rootBlockId,
        kind: .root,
        spanId: rootSpanId,
        parentId: nil,
        level: 1,
        heading: env.docTitle,
        language: nil,
        tableHeader: nil,
        tableRows: nil,
        metadata: ["mediaType": env.mediaType],
        provenance: "umaf:0.5.0:root",
        confidence: 1.0
      )
      env.blocks.insert(block, at: 0)
    }

    return env
  }

  // MARK: - Helpers

  private static func parentSectionId(
    for line: Int,
    sections: [SectionPlacement]
  ) -> String? {
    sections.last(where: { line >= $0.startLine && line <= $0.endLine })?.blockId
  }

  private static func frontMatterPlacement(
    lines: [String],
    entries: [UMAFCoreEngine.FrontMatterEntry],
    lineCount: Int
  ) -> FrontMatterPlacement? {
    guard !entries.isEmpty else { return nil }
    guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
      return nil
    }

    var endIndex: Int?
    if lines.count > 1 {
      for i in 1..<lines.count {
        if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
          endIndex = i + 1  // 1-based
          break
        }
      }
    }

    guard let end = endIndex else { return nil }
    let clampedEnd = min(max(1, end), lineCount)
    let range = 1...clampedEnd
    return FrontMatterPlacement(entries: entries, range: range)
  }

  private static func codePlacement(
    for block: UMAFCoreEngine.CodeBlock,
    lineCount: Int
  ) -> CodePlacement? {
    let codeLines =
      block.code.isEmpty
      ? 0
      : block.code.split(separator: "\n", omittingEmptySubsequences: false)
        .count
    let totalLines = codeLines + 2  // fences + content
    let start = block.startLineIndex + 1
    guard start <= lineCount else { return nil }
    let end = min(lineCount, start + totalLines - 1)
    return CodePlacement(block: block, range: start...end)
  }

  private static func tablePlacement(
    for table: UMAFCoreEngine.Table,
    lineCount: Int
  ) -> TablePlacement? {
    let totalLines = 2 + table.rows.count
    let start = table.startLineIndex + 1
    guard start <= lineCount else { return nil }
    let end = min(lineCount, start + totalLines - 1)
    return TablePlacement(table: table, range: start...end)
  }

  private static func bulletPlacement(
    for bullet: UMAFCoreEngine.Bullet,
    lineCount: Int
  ) -> BulletPlacement? {
    let start = bullet.lineIndex + 1
    guard start <= lineCount else { return nil }
    return BulletPlacement(bullet: bullet, range: start...start)
  }

  private static func locateSectionStarts(
    sections: [UMAFCoreEngine.Section],
    lines: [String],
    excludedLines: Set<Int>
  ) -> [Int?] {
    var results: [Int?] = Array(repeating: nil, count: sections.count)
    var searchIndex = 0

    for (idx, section) in sections.enumerated() {
      let found = findHeading(
        for: section,
        lines: lines,
        startingAt: searchIndex,
        excludedLines: excludedLines
      )
      results[idx] = found
      if let found = found {
        searchIndex = found
      } else {
        searchIndex = lines.count
      }
    }

    return results
  }

  private static func findHeading(
    for section: UMAFCoreEngine.Section,
    lines: [String],
    startingAt index: Int,
    excludedLines: Set<Int>
  ) -> Int? {
    guard index < lines.count else { return nil }

    var i = index
    while i < lines.count {
      let lineNumber = i + 1
      if excludedLines.contains(lineNumber) {
        i += 1
        continue
      }

      guard let heading = parseHeading(from: lines[i]) else {
        i += 1
        continue
      }

      if heading.text == section.heading && heading.level == section.level {
        return lineNumber
      }
      i += 1
    }

    return nil
  }

  private static func parseHeading(from line: String) -> (text: String, level: Int)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.first == "#" else { return nil }

    var level = 0
    var idx = trimmed.startIndex
    while idx < trimmed.endIndex, trimmed[idx] == "#" {
      level += 1
      idx = trimmed.index(after: idx)
    }

    if idx < trimmed.endIndex, trimmed[idx] == " " {
      idx = trimmed.index(after: idx)
    }

    let text = String(trimmed[idx...])
    return (text, level)
  }

  private static func sectionPlacements(
    sections: [UMAFCoreEngine.Section],
    lines: [String],
    lineCount: Int,
    excludedLines: Set<Int>
  ) -> [SectionPlacement] {
    let starts = locateSectionStarts(
      sections: sections,
      lines: lines,
      excludedLines: excludedLines
    )

    var placements: [SectionPlacement] = []
    var fallbackStart = 1

    for (idx, section) in sections.enumerated() {
      let hasHeading = starts[idx] != nil
      let startLine = starts[idx] ?? fallbackStart

      let endLine: Int
      if hasHeading {
        endLine = min(lineCount, startLine + section.lines.count)
      } else {
        let total = max(section.lines.count, 1)
        endLine = min(lineCount, startLine + total - 1)
      }

      let placement = SectionPlacement(
        section: section,
        startLine: startLine,
        endLine: max(startLine, endLine),
        hasHeading: hasHeading
      )
      placements.append(placement)
      fallbackStart = endLine + 1
    }

    return placements
  }

  private static func paragraphRanges(
    in placement: SectionPlacement,
    lineCount: Int,
    excludedLines: Set<Int>
  ) -> [ClosedRange<Int>] {
    guard !placement.section.lines.isEmpty else { return [] }

    let offset = placement.hasHeading ? 1 : 0
    let bodyStart = placement.startLine + offset

    var ranges: [ClosedRange<Int>] = []
    var currentStart: Int?

    for (idx, line) in placement.section.lines.enumerated() {
      let lineNumber = bodyStart + idx
      if lineNumber > lineCount { break }

      let isBlank = line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if excludedLines.contains(lineNumber) || isBlank {
        if let start = currentStart {
          let end = lineNumber - 1
          if end >= start { ranges.append(start...end) }
        }
        currentStart = nil
        continue
      }

      if currentStart == nil { currentStart = lineNumber }
    }

    if let start = currentStart {
      let end = min(lineCount, bodyStart + placement.section.lines.count - 1)
      if end >= start { ranges.append(start...end) }
    }

    return ranges
  }

  private static func lineSet(for ranges: [ClosedRange<Int>]) -> Set<Int> {
    ranges.reduce(into: Set<Int>()) { acc, range in
      for line in range where line > 0 { acc.insert(line) }
    }
  }

  private static func uncoveredRanges(
    upTo lineCount: Int,
    coveredLines: Set<Int>
  ) -> [ClosedRange<Int>] {
    var ranges: [ClosedRange<Int>] = []
    var currentStart: Int?

    for line in 1...lineCount {
      if coveredLines.contains(line) {
        if let start = currentStart {
          ranges.append(start...line - 1)
          currentStart = nil
        }
        continue
      }

      if currentStart == nil { currentStart = line }
    }

    if let start = currentStart {
      ranges.append(start...lineCount)
    }

    return ranges
  }
}
