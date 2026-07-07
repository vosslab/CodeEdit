import Foundation
import CodeEditHighlighting

public enum CodeEditSyntaxDefinitions {
    public static func highlightSpans(text: String, language: String) -> [HighlightSpan] {
        SyntaxDefinitionRepository.shared.highlightSpans(text: text, language: language)
    }
}

public struct SyntaxDefinition: Sendable {
    public let language: String
    public let aliases: [String]
    public let rootContext: String
    public let rules: [SyntaxRule]

    public init(language: String, aliases: [String] = [], rootContext: String, rules: [SyntaxRule]) {
        self.language = language
        self.aliases = aliases
        self.rootContext = rootContext
        self.rules = rules
    }
}

public struct SyntaxRule: Sendable {
    public let pattern: String
    public let token: HighlightToken
    public let column: Int?
    public let firstNonSpace: Bool
    public let minimal: Bool

    public init(pattern: String, token: HighlightToken, column: Int? = nil, firstNonSpace: Bool = false, minimal: Bool = false) {
        self.pattern = pattern
        self.token = token
        self.column = column
        self.firstNonSpace = firstNonSpace
        self.minimal = minimal
    }
}

public final class SyntaxDefinitionRepository: @unchecked Sendable {
    public static let shared = SyntaxDefinitionRepository()

    private let lock = NSLock()
    private let fileURLs: [String: URL]
    private var definitions: [String: SyntaxDefinition] = [:]
    private var loadedFileNames: Set<String> = []

    private init() {
        self.fileURLs = SyntaxDefinitionLoader.loadBundledFileURLs()
    }

    public func highlightSpans(text: String, language: String) -> [HighlightSpan] {
        guard let definition = definition(for: language.lowercased()) else {
            return []
        }

        return RegexRuleInterpreter.highlightSpans(text: text, rules: definition.rules)
    }

    private func definition(for key: String) -> SyntaxDefinition? {
        lock.lock()
        defer { lock.unlock() }

        if let cached = definitions[key] {
            return cached
        }

        if let definition = loadDefinition(forKey: key) {
            return definition
        }

        return loadFallbackDefinition(forKey: key)
    }

    private func loadDefinition(forKey key: String) -> SyntaxDefinition? {
        guard let url = fileURLs[key], !loadedFileNames.contains(url.lastPathComponent.lowercased()) else {
            return nil
        }
        guard let contents = try? String(contentsOf: url, encoding: .utf8),
              let definition = SyntaxDefinitionLoader.load(from: contents) else {
            return nil
        }

        cache(definition: definition, fileName: url.deletingPathExtension().lastPathComponent.lowercased())
        loadedFileNames.insert(url.lastPathComponent.lowercased())
        return definition
    }

    private func loadFallbackDefinition(forKey key: String) -> SyntaxDefinition? {
        for (fileName, url) in fileURLs where !loadedFileNames.contains(url.lastPathComponent.lowercased()) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8),
                  let definition = SyntaxDefinitionLoader.load(from: contents) else {
                continue
            }
            cache(definition: definition, fileName: fileName)
            loadedFileNames.insert(url.lastPathComponent.lowercased())
            if let cached = definitions[key] {
                return cached
            }
        }
        return definitions[key]
    }

    private func cache(definition: SyntaxDefinition, fileName: String) {
        definitions[definition.language.lowercased()] = definition
        definitions[fileName] = definition
        for alias in definition.aliases {
            definitions[alias] = definition
        }
    }
}

enum SyntaxDefinitionLoader {
    static func loadBundledFileURLs() -> [String: URL] {
        if let manifestURL = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Vendor/Kate"),
           let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(SyntaxManifest.self, from: data) {
            var urls: [String: URL] = [:]
            for (language, fileName) in manifest.languages {
                if let url = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "Vendor/Kate") {
                    urls[language.lowercased()] = url
                }
            }
            if !urls.isEmpty {
                return urls
            }
        }

