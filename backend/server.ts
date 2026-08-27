import fs from 'fs';
import express from 'express';
import path from 'path';
import { createServer as createViteServer } from 'vite';
import {
  EndSensitivity,
  GoogleGenAI,
  LiveServerMessage,
  Modality,
  StartSensitivity,
} from '@google/genai';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import { WebSocketServer } from 'ws';

const getDirname = () => {
  if (typeof __dirname !== 'undefined') return __dirname;
  try {
    if (typeof import.meta !== 'undefined' && import.meta?.url) {
      return path.dirname(fileURLToPath(import.meta.url));
    }
  } catch {}
  return process.cwd();
};
const serverDir = getDirname();

// Load environment variables
const envCandidates = [
  path.join(process.cwd(), '.env'),
  path.join(serverDir, '.env'),
  path.join(process.cwd(), 'backend', '.env'),
  path.join(serverDir, '..', '.env'),
];

for (const envPath of envCandidates) {
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log(`[Server] Loaded environment variables from ${envPath}`);
    break;
  }
}
dotenv.config();

let aiClient: GoogleGenAI | null = null;
const getAi = () => {
  if (!aiClient) {
    const apiKey = process.env.GEMINI_API_KEY || process.env.API_KEY || process.env.GOOGLE_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not set. Please define GEMINI_API_KEY in your .env file.");
    }
    aiClient = new GoogleGenAI({
      apiKey,
      httpOptions: {
        headers: {
          'User-Agent': 'delphi-gemini-live-sample',
        },
      },
    });
  }
  return aiClient;
};

