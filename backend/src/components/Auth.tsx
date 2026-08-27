import React, { useState } from 'react';
import { Lock, ArrowRight, Loader2 } from 'lucide-react';

interface AuthProps {
  onAuthenticated: () => void;
}

export function Auth({ onAuthenticated }: AuthProps) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password })
      });

      if (res.ok) {
        localStorage.setItem('datalens_auth', 'true');
        onAuthenticated();
      } else {
        setError('Palavra-chave incorreta.');
      }
    } catch (err) {
      setError('Erro de conexão. Tente novamente.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4 selection:bg-indigo-500/30">
      <div className="w-full max-w-md card bg-slate-800">
        <div className="text-center mb-8 flex flex-col items-center">
          <div className="w-12 h-12 bg-indigo-600 rounded-xl flex items-center justify-center shadow-inner mb-4">
            <Lock className="w-6 h-6 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white font-heading">Acesso Restrito</h1>
          <p className="text-slate-400 text-sm mt-2">Informe a palavra-chave para acessar o DataLens</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="Palavra-chave..."
              className="w-full bg-slate-900 border border-slate-700/50 rounded-lg px-4 py-3 text-white placeholder:text-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all shadow-inner"
              autoFocus
            />
          </div>

          {error && (
            <p className="text-red-400 text-sm text-center font-medium animate-in fade-in">{error}</p>
          )}

          <button
            type="submit"
            disabled={!password || loading}
            className="w-full flex items-center justify-center gap-2 bg-indigo-600 text-white font-medium rounded-lg px-4 py-3 hover:bg-indigo-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-md"
          >
            {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : (
              <>Acessar <ArrowRight className="w-5 h-5" /></>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
