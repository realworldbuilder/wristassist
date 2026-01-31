import SwiftUI

struct RecordingView: View {
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var connectivity = WatchConnectivityManager()
    @StateObject private var extendedSession = ExtendedSessionManager()

    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    @State private var isPulsing = false
    @State private var ringRotation: Double = 0
    @State private var dotVisible = true
    @State private var showSnippet = false

    private var idleGradient: [Color] {
        [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)]
    }

    private var recordingGradient: [Color] {
        [Color(red: 0.1, green: 0.9, blue: 0.1), Color(red: 0.0, green: 0.5, blue: 0.15)]
    }

    var body: some View {
        Group {
            if isLuminanceReduced {
                alwaysOnView
            } else {
                activeView
            }
        }
        .onChange(of: connectivity.lastTranscription) {
            if connectivity.lastTranscription != nil {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSnippet = true
                }
            }
        }
        .onChange(of: recorder.isRecording) {
            if recorder.isRecording {
                showSnippet = false
                startAnimations()
                extendedSession.startSession()
            } else {
                stopAnimations()
                extendedSession.endSession()
            }
        }
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(spacing: 12) {
            Spacer()

            recordButton

            statusArea

            Spacer()

            snippetCard
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Always On Display View

    private var alwaysOnView: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            if recorder.isRecording {
                Text(formattedDuration)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("Ready")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                stopAndSend()
            } else {
                recorder.startRecording()
            }
        } label: {
            ZStack {
                // Glow behind button when recording
                if recorder.isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.1, green: 0.9, blue: 0.1).opacity(0.4), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 55
                            )
                        )
                        .frame(width: 90, height: 90)
                        .opacity(isPulsing ? 0.8 : 0.3)
                }

                // Rotating ring when recording
                if recorder.isRecording {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: recordingGradient + [recordingGradient[0]],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(ringRotation))
                }

                // Main gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: recorder.isRecording ? recordingGradient : idleGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                // Icon
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPulsing ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: recorder.isRecording)
    }

    // MARK: - Status Area

    @ViewBuilder
    private var statusArea: some View {
        if recorder.isRecording {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .opacity(dotVisible ? 1.0 : 0.0)

                Text(formattedDuration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
            }
        } else if connectivity.isSending {
            VStack(spacing: 6) {
                ProgressView()
                    .tint(.green)

                Text("Transcribing")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fixedSize()
            }
        } else {
            Text("Tap to record")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Snippet Card

    @ViewBuilder
    private var snippetCard: some View {
        if let transcription = connectivity.lastTranscription {
            Text(truncatedSnippet(transcription))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                )
                .opacity(showSnippet ? 1 : 0)
                .offset(y: showSnippet ? 0 : 12)
        }

        if let error = connectivity.lastError {
            Label {
                Text(error)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let seconds = Int(recorder.recordingDuration)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func truncatedSnippet(_ text: String, maxLength: Int = 80) -> String {
        guard text.count > maxLength else { return text }
        let trimmed = text.prefix(maxLength)
        if let lastSpace = trimmed.lastIndex(of: " ") {
            return String(trimmed[trimmed.startIndex..<lastSpace]) + "..."
        }
        return String(trimmed) + "..."
    }

    private func stopAndSend() {
        guard let url = recorder.stopRecording() else { return }
        connectivity.transferAudioFile(at: url)
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            dotVisible = false
        }
    }

    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPulsing = false
            ringRotation = 0
            dotVisible = true
        }
    }
}
