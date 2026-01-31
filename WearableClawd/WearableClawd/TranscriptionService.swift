import Foundation
import WhisperKit

@MainActor
final class TranscriptionService: ObservableObject {
    @Published var isProcessing = false
    @Published var isModelLoaded = false
    @Published var isLoadingModel = false
    @Published var loadError: String?

    private var whisperKit: WhisperKit?

    func loadModel() async {
        guard whisperKit == nil, !isLoadingModel else { return }
        isLoadingModel = true
        loadError = nil
        do {
            let modelPath = Bundle.main.bundlePath + "/openai_whisper-tiny"
            whisperKit = try await WhisperKit(
                modelFolder: modelPath,
                verbose: true,
                logLevel: .debug,
                download: false
            )
            isModelLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingModel = false
    }

    func transcribe(audioURL: URL) async -> Result<String, Error> {
        guard let whisperKit else {
            return .failure(TranscriptionError.modelNotLoaded)
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let results = try await whisperKit.transcribe(audioPath: audioURL.path())
            let text = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if text.isEmpty {
                return .failure(TranscriptionError.emptyResult)
            }
            return .success(text)
        } catch {
            return .failure(error)
        }
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "Whisper model not loaded"
        case .emptyResult: "No speech detected"
        }
    }
}
