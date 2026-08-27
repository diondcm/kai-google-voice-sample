import React, { useState } from 'react';
import { Settings, BarChart2, Check, Pickaxe } from 'lucide-react';

interface ConfiguratorProps {
  headers: string[];
  data: any[];
  onConfirm: (dimensions: string[], metrics: string[]) => void;
}

export function Configurator({ headers, data, onConfirm }: ConfiguratorProps) {
  const [dimensions, setDimensions] = useState<string[]>([]);
  const [metrics, setMetrics] = useState<string[]>([]);

  // Simple type detection based on first row
  const sampleRow = data.length > 0 ? data[0] : {};

  const toggleDimension = (col: string) => {
    setDimensions(prev => prev.includes(col) ? prev.filter(c => c !== col) : [...prev, col]);
  };

  const toggleMetric = (col: string) => {
    setMetrics(prev => prev.includes(col) ? prev.filter(c => c !== col) : [...prev, col]);
  };

  const isNumeric = (col: string) => {
    return typeof sampleRow[col] === 'number';
  };

  return (
    <div className="card w-full max-w-2xl mx-auto">
      <div className="card-title-container">
        <h2 className="card-title flex items-center gap-2">
          <Settings className="w-5 h-5 text-indigo-400" />
          Configurar Análise
        </h2>
        <span className="group-badge model">Passo 2 de 3</span>
      </div>

      <p className="text-slate-400 text-sm mb-6">
        Selecione as colunas que servirão como base para agrupamentos (Agrupamentos) 
        e as colunas contendo valores para analisar (Métricas).
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h3 className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-3 flex items-center gap-1">
            <Pickaxe className="w-3 h-3" />
            Agrupamentos (Dimensões)
          </h3>
          <p className="text-xs text-slate-500 mb-3">Ex: Cidade, Profissão, Status, Data</p>
          <div className="space-y-2 max-h-60 overflow-y-auto pr-2 custom-scrollbar">
            {headers.map(col => (
              <label key={col} className={`flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-colors ${dimensions.includes(col) ? 'bg-indigo-900/40 border-indigo-500/50' : 'bg-slate-800/50 border-slate-700/50 hover:bg-slate-800'}`}>
                <span className="text-sm font-medium text-slate-200 truncate pr-2">{col}</span>
                <input type="checkbox" className="sr-only" checked={dimensions.includes(col)} onChange={() => toggleDimension(col)} />
                <div className={`w-4 h-4 rounded-sm border flex items-center justify-center flex-shrink-0 ${dimensions.includes(col) ? 'bg-indigo-500 border-indigo-500' : 'border-slate-500'}`}>
                  {dimensions.includes(col) && <Check className="w-3 h-3 text-white" />}
                </div>
              </label>
            ))}
          </div>
        </div>

        <div>
          <h3 className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-3 flex items-center gap-1">
            <BarChart2 className="w-3 h-3" />
            Métricas (Valores)
          </h3>
          <p className="text-xs text-slate-500 mb-3">Ex: Salário, Valor da Venda, Idade</p>
          <div className="space-y-2 max-h-60 overflow-y-auto pr-2 custom-scrollbar">
             {headers.map(col => {
               const num = isNumeric(col);
               return (
                <label key={col} className={`flex items-center justify-between p-3 rounded-lg border cursor-pointer transition-colors ${metrics.includes(col) ? 'bg-teal-900/40 border-teal-500/50' : 'bg-slate-800/50 border-slate-700/50 hover:bg-slate-800'}`}>
                  <div className="flex items-center gap-2 truncate pr-2">
                    <span className="text-sm font-medium text-slate-200 truncate">{col}</span>
                    {num && <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-700 text-slate-300">#</span>}
                  </div>
                  <input type="checkbox" className="sr-only" checked={metrics.includes(col)} onChange={() => toggleMetric(col)} />
                  <div className={`w-4 h-4 rounded-sm border flex items-center justify-center flex-shrink-0 ${metrics.includes(col) ? 'bg-teal-500 border-teal-500' : 'border-slate-500'}`}>
                    {metrics.includes(col) && <Check className="w-3 h-3 text-white" />}
                  </div>
                </label>
               )
             })}
          </div>
        </div>
      </div>

      <div className="mt-8 pt-6 border-t border-slate-700/50 flex flex-col md:flex-row items-center justify-between gap-4">
        <span className="text-sm text-slate-400">
          {(dimensions.length === 0 || metrics.length === 0) 
            ? "Sem seleções? A IA escolherá as melhores visões para você." 
            : `${dimensions.length} agrupamento(s) e ${metrics.length} métrica(s) selecionados.`}
        </span>
        <button
          onClick={() => onConfirm(dimensions, metrics)}
          className="px-6 py-2.5 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition-colors shadow-sm w-full md:w-auto"
        >
          {dimensions.length === 0 || metrics.length === 0 ? 'Gerar Dashboard Automático (IA)' : 'Gerar Dashboard Interativo'}
        </button>
      </div>
    </div>
  );
}
