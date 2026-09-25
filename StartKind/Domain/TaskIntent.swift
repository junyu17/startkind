import Foundation

/// The semantic input used to compose a first step.
///
/// `TaskCategory` is deliberately not part of the action itself. It is a
/// useful calibration and domain hint, while the action phrase, object, and
/// context come from what the person actually wrote.
enum TaskIntentStrategy: String, Equatable, Sendable {
    case paint
    case purchase
    case sale
    case feeding
    case mailing
    case repair
    case surfaceCare
    case directAction
    case domain
    case generic
}

struct TaskIntent: Equatable, Sendable {
    let sourceText: String
    let actionPhrase: String
    let verb: String?
    /// A meaningful object phrase without a leading article or possessive.
    let object: String?
    /// The rest of the object phrase as the user supplied it, when available.
    let objectPhrase: String?
    let context: String?
    let strategy: TaskIntentStrategy
    let language: String
    let categoryHint: TaskCategory?
    let anchorConfidence: Double

    var hasConfidentAnchor: Bool {
        anchorConfidence >= 0.8 && !anchorTokens.isEmpty
    }

    /// Content words used by the cloud-response gate. Short function words
    /// intentionally do not become rejection anchors.
    var anchorTokens: [String] {
        let source = object ?? context
        guard let source, !source.isEmpty else { return [] }

        if usesUnspacedScript {
            let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
            let functionWords = Self.functionWords(for: language)
            return functionWords.contains(value) ? [] : [value]
        }

        return source
            .split { $0.isWhitespace || $0.isPunctuation }
            .map { String($0).lowercased() }
            .filter { token in
                token.count > 1 && !Self.englishFunctionWords.contains(token)
            }
    }

    func matchesAnchor(in response: String) -> Bool {
        guard hasConfidentAnchor else { return true }
        let normalizedResponse = response.lowercased()

        if usesUnspacedScript {
            return anchorTokens.contains { normalizedResponse.contains($0.lowercased()) }
        }

        let responseTokens = Set(
            normalizedResponse
                .split { $0.isWhitespace || $0.isPunctuation }
                .map { String($0) }
        )
        return anchorTokens.contains { responseTokens.contains($0) }
    }

    /// Chinese and Japanese are written without spaces between words, so the
    /// anchor is kept as one whole phrase and matched by substring. Splitting
    /// either on whitespace would yield a single token that exact-set matching
    /// then fails to find in a cloud response.
    private var usesUnspacedScript: Bool {
        switch ContentLanguage(language) {
        case .zhHans, .ja: return true
        case .en: return false
        }
    }

    private static func functionWords(for language: String) -> Set<String> {
        switch ContentLanguage(language) {
        case .zhHans: return chineseFunctionWords
        case .ja: return japaneseFunctionWords
        case .en: return englishFunctionWords
        }
    }

    private static let englishFunctionWords: Set<String> = [
        "a", "an", "the", "my", "our", "your", "his", "her", "their",
        "this", "that", "these", "those", "one", "some", "to", "for",
        "with", "from", "about", "into", "onto", "and", "or", "of",
        "in", "on", "at", "it", "its", "them", "thing", "task"
    ]

    private static let chineseFunctionWords: Set<String> = [
        "我", "你", "他", "她", "它", "的", "了", "要", "想", "去", "把",
        "给", "在", "是", "这", "那", "一个", "一件", "一下"
    ]

    private static let japaneseFunctionWords: Set<String> = [
        "私", "あなた", "これ", "それ", "あれ", "この", "その", "あの",
        "こと", "もの", "やつ", "ため", "とき", "ひとつ", "一つ",
        "の", "は", "が", "を", "に", "へ", "で", "と", "も", "から", "まで"
    ]
}

/// Deterministic parser for the two supported capture languages.
///
/// This intentionally uses a small set of intent shapes instead of pretending
/// to be a full linguistic parser. Unknown verbs still retain the user's
/// action phrase and, when possible, a concrete object for the generic
/// reversible first-step composer.
struct TaskIntentParser: Sendable {
    init() {}

