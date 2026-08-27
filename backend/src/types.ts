export interface ChartConfig {
  type: string;
  xAxis: string;
  yAxis: string[];
  title: string;
  description: string;
  aggregation: 'sum' | 'average' | 'count' | 'min' | 'max';
}

export interface TabConfig {
  dimension: string;
  title: string;
  summaryText: string;
  charts: ChartConfig[];
}

export interface DashboardState {
  file: File | null;
  data: any[];
  headers: string[];
  tabs: TabConfig[];
  activeTab: string | null;
  selectedDimensions: string[];
  selectedMetrics: string[];
  status: 'idle' | 'parsing' | 'configuring' | 'analyzing' | 'success' | 'error';
  errorMessage?: string;
}
