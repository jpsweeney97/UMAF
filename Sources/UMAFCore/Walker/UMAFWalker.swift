// Sources/UMAFCore/Walker/UMAFWalker.swift
import Foundation

enum UMAFWalkerV0_7 {

  private struct StableIDGenerator {
    private var counts: [String: Int] = [:]
    mutating func nextSpan(prefix: String) -> String { makeId(prefix: prefix) }
    mutating func nextBlock(prefix: String) -> String { makeId(prefix: prefix) }
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

  static func build(
    from coreEnvelope: UMAFCoreEngine.Envelope
  ) -> UMAFEnvelopeV0_7 {
    let source = BlockProvenanceV0_7.source(for: coreEnvelope.mediaType)
    let normalizedLines = coreEnvelope.normalized.split(
      separator: "\n", omittingEmptySubsequences: false
    ).map(String.init)
    let lineCount = max(1, coreEnvelope.lineCount)

    var spans: [UMAFSpanV0_7] = []
    var blocks: [UMAFBlockV0_7] = []
    var ids = StableIDGenerator()

    let rootSpanId = "span:root"
    let rootSpan = UMAFSpanV0_7(id: rootSpanId, startLine: 1, endLine: lineCount)
    spans.append(rootSpan)

    let rootBlockId = "block:root"
    let rootBlock = UMAFBlockV0_7(
      id: rootBlockId,
      kind: .root,
      spanId: rootSpanId,
      parentId: nil,
      level: 1,
      heading: coreEnvelope.docTitle,
      metadata: ["mediaType": coreEnvelope.mediaType],
      provenance: "umaf:\(UMAFVersion.provenance):root",
      confidence: 1.0
    )
    blocks.append(rootBlock)

    let frontMatterPlacement = Self.frontMatterPlacement(
      lines: normalizedLines, entries: coreEnvelope.frontMatter, lineCount: lineCount)
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

    let sectionPlacements = coreEnvelope.sections.map {
      SectionPlacement(
        section: $0,
        startLine: $0.startLineIndex + 1,
        endLine: $0.endLineIndex + 1
      )
    }

    var items: [StructuralItem] = []
    if let front = frontMatterPlacement { items.append(StructuralItem(kind: .frontMatter(front))) }
    for section in sectionPlacements { items.append(StructuralItem(kind: .section(section))) }
    for table in tablePlacements { items.append(StructuralItem(kind: .table(table))) }
    for code in codePlacements { items.append(StructuralItem(kind: .code(code))) }
    for bullet in bulletPlacements { items.append(StructuralItem(kind: .bullet(bullet))) }

    items.sort { lhs, rhs in
      if lhs.kind.startLine != rhs.kind.startLine { return lhs.kind.startLine < rhs.kind.startLine }
      if lhs.kind.priority != rhs.kind.priority { return lhs.kind.priority < rhs.kind.priority }
      return lhs.kind.endLine < rhs.kind.endLine
    }

    var sectionBlocks: [SectionPlacement] = []

    for item in items {
      switch item.kind {
      case .frontMatter(let placement):
        let spanId = ids.nextSpan(prefix: "span:front")
        let blockId = ids.nextBlock(prefix: "block:front")
        spans.append(
          UMAFSpanV0_7(
            id: spanId, startLine: placement.range.lowerBound, endLine: placement.range.upperBound))
        var metadata: [String: String] = [:]
        for entry in placement.entries { metadata[entry.key] = entry.value }
        let prov = BlockProvenanceV0_7.provenanceAndConfidence(for: .frontMatter, source: source)
        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .frontMatter, spanId: spanId, parentId: rootBlockId,
            metadata: metadata.isEmpty ? nil : metadata, provenance: prov.provenance,
            confidence: prov.confidence))

      case .section(var placement):
        let spanId = ids.nextSpan(prefix: "span:sec")
        let blockId = ids.nextBlock(prefix: "block:sec")
        placement.spanId = spanId
        placement.blockId = blockId
        spans.append(
          UMAFSpanV0_7(id: spanId, startLine: placement.startLine, endLine: placement.endLine))

        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .section, spanId: spanId, parentId: rootBlockId,
            level: placement.section.level, heading: placement.section.heading,
            provenance: BlockProvenanceV0_7.provenanceAndConfidence(for: .section, source: source)
              .provenance,
            confidence: BlockProvenanceV0_7.provenanceAndConfidence(for: .section, source: source)
              .confidence
          ))
        sectionBlocks.append(placement)

