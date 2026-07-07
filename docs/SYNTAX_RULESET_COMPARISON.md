# Syntax Rule-Set Comparison

This note compares the likely first-milestone syntax highlighting formats for CodeEdit.

## 1. Kate / KSyntaxHighlighting XML

Pros:

- Closest fit to the Kate-style custom language story.
- Declarative data files.
- User-installable definitions can live outside the app bundle.
- Good match for a lightweight editor that wants configurable highlighting.

Cons:

- Requires a Swift parser/interpreter for the XML format.
- More format-specific behavior to support if the app wants full compatibility.

## 2. TextMate grammars

Pros:

- Very common across editors.
- Declarative data files, often plist or JSON.
- Broad ecosystem of existing grammars.

Cons:

- Regex-heavy and sometimes inconsistent across grammar authors.
- Still needs a Swift interpreter plus scope-to-theme mapping.

## 3. Sublime `.sublime-syntax`

Pros:

- Declarative YAML.
- Designed for syntax highlighting.
- Easy for users to inspect and edit.

Cons:

- Smaller ecosystem than TextMate.
- Still requires a Swift parser/interpreter.

## Working Conclusion

For this project, the preferred decision point is the rule-set format itself, not editor features.

Current implementation note:

- KDE KSyntaxHighlighting XML is the selected first source of truth for syntax definitions.
- The app should load syntax definition data from XML files, not from hand-authored editor rules.
- The editor adapter's job is to apply spans to `NSTextStorage`, not to define language logic.
- The current bootstrap subset exists only to prove the import boundary while the broader vendored collection and interpreter coverage are completed.

Recommended selection order:

1. Kate / KSyntaxHighlighting XML
2. TextMate grammars
3. Sublime `.sublime-syntax`

The deciding factors should be:

- user-extensibility
- availability of existing language files
- ease of building a native Swift interpreter
- scope-to-theme mapping quality
- long-term maintenance burden

Decision:

- Kate / KSyntaxHighlighting XML is in scope as the first complete ruleset source.
- The first milestone should prove loaded XML-driven coloring and plain-text fallback, then broaden coverage from the same format.