    func parse(
        text: String,
        language: String,
        categoryHint: TaskCategory? = nil
    ) -> TaskIntent {
        let normalized = Self.normalized(text)
        guard !normalized.isEmpty else {
            return TaskIntent(
                sourceText: text,
                actionPhrase: "",
                verb: nil,
                object: nil,
                objectPhrase: nil,
                context: nil,
                strategy: .generic,
                language: language,
                categoryHint: categoryHint,
                anchorConfidence: 0
            )
        }

        if language.lowercased().hasPrefix("zh") {
            return parseChinese(
                sourceText: text,
                normalized: normalized,
                language: language,
                categoryHint: categoryHint
            )
        }
        // Japanese has no structured parser: the patterns rely on Chinese phrase
        // shapes or English word order, and neither maps onto Japanese
        // conjugation. It still routes to the domain composer, which is driven
        // by the task category rather than by a parsed verb and object, so a
        // Japanese user gets the same category-specific first action an English
        // user gets. Without this it reached genericStep for every input and
        // every Japanese next step was "find an official guide", leaving
        // japaneseDomainStep's per-category copy unreachable.
        if language.lowercased().hasPrefix("ja") {
            return TaskIntent(
                sourceText: text,
                actionPhrase: normalized,
                verb: nil,
                object: nil,
                objectPhrase: nil,
                context: nil,
                strategy: .domain,
                language: language,
                categoryHint: categoryHint,
                anchorConfidence: 0
            )
        }
        guard language.lowercased().hasPrefix("en") else {
            return TaskIntent(
                sourceText: text,
                actionPhrase: normalized,
                verb: nil,
                object: nil,
                objectPhrase: nil,
                context: nil,
                strategy: .generic,
                language: language,
                categoryHint: categoryHint,
                anchorConfidence: 0
            )
        }
        return parseEnglish(
            sourceText: text,
            normalized: normalized,
            language: language,
            categoryHint: categoryHint
        )
    }
}

private extension TaskIntentParser {
    struct EnglishPattern {
        let words: [String]
        let strategy: TaskIntentStrategy
    }

    struct EnglishObject {
        let object: String?
        let objectPhrase: String?
        let context: String?
    }

    struct ChinesePattern {
        let phrase: String
        let strategy: TaskIntentStrategy
    }

    static let englishPatterns: [EnglishPattern] = [
        EnglishPattern(words: ["list", "for", "sale"], strategy: .sale),
        EnglishPattern(words: ["shop", "for"], strategy: .purchase),
        EnglishPattern(words: ["send", "out"], strategy: .mailing),
        EnglishPattern(words: ["ship", "back"], strategy: .domain),
        EnglishPattern(words: ["fill", "out"], strategy: .domain),
        EnglishPattern(words: ["sort", "out"], strategy: .generic),
        EnglishPattern(words: ["paint"], strategy: .paint),
        EnglishPattern(words: ["repaint"], strategy: .paint),
        EnglishPattern(words: ["buy"], strategy: .purchase),
        EnglishPattern(words: ["purchase"], strategy: .purchase),
        EnglishPattern(words: ["order"], strategy: .purchase),
        EnglishPattern(words: ["sell"], strategy: .sale),
        EnglishPattern(words: ["feed"], strategy: .feeding),
        EnglishPattern(words: ["mail"], strategy: .mailing),
        EnglishPattern(words: ["post"], strategy: .mailing),
        EnglishPattern(words: ["ship"], strategy: .mailing),
        EnglishPattern(words: ["send"], strategy: .mailing),
        EnglishPattern(words: ["fix"], strategy: .repair),
        EnglishPattern(words: ["repair"], strategy: .repair),
        EnglishPattern(words: ["mend"], strategy: .repair),
        EnglishPattern(words: ["troubleshoot"], strategy: .repair),
        EnglishPattern(words: ["polish"], strategy: .surfaceCare),
        EnglishPattern(words: ["buff"], strategy: .surfaceCare),
        EnglishPattern(words: ["wipe"], strategy: .surfaceCare),
        EnglishPattern(words: ["dust"], strategy: .surfaceCare),
        EnglishPattern(words: ["clean"], strategy: .surfaceCare),
        EnglishPattern(words: ["wash"], strategy: .surfaceCare),
        EnglishPattern(words: ["open"], strategy: .directAction),
        EnglishPattern(words: ["read"], strategy: .directAction),
        EnglishPattern(words: ["pay"], strategy: .domain),
        EnglishPattern(words: ["settle"], strategy: .domain),
        EnglishPattern(words: ["reply"], strategy: .domain),
        EnglishPattern(words: ["respond"], strategy: .domain),
        EnglishPattern(words: ["email"], strategy: .domain),
        EnglishPattern(words: ["message"], strategy: .domain),
        EnglishPattern(words: ["schedule"], strategy: .domain),
        EnglishPattern(words: ["book"], strategy: .domain),
        EnglishPattern(words: ["reschedule"], strategy: .domain),
        EnglishPattern(words: ["return"], strategy: .domain),
        EnglishPattern(words: ["refund"], strategy: .domain),
        EnglishPattern(words: ["review"], strategy: .domain),
        EnglishPattern(words: ["submit"], strategy: .domain)
    ]

