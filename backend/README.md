# Gemini Voice Live - WebSocket Relay Server

Node.js / Express WebSocket relay that connects Embarcadero Delphi (or Web clients) to Google's **Gemini Multimodal Live API** (`gemini-3.1-flash-live-preview`).

---

## 🌟 Features

- **Bidirectional Audio Streaming**: Streams 16kHz PCM audio from Delphi WaveIn / Mic to Gemini Live, and relays 24kHz PCM synthesized speech back to Delphi WaveOut.
- **Real-Time Voice & Text Transcripts**: Concurrently delivers synthesized audio frames and streaming text responses.
- **Interruption Handling**: Forwards interruption signals when the user speaks while Gemini is talking.
- **Multilingual Support**: Supports custom system instructions, language parameters (`pt-BR`, `en-US`), and voice configurations.

---

## 🚀 Getting Started

### Prerequisites

- **Node.js (v18+)**
- **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com/)

### Installation & Run

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and insert your Gemini API Key:
   ```ini
   GEMINI_API_KEY=your_gemini_api_key_here
   PORT=3000
   ```

3. Start development server:
   ```bash
   npm run dev
   ```

The server will listen for WebSocket connections on `ws://127.0.0.1:3000/live`.
