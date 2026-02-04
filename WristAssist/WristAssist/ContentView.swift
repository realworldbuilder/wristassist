import AVFoundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityManager: PhoneConnectivityManager
    @StateObject private var recorder = PhoneAudioRecorderService()
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @State private var copyFeedbackTrigger = false
    @State private var showDeleteConfirmation = false
    @State private var showMicPermissionDenied = false

    private var showRecordButton: Bool {
        connectivityManager.isModelLoaded
            && !editMode.isEditing
            && !connectivityManager.isProcessing
            && !recorder.isRecording
    }

    var body: some View {
        NavigationStack {
            Group {
                if !connectivityManager.isModelLoaded {
                    modelLoadingState
                } else if connectivityManager.transcriptions.isEmpty {
                    emptyState
                } else {
                    transcriptionList
                }
            }
            .navigationTitle("WristAssist")
            .toolbar {
                if !connectivityManager.transcriptions.isEmpty {
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Text(editMode.isEditing ? "Done" : "Select")
                    }
                }
            }
            .toolbar {
                if editMode.isEditing && !selection.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            copySelected()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Spacer()
                        ShareLink(item: selectedTexts())
                        Spacer()
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) {
                if !editMode.isEditing {
                    selection.removeAll()
                }
            }
            .overlay(alignment: .bottom) {
                if connectivityManager.isProcessing {
                    processingBanner
                }
            }
            .overlay(alignment: .bottom) {
                if recorder.isRecording {
                    recordingOverlay
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showRecordButton {
                    recordButton
                }
            }
            .alert("Delete Transcriptions", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(selection.count) transcription\(selection.count == 1 ? "" : "s")?")
            }
            .alert("Microphone Access Required", isPresented: $showMicPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in Settings to record voice notes.")
            }
            .alert("Transcription Error", isPresented: Binding(
                get: { connectivityManager.lastLocalError != nil },
                set: { if !$0 { connectivityManager.lastLocalError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(connectivityManager.lastLocalError ?? "")
            }
        }
        .sensoryFeedback(.success, trigger: copyFeedbackTrigger)
    }

    private var modelLoadingState: some View {
        VStack(spacing: 20) {
            if let error = connectivityManager.modelLoadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Model Failed to Load")
                    .font(.title2.bold())
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    connectivityManager.retryModelLoad()
                }
                .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Loading transcription model")
                Text("Preparing Whisper Model")
                    .font(.title2.bold())
                Text("This is a one-time setup and may take a moment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Transcriptions", systemImage: "mic.slash")
        } description: {
            Text("Record a voice note on your Apple Watch or tap the microphone button below to get started.")
        }
    }

    private var transcriptionList: some View {
        List(selection: $selection) {
            ForEach(connectivityManager.transcriptions) { record in
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.text)
                        .font(.body)
                    Text(record.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.vertical, 4)
                .textSelection(.enabled)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = record.text
                        copyFeedbackTrigger.toggle()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: record.text)
                }
            }
            .onDelete { offsets in
                connectivityManager.deleteTranscriptions(at: offsets)
            }
        }
    }

    // MARK: - Recording UI

    private var recordButton: some View {
        Button {
            requestMicAndRecord()
        } label: {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.3, green: 0.85, blue: 0.2), Color(red: 0.1, green: 0.65, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(radius: 4)
        }
        .padding(24)
        .accessibilityLabel("Record voice note")
    }

    private var recordingOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                Text(formattedDuration)
                    .font(.body.monospacedDigit())
            }

            Button {
                stopAndTranscribe()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.red, in: Circle())
            }
            .accessibilityLabel("Stop recording")

            Text("Tap to stop")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.bottom)
    }

    private var formattedDuration: String {
        let minutes = Int(recorder.recordingDuration) / 60
        let seconds = Int(recorder.recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func requestMicAndRecord() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    if granted {
                        recorder.startRecording()
                    } else {
                        showMicPermissionDenied = true
                    }
                }
            }
        case .denied:
            showMicPermissionDenied = true
        case .granted:
            recorder.startRecording()
        @unknown default:
            break
        }
    }

    private func stopAndTranscribe() {
        guard let url = recorder.stopRecording() else { return }
        connectivityManager.transcribeLocalAudio(at: url)
    }

    // MARK: - Helpers

    private func selectedTexts() -> String {
        connectivityManager.transcriptions
            .filter { selection.contains($0.id) }
            .map(\.text)
            .joined(separator: "\n\n")
    }

    private func copySelected() {
        UIPasteboard.general.string = selectedTexts()
        copyFeedbackTrigger.toggle()
    }

    private func deleteSelected() {
        let offsets = IndexSet(
            connectivityManager.transcriptions.enumerated()
                .filter { selection.contains($0.element.id) }
                .map(\.offset)
        )
        connectivityManager.deleteTranscriptions(at: offsets)
        selection.removeAll()
    }

    private var processingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Transcribing...")
                .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Transcription in progress")
    }
}
