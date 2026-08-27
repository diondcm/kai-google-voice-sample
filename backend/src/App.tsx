import React, { useState, useCallback, useMemo, useEffect } from 'react';
import Papa from 'papaparse';
import { Uploader } from './components/Uploader';
import { Configurator } from './components/Configurator';
import { ChartRenderer } from './components/ChartRenderer';
import { Auth } from './components/Auth';
import { TabConfig, DashboardState } from './types';
import { LayoutDashboard, AlertCircle, RefreshCw, Printer, Download, Sun, Moon } from 'lucide-react';

function aggregateData(data: any[], dimension: string, metrics: string[], aggType: string) {
  const groups: Record<string, any> = {};
  for (const row of data) {
    const key = String(row[dimension] || 'Desconhecido');
    if (!groups[key]) {
      groups[key] = { [dimension]: key, _count: 0 };
      for (const m of metrics) groups[key][m] = 0;
    }
    groups[key]._count += 1;
    for (const m of metrics) {
      const val = Number(row[m]) || 0;
      if (aggType === 'sum' || aggType === 'average') groups[key][m] += val;
      else if (aggType === 'min') groups[key][m] = groups[key]._count === 1 ? val : Math.min(groups[key][m], val);
      else if (aggType === 'max') groups[key][m] = groups[key]._count === 1 ? val : Math.max(groups[key][m], val);
    }
  }

  let result = Object.values(groups);
  if (aggType === 'average') {
    result = result.map(g => {
      const out = { ...g };
      for (const m of metrics) out[m] = Number((out[m] / out._count).toFixed(2));
      return out;
    });
  } else if (aggType === 'count') {
    result = result.map(g => {
      const out = { ...g };
      for (const m of metrics) out[m] = out._count;
      return out;
    });
  }
  return result;
}

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return localStorage.getItem('datalens_auth') === 'true';
  });

  const [theme, setTheme] = useState<'dark' | 'light'>('dark');

  // Apply theme class to document element
  useEffect(() => {
    if (theme === 'light') {
      document.documentElement.classList.add('light-mode');
    } else {
      document.documentElement.classList.remove('light-mode');
    }
  }, [theme]);

  const [state, setState] = useState<DashboardState>({
    file: null,
    data: [],
    headers: [],
    tabs: [],
    activeTab: null,
    selectedDimensions: [],
    selectedMetrics: [],
    status: 'idle',
  });

  if (!isAuthenticated) {
    return <Auth onAuthenticated={() => setIsAuthenticated(true)} />;
  }

  const generateDashboard = async (dimensions: string[], metrics: string[]) => {
    try {
      setState(prev => ({ 
        ...prev, 
        selectedDimensions: dimensions, 
        selectedMetrics: metrics, 
        status: 'analyzing' 
      }));
      
      const sampleData = state.data.slice(0, 5);
      
      const response = await fetch('/api/analyze-csv', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ columns: state.headers, sampleData, dimensions, metrics, theme }),
      });
      
      if (!response.ok) {
        throw new Error('Failed to generate dashboard');
      }
      
      const result = await response.json();
      
      setState(prev => ({
        ...prev,
        tabs: result.tabs,
        activeTab: result.tabs[0]?.dimension || null,
        selectedDimensions: result.suggestedDimensions || dimensions,
        selectedMetrics: result.suggestedMetrics || metrics,
        status: 'success'
      }));
    } catch (err: any) {
      console.error(err);
      setState(prev => ({
        ...prev,
        status: 'error',
        errorMessage: err.message || 'An error occurred.'
      }));
    }
  };

  const handleFileSelect = useCallback((file: File) => {
    setState(prev => ({ ...prev, file, status: 'parsing', errorMessage: undefined }));
    
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      dynamicTyping: true,
      complete: (results) => {
        if (results.errors.length > 0 && results.data.length === 0) {
          setState(prev => ({
            ...prev,
            status: 'error',
            errorMessage: 'Failed to parse CSV file.'
          }));
          return;
        }
        setState(prev => ({ 
          ...prev, 
          data: results.data, 
          headers: results.meta.fields || [],
          status: 'configuring' 
        }));
      },
      error: (error) => {
         setState(prev => ({
            ...prev,
            status: 'error',
            errorMessage: error.message
          }));
      }
    });
  }, []);

  const resetDashboard = () => {
    setState({
      file: null,
      data: [],
      headers: [],
      tabs: [],
      activeTab: null,
      selectedDimensions: [],
      selectedMetrics: [],
      status: 'idle',
    });
  };

  const activeTabData = state.tabs.find(t => t.dimension === state.activeTab);

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 font-sans flex flex-col print:bg-white print:text-black">
      <header className="h-16 px-8 border-b border-slate-700/50 bg-slate-900 flex items-center justify-between shrink-0 sticky top-0 z-10 w-full print:hidden">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center shadow-inner">
            <LayoutDashboard className="w-5 h-5 text-white" />
          </div>
          <h1 className="text-xl font-bold tracking-tight text-white font-heading">CSView</h1>
        </div>
        
        {state.file && (
          <div className="flex items-center gap-2 sm:gap-4">
            <span className="text-sm text-slate-400 truncate max-w-[150px] hidden md:block" title={state.file.name}>
              {state.file.name}
            </span>
            
            <div className="flex items-center gap-2 border-r border-slate-700/50 pr-2 sm:pr-4">
              <button 
                onClick={() => window.print()}
                className="text-xs font-medium text-slate-300 hover:text-white flex items-center gap-1.5 transition-colors px-3 py-1.5 rounded bg-slate-800 hover:bg-slate-700 border border-slate-700/50 shadow-sm"
              >
                <Printer className="w-3.5 h-3.5" /> <span className="hidden sm:inline">Imprimir</span>
              </button>
              <button 
                onClick={() => window.print()}
                className="text-xs font-medium text-slate-300 hover:text-white flex items-center gap-1.5 transition-colors px-3 py-1.5 rounded bg-slate-800 hover:bg-slate-700 border border-slate-700/50 shadow-sm"
              >
                <Download className="w-3.5 h-3.5" /> <span className="hidden sm:inline">PDF</span>
              </button>
              <button 
                onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
                className="text-xs font-medium transition-colors px-3 py-1.5 rounded bg-slate-800 hover:bg-slate-700 border border-slate-700/50 shadow-sm flex items-center gap-1.5 text-slate-300 hover:text-amber-400"
                title="Trocar tema"
              >
                {theme === 'dark' ? <Sun className="w-3.5 h-3.5" /> : <Moon className="w-3.5 h-3.5 text-indigo-400" />}
              </button>
            </div>

            <button 
              onClick={resetDashboard}
              className="text-sm font-medium text-indigo-300 hover:text-indigo-200 flex items-center gap-2 transition-colors px-3 py-1.5 rounded bg-indigo-900/30 hover:bg-indigo-900/50 border border-indigo-500/30"
            >
              <RefreshCw className="w-4 h-4" /> Nova Importação
            </button>
          </div>
        )}
      </header>

      <main className="flex-1 w-full max-w-7xl mx-auto p-4 sm:p-6 overflow-x-hidden">
        {state.status === 'idle' || state.status === 'parsing' ? (
          <div className="max-w-xl mx-auto mt-[10vh] animate-in fade-in zoom-in-95 duration-500">
            <Uploader 
              onFileSelect={handleFileSelect} 
              isLoading={state.status === 'parsing'} 
            />
          </div>
        ) : null}

        {state.status === 'configuring' && (
          <div className="mt-[5vh] animate-in slide-in-from-bottom-4 duration-500">
            <Configurator 
              headers={state.headers} 
              data={state.data} 
              onConfirm={generateDashboard} 
            />
          </div>
        )}

        {state.status === 'analyzing' && (
          <div className="flex flex-col items-center justify-center mt-[15vh] animate-in fade-in">
            <div className="w-16 h-16 mb-6 rounded-full border-4 border-indigo-500/20 border-t-indigo-500 animate-spin"></div>
            <h2 className="text-2xl font-bold text-white mb-2">Estruturando Insights...</h2>
            <p className="text-slate-400">Analisando suas seleções e desenhando os melhores gráficos</p>
          </div>
        )}

        {state.status === 'error' && (
           <div className="max-w-xl mx-auto mt-12 w-full p-4 rounded-xl bg-red-900/20 border border-red-500/30 flex items-start gap-4">
             <AlertCircle className="w-6 h-6 text-red-400 flex-shrink-0 mt-0.5" />
             <div>
               <h3 className="font-semibold text-red-300">Erro na Análise</h3>
               <p className="text-red-400/80 text-sm mt-1">{state.errorMessage}</p>
             </div>
           </div>
        )}

        {state.status === 'success' && activeTabData && (
          <div className="animate-in fade-in slide-in-from-bottom-4 duration-700 w-full mb-12">
            
            {/* Executive Dashboard Area */}
            <div className="w-full bg-gradient-to-br from-slate-800 to-slate-900 border border-slate-700/50 rounded-2xl p-5 mb-6 shadow-xl relative overflow-hidden">
              <div className="absolute top-0 left-0 w-1 h-full bg-gradient-to-b from-indigo-500 to-transparent opacity-50"></div>
              
              <div className="flex justify-between items-center mb-6 pb-4 border-b border-slate-700/50">
                <h2 className="text-2xl font-bold text-white font-heading">Painel Executivo</h2>
                <span className="group-badge model px-3 py-1">Dimensões Selecionadas: {state.selectedDimensions.length}</span>
              </div>
              
              {/* Dynamic Tabs */}
              <div className="nav-tabs mb-6 flex flex-wrap gap-3 pb-4 pt-2 print:hidden border-b border-slate-700/50">
                {state.tabs.map(tab => (
                  <button 
                    key={tab.dimension}
                    onClick={() => setState(prev => ({ ...prev, activeTab: tab.dimension }))}
                    className={`tab-btn flex-shrink-0 flex items-center gap-2 ${state.activeTab === tab.dimension ? 'active' : ''}`}
                  >
                    <span className="opacity-70 text-[10px] uppercase font-bold tracking-wider">Visão</span>
                    <span className="text-sm font-bold">{tab.dimension}</span>
                  </button>
                ))}
              </div>

              {/* Stat Cards */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="stat-card">
                  <span className="label">Total de Registros</span>
                  <span className="value text-indigo-400">{state.data.length}</span>
                  <span className="text-[11px] text-slate-500 mt-1">Linhas processadas</span>
                </div>
                <div className="stat-card">
                  <span className="label">Categorias Únicas ({activeTabData.dimension})</span>
                  <span className="value text-teal-400">
                    {new Set(state.data.map(d => d[activeTabData.dimension])).size}
                  </span>
                  <span className="text-[11px] text-slate-500 mt-1">Nesta visão de dados</span>
                </div>
                <div className="stat-card border-none bg-indigo-900/30">
                  <span className="label text-indigo-300">Resumo</span>
                  <p className="text-sm text-slate-300 mt-2 leading-relaxed">{activeTabData.summaryText}</p>
                </div>
              </div>
            </div>
             
            {/* Charts Grid */}
            <div className="grid grid-cols-12 gap-6">
               {activeTabData.charts.map((chart, index) => {
                 const colSpan = index === 0 ? "col-span-12 lg:col-span-8" : "col-span-12 lg:col-span-4";
                 
                 // Perform Aggregation Locally before passing to ChartRenderer
                 // Optimization: we could useMemo this, but for < 10k rows it's instantly fast.
                 const chartData = aggregateData(state.data, activeTabData.dimension, chart.yAxis, chart.aggregation);
                 
                 return (
                   <div key={`${state.activeTab}-${index}`} className={`${colSpan} card flex flex-col min-h-[420px]`}>
                     <ChartRenderer config={chart} data={chartData} />
                   </div>
                 );
               })}
            </div>

            {/* Dynamic aggregated Data Table */}
            <div className="w-full mt-6 card p-0 overflow-hidden">
               <div className="px-5 py-4 border-b border-slate-700/60 bg-slate-800/50 flex justify-between items-center">
                 <h3 className="text-sm font-bold text-slate-200">Tabela Consolidada ({activeTabData.dimension})</h3>
                 <span className="text-[10px] text-slate-400 uppercase tracking-widest">Base de Dados</span>
               </div>
               <div className="table-container max-h-[400px]">
                 <table className="custom-table">
                   <thead>
                     <tr>
                       <th>{activeTabData.dimension}</th>
                       <th>Registros (Count)</th>
                       {state.selectedMetrics.map(m => <th key={m}>{m}</th>)}
                     </tr>
                   </thead>
                   <tbody>
                     {aggregateData(state.data, activeTabData.dimension, state.selectedMetrics, 'sum').map((row, idx) => (
                       <tr key={idx}>
                         <td className="font-medium text-slate-200">{row[activeTabData.dimension]}</td>
                         <td>{row._count}</td>
                         {state.selectedMetrics.map(m => (
                           <td key={m} className="font-mono text-xs">{typeof row[m] === 'number' ? Number(row[m]).toLocaleString() : row[m]}</td>
                         ))}
                       </tr>
                     ))}
                   </tbody>
                 </table>
               </div>
            </div>

          </div>
        )}
      </main>
    </div>
  );
}