    static let chinesePatterns: [ChinesePattern] = [
        ChinesePattern(phrase: "刷油漆", strategy: .paint),
        ChinesePattern(phrase: "购买", strategy: .purchase),
        ChinesePattern(phrase: "出售", strategy: .sale),
        ChinesePattern(phrase: "邮寄", strategy: .mailing),
        ChinesePattern(phrase: "寄出", strategy: .mailing),
        ChinesePattern(phrase: "发送", strategy: .domain),
        ChinesePattern(phrase: "修理", strategy: .repair),
        ChinesePattern(phrase: "维修", strategy: .repair),
        ChinesePattern(phrase: "修复", strategy: .repair),
        ChinesePattern(phrase: "抛光", strategy: .surfaceCare),
        ChinesePattern(phrase: "擦亮", strategy: .surfaceCare),
        ChinesePattern(phrase: "打磨", strategy: .surfaceCare),
        ChinesePattern(phrase: "清洁", strategy: .surfaceCare),
        ChinesePattern(phrase: "支付", strategy: .domain),
        ChinesePattern(phrase: "缴费", strategy: .domain),
        ChinesePattern(phrase: "付款", strategy: .domain),
        ChinesePattern(phrase: "回复", strategy: .domain),
        ChinesePattern(phrase: "预约", strategy: .domain),
        ChinesePattern(phrase: "预订", strategy: .domain),
        ChinesePattern(phrase: "退货", strategy: .domain),
        ChinesePattern(phrase: "退款", strategy: .domain),
        ChinesePattern(phrase: "买", strategy: .purchase),
        ChinesePattern(phrase: "卖", strategy: .sale),
        ChinesePattern(phrase: "喂", strategy: .feeding),
        ChinesePattern(phrase: "刷", strategy: .paint),
        ChinesePattern(phrase: "寄", strategy: .mailing),
        ChinesePattern(phrase: "修", strategy: .repair),
        ChinesePattern(phrase: "擦", strategy: .surfaceCare),
        ChinesePattern(phrase: "打开", strategy: .directAction),
        ChinesePattern(phrase: "查看", strategy: .domain),
        ChinesePattern(phrase: "阅读", strategy: .directAction),
        ChinesePattern(phrase: "读", strategy: .directAction),
        ChinesePattern(phrase: "填写", strategy: .domain),
        ChinesePattern(phrase: "提交", strategy: .domain)
    ]

    static let englishLeadingPhrases: [[String]] = [
        ["can", "you", "help", "me"],
        ["i", "would", "like", "to"],
        ["i'd", "like", "to"],
        ["i", "need", "to"],
        ["i", "have", "to"],
        ["i", "want", "to"],
        ["need", "to"],
        ["have", "to"],
        ["want", "to"],
        ["trying", "to"],
        ["help", "me"]
    ]

    static let englishContextMarkers: Set<String> = [
        "about", "because", "before", "after", "when", "while", "for",
        "from", "with", "at", "on", "in", "to"
    ]

    static let englishLeadingObjectWords: Set<String> = [
        "a", "an", "the", "my", "our", "your", "his", "her", "their",
        "this", "that", "these", "those", "one", "some"
    ]

    static let englishTrailingWords: Set<String> = [
        "please", "today", "now", "tonight", "later"
    ]

    static let chineseLeadingPhrases = [
        "我想", "我需要", "我得", "请帮我", "帮我", "帮忙", "需要", "请"
    ]

    static let chineseLeadingObjectWords = [
        "我的", "我们的", "你的", "这个", "那个", "这台", "那台", "这件", "那件",
        "一部", "一台", "一个", "一件", "一只", "一份", "一些", "把", "给", "掉"
    ]

