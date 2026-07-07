# Related and Reference Projects

## Purpose

This document maps related repositories and reference projects.

It separates inherited CodeEdit ecosystem projects from external reference projects. The goal is to make the repo easier to understand without assuming that every inherited dependency still belongs in the current product.

Current milestone: lightweight macOS text editor with syntax highlighting, not an IDE.

## CodeEdit Ecosystem and Inherited Projects

### CodeEdit

- Relationship: upstream source and parent project
- Link: https://github.com/CodeEditApp/CodeEdit
- Status for this repo: upstream ancestry and source material
- Evidence: this repo started from the CodeEdit ecosystem, and local packages link back to CodeEditApp repositories.
- Notes: useful for understanding inherited architecture, but inherited architecture can be simplified when it conflicts with the current scope.

### CodeEditTextView

- Relationship: companion library and lower-level editor surface
- Link: https://github.com/CodeEditApp/CodeEditTextView
- Status for this repo: high-value reference and possible active editor surface
- Evidence: the project describes itself as a text editor specialized for displaying and editing code documents. It lists basic text editing, extremely fast initial layout, large document handling, and customization options for code documents. ([GitHub](https://github.com/CodeEditApp/CodeEditTextView?utm_source=chatgpt.com))
- Notes: this is the most relevant CodeEdit ecosystem project for the plain-editor path. It is closer to the required editor surface than CodeEditSourceEditor.

### CodeEditSourceEditor

- Relationship: inherited higher-level source-editor facade
- Link: https://github.com/CodeEditApp/CodeEditSourceEditor
- Status for this repo: legacy or being removed from the required build path
- Evidence: the project describes itself as an Xcode-inspired code editor view written in Swift and powered by tree-sitter. It includes syntax highlighting, code completion, find and replace, text diff, validation, current-line highlighting, minimap, inline messages, bracket matching, and more. ([GitHub](https://github.com/CodeEditApp/CodeEditSourceEditor?utm_source=chatgpt.com))
- Notes: useful for understanding the inherited editor stack, but it is heavier than the current plain-editor milestone.

### CodeEditLanguages

- Relationship: companion language metadata and parser package
- Link: https://github.com/CodeEditApp/CodeEditLanguages
- Status for this repo: legacy if tied to tree-sitter-based parser packages
- Evidence: the project describes its supported languages in terms of tree-sitter grammars and `highlights.scm` files used for syntax highlighting. ([GitHub](https://github.com/CodeEditApp/CodeEditLanguages?utm_source=chatgpt.com))
- Notes: useful for understanding the old syntax-highlighting path. The current direction favors syntax definitions as data files, not compiled parser packages.

### CodeEditKit

- Relationship: companion extension-facing library
- Link: https://github.com/CodeEditApp/CodeEditKit
- Status for this repo: inherited support package, evaluate and trim
- Evidence: CodeEdit ecosystem package documentation identifies CodeEditKit as part of the shared CodeEdit package family.
- Notes: useful only where it directly supports the current app. Extension-platform machinery should not drive the plain-editor build path.

### CodeEditCLI

- Relationship: companion CLI
- Link: https://github.com/CodeEditApp/CodeEditCLI
- Status for this repo: out of scope for the current milestone
- Evidence: the project is a command-line companion in the CodeEdit ecosystem.
- Notes: useful as ecosystem context, but not needed for the current plain-editor app build.

## External Reference Projects and Prior Art

### CodeEditorView

- Relationship: same-domain SwiftUI code editor component
- Link: https://github.com/mchakravarty/CodeEditorView
- Status for this repo: reference only
- Evidence: the README describes a SwiftUI code editor view for iOS, visionOS, and macOS. It is based on TextKit 2 and includes syntax highlighting, configurable themes, inline messages, bracket matching, completion, and minimap support. ([GitHub](https://github.com/mchakravarty/CodeEditorView?utm_source=chatgpt.com))
- Confidence: high
- Notes: useful for SwiftUI/TextKit 2 editor architecture. Some features are beyond the current plain-editor milestone.

### SwiftEdit

- Relationship: historical prior art
- Link: https://github.com/jpsim/SwiftEdit
- Status for this repo: reference only
- Evidence: the README describes it as a proof-of-concept Swift editor with Swift syntax highlighting using SourceKitten.
- Confidence: high
- Notes: useful historically, but old enough that it should not define modern Swift 6 or macOS 26 architecture.

### CodeEditor

- Relationship: same-domain SwiftUI editor component
- Link: https://github.com/ZeeZide/CodeEditor
- Status for this repo: cautionary reference
- Evidence: the README describes it as a SwiftUI `TextEditor` view with syntax highlighting using Highlight.js through Highlightr.
- Confidence: high
- Notes: useful for SwiftUI editor wrapping ideas, but the Highlight.js/Highlightr path does not match the preferred native syntax-definition direction.

### SwiftCodeEditor

- Relationship: same-domain SwiftUI editor component
- Link: https://github.com/jankammerath/SwiftCodeEditor
- Status for this repo: cautionary reference
- Evidence: the README describes it as a SwiftUI `TextEditor` view with syntax highlighting using Highlight.js through Highlightr.
- Confidence: high
- Notes: useful only as prior art for SwiftUI packaging. It does not match the preferred direction because it depends on a JavaScript-based highlighter stack.

### RichEditorSwiftUI

- Relationship: adjacent editor work
- Link: https://github.com/canopas/rich-editor-swiftui
- Status for this repo: low relevance
- Evidence: the project is a SwiftUI rich text editor wrapper, focused on rich text editing rather than source-code editing.
- Confidence: medium
- Notes: possibly useful for SwiftUI/UIKit or AppKit bridging concepts, but it is not a code editor reference.

### SwiftUI Code Editor Article

- Relationship: article-level prior art
- Link: https://sebwhitfield.medium.com/building-a-code-editor-using-swiftui-bb74819b5c1f
- Status for this repo: reference only
- Evidence: article about building a code editor using SwiftUI.
- Confidence: medium
- Notes: useful as design background, not as an implementation source of truth.

### Editor

- Relationship: external reference project
- Link: https://github.com/mmackh/Editor
- Status for this repo: evaluate before assigning architectural weight
- Evidence: not confirmed from reliable web search in this pass.
- Confidence: unknown
- Notes: evaluate from the upstream README, package manifest, license, and source structure before assigning it architectural weight.

## Current Interpretation

The most relevant projects for the current plain-editor direction are:

1. `CodeEditTextView`
   - Most useful inherited editor-surface reference.

2. `CodeEditorView`
   - Useful SwiftUI/TextKit 2 architecture reference.

3. `CodeEditSourceEditor`
   - Useful mainly as inherited context and cautionary reference because it includes heavier source-editor and IDE-adjacent behavior.

4. `CodeEditLanguages`
   - Useful mainly as inherited syntax-highlighting context. It does not match the preferred data-file syntax-definition direction.

5. `CodeEditor` and `SwiftCodeEditor`
   - Useful as SwiftUI editor prior art, but not as a preferred highlighting path because they use Highlight.js/Highlightr.
