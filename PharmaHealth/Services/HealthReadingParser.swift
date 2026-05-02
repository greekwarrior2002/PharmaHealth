import Foundation

/// One candidate reading produced by a parser. The UI presents these to the
/// user (typically the highest-confidence first) on the confirmation screen.
struct ParsedHealthReading: Equatable, Identifiable {
    let id: UUID
    let metric: HealthMetricType
    let primary: Double
    let secondary: Double?
    let unit: String
    /// Confidence score in 0...1. Used only for ordering — not surfaced to the
    /// user as a number to avoid implying medical certainty.
    let confidence: Double
    /// Original text snippet the parser pulled the value from. Useful for
    /// debugging and for the "we detected this" string in the confirmation UI.
    let sourceSnippet: String

    init(
        id: UUID = UUID(),
        metric: HealthMetricType,
        primary: Double,
        secondary: Double? = nil,
        unit: String,
        confidence: Double,
        sourceSnippet: String
    ) {
        self.id = id
        self.metric = metric
        self.primary = primary
        self.secondary = secondary
        self.unit = unit
        self.confidence = confidence
        self.sourceSnippet = sourceSnippet
    }
}

/// Pluggable parser interface. The current local implementation uses regex;
/// a future `AIHealthReadingParser` could call a hosted LLM and return the
/// same shape so the rest of the app does not need to change.
protocol HealthReadingParser {
    func parse(text: String) -> [ParsedHealthReading]
}

/// Best-effort regex-based parser. It is intentionally conservative — when in
/// doubt the user is asked to confirm or correct on the next screen.
struct LocalRegexHealthReadingParser: HealthReadingParser {

