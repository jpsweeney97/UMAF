---
title: "UMAF Markdown Crucible v2"
description: "Comprehensive torture-test for UMAF envelope & Markdown normalization."
tags: ["crucible", "markdown", "edge-cases"]
version: "2.0"
---

# UMAF – Markdown Crucible v2

This file is deliberately hostile.
Its only purpose is to stress-test UMAF's parsing, normalization,
and envelope generation.

If UMAF can transform this file into a valid envelope that passes
the schema and is stable under re-transformation, we’re doing very well.

## 1. Headings & Spacing (Setext + ATX + malformed)

###NoSpaceHeading
This heading has no space after the hashes.
Will it be normalized or treated as plain text?

### Extra Space Around Hashes

This heading has leading and internal extra spaces.

#### H4 With Trailing Spaces

This line should end with no trailing spaces after canonicalization.

##### Mixed CASE Heading

Paragraph under a fifth-level heading.

######TooTight
Another malformed heading with no space.

Heading that uses setext style:
First line
should be an `h2` below:

## Setext Style Heading

This one should be an `h3`:

Another Setext Heading

````



##   2. Paragraphs, Blank Lines, and Whitespace Only Lines


This paragraph has trailing spaces at the end of the line.
This line has none.


This paragraph is separated from the previous by multiple blank lines,
some of which contain only spaces or tabs.

This paragraph
is intentionally split
across multiple lines
without a blank line between them.

There should be exactly one blank line after this paragraph
before the next block.

This is another paragraph in the same section.

This paragraph has a literal NBSP between words: `hello world` (copy/paste may show as a normal space).



##   3. List Zoo: Bullets, Nesting, Checkboxes, and Gaps


- Top-level item A
- Top-level item B with trailing spaces
- Top-level item C

    - Child of C (4 spaces before dash)
        - Grandchild of C (8 spaces before dash)
    - Second child of C

- List with blank lines

- Item 1

- Item 2

- Item 3

* Mixed-style bullet one
* Mixed-style bullet two

+ Plus-style bullet one

+ Plus-style bullet two

- [ ] Checkbox unchecked
- [x] Checkbox checked
- [X] Checkbox with capital X (still checked)
- [ ]   Checkbox with weird spacing

1. First ordered item
2. Second item with trailing spaces
3. Third item

1. Another list that restarts numbering
2. Still ok if canonical
10. Jumped ahead, will UMAF keep it?

3. Out-of-order numbering
1. Smaller number after larger one
5. Another arbitrary value

1. Parent item with nested ordered list
   1. Child item
   2. Another child
      1. Grandchild
      2. Second grandchild



##  4. Blockquotes & Nested Lists & Code


>   This blockquote line has extra leading spaces and trailing spaces.
> Second line of the quote.
>
>
> Third line after multiple blank lines in the quote.
> - Bullet inside quote
> - Second bullet inside quote
>   - Nested quote bullet
>
> Ending paragraph in quote.

> Blockquote with fenced code:
>
> ```js
> function quoted() {
>   console.log("Hello from inside a quote");
> }
> ```
>
> Final line in quote.

This paragraph has `inline code`, **bold text**, *italic text*, ~~strikethrough~~,
and a link [Example Link][example-link].

