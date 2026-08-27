import React, { useCallback, useRef, useState } from 'react';
import { UploadCloud, FileSpreadsheet, Loader2 } from 'lucide-react';

interface UploaderProps {
  onFileSelect: (file: File) => void;
  isLoading: boolean;
}

export function Uploader({ onFileSelect, isLoading }: UploaderProps) {
  const [isDragActive, setIsDragActive] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setIsDragActive(true);
    } else if (e.type === 'dragleave') {
      setIsDragActive(false);
    }
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      onFileSelect(e.dataTransfer.files[0]);
    }
  }, [onFileSelect]);

  const handleChange = function(e: React.ChangeEvent<HTMLInputElement>) {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      onFileSelect(e.target.files[0]);
    }
  };

  const onButtonClick = () => {
    inputRef.current?.click();
  };

  return (
    <div
      className={`relative rounded-2xl border-2 border-dashed p-12 text-center flex flex-col items-center justify-center transition-all ${
        isDragActive 
          ? 'border-indigo-500 bg-indigo-500/10' 
          : 'border-slate-700 bg-slate-800/50 hover:bg-slate-800 hover:border-slate-600 shadow-sm'
      }`}
      onDragEnter={handleDrag}
      onDragLeave={handleDrag}
      onDragOver={handleDrag}
      onDrop={handleDrop}
    >
      <input
        ref={inputRef}
        type="file"
        accept=".csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/vnd.ms-excel"
        className="hidden"
        onChange={handleChange}
        disabled={isLoading}
      />

      <div className="bg-slate-700/50 p-4 rounded-full mb-4 border border-slate-600">
        {isLoading ? (
          <Loader2 className="w-8 h-8 text-indigo-400 animate-spin" />
        ) : (
          <FileSpreadsheet className="w-8 h-8 text-indigo-400" />
        )}
      </div>

      <h3 className="text-xl font-bold mb-2 text-slate-100 font-heading">
        {isLoading ? 'Analisando Dados...' : 'Faça Upload do Arquivo CSV'}
      </h3>
      
      <p className="text-slate-400 mb-6 max-w-sm text-sm">
        {isLoading 
          ? 'Analisando sua estrutura de dados...' 
          : 'Arraste seu arquivo CSV primário para iniciar a configuração.'}
      </p>

      {!isLoading && (
        <button
          onClick={onButtonClick}
          className="px-6 py-2.5 bg-indigo-600 text-white font-medium text-sm border-none rounded-md hover:bg-indigo-700 transition-colors flex items-center gap-2 shadow-sm"
        >
          <UploadCloud className="w-4 h-4" />
          Selecionar Arquivo
        </button>
      )}
    </div>
  );
}
