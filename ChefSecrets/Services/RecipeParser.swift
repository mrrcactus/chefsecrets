import Foundation

struct LineDraft: Identifiable {
    let id = UUID()
    var amount = ""
    var name = ""
    /// Comma-separated substitutes, e.g. "turkey breast, firm tofu".
    var swaps = ""
}

struct StepDraft: Identifiable {
    let id = UUID()
    var text = ""
}

/// An editable, not-yet-saved copy of a recipe. Paste, manual add and edit all go through this.
struct RecipeDraft {
    var title = ""
    var servings = 1
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var lines: [LineDraft] = []
    var steps: [StepDraft] = []
    var category: RecipeCategory = .other
    var source: RecipeSource = .me
    var sourceLink = ""
    var photo: Data?

    init() {}

    init(recipe: Recipe) {
        title = recipe.title
        servings = recipe.servings
        kcal = recipe.kcal
        protein = recipe.protein
        carbs = recipe.carbs
        fat = recipe.fat
        lines = recipe.sortedLines.map {
            LineDraft(amount: $0.amount, name: $0.ingredient?.name ?? "", swaps: $0.swaps.joined(separator: ", "))
        }
        steps = recipe.steps.map { StepDraft(text: $0) }
        category = recipe.category
        source = recipe.source
        sourceLink = recipe.sourceLink
        photo = recipe.photo
    }
}

/// Reads the ChefSecrets text format (see `ChefPrompt`). Lenient about markdown and casing,
/// because ChatGPT and Claude sometimes add bold or headings anyway.
enum RecipeParser {
    private enum Section { case none, ingredients, steps }

    static func parse(_ text: String) -> RecipeDraft {
        var draft = RecipeDraft()
        var section = Section.none

        for raw in text.components(separatedBy: .newlines) {
            let line = clean(raw)
            if line.isEmpty { continue }

            if !isListItem(line) {
                let (head, rest) = splitHeader(line)
                switch head {
                case "TITLE", "NAME", "RECIPE":
                    draft.title = rest
                    continue
                case "SERVINGS", "SERVES", "YIELD":
                    draft.servings = max(1, Int(firstNumber(in: rest) ?? 1))
                    continue
                case let h where h.hasPrefix("MACROS") || h.hasPrefix("NUTRITION"):
                    parseMacros(rest, into: &draft)
                    continue
                case "LINK", "SOURCE", "SOURCE LINK", "URL":
                    draft.sourceLink = rest
                    continue
                case "CATEGORY", "TYPE", "MEAL":
                    draft.category = RecipeCategory(text: rest)
                    continue
                case "FROM":
                    if let source = RecipeSource.allCases.first(where: { $0.label.lowercased() == rest.lowercased() }) {
                        draft.source = source
                    }
                    continue
                case "INGREDIENTS":
                    section = .ingredients
                    continue
                case "STEPS", "INSTRUCTIONS", "DIRECTIONS", "METHOD":
                    section = .steps
                    continue
                default:
                    break
                }
            }

            switch section {
            case .ingredients:
                if let parsed = parseIngredient(line) { draft.lines.append(parsed) }
            case .steps:
                let step = stripListMarker(line)
                if !step.isEmpty { draft.steps.append(StepDraft(text: step)) }
            case .none:
                break
            }
        }

        if let link = firstLink(in: text) {
            if draft.sourceLink.isEmpty { draft.sourceLink = link }
            if link.contains("tiktok.com") { draft.source = .tiktok }
        }
        return draft
    }

    // MARK: - Pieces

    private static func clean(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        s = s.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix("#") { s.removeFirst() }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func isListItem(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        return first == "-" || first == "•" || first == "*" || first.isNumber
    }

    /// "MACROS PER SERVING: 540 kcal" → ("MACROS PER SERVING", "540 kcal"). A bare "Ingredients" → ("INGREDIENTS", "").
    private static func splitHeader(_ line: String) -> (String, String) {
        guard let colon = line.firstIndex(of: ":") else {
            return (line.uppercased(), "")
        }
        let head = line[..<colon].trimmingCharacters(in: .whitespaces).uppercased()
        let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return (head, rest)
    }

    private static func parseMacros(_ text: String, into draft: inout RecipeDraft) {
        // Matches both "45 P" / "45g protein" and "Protein: 45g".
        let numberFirst = #/(?i)(\d+(?:\.\d+)?)\s*g?\s*(kcal|calories|cal|protein|carbs?|fat|p|c|f)\b/#
        let wordFirst = #/(?i)(kcal|calories|protein|carbs?|fat)\s*:?\s*(\d+(?:\.\d+)?)/#

        func assign(_ word: Substring, _ number: Substring) {
            guard let value = Double(number) else { return }
            switch word.lowercased() {
            case "kcal", "calories", "cal": draft.kcal = value
            case "protein", "p": draft.protein = value
            case "carbs", "carb", "c": draft.carbs = value
            case "fat", "f": draft.fat = value
            default: break
            }
        }

        for match in text.matches(of: numberFirst) { assign(match.output.2, match.output.1) }
        for match in text.matches(of: wordFirst) { assign(match.output.1, match.output.2) }
    }

    private static func parseIngredient(_ line: String) -> LineDraft? {
        let body = stripListMarker(line)
        guard !body.isEmpty else { return nil }

        var parts = body.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        var swaps = ""
        if let last = parts.last, last.lowercased().hasPrefix("swap") {
            swaps = last.split(separator: ":", maxSplits: 1).dropFirst().first.map {
                $0.trimmingCharacters(in: .whitespaces)
            } ?? ""
            parts.removeLast()
        }

        switch parts.count {
        case 0:
            return nil
        case 1:
            let (amount, name) = splitAmount(parts[0])
            return LineDraft(amount: amount, name: name, swaps: swaps)
        default:
            return LineDraft(amount: parts[0], name: parts[1], swaps: swaps)
        }
    }

    /// Best-effort split of "200 g chicken breast" into ("200 g", "chicken breast").
    private static func splitAmount(_ text: String) -> (String, String) {
        let pattern = #/(?i)^([\d½¼¾⅓⅔\/.\s-]+(?:g|kg|ml|l|oz|lb|lbs|cups?|tbsp|tsp|cloves?|slices?|cans?|scoops?)?\.?)\s+(.+)$/#
        if let match = text.firstMatch(of: pattern) {
            return (match.output.1.trimmingCharacters(in: .whitespaces), String(match.output.2))
        }
        return ("", text)
    }

    private static func stripListMarker(_ line: String) -> String {
        line.replacing(#/^\s*(?:[-•*]|\d+[.)])\s*/#, with: "")
    }

    private static func firstNumber(in text: String) -> Double? {
        text.firstMatch(of: #/\d+(?:\.\d+)?/#).flatMap { Double($0.output) }
    }

    private static func firstLink(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url?.absoluteString
    }
}