      case .table(let placement):
        let spanId = ids.nextSpan(prefix: "span:tbl")
        let blockId = ids.nextBlock(prefix: "block:tbl")
        spans.append(
          UMAFSpanV0_7(
            id: spanId, startLine: placement.range.lowerBound, endLine: placement.range.upperBound))
        let parentId =
          Self.parentSectionId(for: placement.range.lowerBound, sections: sectionBlocks)
          ?? rootBlockId
        let prov = BlockProvenanceV0_7.provenanceAndConfidence(
          for: .table, source: source,
          tableInfo: BlockProvenanceV0_7.TableInfo(
            headerCount: placement.table.header.count, rowCounts: placement.table.rows.map(\.count))
        )
        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .table, spanId: spanId, parentId: parentId,
            tableHeader: placement.table.header, tableRows: placement.table.rows,
            provenance: prov.provenance, confidence: prov.confidence))

      case .code(let placement):
        let spanId = ids.nextSpan(prefix: "span:code")
        let blockId = ids.nextBlock(prefix: "block:code")
        spans.append(
          UMAFSpanV0_7(
            id: spanId, startLine: placement.range.lowerBound, endLine: placement.range.upperBound))
        let parentId =
          Self.parentSectionId(for: placement.range.lowerBound, sections: sectionBlocks)
          ?? rootBlockId
        let prov = BlockProvenanceV0_7.provenanceAndConfidence(for: .code, source: source)
        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .code, spanId: spanId, parentId: parentId,
            language: placement.block.language, provenance: prov.provenance,
            confidence: prov.confidence))

      case .bullet(let placement):
        let spanId = ids.nextSpan(prefix: "span:bullet")
        let blockId = ids.nextBlock(prefix: "block:bullet")
        spans.append(
          UMAFSpanV0_7(
            id: spanId, startLine: placement.range.lowerBound, endLine: placement.range.upperBound))
        let parentId =
          Self.parentSectionId(for: placement.range.lowerBound, sections: sectionBlocks)
          ?? rootBlockId
        let prov = BlockProvenanceV0_7.provenanceAndConfidence(for: .bullet, source: source)
        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .bullet, spanId: spanId, parentId: parentId,
            level: placement.bullet.sectionLevel, heading: placement.bullet.text,
            provenance: prov.provenance, confidence: prov.confidence))
      }
    }

    let paragraphExcluded = frontMatterLines.union(codeLineSet).union(tableLineSet).union(
      bulletLineSet)

    for section in sectionBlocks {
      let ranges = Self.paragraphRanges(
        in: section, lineCount: lineCount, excludedLines: paragraphExcluded)
      for range in ranges {
        let spanId = ids.nextSpan(prefix: "span:p")
        let blockId = ids.nextBlock(prefix: "block:p")
        spans.append(
          UMAFSpanV0_7(id: spanId, startLine: range.lowerBound, endLine: range.upperBound))
        let prov = BlockProvenanceV0_7.provenanceAndConfidence(for: .paragraph, source: source)
        blocks.append(
          UMAFBlockV0_7(
            id: blockId, kind: .paragraph, spanId: spanId, parentId: section.blockId,
            provenance: prov.provenance, confidence: prov.confidence))
      }
    }

    let coveredBySpans = Self.lineSet(
      for: spans.filter { $0.id != rootSpanId }.map { $0.startLine...$0.endLine })
    let uncoveredRanges = Self.uncoveredRanges(upTo: lineCount, coveredLines: coveredBySpans)

    for range in uncoveredRanges {
      let spanId = ids.nextSpan(prefix: "span:raw")
      let blockId = ids.nextBlock(prefix: "block:raw")
      spans.append(UMAFSpanV0_7(id: spanId, startLine: range.lowerBound, endLine: range.upperBound))
      let parentId =
        Self.parentSectionId(for: range.lowerBound, sections: sectionBlocks) ?? rootBlockId
      let prov = BlockProvenanceV0_7.provenanceAndConfidence(for: .raw, source: source)
      blocks.append(
        UMAFBlockV0_7(
          id: blockId, kind: .raw, spanId: spanId, parentId: parentId, provenance: prov.provenance,
          confidence: prov.confidence))
    }

    // Copy semantic data to envelope
    let sections = coreEnvelope.sections.map { $0.asEnvelopeSection() }
    let bullets = coreEnvelope.bullets.map {
      UMAFEnvelopeV0_7.Bullet(
        text: $0.text, lineIndex: $0.lineIndex, sectionHeading: $0.sectionHeading,
        sectionLevel: $0.sectionLevel)
    }
    let frontMatter = coreEnvelope.frontMatter.map {
      UMAFEnvelopeV0_7.FrontMatterEntry(key: $0.key, value: $0.value)
    }
    let tables = coreEnvelope.tables.map {
      UMAFEnvelopeV0_7.Table(startLineIndex: $0.startLineIndex, header: $0.header, rows: $0.rows)
    }
    let codeBlocks = coreEnvelope.codeBlocks.map {
      UMAFEnvelopeV0_7.CodeBlock(
        startLineIndex: $0.startLineIndex, language: $0.language, code: $0.code)
    }

    return UMAFEnvelopeV0_7(
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
      featureFlags: ["structure": true]
    )
  }

  static func ensureRootSpanAndBlock(_ envelope: UMAFEnvelopeV0_7) -> UMAFEnvelopeV0_7 {
    var env = envelope
    let rootSpanId = "span:root"
    let rootBlockId = "block:root"
    let lineCount = max(1, env.lineCount)

    if env.spans.first(where: { $0.id == rootSpanId }) == nil {
      env.spans.insert(UMAFSpanV0_7(id: rootSpanId, startLine: 1, endLine: lineCount), at: 0)
    }
    if env.blocks.first(where: { $0.id == rootBlockId }) == nil {
      env.blocks.insert(
        UMAFBlockV0_7(
          id: rootBlockId, kind: .root, spanId: rootSpanId, parentId: nil, level: 1,
          heading: env.docTitle, metadata: ["mediaType": env.mediaType],
          provenance: "umaf:\(UMAFVersion.provenance):root", confidence: 1.0), at: 0)
    }
    env.featureFlags["structure"] = true
    return env
  }

  // MARK: - Helpers

  private static func parentSectionId(for line: Int, sections: [SectionPlacement]) -> String? {
    sections.last(where: { line >= $0.startLine && line <= $0.endLine })?.blockId
  }

  private static func frontMatterPlacement(
    lines: [String], entries: [UMAFCoreEngine.FrontMatterEntry], lineCount: Int
  ) -> FrontMatterPlacement? {
    guard !entries.isEmpty, let first = lines.first,
      first.trimmingCharacters(in: .whitespaces) == "---"
    else { return nil }
    var endIndex: Int?
    for i in 1..<lines.count {
      if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
        endIndex = i + 1
        break
      }
    }
    guard let end = endIndex else { return nil }
    let clampedEnd = min(max(1, end), lineCount)
    return FrontMatterPlacement(entries: entries, range: 1...clampedEnd)
  }

  private static func codePlacement(for block: UMAFCoreEngine.CodeBlock, lineCount: Int)
    -> CodePlacement?
  {
    let codeLines =
      block.code.isEmpty
      ? 0 : block.code.split(separator: "\n", omittingEmptySubsequences: false).count
    let totalLines = codeLines + 2
    let start = block.startLineIndex + 1
    guard start <= lineCount else { return nil }
    let end = min(lineCount, start + totalLines - 1)
    return CodePlacement(block: block, range: start...end)
  }

  private static func tablePlacement(for table: UMAFCoreEngine.Table, lineCount: Int)
    -> TablePlacement?
  {
    let totalLines = 2 + table.rows.count
    let start = table.startLineIndex + 1
    guard start <= lineCount else { return nil }
    let end = min(lineCount, start + totalLines - 1)
    return TablePlacement(table: table, range: start...end)
  }

  private static func bulletPlacement(for bullet: UMAFCoreEngine.Bullet, lineCount: Int)
    -> BulletPlacement?
  {
    let start = bullet.lineIndex + 1
    guard start <= lineCount else { return nil }
    return BulletPlacement(bullet: bullet, range: start...start)
  }

  private static func paragraphRanges(
    in placement: SectionPlacement, lineCount: Int, excludedLines: Set<Int>
  ) -> [ClosedRange<Int>] {
    guard !placement.section.lines.isEmpty else { return [] }
    // Fix: Offset by 1 to skip the Heading line itself.
    // The section.lines array matches the document lines starting immediately AFTER the heading.
    // e.g. Doc: [Line 1: Heading] [Line 2: Blank] [Line 3: Text]
    // section.lines: ["" (Line 2), "Text" (Line 3)]
    // Iterating section.lines[0] should yield Line 2.
    // So bodyStart = StartLine(1) + 1 = 2.
    let bodyStart = placement.startLine + 1

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

  private static func uncoveredRanges(upTo lineCount: Int, coveredLines: Set<Int>) -> [ClosedRange<
    Int
  >] {
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
    if let start = currentStart { ranges.append(start...lineCount) }
    return ranges
  }
}
