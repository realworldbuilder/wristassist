import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var lastTranscription: String?
    @Published var lastError: String?
    @Published var isSending = false

    private let session: WCSession
    private var sendingTimeout: DispatchWorkItem?

    override init() {
        self.session = WCSession.default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func transferAudioFile(at url: URL) {
        guard session.activationState == .activated else {
            lastError = "Watch not connected to iPhone"
            return
        }
        isSending = true
        lastTranscription = nil
        lastError = nil
        session.transferFile(url, metadata: nil)
        startTimeout()
    }

    private func startTimeout() {
        sendingTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isSending else { return }
                self.lastError = "No response from iPhone"
                self.isSending = false
            }
        }
        sendingTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
    }

    private func cancelTimeout() {
        sendingTimeout?.cancel()
        sendingTimeout = nil
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.lastError = "Activation failed: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.cancelTimeout()
            if let transcription = message[ConnectivityConstants.transcriptionKey] as? String {
                self.lastTranscription = transcription
                self.isSending = false
            } else if let error = message[ConnectivityConstants.errorKey] as? String {
                self.lastError = error
                self.isSending = false
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.cancelTimeout()
            if let transcription = userInfo[ConnectivityConstants.transcriptionKey] as? String {
                self.lastTranscription = transcription
                self.isSending = false
            } else if let error = userInfo[ConnectivityConstants.errorKey] as? String {
                self.lastError = error
                self.isSending = false
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.cancelTimeout()
                self.lastError = "Transfer failed: \(error.localizedDescription)"
                self.isSending = false
            }
        }
    }
}
