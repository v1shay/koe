#if MACPARAKEET_XCODE15_COMPAT
import Foundation

private let nemotronXcode15UnavailableMessage =
    "Nemotron requires Xcode 16 or later. Choose Parakeet, Parakeet Unified, or Cohere in this build."

/// Source-compatible placeholder for FluidAudio's Core ML stateful Nemotron
/// implementation, whose required APIs are not present in the Xcode 15.4 SDK.
public actor NemotronEngine: STTTranscribing, NativeLiveDictating {
    public static let defaultModelVariant = SpeechEnginePreference.defaultNemotronModelVariant

    public init(
        modelVariant: NemotronModelVariant = NemotronEngine.defaultModelVariant,
        language: String? = nil
    ) {}

    public func transcribe(
        audioPath: String,
        job: STTJobKind,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> STTResult {
        throw unavailableError
    }

    public func transcribe(
        audioURL: URL,
        job: STTJobKind,
        language: String?,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> STTResult {
        throw unavailableError
    }

    public func beginLiveDictation(
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws {
        throw unavailableError
    }

    public func processLiveDictationSamples(_ samples: [Float]) async throws {
        throw unavailableError
    }

    public func finishLiveDictation() async throws -> STTResult {
        throw unavailableError
    }

    public func cancelLiveDictation() async {}

    public func prepare(onProgress: (@Sendable (String) -> Void)? = nil) async throws {
        throw unavailableError
    }

    public func unload() async {}

    public func isReady() -> Bool { false }

    public nonisolated static func defaultCacheRoot() -> URL {
        AppPaths.fluidAudioModelDirectory(for: .nemotronMultilingual)
    }

    public nonisolated static func defaultVariantDirectory(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        language: String? = nil
    ) -> URL {
        let languageDirectory = SpeechEnginePreference.normalizeNemotronLanguage(language) ?? "auto"
        return defaultCacheRoot()
            .appendingPathComponent(languageDirectory, isDirectory: true)
            .appendingPathComponent("\(modelVariant.chunkMilliseconds)ms", isDirectory: true)
    }

    public nonisolated static func isModelCached(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        language: String? = nil
    ) -> Bool {
        false
    }

    @discardableResult
    public nonisolated static func deleteModel(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        language: String? = nil
    ) -> Bool {
        deleteItemIfPresent(at: defaultVariantDirectory(modelVariant: modelVariant, language: language))
    }

    @discardableResult
    nonisolated static func deleteModel(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        language: String? = nil,
        cacheRoot: URL
    ) -> Bool {
        let languageDirectory = SpeechEnginePreference.normalizeNemotronLanguage(language) ?? "auto"
        let target = cacheRoot
            .appendingPathComponent(languageDirectory, isDirectory: true)
            .appendingPathComponent("\(modelVariant.chunkMilliseconds)ms", isDirectory: true)
        return deleteItemIfPresent(at: target)
    }

    @discardableResult
    nonisolated static func deleteModelCaches(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        cacheRoot: URL = defaultCacheRoot()
    ) -> Bool {
        deleteItemIfPresent(at: cacheRoot)
    }

    public nonisolated static func downloadModel(
        modelVariant: NemotronModelVariant = defaultModelVariant,
        language: String? = nil,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> URL {
        throw STTError.engineStartFailed(nemotronXcode15UnavailableMessage)
    }

    private var unavailableError: STTError {
        .engineStartFailed(nemotronXcode15UnavailableMessage)
    }
}

public actor NemotronEnglishEngine: STTTranscribing, NativeLiveDictating {
    public static let modelVariant = NemotronModelVariant.english1120

    public init() {}

    public func transcribe(
        audioPath: String,
        job: STTJobKind,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> STTResult {
        throw unavailableError
    }

    public func transcribe(
        audioURL: URL,
        job: STTJobKind,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> STTResult {
        throw unavailableError
    }

    public func beginLiveDictation(
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws {
        throw unavailableError
    }

    public func processLiveDictationSamples(_ samples: [Float]) async throws {
        throw unavailableError
    }

    public func finishLiveDictation() async throws -> STTResult {
        throw unavailableError
    }

    public func cancelLiveDictation() async {}

    public func prepare(onProgress: (@Sendable (String) -> Void)? = nil) async throws {
        throw unavailableError
    }

    public func unload() async {}

    public func isReady() -> Bool { false }

    nonisolated static func modelsBaseDirectory() -> URL {
        AppPaths.fluidAudioModelsDirURL
    }

    public nonisolated static func defaultCacheRoot() -> URL {
        modelsBaseDirectory()
            .appendingPathComponent("nemotron-streaming", isDirectory: true)
            .appendingPathComponent("1120ms", isDirectory: true)
    }

    public nonisolated static func isModelCached() -> Bool { false }

    nonisolated static func isModelCached(cacheRoot: URL) -> Bool { false }

    @discardableResult
    public nonisolated static func deleteModel() -> Bool {
        deleteItemIfPresent(at: defaultCacheRoot())
    }

    @discardableResult
    nonisolated static func deleteModel(cacheRoot: URL) -> Bool {
        deleteItemIfPresent(at: cacheRoot)
    }

    public nonisolated static func downloadModel(
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> URL {
        throw STTError.engineStartFailed(nemotronXcode15UnavailableMessage)
    }

    private var unavailableError: STTError {
        .engineStartFailed(nemotronXcode15UnavailableMessage)
    }
}

@discardableResult
private func deleteItemIfPresent(at url: URL) -> Bool {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else { return false }
    do {
        try fileManager.removeItem(at: url)
        return true
    } catch {
        return false
    }
}
#endif
