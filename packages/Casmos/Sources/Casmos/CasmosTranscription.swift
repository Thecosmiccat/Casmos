import Foundation

/// Local Cloudflare Workers AI / transcription placeholders.
/// There is no free anonymous path. This tree does not upload voice audio.
public enum CasmosTranscription {
    public static let placeholderAccountId = "CASMOS_PLACEHOLDER_CF_ACCOUNT_ID"
    public static let placeholderApiToken = "CASMOS_PLACEHOLDER_CF_API_TOKEN"
    public static let defaultModel = "@cf/openai/whisper"

    public enum SkipReason: Equatable {
        case disabled
        case placeholder
        case noFreePath
    }

    public static func displayAccountId(_ stored: String = CasmosPreferences.transcriptionAccountId) -> String {
        stripped(stored, placeholder: placeholderAccountId)
    }

    public static func displayApiToken(_ stored: String = CasmosPreferences.transcriptionApiToken) -> String {
        stripped(stored, placeholder: placeholderApiToken)
    }

    public static func displayModel(_ stored: String = CasmosPreferences.transcriptionModel) -> String {
        let value = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return value
    }

    public static var hasLiveCredentials: Bool {
        liveValue(CasmosPreferences.transcriptionAccountId, placeholder: placeholderAccountId) != nil
            && liveValue(CasmosPreferences.transcriptionApiToken, placeholder: placeholderApiToken) != nil
    }

    /// Workers AI is paid / account-gated. Live calls are always skipped in this tree.
    public static var shouldSkipLiveCalls: Bool {
        true
    }

    public static var skipReason: SkipReason {
        if !CasmosPreferences.workersAiTranscriptionEnabled {
            return .disabled
        }
        if !hasLiveCredentials {
            return .placeholder
        }
        return .noFreePath
    }

    /// Never performs a network call. Documented skip for the missing free Workers AI path.
    @discardableResult
    public static func skipLiveCall() -> SkipReason {
        let reason = skipReason
        CasmosHooks.log("transcription", "skip live Workers AI call (\(reasonLabel(reason)))")
        return reason
    }

    /// Never performs a network call. Documented skip for the missing free Workers AI path.
    public static func transcribe(audio: Data) -> Result<String, CasmosTranscriptionSkip> {
        _ = audio
        return .failure(CasmosTranscriptionSkip(reason: skipLiveCall()))
    }

    public static func sanitizeStored(_ value: String, placeholder: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == placeholder {
            return ""
        }
        return trimmed
    }

    private static func stripped(_ value: String, placeholder: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == placeholder {
            return ""
        }
        return trimmed
    }

    private static func liveValue(_ value: String, placeholder: String) -> String? {
        let trimmed = stripped(value, placeholder: placeholder)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func reasonLabel(_ reason: SkipReason) -> String {
        switch reason {
        case .disabled:
            return "toggle off"
        case .placeholder:
            return "empty or placeholder credentials"
        case .noFreePath:
            return "no free Cloudflare path; live calls not wired"
        }
    }
}

public struct CasmosTranscriptionSkip: Error, Equatable {
    public let reason: CasmosTranscription.SkipReason

    public init(reason: CasmosTranscription.SkipReason) {
        self.reason = reason
    }
}
