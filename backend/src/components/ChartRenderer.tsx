import React, { useState } from 'react';
import { HelpCircle, X, Loader2, Mic } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import { LiveAudioChat } from './LiveAudioChat';
import {
  ResponsiveContainer,
  BarChart, Bar,
  LineChart, Line,
  PieChart, Pie, Cell,
  ScatterChart, Scatter,
  AreaChart, Area,
  ComposedChart,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend
} from 'recharts';

interface ChartConfig {
  type: string;
  xAxis: string;
  yAxis: string[];
  title: string;
  description: string;
  aggregation?: string;
}

interface ChartRendererProps {
  config: ChartConfig;
  data: any[];
}

const COLORS = ['#8b5cf6', '#14b8a6', '#f43f5e', '#f59e0b', '#3b82f6', '#ec4899', '#10b981'];

export function ChartRenderer({ config, data }: ChartRendererProps) {
  const { type, xAxis, yAxis, title, description, aggregation } = config;
  
  const [modalState, setModalState] = useState<'closed' | 'ask' | 'loading' | 'view' | 'live'>('closed');
  const [explanation, setExplanation] = useState<string | null>(null);

  const handleHelpClick = () => {
    if (explanation) {
      setModalState('view');
    } else {
      setModalState('ask');
    }
  };

  const fetchExplanation = async () => {
    setModalState('loading');
    try {
      const stats: any = {};
      
      // Calculate X Axis stats
      const xVals = data.map(d => d[xAxis]).filter(v => v !== undefined && v !== null);
      if (xVals.length > 0) {
        if (typeof xVals[0] === 'number') {
          stats[xAxis] = { min: Math.min(...xVals), max: Math.max(...xVals) };
        } else {
          stats[xAxis] = { 
            unique_count: new Set(xVals).size, 
            sample_start: xVals[0], 
            sample_end: xVals[xVals.length - 1] 
          };
        }
      }

      // Calculate Y Axis stats
      if (yAxis && yAxis.length > 0) {
        yAxis.forEach(yKey => {
          const vals = data.map(d => Number(d[yKey])).filter(v => !isNaN(v));
          stats[yKey] = {
            min: vals.length ? Math.min(...vals) : null,
            max: vals.length ? Math.max(...vals) : null
          };
        });
      }

      const res = await fetch('/api/explain-chart', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chartConfig: config, stats })
      });
      
      const json = await res.json();
      if (json.explanation) {
        setExplanation(json.explanation);
        setModalState('view');
      } else {
        throw new Error('Falha ao obter explicação server');
      }
    } catch (err) {
      console.error(err);
      setExplanation("Desculpe, ocorreu um erro ao gerar a explicação deste gráfico.");
      setModalState('view');
    }
  };

  const renderChart = () => {
    switch (type.toLowerCase()) {
      case 'bar':
        return (
          <BarChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} />
            <XAxis dataKey={xAxis} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
            <YAxis tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
            <Tooltip contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} />
            <Legend />
            {yAxis.map((key, index) => (
              <Bar key={key} dataKey={key} fill={COLORS[index % COLORS.length]} radius={[4, 4, 0, 0]} />
            ))}
          </BarChart>
        );
      case 'line':
        return (
          <LineChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
             <CartesianGrid strokeDasharray="3 3" vertical={false} />
             <XAxis dataKey={xAxis} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <YAxis tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <Tooltip contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} />
             <Legend />
             {yAxis.map((key, index) => (
               <Line key={key} type="monotone" dataKey={key} stroke={COLORS[index % COLORS.length]} strokeWidth={3} dot={{r: 4, fill: '#1e293b', strokeWidth: 2}} activeDot={{r: 6}} />
             ))}
          </LineChart>
        );
      case 'area':
        return (
           <AreaChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
             <CartesianGrid strokeDasharray="3 3" vertical={false} />
             <XAxis dataKey={xAxis} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <YAxis tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <Tooltip contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} />
             <Legend />
             {yAxis.map((key, index) => (
               <Area key={key} type="monotone" dataKey={key} fill={COLORS[index % COLORS.length]} stroke={COLORS[index % COLORS.length]} fillOpacity={0.3} strokeWidth={2} />
             ))}
           </AreaChart>
        );
      case 'pie':
        const pieValueKey = yAxis[0];
        return (
          <PieChart margin={{ top: 10, right: 20, left: 20, bottom: 10 }}>
            <Tooltip contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} itemStyle={{color: '#f8fafc'}} />
            <Legend layout="horizontal" verticalAlign="bottom" align="center" wrapperStyle={{paddingTop: '20px'}} />
            <Pie
              data={data}
              dataKey={pieValueKey}
              nameKey={xAxis}
              cx="50%"
              cy="50%"
              innerRadius={60}
              outerRadius={100}
              paddingAngle={5}
              stroke="none"
              label={{ fill: '#f8fafc', fontSize: 12 }}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
          </PieChart>
        );
      case 'scatter':
        const scatterY = yAxis[0];
        return (
          <ScatterChart margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
             <CartesianGrid strokeDasharray="3 3" vertical={false} />
             <XAxis dataKey={xAxis} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <YAxis dataKey={scatterY} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
             <Tooltip cursor={{ strokeDasharray: '3 3' }} contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} />
             <Legend />
             <Scatter name={title} data={data} fill={COLORS[0]} />
          </ScatterChart>
        );
      case 'composed':
      default:
        return (
          <ComposedChart data={data} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" vertical={false} />
            <XAxis dataKey={xAxis} tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
            <YAxis tick={{fill: '#94a3b8'}} tickLine={{stroke: '#334155'}} axisLine={{stroke: '#334155'}} />
            <Tooltip contentStyle={{backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '8px', color: '#f8fafc'}} />
            <Legend />
            {yAxis.map((key, index) => {
               if (index === 0) return <Bar key={key} dataKey={key} fill={COLORS[index % COLORS.length]} radius={[4, 4, 0, 0]} />;
               return <Line key={key} type="monotone" dataKey={key} stroke={COLORS[index % COLORS.length]} strokeWidth={3} dot={{r: 4, fill: '#1e293b', strokeWidth: 2}} />;
            })}
          </ComposedChart>
        );
    }
  };

  return (
    <div className="flex flex-col h-full w-full relative">
      <div className="mb-4">
        <div className="flex justify-between items-start">
          <h3 className="text-lg font-bold text-slate-100 font-heading pr-2">{title}</h3>
          <div className="flex items-center gap-2">
            {aggregation && (
              <span className="text-[10px] uppercase font-bold px-2 py-1 rounded bg-slate-800 border border-slate-700 text-slate-400">
                Agg: {aggregation}
              </span>
            )}
            <button 
              onClick={handleHelpClick}
              className="text-slate-400 hover:text-indigo-400 transition-colors p-1"
              title="Explicação da IA"
            >
              <HelpCircle className="w-5 h-5" />
            </button>
          </div>
        </div>
        <p className="text-sm text-slate-400 mt-1">{description}</p>
      </div>
      
      <div className="flex-1 min-h-[300px] flex items-end gap-2 w-full">
        <ResponsiveContainer width="100%" height="100%">
          {renderChart()}
        </ResponsiveContainer>
      </div>

      {modalState !== 'closed' && (
        <div className={
          modalState === 'live' 
            ? "fixed bottom-6 right-6 z-50 pointer-events-none" 
            : "fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4"
        }>
          <div className={
            modalState === 'live'
              ? "bg-slate-800 rounded-xl shadow-2xl border border-indigo-500/40 p-4 w-[320px] pointer-events-auto"
              : "bg-slate-800 rounded-xl shadow-2xl border border-slate-700 p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto"
          }>
            {modalState !== 'live' && (
              <div className="flex justify-between items-start mb-4">
                <h4 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                  <HelpCircle className="w-5 h-5 text-indigo-400" />
                  Explicação Inteligente
                </h4>
                <div className="flex items-center gap-2">
                  {modalState === 'view' && (
                    <button 
                      onClick={() => setModalState('live')}
                      className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600/20 text-indigo-300 hover:text-indigo-200 hover:bg-indigo-600/30 rounded-lg text-sm font-medium transition-colors border border-indigo-500/30 mr-2"
                    >
                      <Mic className="w-4 h-4" /> Conversar com IA
                    </button>
                  )}
                  <button 
                    onClick={() => setModalState('closed')} 
                    className="text-slate-400 hover:text-slate-200 transition-colors"
                  >
                    <X className="w-5 h-5"/>
                  </button>
                </div>
              </div>
            )}

            {modalState === 'live' && (
              <div className="flex justify-between items-center mb-2">
                <h4 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                  <Mic className="w-4 h-4 text-indigo-400" />
                  Conversar com IA
                </h4>
                <button 
                  onClick={() => setModalState('view')} 
                  className="text-slate-400 hover:text-slate-200 transition-colors p-1"
                >
                  <X className="w-4 h-4"/>
                </button>
              </div>
            )}
            
            {modalState === 'ask' && (
              <div className="space-y-4">
                <p className="text-slate-300 text-sm leading-relaxed">
                  Deseja que a nossa IA analise e explique o que este gráfico está mostrando? 
                  <br/><br/>
                  <span className="text-slate-400 text-xs">
                    (Nenhum dado sensível bruto será enviado ao servidor, enviaremos apenas as métricas de agregação, máximos e mínimos para contextualizar os limites do gráfico.)
                  </span>
                </p>
                <div className="flex justify-end gap-3 pt-2">
                  <button 
                    onClick={() => setModalState('closed')} 
                    className="px-4 py-2 text-sm text-slate-300 hover:bg-slate-700 rounded-lg transition-colors border border-slate-600"
                  >
                    Cancelar
                  </button>
                  <button 
                    onClick={fetchExplanation} 
                    className="px-4 py-2 text-sm text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium shadow-sm transition-colors"
                  >
                    Gerar Explicação
                  </button>
                </div>
              </div>
            )}

            {modalState === 'loading' && (
              <div className="flex flex-col items-center justify-center py-8">
                <Loader2 className="w-8 h-8 text-indigo-500 animate-spin mb-4" />
                <p className="text-slate-400 text-sm">Analisando estatísticas e formulando insights...</p>
              </div>
            )}

            {modalState === 'view' && explanation && (
              <div className="space-y-4">
                <div className="markdown-body prose prose-invert prose-slate prose-sm text-slate-200 whitespace-pre-wrap max-w-none">
                  <ReactMarkdown>{explanation}</ReactMarkdown>
                </div>
                <div className="flex items-center justify-between pt-4 border-t border-slate-700">
                  <button 
                    onClick={() => setModalState('live')}
                    className="flex items-center gap-2 px-4 py-2 text-sm text-indigo-300 bg-indigo-600/10 hover:bg-indigo-600/20 rounded-lg font-medium transition-colors border border-indigo-500/20"
                  >
                    <Mic className="w-4 h-4" /> Quer aprofundar? Converse com a IA
                  </button>
                  <button 
                    onClick={() => setModalState('closed')} 
                    className="px-4 py-2 text-sm text-white bg-slate-700 hover:bg-slate-600 rounded-lg font-medium transition-colors"
                  >
                    Fechar
                  </button>
                </div>
              </div>
            )}

            {modalState === 'live' && explanation && (
               <LiveAudioChat 
                 contextText={explanation}
                 onClose={() => setModalState('view')}
               />
            )}
          </div>
        </div>
      )}
    </div>
  );
}
