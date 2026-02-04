import Combine
import Foundation
import os
import WatchConnectivity

struct TranscriptionRecord: Identifiable, Hashable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(text: String, timestamp: Date) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
    }
}

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    private static let logger = Logger(subsystem: "com.wristassist.app", category: "PhoneConnectivityManager")

    @Published var transcriptions: [TranscriptionRecord] = []
    @Published var isProcessing = false
    @Published var lastLocalError: String?

    private let session: WCSession
    private let transcriptionService = TranscriptionService()
    private var cancellable: AnyCancellable?

    override init() {
        self.session = WCSession.default
        super.init()
        loadTranscriptions()
        cancellable = transcriptionService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        Task {
            await transcriptionService.loadModel()
        }
    }

    var isModelLoaded: Bool {
        transcriptionService.isModelLoaded
    }

    var isLoadingModel: Bool {
        transcriptionService.isLoadingModel
    }

    var modelLoadError: String? {
        transcriptionService.loadError
    }

    func retryModelLoad() {
        Task {
            await transcriptionService.loadModel()
        }
    }

    func transcribeLocalAudio(at url: URL) {
        processAudio(at: url, fromWatch: false)
    }

    private func handleReceivedAudio(at url: URL) {
        processAudio(at: url, fromWatch: true)
    }

    private func processAudio(at url: URL, fromWatch: Bool) {
        Task { @MainActor in
            isProcessing = true
            defer { isProcessing = false }

            let result = await transcriptionService.transcribe(audioURL: url)

            switch result {
            case .success(let text):
                let record = TranscriptionRecord(text: text, timestamp: Date())
                transcriptions.insert(record, at: 0)
                saveTranscriptions()
                if fromWatch {
                    sendTranscriptionToWatch(text)
                }

            case .failure(let error):
                let message = error.localizedDescription
                if fromWatch {
                    sendErrorToWatch(message)
                } else {
                    lastLocalError = message
                }
            }

            // Clean up the audio file
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func sendTranscriptionToWatch(_ text: String) {
        let payload = [ConnectivityConstants.transcriptionKey: text]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                self?.session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func sendErrorToWatch(_ error: String) {
        let payload = [ConnectivityConstants.errorKey: error]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                self?.session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Persistence

    private static var transcriptionsFileURL: URL {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory not found")
        }
        return documentsDir.appendingPathComponent("transcriptions.json")
    }

    private func saveTranscriptions() {
        do {
            let data = try JSONEncoder().encode(transcriptions)
            try data.write(to: Self.transcriptionsFileURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to save transcriptions: \(error)")
        }
    }

    private func loadTranscriptions() {
        let url = Self.transcriptionsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            transcriptions = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            Self.logger.error("Failed to load transcriptions: \(error)")
        }
    }

    func deleteTranscriptions(at offsets: IndexSet) {
        transcriptions.remove(atOffsets: offsets)
        saveTranscriptions()
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Required delegate method
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for iOS
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Copy file to a stable location before the system cleans it up
        let tempDir = FileManager.default.temporaryDirectory
        let destURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: destURL)
            Task { @MainActor in
                self.handleReceivedAudio(at: destURL)
            }
        } catch {
            Self.logger.error("Failed to copy received audio file: \(error)")
        }
    }
}
