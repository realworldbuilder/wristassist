# WristAssist

On-device voice-to-text for Apple Watch. Record on your wrist, transcribe on your phone. No cloud. No network. Runs [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Whisper Tiny) entirely on-device via CoreML.

## Overview

```
┌─ Apple Watch ──────────────┐          ┌─ iPhone ─────────────────────────┐
│                            │          │                                  │
│  RecordingView             │  .wav    │  ContentView                     │
│  AudioRecorderService ─────────────▶  PhoneConnectivityManager          │
│  ExtendedSessionManager    │          │    └─ TranscriptionService       │
│  WatchConnectivityManager ◀────────────       └─ WhisperKit (CoreML)    │
│                            │  text    │                                  │
└────────────────────────────┘          └──────────────────────────────────┘
```

Watch records 16kHz mono PCM → transfers via `WCSession.transferFile()` → iPhone runs Whisper inference → sends transcription back via `sendMessage()` (realtime) or `transferUserInfo()` (background fallback).

## Project Structure

```
WristAssist/
├── Shared/
│   └── ConnectivityConstants.swift       # WatchConnectivity message keys
├── WristAssist/                          # iOS target
│   ├── WristAssistApp.swift
│   ├── ContentView.swift                 # Transcription list UI
│   ├── TranscriptionService.swift        # WhisperKit wrapper
│   ├── PhoneConnectivityManager.swift    # WCSession delegate, persistence
│   └── Models/openai_whisper-tiny/       # Bundled CoreML models
│       ├── AudioEncoder.mlmodelc
│       ├── MelSpectrogram.mlmodelc
│       └── TextDecoder.mlmodelc
└── WristAssist Watch App/                # watchOS target
    ├── WristAssistWatchApp.swift
    ├── RecordingView.swift               # Record button + status UI
    ├── AudioRecorderService.swift        # AVAudioRecorder (16kHz/16-bit/mono)
    ├── WatchConnectivityManager.swift    # File transfer + message handling
    └── ExtendedSessionManager.swift      # WKExtendedRuntimeSession
```

## Setup

```bash
git clone https://github.com/realworldbuilder/wristassist.git
open WristAssist/WristAssist.xcodeproj
```

SPM resolves [WhisperKit](https://github.com/argmaxinc/WhisperKit) (`>=0.9.0`) automatically. The Whisper Tiny model is bundled in-app — no download step.

**Targets:** iOS 17.0+ / watchOS 10.0+

## Technical Notes

- **Audio format:** Linear PCM, 16kHz sample rate, 16-bit depth, mono — optimized for Whisper input
- **Model loading:** Async on first launch from bundle path, no network fetch (`download: false`)
- **Persistence:** Transcriptions saved to `Documents/transcriptions.json` (Codable)
- **Threading:** All observable objects are `@MainActor`; ML inference runs async
- **Watch runtime:** `WKExtendedRuntimeSession` keeps the watch awake during transfer
- **Connectivity:** Dual-path — `sendMessage()` when reachable, `transferUserInfo()` as fallback, 60s timeout

## License

[MIT](LICENSE)
