# Notetaking Software

Welcome to the Notetaking Software repository. This project turns voice recordings into clean written notes, entirely on your own machine. A native **SwiftUI** app on macOS lets you pick an audio file; a local **Flask** service transcribes it with **OpenAI Whisper** and then uses **Microsoft Phi-3 via Ollama** to convert the raw transcript into a structured Word document. Nothing about the recording ever leaves your computer.

## About the project

Lecture notes, interview tapes, and meeting recordings are valuable but tedious to turn into readable text. Existing services solve this by uploading audio to someone else's GPU — fine for a birthday party playlist, less fine for research interviews or coursework. The goal here was to build the smallest reasonable end-to-end pipeline (record → transcribe → summarize → document) using only open models running locally, with a native UI that feels like a real macOS app rather than a browser tab.

## Features

- **One-click upload** from a native SwiftUI macOS client.
- **Offline transcription** using Whisper `small.en` (English-optimized, fast on CPU).
- **Offline summarization** using Phi-3 through Ollama, prompted to preserve meaning and add titles / subtitles.
- **Structured output** — a plain-text transcript (`.txt`) and a Word document (`.docx`) dropped straight into `~/Downloads`.
- **Single-endpoint API** that is easy to inspect, replace, or port to another frontend.

## End-to-end Flow

1. You launch the Flask backend; Whisper loads once, Ollama is ready with `phi3` pulled.
2. You launch the SwiftUI app and tap **Upload Recording**.
3. The macOS file picker (`.fileImporter`) returns an audio file.
4. The app builds a `multipart/form-data` request and `POST`s it to `http://127.0.0.1:5000/upload`.
5. Flask saves the file, runs Whisper, writes `<name>.txt` to `~/Downloads`, feeds the transcript to Phi-3, and writes `<name>.docx` to `~/Downloads`.
6. The response carries both paths back; buttons in the app open them through `NSWorkspace`.

## Tech Stack

| Layer | Choice |
| --- | --- |
| Client | SwiftUI (macOS) |
| Backend | Python 3, Flask |
| Transcription | [`openai-whisper`](https://github.com/openai/whisper) — model `small.en` |
| Summarization | [Ollama](https://ollama.com) running `phi3`, driven via `langchain-community`'s `Ollama` wrapper |
| Document generation | `python-docx` |
| Transport | `multipart/form-data` over HTTP on `127.0.0.1:5000` |

No database is involved. The server uses `uploads/` as a scratch directory and writes finished artifacts to `~/Downloads`.

## Project Structure

```
Notetaking-Software/
├── notetaking.py          # Flask app: /upload, Whisper, Phi-3, docx writer
├── NotetakingApp.swift    # SwiftUI @main entry
├── ContentView.swift      # UI: file picker, upload, open result buttons
├── README.md
└── .gitignore             # ignores uploads/ and generated transcripts
```

## Prerequisites

- **macOS** (the client uses `NSWorkspace`, which is AppKit / macOS only)
- **Xcode** recent enough for modern SwiftUI syntax
- **Python 3.10+** with `pip`
- **[ffmpeg](https://ffmpeg.org/)** on your `PATH` (Whisper needs it to decode most audio formats)
- **[Ollama](https://ollama.com)** installed and running

Pull Phi-3 before first run:

```bash
ollama pull phi3
```

## Setup

### 1. Backend

There is no `requirements.txt` in the repo yet; install the direct dependencies yourself:

```bash
pip install flask werkzeug openai-whisper python-docx langchain-community
# and the Torch wheel appropriate for your platform
# (CPU example):
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

Then start the server:

```bash
python notetaking.py
```

It listens on `http://127.0.0.1:5000`. On first launch Whisper will download the `small.en` weights (~250 MB).

### 2. Frontend

The repository ships the two Swift source files without an Xcode project.

1. In Xcode, create a new **macOS App** (SwiftUI lifecycle).
2. Drop `NotetakingApp.swift` and `ContentView.swift` into the target.
3. Build and run. The app expects the Flask server to be reachable at `http://127.0.0.1:5000` — if you change the port, edit the URL in `ContentView.swift`.

If you enable App Sandbox, allow outgoing network connections so the client can reach `localhost:5000`.

## API

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| `POST` | `/upload` | `multipart/form-data` with field `file` (audio) | JSON `{ transcript_file_path, docx_file_path, message }`. `400` if `file` is missing or empty. |

The request is blocking for the duration of transcription and summarization — expect tens of seconds for short clips on CPU, longer for long recordings.

## Usage

1. Start the backend (`python notetaking.py`).
2. Start Ollama (`ollama serve` or the desktop app).
3. Launch the SwiftUI app → **Upload Recording** → pick an audio file.
4. When processing finishes, use **Open Transcript** and **Open Notes** to view the `.txt` and `.docx` in `~/Downloads`.

## Future Work

- Add a `requirements.txt` and a Makefile / shell script for one-command setup.
- In-app recording (currently only file upload is supported).
- Live progress / streaming of the transcript in the client rather than waiting on a single HTTP response.
- Swap the Flask + Python server for a Swift-native backend so the whole pipeline ships as one app.
- Optional deployment to a home server (e.g. a Raspberry Pi or mini-PC) so multiple devices can share one transcription endpoint.

## Caveats

- The committed Swift code references a `WhisperState` type and a `URL.mimeType` helper that are not in the repo; these need to be stubbed out or implemented locally before the target compiles.
- The backend disables default HTTPS certificate verification globally (`ssl._create_default_https_context = ssl._create_unverified_context`). This is convenient during setup but should be removed before exposing the server to anything beyond `localhost`.
