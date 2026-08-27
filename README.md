# Gemini Voice Live with Embarcadero Delphi & Node.js

A full-duplex real-time voice and simultaneous translation application built using **Embarcadero Delphi (FMX / WinRT / Windows Multimedia PCM)** and a **Node.js / Express WebSocket Backend** powered by Google's **Gemini Multimodal Live API** (`gemini-3.1-flash-live-preview`).

---

## 🌟 Overview & Features

- **Full-Duplex Interactive Voice Assistant**: Real-time conversational AI in Brazilian Portuguese with ultra-low latency.
- **Simultaneous Translator (English)**: Live speech-to-English translation streaming both synthesized audio and transcribed text in real time.
- **Native Delphi Audio Engine (`Audio.PCM.Windows.pas`)**: Direct low-latency PCM audio capture (16kHz, 16-bit Mono) with Voice Activity Detection (RMS) and PCM playback (24kHz, 16-bit Mono) using Windows Multimedia (`winmm.dll`).
- **Async WebSocket Client (`Gemini.Live.Client.pas`)**: Asynchronous threaded communication with the backend relay using Windows WinRT `IMessageWebSocket`.
- **Intelligent Echo & Interruption Handling**: Prevents acoustic feedback during AI speech and seamlessly handles model interruptions.

---

## 🏗 Architecture

```
┌────────────────────────────────────────────────────────┐
│              Embarcadero Delphi Client                 │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │   TWindowsPcmAudio    │   │  TGeminiLiveClient   │  │
│  │  - 16kHz PCM In (Mic) │   │  - WinRT WebSocket   │  │
│  │  - 24kHz PCM Out (Spk)│   │  - Message Queues    │  │
│  │  - RMS VAD & Echo Mute│   │  - State Management  │  │
│  └───────────────────────┘   └──────────────────────┘  │
└───────────────────────────▲────────────────────────────┘
                            │ WebSocket (JSON + Base64 PCM)
                            │ ws://127.0.0.1:3000/live
┌───────────────────────────▼────────────────────────────┐
│                  Node.js Backend Relay                 │
│                                                        │
│  - Express HTTP & WebSocket Server (`server.ts`)       │
│  - Google GenAI SDK (`@google/genai`)                  │
│  - Model: `gemini-3.1-flash-live-preview`              │
└───────────────────────────▲────────────────────────────┘
                            │ Gemini Live Bidirectional Stream
                            ▼
               Google Gemini Live API
```

---

## 📁 Repository Structure

```text
kai-google-voice-sample/
├── delphi/                     # Delphi FMX Client Application
│   ├── DelphiVoiceSample.dpr   # Delphi project source file
│   ├── DelphiVoiceSample.dproj # Delphi project configuration
│   ├── Form.Main.pas / .fmx    # Main UI form and interaction handlers
│   ├── Gemini.Live.Client.pas  # Asynchronous WinRT WebSocket client
│   └── Audio.PCM.Windows.pas   # Native Windows PCM WaveIn/WaveOut driver
├── backend/                    # Node.js WebSocket relay & Web Dashboard
│   ├── server.ts               # Express & WebSocket Gemini Live proxy
│   ├── package.json            # Node.js dependencies and scripts
│   ├── .env.example            # Environment variable template (NEVER commit .env)
│   ├── src/                    # Web frontend components
│   └── tsconfig.json           # TypeScript configuration
├── .gitignore                  # Excludes binaries, node_modules, and secrets
├── LICENSE                     # License file
└── README.md                   # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites

1. **Embarcadero Delphi 11 Alexandria / 12 Athens** (or compatible) with FireMonkey and Windows SDK.
2. **Node.js (v18+)** and `npm`.
3. **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com/).

---

### Step 1: Start the Backend Relay

1. Navigate to the `backend` folder:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create your `.env` file from `.env.example`:
   ```bash
   cp .env.example .env
   ```
4. Open `.env` and set your `GEMINI_API_KEY`:
   ```ini
   GEMINI_API_KEY=your_actual_gemini_api_key_here
   PORT=3000
   ```
5. Run the backend development server:
   ```bash
   npm run dev
   ```
   The backend server will start on `http://127.0.0.1:3000` and listen for Delphi WebSocket connections on `ws://127.0.0.1:3000/live`.

---

### Step 2: Run the Delphi Client

1. Open `delphi/DelphiVoiceSample.dproj` in **Embarcadero RAD Studio / Delphi**.
2. Select the target platform (**Win32** or **Win64**).
3. Build and run the application (`F9`).
4. Click:
   - **"Iniciar Gemini Live"** to start an interactive conversation in Brazilian Portuguese.
   - **"Iniciar Tradutor Inglês"** to translate your spoken Portuguese to English with real-time voice and transcript text.

---

## 🔒 Security Notes

- **Never commit your `.env` file or API keys to GitHub.**
- The `.gitignore` in this repository is pre-configured to ignore `.env*` files, build binaries (`*.dcu`, `*.exe`, `Win32/`, `Win64/`), and `node_modules/`.
