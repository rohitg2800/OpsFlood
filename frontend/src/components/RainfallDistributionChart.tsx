import React from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import { useAppState } from '../context/AppContext';

export function RainfallDistributionChart() {
  const { state } = useAppState();

  const data = state.form.rainfallDistribution || [];

  if (data.length === 0) {
    return (
      <div className="w-full h-80 flex items-center justify-center bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl">
        <p className="text-slate-500 font-bold">No rainfall data available</p>
      </div>
    );
  }

  return (
    <div className="w-full bg-black/25 p-6 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl">
      <h3 className="text-lg font-black text-white mb-4 tracking-tight">
        7-Day Rainfall Distribution
      </h3>

      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white/5 border border-white/10 p-4 rounded-2xl">
          <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black">Total Rainfall</p>
          <p className="text-2xl font-black text-teal-200 font-mono">
            {state.form.rainfallTotal.toFixed(1)}
            <span className="text-sm text-slate-400 ml-1">mm</span>
          </p>
        </div>
        <div className="bg-white/5 border border-white/10 p-4 rounded-2xl">
          <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black">Daily Average</p>
          <p className="text-2xl font-black text-slate-200 font-mono">
            {state.form.rainfallAverage.toFixed(1)}
            <span className="text-sm text-slate-400 ml-1">mm</span>
          </p>
        </div>
        <div className="bg-white/5 border border-white/10 p-4 rounded-2xl">
          <p className="text-[10px] uppercase tracking-widest text-slate-500 font-black">Trend</p>
          <p className="text-2xl font-black text-[#ff0037]">
            {state.form.rainfallTotal > 600 ? '⚠️ High' : '✓ Normal'}
          </p>
        </div>
      </div>

      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.10)" />
          <XAxis dataKey="day" tick={{ fill: '#94a3b8', fontSize: 10 }} axisLine={{ stroke: 'rgba(255,255,255,0.12)' }} tickLine={false} />
          <YAxis tick={{ fill: '#94a3b8', fontSize: 10 }} axisLine={{ stroke: 'rgba(255,255,255,0.12)' }} tickLine={false} />
          <Tooltip
            formatter={(value) => `${typeof value === 'number' ? value.toFixed(1) : value} mm`}
            labelFormatter={(label) => `Day ${label}`}
            contentStyle={{ backgroundColor: '#0b0a10', border: '1px solid rgba(255,255,255,0.10)', borderRadius: '14px', color: '#e2e8f0' }}
          />
          <Bar dataKey="mm" fill="#f59e0b" name="Rainfall" radius={[10, 10, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>

      <div className="mt-6 p-5 bg-white/5 border border-white/10 rounded-2xl">
        <h4 className="text-sm font-black text-slate-200 mb-2">Rainfall Category</h4>
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded-full bg-green-500"></div>
          <p className="text-sm text-slate-300 font-bold">
            {state.form.rainfallTotal < 300
              ? 'Low (Normal Conditions)'
              : state.form.rainfallTotal < 450
              ? 'Moderate (Caution)'
              : state.form.rainfallTotal < 600
              ? 'High (Alert)'
              : 'Critical (Emergency)'}
          </p>
        </div>
      </div>
    </div>
  );
}