    static let chineseTrailingWords = [
        "一下", "一修", "出去", "出来", "掉", "好", "吧", "呀", "呢", "了"
    ]

    func parseEnglish(
        sourceText: String,
        normalized: String,
        language: String,
        categoryHint: TaskCategory?
    ) -> TaskIntent {
        let tokens = normalized.split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        let lowerTokens = tokens.map { $0.lowercased() }
        let actionStart = leadingPhraseEnd(in: lowerTokens)
        let remaining = Array(tokens.dropFirst(actionStart))
        let remainingLower = remaining.map { $0.lowercased() }

        let pattern = Self.englishPatterns.first { candidate in
            remainingLower.starts(with: candidate.words)
        }
        let actionWords = pattern?.words.count ?? min(1, remaining.count)
        let verb = pattern?.words.joined(separator: " ") ?? remaining.prefix(actionWords).joined(separator: " ")
        let phraseTokens = Array(remaining.dropFirst(actionWords))
        let objectInfo = englishObject(from: phraseTokens)
        let actionPhrase = remaining.joined(separator: " ")
        let strategy = adjustedEnglishStrategy(
            initial: pattern?.strategy ?? .generic,
            actionPhrase: actionPhrase,
            object: objectInfo.object,
            context: objectInfo.context,
            categoryHint: categoryHint
        )

        return TaskIntent(
            sourceText: sourceText,
            actionPhrase: actionPhrase.isEmpty ? normalized : actionPhrase,
            verb: verb.isEmpty ? nil : verb,
            object: objectInfo.object,
            objectPhrase: objectInfo.objectPhrase,
            context: objectInfo.context,
            strategy: strategy,
            language: language,
            categoryHint: categoryHint,
            anchorConfidence: objectInfo.object == nil ? 0 : 0.95
        )
    }

    func parseChinese(
        sourceText: String,
        normalized: String,
        language: String,
        categoryHint: TaskCategory?
    ) -> TaskIntent {
        let phrase = stripChineseLeadingPhrase(normalized)
        let match = Self.chinesePatterns
            .compactMap { pattern -> (ChinesePattern, Range<String.Index>)? in
                guard let range = phrase.range(of: pattern.phrase) else { return nil }
                return (pattern, range)
            }
            .min { lhs, rhs in lhs.1.lowerBound < rhs.1.lowerBound }

        if let match {
            let objectParts = chineseObjectParts(in: phrase, verbRange: match.1)
            let objectInfo = cleanChineseObjectParts(objectParts)
            let actionPhrase = phrase
            return TaskIntent(
                sourceText: sourceText,
                actionPhrase: actionPhrase,
                verb: match.0.phrase,
                object: objectInfo.object,
                objectPhrase: objectInfo.objectPhrase,
                context: objectInfo.context,
                strategy: adjustedChineseStrategy(
                    initial: match.0.strategy,
                    phrase: phrase,
                    object: objectInfo.object,
                    categoryHint: categoryHint
                ),
                language: language,
                categoryHint: categoryHint,
                anchorConfidence: objectInfo.object == nil ? 0 : 0.95
            )
        }

        // For an unseen Chinese verb there is no reliable word boundary. A
        // two-character action prefix is a conservative hint; the full phrase
        // remains intact so the generic composer can still use it.
        let characters = Array(phrase)
        let assumedVerb: String?
        let objectPhrase: String?
        if characters.count >= 4 {
            assumedVerb = String(characters.prefix(2))
            objectPhrase = String(characters.dropFirst(2))
        } else {
            assumedVerb = nil
            objectPhrase = nil
        }
        let cleaned = objectPhrase.flatMap(cleanChineseObject)
        return TaskIntent(
            sourceText: sourceText,
            actionPhrase: phrase,
            verb: assumedVerb,
            object: cleaned,
            objectPhrase: objectPhrase,
            context: nil,
            strategy: .generic,
            language: language,
            categoryHint: categoryHint,
            anchorConfidence: cleaned == nil ? 0 : 0.7
        )
    }