It also includes an image: ![Alt Text](https://example.com/image.png "Title")



##  5. Tables (simple, messy, malformed)


### 5.1 Simple, Clean Table

| Name  | Value | Notes           |
| ----- | :---: | --------------- |
| A     |  1    | First entry     |
| B     |  22   | Second entry    |
| Long  | 333   | Multi-word note |


### 5.2 Messy, Misaligned Table

|  Col A   |Col B|   Col C  |
| --- |  :---: | ---: |
|   1   | two |   3   |
| four| 5    |   6|
|seven | eight|9 |

### 5.3 Inconsistent Columns (Malformed)

| A | B |
|---|---|
| 1 | 2 | extra |
| only-one-cell |
| 3 | 4 |

The last table is intentionally malformed to see how robust the table detector is.



##  6. Fenced Code Blocks (closed, unclosed, languages, nested backticks)


```swift
// This Swift code block should NOT be aggressively canonicalized
// beyond trimming trailing whitespace on the fence lines.
//
// The blank lines *inside* the block should be preserved.

struct Example {
    let value: Int

    func double() -> Int {
        return value * 2   // trailing spaces here
    }
}

// The next line contains backticks:
let raw = "```this should not terminate the fence```"
```

```json
{
  "messy":  true,
  "numbers": [1,  2, 3    ],
  "nested": {
    "a": 1,
    "b": 2
  }
}
```

```markdown
# Heading in a code block

- Bullet that *looks* like a real Markdown list
- But lives inside a fenced code block

```nested
Not really nested, but looks suspicious.
```
```

This fence starts but never closes correctly:

```python
def unclosed():
    print("This fence is never properly closed")
    print("UMAF should still recover and not swallow the rest of the file.")

# Below is a stray closing fence that does not match anything above:
```

The above situation is meant to simulate mis-nested fences.

Now here’s a fence using tildes (should still be recognized by some parsers, even if UMAF focuses on ```):

~~~bash
echo "This is inside a tilde fence"
ls -la
~~~



##  7. Broken Markdown Constructs: Links, Footnotes, Images


This line has an incomplete link: [Broken Link](https://example.com "title

This line has a reference-style link with a missing definition: [Missing Ref][no-such-ref]

Here is a link with weird escaping: \[Not a link\](actually-not)

This is an inline footnote reference[^1] and another[^missing].

![Broken image](not a valid url "Unclosed title)

Some text with a stray `]` character that might confuse naive parsers ] here.

[^1]: This is a valid footnote definition.
[^missing]: This one is intentionally mis-ordered.



##  8. Mixed Inline HTML and Markdown


<p>This paragraph is wrapped in HTML tags <strong>with bold text</strong> and
a <em>mix of inline emphasis</em>. There is also a <a href="https://example.com">link</a>.</p>

<p>Below is an HTML unordered list with nested tags:</p>
<ul>
  <li>HTML item one</li>
  <li>HTML item two with <strong>bold</strong> and <em>emphasis</em></li>
  <li>HTML item three
    <ul>
      <li>Nested child one</li>
      <li>Nested child two</li>
    </ul>
  </li>
</ul>

This paragraph follows the inline HTML. It should not be merged into the list above.

<div class="note">
  <p>Block-level HTML container with <code>inline code</code> and <strong>bold</strong>.</p>
</div>



##  9. Escapes, Backslashes, and Literal Characters


This line has a literal backslash at the end: \\
This line has a backslash before a backtick: \`code?`
This line has escaped asterisks: \*not italic\*
This line has escaped underscores: \_not italic\_
This line has escaped brackets: \[not a link\](not-a-url)

- List item with an escaped bullet inside: \- not a real bullet
- List item with escaped `\`inline code\`` and \\slashes\\

> Blockquote with \`escaped\` code and \*escaped stars\*.

Here is an inline code span that contains a backtick: ``code with ` backtick``

Here is a code span that ends right before a backslash: `ends with slash\`



##  10. Unicode, Emojis, and Strange Text


This line has emoji: 😀 😅 🚀 🧪
This line has accented characters: àéîõü, ÄÖÜß, café, naïve, coöperate
This line has mixed scripts: English النص العربي 中文测试 кириллица

- Bullet with emoji at start 😀 Item
- Bullet with emoji in the middle: Item 😅 in progress
- Bullet with emoji at the end: Item finished ✅


### 10.1 Zero-width oddities (if your editor preserves them)

This line may contain zero-width space between words: `word1​word2`
This line may contain a zero-width joiner in the middle: `a‍b`

(Depending on your editor, these may or may not be visible; they are here to test text normalization.)



##  11. Final Stability Check (Idempotence Expectations)


After one UMAF → JSON envelope → Markdown transform, the resulting Markdown should:

- Have exactly one space after each heading’s `#` run.
- Have **no** trailing spaces on any line.
- Have at most one blank line between any two block elements.
- Have no blank lines between consecutive list items in the same list.
- Preserve fenced code blocks exactly (internal blank lines and content unchanged).
- Preserve tables’ row structure (no rows merged or deleted, even if malformed).
- Treat unclosed fences and malformed constructs robustly, not swallowing the rest of the document.
- Be stable: running UMAF → JSON envelope → Markdown again should produce the **exact same file** (modulo allowed metadata like timestamps).

If any of those conditions fail for this file, UMAF's strict canonical Markdown mode and envelope generation still have work to do.



[example-link]: https://example.com "Example link title"
````