    func parse(text: String) -> [ParsedHealthReading] {
        // OCR output often has stray whitespace and split lines; normalize.
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        var candidates: [ParsedHealthReading] = []
        candidates.append(contentsOf: parseBloodPressure(normalized))
        candidates.append(contentsOf: parseBloodOxygen(normalized))
        candidates.append(contentsOf: parseHeartRate(normalized))
        candidates.append(contentsOf: parseTemperature(normalized))
        candidates.append(contentsOf: parseGlucose(normalized))
        candidates.append(contentsOf: parseWeight(normalized))

        // Sort high-confidence first so the UI can preselect the best guess.
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Blood pressure
    // Recognizes: 120/80, 120 / 80, 120 over 80, SYS 120 DIA 80.
    private func parseBloodPressure(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []

        let slashPattern = #"(\d{2,3})\s*[/\\]\s*(\d{2,3})"#
        for match in matches(in: text, pattern: slashPattern) {
            guard match.count >= 3,
                  let sys = Double(match[1]),
                  let dia = Double(match[2]) else { continue }
            // Avoid matching things like "1/2 tablet". Both should be in BP range.
            guard sys >= 60 && sys <= 260 && dia >= 30 && dia <= 180 else { continue }
            results.append(ParsedHealthReading(
                metric: .bloodPressure,
                primary: sys,
                secondary: dia,
                unit: "mmHg",
                confidence: 0.9,
                sourceSnippet: match[0]
            ))
        }

        let overPattern = #"(\d{2,3})\s*(?:over|OVER)\s*(\d{2,3})"#
        for match in matches(in: text, pattern: overPattern) {
            guard match.count >= 3,
                  let sys = Double(match[1]),
                  let dia = Double(match[2]) else { continue }
            results.append(ParsedHealthReading(
                metric: .bloodPressure, primary: sys, secondary: dia,
                unit: "mmHg", confidence: 0.85, sourceSnippet: match[0]
            ))
        }

        let sysDiaPattern = #"SYS[^\d]{0,4}(\d{2,3})[^\d]{1,8}DIA[^\d]{0,4}(\d{2,3})"#
        for match in matches(in: text, pattern: sysDiaPattern, options: [.caseInsensitive]) {
            guard match.count >= 3,
                  let sys = Double(match[1]),
                  let dia = Double(match[2]) else { continue }
            results.append(ParsedHealthReading(
                metric: .bloodPressure, primary: sys, secondary: dia,
                unit: "mmHg", confidence: 0.95, sourceSnippet: match[0]
            ))
        }
        return results
    }

    // MARK: - Blood oxygen
    // Recognizes "SpO2 98%", "SPO2: 98", "Oxygen 97%", "O2 99 %".
    private func parseBloodOxygen(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []
        let pattern = #"(?:SpO2|SPO2|SpO₂|Oxygen|O2)\D{0,8}(\d{2,3})\s*%?"#
        for match in matches(in: text, pattern: pattern, options: [.caseInsensitive]) {
            guard match.count >= 2, let value = Double(match[1]) else { continue }
            guard value >= 50 && value <= 100 else { continue }
            results.append(ParsedHealthReading(
                metric: .bloodOxygen, primary: value, unit: "%",
                confidence: 0.9, sourceSnippet: match[0]
            ))
        }
        // Standalone "98%" near pulse-ox keywords.
        if results.isEmpty,
           text.range(of: "%") != nil,
           let m = matches(in: text, pattern: #"(\d{2,3})\s*%"#).first,
           m.count >= 2,
           let value = Double(m[1]),
           value >= 80 && value <= 100 {
            results.append(ParsedHealthReading(
                metric: .bloodOxygen, primary: value, unit: "%",
                confidence: 0.55, sourceSnippet: m[0]
            ))
        }
        return results
    }

    // MARK: - Heart rate / pulse
    private func parseHeartRate(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []
        let pattern = #"(?:HR|Heart\s?Rate|Pulse|PR)\D{0,8}(\d{2,3})\s*(?:bpm)?"#
        for match in matches(in: text, pattern: pattern, options: [.caseInsensitive]) {
            guard match.count >= 2, let value = Double(match[1]) else { continue }
            guard value >= 20 && value <= 250 else { continue }
            results.append(ParsedHealthReading(
                metric: .heartRate, primary: value, unit: "bpm",
                confidence: 0.85, sourceSnippet: match[0]
            ))
        }
        // Standalone "72 bpm".
        for match in matches(in: text, pattern: #"(\d{2,3})\s*bpm"#, options: [.caseInsensitive]) {
            guard match.count >= 2, let value = Double(match[1]) else { continue }
            guard value >= 20 && value <= 250 else { continue }
            results.append(ParsedHealthReading(
                metric: .heartRate, primary: value, unit: "bpm",
                confidence: 0.8, sourceSnippet: match[0]
            ))
        }
        return results
    }

    // MARK: - Temperature
    private func parseTemperature(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []
        let pattern = #"(\d{2,3}(?:\.\d+)?)\s*°?\s*([CF])\b"#
        for match in matches(in: text, pattern: pattern) {
            guard match.count >= 3,
                  let value = Double(match[1]) else { continue }
            let unitChar = match[2].uppercased()
            let unit = unitChar == "F" ? "°F" : "°C"
            results.append(ParsedHealthReading(
                metric: .temperature, primary: value, unit: unit,
                confidence: 0.85, sourceSnippet: match[0]
            ))
        }
        return results
    }

    // MARK: - Glucose
    private func parseGlucose(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []
        let pattern = #"(\d{1,3}(?:\.\d+)?)\s*(mg/dL|mg\\/dL|mmol/L|mmol\\/L)"#
        for match in matches(in: text, pattern: pattern, options: [.caseInsensitive]) {
            guard match.count >= 3, let value = Double(match[1]) else { continue }
            let raw = match[2].lowercased()
            let unit = raw.contains("mmol") ? "mmol/L" : "mg/dL"
            results.append(ParsedHealthReading(
                metric: .bloodGlucose, primary: value, unit: unit,
                confidence: 0.85, sourceSnippet: match[0]
            ))
        }
        return results
    }

    // MARK: - Weight
    private func parseWeight(_ text: String) -> [ParsedHealthReading] {
        var results: [ParsedHealthReading] = []
        let pattern = #"(\d{1,3}(?:\.\d+)?)\s*(kg|kilograms?|lbs?|pounds?)\b"#
        for match in matches(in: text, pattern: pattern, options: [.caseInsensitive]) {
            guard match.count >= 3, let value = Double(match[1]) else { continue }
            let raw = match[2].lowercased()
            let unit = (raw == "kg" || raw.hasPrefix("kilo")) ? "kg" : "lb"
            results.append(ParsedHealthReading(
                metric: .weight, primary: value, unit: unit,
                confidence: 0.8, sourceSnippet: match[0]
            ))
        }
        return results
    }

    // MARK: - Regex helper

    /// Returns each match as `[fullMatch, group1, group2, …]`.
    private func matches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { result in
            (0..<result.numberOfRanges).compactMap { i in
                guard let r = Range(result.range(at: i), in: text) else { return nil }
                return String(text[r])
            }
        }
    }
}
