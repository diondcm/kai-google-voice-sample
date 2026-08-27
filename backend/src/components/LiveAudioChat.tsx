import React, { useEffect, useRef, useState } from 'react';
import { Mic, MicOff, Loader2, StopCircle } from 'lucide-react';

interface LiveAudioChatProps {
  contextText: string;
  onClose: () => void;
}

function pcmToBase64(pcmData: Float32Array): string {
  const buffer = new ArrayBuffer(pcmData.length * 2);
  const view = new DataView(buffer);
  for (let i = 0; i < pcmData.length; i++) {
    let max = Math.max(-1, Math.min(1, pcmData[i]));
    view.setInt16(i * 2, max < 0 ? max * 0x8000 : max * 0x7FFF, true);
  }
  let binary = '';
  const bytes = new Uint8Array(buffer);
  // doing this in chunks can avoid stack overflow, but usually chunks are small enough
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function LiveAudioChat({ contextText, onClose }: LiveAudioChatProps) {
  const [connecting, setConnecting] = useState(true);
  const [active, setActive] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  
  const inputAudioCtxRef = useRef<AudioContext | null>(null);
  const outputAudioCtxRef = useRef<AudioContext | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const nextStartTimeRef = useRef(0);
  const inactivityTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const sourceNodesRef = useRef<Set<AudioBufferSourceNode>>(new Set());

  const stopSession = () => {
    if (inactivityTimeoutRef.current) clearTimeout(inactivityTimeoutRef.current);
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    sourceNodesRef.current.forEach(source => {
      try { source.stop(); } catch(e) {}
    });
    sourceNodesRef.current.clear();

    if (inputAudioCtxRef.current) {
      inputAudioCtxRef.current.close().catch(() => {});
      inputAudioCtxRef.current = null;
    }
    if (outputAudioCtxRef.current) {
      outputAudioCtxRef.current.close().catch(() => {});
      outputAudioCtxRef.current = null;
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(t => t.stop());
      streamRef.current = null;
    }
    setActive(false);
  };

  const resetTimeout = () => {
    if (inactivityTimeoutRef.current) clearTimeout(inactivityTimeoutRef.current);
    
    let playDuration = 0;
    const audioCtx = outputAudioCtxRef.current;
    if (audioCtx && nextStartTimeRef.current > audioCtx.currentTime) {
      playDuration = (nextStartTimeRef.current - audioCtx.currentTime) * 1000;
    }
    
    inactivityTimeoutRef.current = setTimeout(() => {
      stopSession();
      onClose();
    }, 10000 + playDuration);
  };

  const playAudioChunk = (base64Audio: string) => {
    const audioCtx = outputAudioCtxRef.current;
    if (!audioCtx) return;

    resetTimeout(); // Any incoming audio resets timeout

    const binary = atob(base64Audio);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    const buffer = bytes.buffer;
    
    // 16-bit 24kHz raw PCM from Gemini Live
    const audioBuffer = audioCtx.createBuffer(1, bytes.length / 2, 24000);
    const channelData = audioBuffer.getChannelData(0);
    const dataView = new DataView(buffer);
    for (let i = 0; i < channelData.length; i++) {
      channelData[i] = dataView.getInt16(i * 2, true) / 0x8000;
    }
    
    const source = audioCtx.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(audioCtx.destination);
    
    source.onended = () => {
      sourceNodesRef.current.delete(source);
    };
    sourceNodesRef.current.add(source);
    
    if (nextStartTimeRef.current < audioCtx.currentTime) {
      nextStartTimeRef.current = audioCtx.currentTime;
    }
    source.start(nextStartTimeRef.current);
    nextStartTimeRef.current += audioBuffer.duration;
  };

  useEffect(() => {
    let isActiveComponent = true;

    const startSession = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        if (!isActiveComponent) {
          stream.getTracks().forEach(t => t.stop());
          return;
        }
        
        streamRef.current = stream;

        const inputAudioCtx = new AudioContext({ sampleRate: 16000 });
        inputAudioCtxRef.current = inputAudioCtx;
        
        const outputAudioCtx = new AudioContext({ sampleRate: 24000 });
        outputAudioCtxRef.current = outputAudioCtx;

        const source = inputAudioCtx.createMediaStreamSource(stream);
        const processor = inputAudioCtx.createScriptProcessor(4096, 1, 1);
        
        source.connect(processor);
        processor.connect(inputAudioCtx.destination);

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/live?context=${encodeURIComponent(contextText)}`;
        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;

        processor.onaudioprocess = (e) => {
          if (ws.readyState === WebSocket.OPEN) {
            const inputData = e.inputBuffer.getChannelData(0);
            
            let sumSquare = 0;
            for (let i = 0; i < inputData.length; i++) {
              sumSquare += inputData[i] * inputData[i];
            }
            const rms = Math.sqrt(sumSquare / inputData.length);
            if (rms > 0.01) {
              resetTimeout();
            }

            const base64 = pcmToBase64(inputData);
            ws.send(JSON.stringify({ audio: base64 }));
          }
        };

        ws.onopen = () => {
          if (!isActiveComponent) {
             ws.close();
             return;
          }
          setConnecting(false);
          setActive(true);
          resetTimeout();
        };

        ws.onmessage = (event) => {
          const msg = JSON.parse(event.data);
          if (msg.audio) playAudioChunk(msg.audio);
          if (msg.interrupted) {
            nextStartTimeRef.current = outputAudioCtxRef.current?.currentTime || 0;
            sourceNodesRef.current.forEach(source => {
              try { source.stop(); } catch(e) {}
            });
            sourceNodesRef.current.clear();
          }
        };

        ws.onerror = () => {
          if (isActiveComponent) stopSession();
        };

        ws.onclose = () => {
          if (isActiveComponent) stopSession();
        };

      } catch (err: any) {
        console.error(err);
        if (!isActiveComponent) return;
        setConnecting(false);
        if (err.name === 'NotAllowedError' || err.message.includes('Permission denied')) {
          setErrorMsg('Permissão de microfone negada. Se estiver no preview, tente abrir o app em uma nova aba.');
        } else {
          setErrorMsg('Erro ao iniciar áudio: ' + err.message);
        }
      }
    };

    startSession();

    return () => {
      isActiveComponent = false;
      stopSession();
    };
  }, [contextText]);

  return (
    <div className="bg-slate-900/50 rounded-lg p-4 flex flex-col items-center justify-center space-y-3">
      {connecting ? (
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 text-indigo-400 animate-spin" />
          <p className="text-slate-300 text-sm">Conectando ao Gemini Live...</p>
        </div>
      ) : active ? (
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-indigo-600/20 flex items-center justify-center animate-pulse border border-indigo-500">
            <Mic className="w-8 h-8 text-indigo-400" />
          </div>
          <p className="text-slate-300 text-sm text-center">
            Pode falar! A IA está pronta.<br/><span className="text-xs text-slate-500">Encerra após 10s de inatividade.</span>
          </p>
          <button 
            onClick={() => { stopSession(); onClose(); }}
            className="flex items-center gap-2 px-4 py-2 bg-red-500/20 text-red-400 border border-red-500/30 rounded-lg hover:bg-red-500/30 transition-colors"
          >
            <StopCircle className="w-4 h-4" /> Finalizar Chamada
          </button>
        </div>
      ) : errorMsg ? (
        <div className="flex flex-col items-center gap-3 text-red-400 text-center">
          <MicOff className="w-8 h-8" />
          <p className="text-sm font-medium">{errorMsg}</p>
          <button 
            onClick={() => onClose()}
            className="mt-2 px-4 py-2 bg-slate-800 text-slate-300 rounded hover:bg-slate-700 text-sm border border-slate-700"
          >
            Fechar
          </button>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-3 text-red-400">
          <MicOff className="w-8 h-8" />
          <p className="text-sm">Chamada Encerrada</p>
        </div>
      )}
    </div>
  );
}
