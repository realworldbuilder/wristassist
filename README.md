# WristAssist

Voice notes on your Apple Watch with on-device transcription. Record from your wrist, get text on your iPhone — no cloud, no internet required.

## How It Works

1. **Tap to record** on your Apple Watch
2. Audio transfers automatically to your paired iPhone
3. The iPhone transcribes speech to text using [WhisperKit](https://github.com/argmaxinc/WhisperKit) (OpenAI Whisper Tiny model, bundled in-app)
4. Transcription appears on both devices

All processing happens on-device. Nothing leaves your phone.

## Features

**Apple Watch**
- One-tap recording with visual feedback and duration timer
- 16kHz mono WAV audio optimized for speech
- Extended runtime sessions to prevent sleep during transfer
- Always-On Display support
- Transcription preview directly on the watch

**iPhone**
- On-device speech-to-text via WhisperKit (no network needed)
- Transcription history with timestamps
- Multi-select, copy, and share
- Persistent storage across launches

## Requirements

- iPhone running iOS 17.0+
- Apple Watch running watchOS 10.0+
- Xcode 15+

## Getting Started

1. Clone the repo
   ```
   git clone https://github.com/realworldbuilder/wristassist.git
   ```
2. Open `WristAssist/WristAssist.xcodeproj` in Xcode
3. Wait for Swift Package Manager to resolve WhisperKit
4. Select your device/simulator targets and build

The Whisper Tiny model is bundled in the app — no manual download needed.

## Architecture

```
Watch                          iPhone
┌──────────────────┐           ┌──────────────────────────┐
│ RecordingView     │           │ ContentView               │
│ AudioRecorder     │──audio──▶│ PhoneConnectivityManager  │
│ ExtendedSession   │◀──text───│ TranscriptionService      │
│ WatchConnectivity │           │   └─ WhisperKit (CoreML)  │
└──────────────────┘           └──────────────────────────┘
```

- **Watch** handles recording and UI feedback
- **iPhone** handles ML inference and persistent storage
- Communication via WatchConnectivity file transfer with message fallback

## Dependencies

| Package | Purpose |
|---------|---------|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) (>=0.9.0) | On-device speech recognition |

## License

MIT — see [LICENSE](LICENSE).