async function startServer() {
  const app = express();
  const PORT = parseInt(process.env.PORT || '3000', 10);

  app.use(express.json({ limit: '10mb' }));

  // Health check endpoint
  app.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      service: 'gemini-voice-live-relay',
      model: process.env.GEMINI_LIVE_MODEL || 'gemini-3.1-flash-live-preview',
      timestamp: new Date().toISOString(),
    });
  });

  // Vite middleware for web frontend (development / production)
  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(serverDir, 'dist');
    if (fs.existsSync(distPath)) {
      app.use(express.static(distPath));
      app.get('*all', (_req, res) => {
        res.sendFile(path.join(distPath, 'index.html'));
      });
    }
  }

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(` Gemini Voice Live Relay Server`);
    console.log(` Listening on: http://0.0.0.0:${PORT}`);
    console.log(` WebSocket URL: ws://127.0.0.1:${PORT}/live`);
    console.log(` Model: ${process.env.GEMINI_LIVE_MODEL || 'gemini-3.1-flash-live-preview'}`);
    console.log(`====================================================`);
  });

  const wss = new WebSocketServer({ server });

  wss.on('connection', async (clientWs, req) => {
    // Only handle /live WebSocket connections
    if (!req.url?.startsWith('/live')) {
      clientWs.close(1008, 'Unknown endpoint');
      return;
    }

    const sessionId = crypto.randomUUID();
    const urlParams = new URLSearchParams(req.url.split('?')[1] || '');
    const contextText = urlParams.get('context') || '';
    const langParam = urlParams.get('lang') || 'en-US';
    const voiceParam = urlParams.get('voice') || 'Zephyr';
    const isPortuguese = langParam === 'pt-BR' || langParam === 'pt';

    console.log(`[${new Date().toISOString()}] [Session: ${sessionId}] Client connected from ${req.socket.remoteAddress} (Language: ${langParam}, Voice: ${voiceParam})`);

    let audioFrameCount = 0;
    let microphoneDetected = false;

    const describeError = (error: unknown): string => {
      if (error instanceof Error) return error.message;
      if (typeof error === 'string') return error;
      if (error && typeof error === 'object') {
        const candidate = error as { message?: unknown; error?: unknown };
        if (typeof candidate.message === 'string') return candidate.message;
        if (candidate.error instanceof Error) return candidate.error.message;
        if (typeof candidate.error === 'string') return candidate.error;
      }
      try {
        return JSON.stringify(error);
      } catch {
        return 'Unknown Gemini Live error';
      }
    };

    const failClient = (message: string) => {
      console.error(`[Session: ${sessionId}] Gemini Live session error:`, message);
      if (clientWs.readyState === clientWs.OPEN) {
        clientWs.send(JSON.stringify({ error: message }), () => {
          if (clientWs.readyState === clientWs.OPEN) {
            clientWs.close(1011, 'Gemini Live backend error');
          }
        });
      }
    };

    // Construct system instructions based on client context and language
    let systemInstruction = contextText;
    if (!systemInstruction) {
      systemInstruction = isPortuguese
        ? 'Você é um assistente de voz interativo, inteligente e atencioso. Responda em Português do Brasil com naturalidade, clareza e concisão, adequado para áudio falado em tempo real.'
        : 'You are an intelligent, friendly, and helpful real-time voice assistant. Respond with natural spoken conversational phrasing, clarity, and conciseness.';
    }

    try {
      const liveModel = process.env.GEMINI_LIVE_MODEL || 'gemini-3.1-flash-live-preview';
      console.log(`[Session: ${sessionId}] Connecting to Gemini Live API (${liveModel})...`);

      const sessionPromise = getAi().live.connect({
        model: liveModel,
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: {
                voiceName: voiceParam,
              },
            },
          },
          realtimeInputConfig: {
            automaticActivityDetection: {
              disabled: false,
              startOfSpeechSensitivity: StartSensitivity.START_SENSITIVITY_HIGH,
              endOfSpeechSensitivity: EndSensitivity.END_SENSITIVITY_HIGH,
              prefixPaddingMs: 20,
              silenceDurationMs: 600,
            },
          },
          systemInstruction,
        },
        callbacks: {
          onmessage: async (message: LiveServerMessage) => {
            if (clientWs.readyState !== clientWs.OPEN) return;

            const parts = message.serverContent?.modelTurn?.parts || [];
            for (const part of parts) {
              if (part.inlineData?.data) {
                // Relay synthesized PCM audio back to client
                clientWs.send(JSON.stringify({ audio: part.inlineData.data }));
              }
              if (part.text) {
                // Relay transcript text back to client
                clientWs.send(JSON.stringify({ text: part.text }));
              }
            }

            // Handle user interruption signal
            if (message.serverContent?.interrupted) {
              clientWs.send(JSON.stringify({ interrupted: true }));
            }
          },
          onerror: (event) => {
            failClient(describeError(event));
          },
          onclose: (event) => {
            const detail = event.reason
              ? `Gemini Live closed (${event.code}): ${event.reason}`
              : `Gemini Live closed (${event.code})`;
            console.warn(`[Session: ${sessionId}] ${detail}`);
            if (clientWs.readyState === clientWs.OPEN) {
              if (event.code === 1000) {
                clientWs.close(1000, 'Gemini Live session closed');
              } else {
                failClient(detail);
              }
            }
          },
        },
      });

      const session = await sessionPromise;

      if (clientWs.readyState !== clientWs.OPEN) {
        session.close();
        return;
      }

      // Notify client that voice channel is ready
      clientWs.send(JSON.stringify({ ready: true, sessionId, status: 'ready' }));

      // Handle incoming messages from Delphi or Web client
      clientWs.on('message', (data) => {
        try {
          const parsed = JSON.parse(data.toString());

          // 1. Microphone PCM Audio Stream (Base64, 16kHz Mono)
          if (parsed.audio) {
            const pcm = Buffer.from(parsed.audio, 'base64');
            audioFrameCount += 1;

            if (audioFrameCount === 1) {
              console.log(`[Session: ${sessionId}] Voice channel receiving microphone audio (${pcm.length} bytes/frame)`);
            }

            if (!microphoneDetected && pcm.length >= 2) {
              let sumSquares = 0;
              const sampleCount = Math.floor(pcm.length / 2);
              for (let offset = 0; offset + 1 < pcm.length; offset += 2) {
                const sample = pcm.readInt16LE(offset) / 32768;
                sumSquares += sample * sample;
              }
              const rms = Math.sqrt(sumSquares / sampleCount);
              if (rms > 0.003) {
                microphoneDetected = true;
                console.log(`[Session: ${sessionId}] Microphone speech detected (RMS ${rms.toFixed(4)})`);
              }
            }

            session.sendRealtimeInput({
              audio: { data: parsed.audio, mimeType: 'audio/pcm;rate=16000' },
            });
          }
          // 2. Text Input / Prompt
          else if (parsed.text) {
            session.sendRealtimeInput({
              text: parsed.text,
            });
          }
        } catch (err) {
          console.error(`[Session: ${sessionId}] Message processing error:`, err);
          failClient(describeError(err));
        }
      });

      clientWs.on('close', () => {
        try {
          console.log(`[Session: ${sessionId}] Client disconnected`);
          session.close();
        } catch (err) {
          console.error(`[Session: ${sessionId}] Gemini Live close error:`, describeError(err));
        }
      });
    } catch (err) {
      console.error(`[Session: ${sessionId}] Connection error:`, err);
      failClient(describeError(err));
    }
  });
}

startServer();