        let files = Bundle.module.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? []
        return Dictionary(uniqueKeysWithValues: files.map { ($0.deletingPathExtension().lastPathComponent.lowercased(), $0) })
    }

    static func load(from contents: String) -> SyntaxDefinition? {
        guard let language = firstMatch(in: contents, pattern: #"<language\b[^>]*\bname="([^"]+)""#) else {
            return nil
        }
        let aliases = extractAliases(from: contents)
        let contexts = extractContexts(from: contents)
        let rootContext = extractRootContext(from: contents, contexts: contexts)

        let entities = extractEntities(from: contents)
        let lists = extractLists(from: contents, entities: entities)
        let rules = extractRules(from: contexts, rootContext: rootContext, entities: entities, lists: lists)
        return SyntaxDefinition(language: language, aliases: aliases, rootContext: rootContext, rules: rules)
    }

    private static func extractRootContext(from contents: String, contexts: [String: ContextBlock]) -> String {
        if let match = firstMatch(in: contents, pattern: #"<highlighting\b[^>]*\bdefaultContext="([^"]+)""#) {
            return match
        }
        return contexts.keys.sorted().first ?? "Normal"
    }

    private static func extractAliases(from contents: String) -> [String] {
        guard let aliasText = firstMatch(in: contents, pattern: #"<language\b[^>]*\baliases="([^"]+)""#) else {
            return []
        }
        return aliasText
            .split(separator: Character(";"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private static func extractEntities(from contents: String) -> [String: String] {
        var entities: [String: String] = [:]
        let pattern = #"<!ENTITY\s+([A-Za-z0-9_:-]+)\s+"([^"]*)">"#
        for match in matches(in: contents, pattern: pattern) {
            guard match.count >= 3 else { continue }
            entities[match[1]] = match[2]
        }
        return entities
    }

    private static func extractLists(from contents: String, entities: [String: String]) -> [String: [String]] {
        var lists: [String: [String]] = [:]
        let listPattern = #"<list\b[^>]*\bname="([^"]+)"[^>]*>(.*?)</list>"#
        let itemPattern = #"<item>(.*?)</item>"#

        for listMatch in matches(in: contents, pattern: listPattern, options: [.dotMatchesLineSeparators]) {
            guard listMatch.count >= 3 else { continue }
            let listName = listMatch[1]
            let body = listMatch[2]
            let items = matches(in: body, pattern: itemPattern, options: [.dotMatchesLineSeparators])
                .compactMap { itemMatch -> String? in
                    guard itemMatch.count >= 2 else { return nil }
                    return expandEntities(itemMatch[1], entities: entities).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
            lists[listName] = items
        }
        return lists
    }

    private static func extractRules(from contexts: [String: ContextBlock], rootContext: String, entities: [String: String], lists: [String: [String]]) -> [SyntaxRule] {
        var cache: [String: [SyntaxRule]] = [:]
        var active: Set<String> = []

        func rules(for contextName: String) -> [SyntaxRule] {
            if let cached = cache[contextName] {
                return cached
            }
            guard let context = contexts[contextName] else { return [] }
            if active.contains(contextName) { return [] }
            active.insert(contextName)
            defer { active.remove(contextName) }

            var collectedRules: [SyntaxRule] = []
            for include in context.includes {
                collectedRules.append(contentsOf: rules(for: include))
            }
            collectedRules.append(contentsOf: parseRules(from: context.body, entities: entities, lists: lists))
            cache[contextName] = collectedRules
            return collectedRules
        }

        var allRules: [SyntaxRule] = []
        for name in contexts.keys.sorted() {
            allRules.append(contentsOf: rules(for: name))
        }
        return deduplicated(allRules)
    }

    private struct ContextBlock {
        let body: String
        let includes: [String]
    }

    private static func extractContexts(from contents: String) -> [String: ContextBlock] {
        let contextPattern = #"<context\b([^>]*)>(.*?)</context>"#
        var contexts: [String: ContextBlock] = [:]

        for match in matches(in: contents, pattern: contextPattern, options: [.dotMatchesLineSeparators]) {
            guard match.count >= 3 else { continue }
            let attributes = parseAttributes(match[1])
            guard let name = attributes["name"] else { continue }
            let includePattern = #"<IncludeRules\b([^>]*)/?>"#
            let includes = matches(in: match[2], pattern: includePattern, options: [.dotMatchesLineSeparators])
                .compactMap { includeMatch -> String? in
                    guard includeMatch.count >= 2 else { return nil }
                    let attrs = parseAttributes(includeMatch[1])
                    return attrs["context"]
                }
            contexts[name] = ContextBlock(body: match[2], includes: includes)
        }
        return contexts
    }

    private static func parseRules(from contents: String, entities: [String: String], lists: [String: [String]]) -> [SyntaxRule] {
        let tagPattern = #"<(RegExpr|DetectChar|Detect2Chars|DetectSpaces|DetectIdentifier|StringDetect|WordDetect|AnyChar|Int|Float|RangeDetect|LineContinue|HlCStringChar|HlCChar|HlCOct|HlCHex|keyword)\b([^>]*)/?>"#
        return matches(in: contents, pattern: tagPattern, options: [.dotMatchesLineSeparators])
            .compactMap { match -> SyntaxRule? in
                guard match.count >= 3 else { return nil }
                let tag = match[1]
                let attributes = parseAttributes(match[2])
                let styleToken = attributes["attribute"].map { token(for: $0) } ?? HighlightToken.plainText
                let insensitive = attributes["insensitive"]?.lowercased() == "true"
                let column = attributes["column"].flatMap(Int.init)
                let firstNonSpace = attributes["firstNonSpace"]?.lowercased() == "true"
                let minimal = attributes["minimal"]?.lowercased() == "true"

                switch tag {
                case "RegExpr":
                    guard let pattern = attributes["String"] else { return nil }
                    return SyntaxRule(
                        pattern: compiledPattern(expandPattern(pattern, entities: entities), insensitive: insensitive, minimal: minimal),
                        token: styleToken,
                        column: column,
                        firstNonSpace: firstNonSpace,
                        minimal: minimal
                    )
                case "DetectChar":
                    guard let char = attributes["char"] else { return nil }
                    return SyntaxRule(pattern: compiledPattern(NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities)), insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Detect2Chars":
                    guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
                    let pattern = NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities)) + NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(pattern, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "DetectSpaces":
                    return SyntaxRule(pattern: compiledPattern(#"\s+"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "DetectIdentifier":
                    return SyntaxRule(pattern: compiledPattern(#"\b[A-Za-z_][A-Za-z0-9_]*\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "StringDetect":
                    guard let string = attributes["String"] else { return nil }
                    return SyntaxRule(pattern: compiledPattern(NSRegularExpression.escapedPattern(for: expandPattern(string, entities: entities)), insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "WordDetect":
                    guard let string = attributes["String"] else { return nil }
                    let escaped = NSRegularExpression.escapedPattern(for: expandPattern(string, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(#"(?<!\w)"# + escaped + #"(?!\w)"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "AnyChar":
                    guard let string = attributes["String"] else { return nil }
                    let escaped = expandPattern(string, entities: entities)
                        .map { NSRegularExpression.escapedPattern(for: String($0)) }
                        .joined()
                    return SyntaxRule(pattern: compiledPattern("[" + escaped + "]", insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Int":
                    return SyntaxRule(pattern: compiledPattern(#"\b\d+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "Float":
                    return SyntaxRule(pattern: compiledPattern(#"\b\d+\.\d+(?:[eE][+-]?\d+)?\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "RangeDetect":
                    guard let char = attributes["char"], let char1 = attributes["char1"] else { return nil }
                    let open = NSRegularExpression.escapedPattern(for: expandPattern(char, entities: entities))
                    let close = NSRegularExpression.escapedPattern(for: expandPattern(char1, entities: entities))
                    return SyntaxRule(pattern: compiledPattern(open + #".*?"# + close, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "LineContinue":
                    return SyntaxRule(pattern: compiledPattern(#"\\"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCStringChar":
                    return SyntaxRule(pattern: compiledPattern(#"\\(?:[0-7]{1,3}|x[0-9A-Fa-f]+|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|.)"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCChar":
                    return SyntaxRule(pattern: compiledPattern(#"'(?:\\.|[^'\\])'"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCOct":
                    return SyntaxRule(pattern: compiledPattern(#"\b0[0-7]+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "HlCHex":
                    return SyntaxRule(pattern: compiledPattern(#"\b0[xX][0-9A-Fa-f]+\b"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                case "keyword":
                    guard let listName = attributes["String"], let items = lists[listName], !items.isEmpty else { return nil }
                    let escaped = items.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
                    return SyntaxRule(pattern: compiledPattern(#"(?<!\w)(?:"# + escaped + #")(?!\w)"#, insensitive: insensitive, minimal: minimal), token: styleToken, column: column, firstNonSpace: firstNonSpace, minimal: minimal)
                default:
                    return nil
                }
            }
    }

    private static func compiledPattern(_ pattern: String, insensitive: Bool, minimal: Bool) -> String {
        let transformed = minimal ? makeMinimal(pattern) : pattern
        return insensitive ? "(?i)" + transformed : transformed
    }

    private static func makeMinimal(_ pattern: String) -> String {
        var result = ""
        var escaped = false
        var inClass = false
        var previousWasQuantifier = false
        for character in pattern {
            switch character {
            case "\\":
                result.append(character)
                escaped.toggle()
                previousWasQuantifier = false
            case "[" where !escaped:
                inClass = true
                result.append(character)
                previousWasQuantifier = false
            case "]" where !escaped:
                inClass = false
                result.append(character)
                previousWasQuantifier = false
            case "*", "+", "?":
                guard !escaped && !inClass else {
                    result.append(character)
                    escaped = false
                    previousWasQuantifier = false
                    continue
                }
                result.append(character)
                if !previousWasQuantifier {
                    result.append("?")
                }
                previousWasQuantifier = true
            default:
                result.append(character)
                escaped = false
                previousWasQuantifier = false
            }
        }
        return result
    }

    private static func deduplicated(_ rules: [SyntaxRule]) -> [SyntaxRule] {
        var seen = Set<String>()
        return rules.filter { rule in
            let key = "\(rule.pattern)\u{0}\(rule.token)"
            return seen.insert(key).inserted
        }
    }

    private static func parseAttributes(_ source: String) -> [String: String] {
        var attributes: [String: String] = [:]
        let pattern = #"([A-Za-z0-9_:-]+)="([^"]*)""#
        for match in matches(in: source, pattern: pattern) {
            guard match.count >= 3 else { continue }
            attributes[match[1]] = match[2]
        }
        return attributes
    }

    private static func expandPattern(_ pattern: String, entities: [String: String]) -> String {
        expandEntities(pattern, entities: entities)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func expandEntities(_ text: String, entities: [String: String]) -> String {
        var output = text
        for _ in 0..<8 {
            var replaced = false
            for (name, value) in entities {
                let entity = "&\(name);"
                if output.contains(entity) {
                    output = output.replacingOccurrences(of: entity, with: value)
                    replaced = true
                }
            }
            if !replaced { break }
        }
        return output
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let match = matches(in: text, pattern: pattern, options: [.dotMatchesLineSeparators]).first,
              match.count >= 2 else {
            return nil
        }
        return match[1]
    }

    private static func matches(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).compactMap { result in
            (0..<result.numberOfRanges).compactMap { index in
                let range = result.range(at: index)
                guard let swiftRange = Range(range, in: text) else { return nil }
                return String(text[swiftRange])
            }
        }
    }

    private static func token(for attribute: String) -> HighlightToken {
        let value = attribute.lowercased()
        if value.contains("comment") { return .comment }
        if value.contains("string") || value.contains("char") { return .string }
        if value.contains("keyword") || value.contains("boolean") || value.contains("constant") { return .keyword }
        if value.contains("number") || value.contains("float") || value.contains("decimal") || value.contains("hex") { return .number }
        if value.contains("function") { return .function }
        if value.contains("type") || value.contains("data_type") { return .type }
        if value.contains("operator") || value.contains("separator") || value.contains("symbol") { return .operatorToken }
        if value.contains("markup") || value.contains("header") || value.contains("list") || value.contains("code") || value.contains("quote") { return .markup }
        return .plainText
    }
}

private struct SyntaxManifest: Decodable {
    let languages: [String: String]
}

enum RegexRuleInterpreter {
    static func highlightSpans(text: String, rules: [SyntaxRule]) -> [HighlightSpan] {
        let highlightedSpans = rules.flatMap { rule -> [HighlightSpan] in
            spans(for: text, rule: rule)
        }
        return highlightedSpans.sorted(by: {
            let leftLength = text.distance(from: $0.range.lowerBound, to: $0.range.upperBound)
            let rightLength = text.distance(from: $1.range.lowerBound, to: $1.range.upperBound)
            if leftLength != rightLength { return leftLength > rightLength }
            return $0.range.lowerBound < $1.range.lowerBound
        })
    }

    static func spans(for text: String, rule: SyntaxRule) -> [HighlightSpan] {
        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { return [] }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            if let column = rule.column {
                let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
                let actualColumn = text.distance(from: lineStart, to: range.lowerBound)
                if actualColumn != column {
                    return nil
                }
            }
            if rule.firstNonSpace {
                let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
                let prefix = text[lineStart..<range.lowerBound]
                if prefix.contains(where: { !$0.isWhitespace }) {
                    return nil
                }
            }
            return HighlightSpan(range: range, token: rule.token)
        }
    }
}