    func leadingPhraseEnd(in tokens: [String]) -> Int {
        var index = 0
        var changed = true
        while changed && index < tokens.count {
            changed = false
            if tokens[index] == "please" {
                index += 1
                changed = true
                continue
            }
            for phrase in Self.englishLeadingPhrases where tokens[index...].starts(with: phrase) {
                index += phrase.count
                changed = true
                break
            }
        }
        return min(index, tokens.count)
    }

    func englishObject(from tokens: [String]) -> EnglishObject {
        guard !tokens.isEmpty else {
            return EnglishObject(object: nil, objectPhrase: nil, context: nil)
        }

        var words = tokens
        while let last = words.last, Self.englishTrailingWords.contains(last.lowercased()) {
            words.removeLast()
        }
        guard !words.isEmpty else {
            return EnglishObject(object: nil, objectPhrase: nil, context: nil)
        }

        var context: String?
        if let markerIndex = words.firstIndex(where: { Self.englishContextMarkers.contains($0.lowercased()) }) {
            if markerIndex > 0 {
                context = words[markerIndex...].joined(separator: " ")
                words = Array(words[..<markerIndex])
            } else if words.count > 1 {
                // In constructions such as "deal with bills", the object is
                // on the far side of the preposition.
                context = words.joined(separator: " ")
                words = Array(words.dropFirst())
            }
        }

        let phrase = words.joined(separator: " ")
        var meaningful = words
        while let first = meaningful.first,
              Self.englishLeadingObjectWords.contains(first.lowercased()) {
            meaningful.removeFirst()
        }
        while let last = meaningful.last,
              Self.englishTrailingWords.contains(last.lowercased()) {
            meaningful.removeLast()
        }

        let object = meaningful.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if object.isEmpty {
            let contextualObject = context?
                .split { $0.isWhitespace || $0.isPunctuation }
                .dropFirst()
                .map(String.init)
                .joined(separator: " ") ?? ""
            return EnglishObject(
                object: contextualObject.isEmpty ? nil : contextualObject,
                objectPhrase: contextualObject.isEmpty ? nil : contextualObject,
                context: context
            )
        }
        return EnglishObject(
            object: object,
            objectPhrase: phrase.isEmpty ? object : phrase,
            context: context
        )
    }

    func adjustedEnglishStrategy(
        initial: TaskIntentStrategy,
        actionPhrase: String,
        object: String?,
        context: String?,
        categoryHint: TaskCategory?
    ) -> TaskIntentStrategy {
        let combined = "\(actionPhrase) \(object ?? "") \(context ?? "")".lowercased()
        if initial == .mailing && ["email", "inbox", "message"].contains(where: { combined.contains($0) }) {
            return .domain
        }
        return initial
    }

    func stripChineseLeadingPhrase(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            for prefix in Self.chineseLeadingPhrases where result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
                break
            }
        }
        return result
    }

    func chineseObjectParts(
        in phrase: String,
        verbRange: Range<String.Index>
    ) -> (before: String, after: String) {
        let before = String(phrase[..<verbRange.lowerBound])
        let after = String(phrase[verbRange.upperBound...])
        let beforeWithoutWrappers = before
            .replacingOccurrences(of: "把", with: "")
            .replacingOccurrences(of: "给", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (beforeWithoutWrappers, after)
    }

    func cleanChineseObjectParts(_ parts: (before: String, after: String)) -> (object: String?, objectPhrase: String?, context: String?) {
        let before = cleanChineseObject(parts.before)
        if let before, !before.isEmpty {
            let after = cleanChineseObject(parts.after)
            return (before, before, after)
        }
        let after = cleanChineseObject(parts.after)
        return (after, after, nil)
    }

    func cleanChineseObject(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !value.isEmpty else { return nil }

        var changed = true
        while changed {
            changed = false
            for prefix in Self.chineseLeadingObjectWords where value.hasPrefix(prefix) {
                value.removeFirst(prefix.count)
                value = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                changed = true
                break
            }
        }
        for suffix in Self.chineseTrailingWords where value.hasSuffix(suffix) {
            value.removeLast(suffix.count)
            value = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            break
        }
        return value.isEmpty ? nil : value
    }

    func adjustedChineseStrategy(
        initial: TaskIntentStrategy,
        phrase: String,
        object: String?,
        categoryHint: TaskCategory?
    ) -> TaskIntentStrategy {
        if initial == .mailing && phrase.contains("邮件") {
            return .domain
        }
        return initial
    }

    static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
