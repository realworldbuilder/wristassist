import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivityManager: PhoneConnectivityManager
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive

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
        }
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
            Text("Record a voice note on your Apple Watch to get started.")
        }
    }

    private var transcriptionList: some View {
        List(connectivityManager.transcriptions, selection: $selection) { record in
            VStack(alignment: .leading, spacing: 6) {
                Text(record.text)
                    .font(.body)
                Text(record.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .textSelection(.enabled)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = record.text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: record.text)
            }
        }
    }

    private func selectedTexts() -> String {
        connectivityManager.transcriptions
            .filter { selection.contains($0.id) }
            .map(\.text)
            .joined(separator: "\n\n")
    }

    private func copySelected() {
        UIPasteboard.general.string = selectedTexts()
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
    }
}
