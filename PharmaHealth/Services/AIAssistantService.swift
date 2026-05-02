import Foundation

// =====================================================================
// AI-ready architecture (no network calls today; intentional placeholders).
// =====================================================================
//
// We deliberately avoid hard-coding any API keys or shipping a paid AI
// dependency. The protocols below describe the surface a future AI
// integration could target (server-side, behind a backend that holds the
// secret) without pulling that integration into the binary today.
//
// IMPORTANT: When this is wired up later, never embed an API key in the
// app bundle. Anyone who installs the app can extract it. Route through a
// backend that stores the key in a secrets manager (Hashicorp Vault, AWS
// Secrets Manager, etc.).
//
// Disclaimer: any AI-generated text surfaced to users must be presented
// as a non-medical convenience feature and never replace clinician advice.

/// One natural-language ask + optional structured context.
struct AIPrompt {
    let userText: String
    let context: [String: String]
}

/// What the assistant returns. Kept minimal — the UI layer is responsible
/// for presenting and formatting.
struct AIResponse {
    let text: String
    let usedDisclaimer: Bool
}

/// Top-level assistant. Implementations include `NoopAIAssistantService`
/// (no-op fallback used until a real backend is configured).
protocol AIAssistantService {
    /// Plain-language summary of a medication regimen. The implementation
    /// must NOT advise dosage changes; it summarizes what's already on file.
    func summarizeRegimen(_ medications: [Medication]) async throws -> AIResponse

    /// Adherence insights given a window of dose history.
    func adherenceInsights(for entries: [DoseEntry], window: DateInterval) async throws -> AIResponse

    /// Refill planning — explains when and where the user should plan their
    /// next pharmacy call. Read-only; never schedules anything itself.
    func refillPlan(for medication: Medication) async throws -> AIResponse

    /// AI-assisted natural-language medication entry, e.g.
    /// "I take 500 mg metformin twice a day with meals." Returns a draft
    /// `Medication` the user must confirm before saving.
    func parseNaturalLanguageMedication(_ utterance: String) async throws -> Medication

    /// Suggested questions for a healthcare professional based on the user's
    /// recent symptoms and meds. Output is a checklist, not a diagnosis.
    func suggestQuestionsForVisit(symptoms: [SymptomLog], medications: [Medication]) async throws -> [String]
}

/// Optional richer health-reading parser, e.g. for messy handwritten notes
/// where the regex parser would fail. Returns the same `ParsedHealthReading`
/// shape so the existing OCR confirmation UI can reuse it as-is.
protocol AIHealthReadingParser: HealthReadingParser {
    func parseAsync(text: String) async throws -> [ParsedHealthReading]
}

// MARK: - Default no-op implementation

/// Safe default that always throws `notConfigured`. Wired into the app so
/// callers can be written today without crashing in production.
struct NoopAIAssistantService: AIAssistantService {
    enum AIError: Error, LocalizedError {
        case notConfigured
        var errorDescription: String? {
            "AI assistant is not configured in this build."
        }
    }
    func summarizeRegimen(_ medications: [Medication]) async throws -> AIResponse { throw AIError.notConfigured }
    func adherenceInsights(for entries: [DoseEntry], window: DateInterval) async throws -> AIResponse { throw AIError.notConfigured }
    func refillPlan(for medication: Medication) async throws -> AIResponse { throw AIError.notConfigured }
    func parseNaturalLanguageMedication(_ utterance: String) async throws -> Medication { throw AIError.notConfigured }
    func suggestQuestionsForVisit(symptoms: [SymptomLog], medications: [Medication]) async throws -> [String] { throw AIError.notConfigured }
}

/// Single resolution point. Future code can swap the implementation behind
/// a feature flag without touching every call site.
enum AIAssistant {
    static var current: AIAssistantService = NoopAIAssistantService()

    /// Mandatory disclaimer string to attach to user-visible AI output.
    static let disclaimer =
        "This information is for organization and tracking only and does not replace professional medical advice."
}
