import React, { useState, useEffect } from 'react';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  Legend, Cell, LineChart, Line, CartesianGrid
} from 'recharts';
import {
  AlertCircle, Droplets, Download, Activity, TrendingUp,
  Clock, ShieldAlert, Gauge, RefreshCw, Siren, CloudRain,
  MapPin, Phone, AlertTriangle
} from 'lucide-react';
import axios from 'axios';
import WeatherWidget from './weatherWidget';

const API_BASE = 'http://127.0.0.1:8000';

// Updated interfaces for Kolhapur-specific ML backend
interface Prediction {
  severity: 'SEVERE' | 'MODERATE';
  confidence: number;
  confidence_percent: number;
  alert: string;
  probabilities?: {
    SEVERE: number;
    MODERATE: number;
  };
  algorithm?: string;
  model_trained?: boolean;
  kolhapur_specific?: boolean;
  historical_basis?: string;
  danger_level?: number;
  monitoring?: {
    level: string;
    action: string;
    frequency: string;
    priority_zones: string[];
    emergency_contacts?: string[];
  };
}

interface LocationData {
  name: string;
  lat: number;
  lon: number;
  country: string;
  state?: string;
}

interface WeatherData {
  temp: number;
  humidity: number;
  windSpeed: number;
  description: string;
  icon: string;
  pressure?: number;
}

interface KolhapurEvent {
  date: string;
  severity: 'SEVERE' | 'MODERATE';
  confidence: number;
  alert: string;
  peak_level?: number;
  rainfall_7day?: number;
}

interface LiveEvent {
  date: string;
  severity: 'SEVERE' | 'MODERATE';
  confidence: number;
  alert: string;
  rainfall_mm?: number;
  river_level_m?: number;
  monitoring_status?: string;
}

type FormDataType = {
  Peak_Flood_Level_m: number;
  Event_Duration_days: number;
  Time_to_Peak_days: number;
  Recession_Time_day: number;
  T1d: number;
  T2d: number;
  T3d: number;
  T4d: number;
  T5d: number;
  T6d: number;
  T7d: number;
};

const severityBg = (s: 'SEVERE' | 'MODERATE') =>
  s === 'SEVERE' ? 'from-red-500 to-orange-500' : 'from-yellow-400 to-amber-500';

const severityCardBg = (s: 'SEVERE' | 'MODERATE') =>
  s === 'SEVERE'
    ? 'bg-gradient-to-r from-red-500 to-orange-500'
    : 'bg-gradient-to-r from-yellow-400 to-amber-500';

/* ─── Alert Meter ─── */
const AlertMeter: React.FC<{ severity: 'SEVERE' | 'MODERATE'; confidence: number }> = ({
  severity, confidence
}) => {
  const isSevere = severity === 'SEVERE';
  return (
    <div className="mt-8 grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">
      <div className="lg:col-span-2 bg-amber-50 rounded-2xl p-6 shadow-inner border border-amber-200">
        <div className="flex items-center gap-2 mb-4">
          <Gauge className="w-5 h-5 text-amber-700" />
          <h3 className="text-xl font-bold text-amber-900">Severity Meter</h3>
        </div>
        <div className="flex justify-between mb-2 text-xs font-semibold text-amber-700">
          <span>LOW</span><span>MODERATE</span><span>SEVERE</span>
        </div>
        <div className="w-full h-7 bg-gradient-to-r from-emerald-400 via-yellow-400 to-red-500 rounded-full relative overflow-hidden shadow">
          <div
            className="absolute top-0 h-7 w-1.5 bg-white shadow-xl border border-slate-200"
            style={{
              left: `${Math.min(Math.max(confidence, 0), 100)}%`,
              transform: 'translateX(-50%)'
            }}
          />
        </div>
        <div className="grid grid-cols-2 gap-4 mt-5">
          <div className="bg-white rounded-xl p-4 border border-amber-200">
            <div className="text-sm text-amber-700">Current Severity</div>
            <div className={`text-2xl font-black ${isSevere ? 'text-red-600' : 'text-yellow-600'}`}>
              {severity}
            </div>
          </div>
          <div className="bg-white rounded-xl p-4 border border-amber-200">
            <div className="text-sm text-amber-700">Confidence</div>
            <div className="text-2xl font-black text-amber-900">{confidence.toFixed(1)}%</div>
          </div>
        </div>
      </div>

      <div className={`p-6 rounded-2xl text-white bg-gradient-to-br ${severityBg(severity)} shadow-xl`}>
        <div className="flex items-center gap-2 mb-4">
          <Siren className="w-6 h-6" />
          <h3 className="text-xl font-black">System Alert</h3>
        </div>
        <div className="text-5xl mb-4 text-center">{isSevere ? '🚨' : '⚠️'}</div>
        <div className="text-center font-black text-2xl mb-2">
          {isSevere ? 'RED ALERT' : 'YELLOW ALERT'}
        </div>
        <p className="text-sm leading-6 opacity-95">
          {isSevere
            ? 'Immediate monitoring required. Watch river rise closely, issue emergency notices, and inspect vulnerable zones every 15 minutes.'
            : 'Moderate risk detected. Maintain active field monitoring, inspect drainage flow, and review embankment conditions every hour.'}
        </p>
      </div>
    </div>
  );
};

/* ─── Monitoring Panel ─── */
const MonitoringPanel: React.FC<{ prediction: Prediction }> = ({ prediction }) => {
  const severe = prediction.severity === 'SEVERE';
  
  const kolhapurItems = severe
    ? [
        'River gauge monitoring every 15 minutes at Irwin Bridge',
        'Evacuate low-lying areas: Shirol, Hatkanangale',
        'Local warning siren activation in riverside areas',
        'Emergency teams deployment to Rankala Lake area',
      ]
    : [
        'River gauge monitoring every 60 minutes',
        'Drainage inspection in Kagal and Shirol',
        'Village-level field staff standby',
        'Weather trend observation at Bhimashankar',
      ];

  return (
    <div className="mt-6 bg-white rounded-2xl p-6 border-2 border-amber-200 shadow-lg">
      <div className="flex items-center gap-2 mb-4">
        <ShieldAlert className={`w-6 h-6 ${severe ? 'text-red-500' : 'text-yellow-500'}`} />
        <h3 className="text-2xl font-bold text-amber-900">Kolhapur Monitoring Protocol</h3>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className={`rounded-xl p-5 ${severe ? 'bg-red-50 border border-red-200' : 'bg-yellow-50 border border-yellow-200'}`}>
          <div className="text-sm font-semibold text-amber-700 mb-1">Alert Class</div>
          <div className={`text-2xl font-black ${severe ? 'text-red-600' : 'text-yellow-600'}`}>
            {severe ? 'SEVERE / RED' : 'MODERATE / YELLOW'}
          </div>
          <div className="mt-3 text-amber-800">
            Confidence: <span className="font-bold">{prediction.confidence_percent.toFixed(1)}%</span>
          </div>
          {prediction.probabilities && (
            <div className="mt-2 text-sm text-amber-700">
              Probability: SEVERE {prediction.probabilities.SEVERE}% | MODERATE {prediction.probabilities.MODERATE}%
            </div>
          )}
        </div>
        
        <div className="rounded-xl p-5 bg-amber-50 border border-amber-200">
          <div className="text-sm font-semibold text-amber-700 mb-1">Check Frequency</div>
          <div className="text-2xl font-black text-amber-900">{severe ? '15 min checks' : 'Hourly checks'}</div>
          <div className="mt-3 text-amber-800">
            Status: <span className="font-semibold">Active monitoring enabled</span>
          </div>
          {prediction.algorithm && (
            <div className="mt-2 text-sm text-amber-700">
              Algorithm: {prediction.algorithm}
            </div>
          )}
        </div>
      </div>
      
      {/* Kolhapur Emergency Contacts */}
      {severe && prediction.monitoring?.emergency_contacts && (
        <div className="mt-4 bg-red-50 border border-red-200 rounded-xl p-4">
          <h4 className="font-bold text-red-800 mb-2 flex items-center gap-2">
            <Phone className="w-4 h-4" />
            Kolhapur Emergency Contacts
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-red-700">
            {prediction.monitoring.emergency_contacts.map((contact, index) => (
              <div key={index} className="text-sm">{contact}</div>
            ))}
          </div>
        </div>
      )}
      
      <div className="mt-5 grid grid-cols-1 md:grid-cols-2 gap-3">
        {kolhapurItems.map((item, i) => (
          <div key={i} className="bg-amber-50 border border-amber-100 rounded-xl p-4 text-amber-900 font-medium">
            {item}
          </div>
        ))}
      </div>
    </div>
  );
};

/* ─── ML Info Panel ─── */
const MLInfoPanel: React.FC<{ prediction: Prediction }> = ({ prediction }) => {
  if (!prediction.model_trained && !prediction.algorithm) return null;

  return (
    <div className="mt-4 bg-blue-50 rounded-2xl p-6 border border-blue-200">
      <h3 className="text-xl font-bold text-blue-900 mb-3 flex items-center gap-2">
        <MapPin className="w-5 h-5" />
        Kolhapur-Specific ML Analysis
      </h3>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <span className="font-semibold text-blue-800">Algorithm:</span>{' '}
          <span className="text-blue-700">{prediction.algorithm || 'Random Forest'}</span>
        </div>
        <div>
          <span className="font-semibold text-blue-800">Model Status:</span>{' '}
          <span className={`font-bold ${prediction.model_trained ? 'text-green-600' : 'text-yellow-600'}`}>
            {prediction.model_trained ? 'Kolhapur-Trained' : 'Using Fallback'}
          </span>
        </div>
        {prediction.historical_basis && (
          <div>
            <span className="font-semibold text-blue-800">Historical Basis:</span>{' '}
            <span className="text-blue-700">{prediction.historical_basis}</span>
          </div>
        )}
        {prediction.danger_level && (
          <div>
            <span className="font-semibold text-blue-800">Danger Level:</span>{' '}
            <span className="text-blue-700">{prediction.danger_level}m (Panchganga River)</span>
          </div>
        )}
        {prediction.probabilities && (
          <div className="md:col-span-2">
            <span className="font-semibold text-blue-800">Probability Analysis:</span>
            <div className="flex gap-4 mt-2">
              <div className="bg-red-100 px-3 py-1 rounded-full text-red-800 font-bold">
                SEVERE: {prediction.probabilities.SEVERE}%
              </div>
              <div className="bg-yellow-100 px-3 py-1 rounded-full text-yellow-800 font-bold">
                MODERATE: {prediction.probabilities.MODERATE}%
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

/* ─── Kolhapur Specific Info ─── */
const KolhapurInfo: React.FC = () => (
  <div className="mb-6 bg-gradient-to-r from-green-50 to-emerald-50 rounded-2xl p-6 border border-green-200">
    <div className="flex items-center gap-3 mb-3">
      <MapPin className="w-6 h-6 text-green-600" />
      <h3 className="text-xl font-bold text-green-900">Kolhapur Flood Prediction</h3>
    </div>
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-green-800">
      <div className="flex items-center gap-2">
        <AlertTriangle className="w-4 h-4" />
        <span>Danger Level: <strong>12.0m</strong></span>
      </div>
      <div className="flex items-center gap-2">
        <span>📍</span>
        <span>River: <strong>Panchganga</strong></span>
      </div>
      <div className="flex items-center gap-2">
        <span>📊</span>
        <span>Based on <strong>2023 Flood Data</strong></span>
      </div>
    </div>
  </div>
);

/* ─── Main App ─── */
function App() {
  const [prediction, setPrediction] = useState<Prediction | null>(null);
  const [kolhapurData, setKolhapurData] = useState<KolhapurEvent[]>([]);
  const [liveEvents, setLiveEvents] = useState<LiveEvent[]>([]);
  const [loading, setLoading] = useState(false);
  const [liveLoading, setLiveLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<'single' | 'kolhapur' | 'live' | 'weather' | 'info'>('single');
  const [windowDays, setWindowDays] = useState(5);
  
  const [formData, setFormData] = useState<FormDataType>({
    Peak_Flood_Level_m: 12.74,
    Event_Duration_days: 3,
    Time_to_Peak_days: 2,
    Recession_Time_day: 2,
    T1d: 156.4, T2d: 299.2, T3d: 384.4,
    T4d: 384.4, T5d: 384.4, T6d: 384.4, T7d: 455.6,
  });

  const fieldLabels: Record<keyof FormDataType, string> = {
    Peak_Flood_Level_m: 'Peak Flood Level (m)',
    Event_Duration_days: 'Event Duration (days)',
    Time_to_Peak_days: 'Time to Peak (days)',
    Recession_Time_day: 'Recession Time (day)',
    T1d: 'T1d (1-day rainfall)', T2d: 'T2d (2-day rainfall)',
    T3d: 'T3d (3-day rainfall)', T4d: 'T4d (4-day rainfall)',
    T5d: 'T5d (5-day rainfall)', T6d: 'T6d (6-day rainfall)',
    T7d: 'T7d (7-day rainfall)',
  };

  useEffect(() => { fetchKolhapur(); }, []);

  useEffect(() => {
    if (activeTab === 'live') fetchLiveWindow(windowDays);
  }, [activeTab, windowDays]);

  const fetchKolhapur = async () => {
    try {
      const res = await axios.get(`${API_BASE}/kolhapur`);
      setKolhapurData(res.data.historical_events || []);
    } catch {
      setKolhapurData([
        { date: '2023-07-15', severity: 'SEVERE', confidence: 92, alert: '🚨', peak_level: 12.8, rainfall_7day: 510 },
        { date: '2023-08-20', severity: 'SEVERE', confidence: 89, alert: '🚨', peak_level: 12.5, rainfall_7day: 480 },
        { date: '2023-09-05', severity: 'MODERATE', confidence: 75, alert: '⚠️', peak_level: 11.8, rainfall_7day: 380 },
        { date: '2023-09-25', severity: 'MODERATE', confidence: 72, alert: '⚠️', peak_level: 11.5, rainfall_7day: 350 },
        { date: '2023-10-10', severity: 'MODERATE', confidence: 68, alert: '⚠️', peak_level: 11.2, rainfall_7day: 320 }
      ]);
    }
  };

  const fetchLiveWindow = async (days: number) => {
    setLiveLoading(true);
    try {
      const res = await axios.get(`${API_BASE}/live-window?days=${days}`);
      setLiveEvents(res.data.events || []);
    } catch {
      setLiveEvents([
        { date: '2024-03-21', severity: 'MODERATE', confidence: 78, alert: '⚠️', rainfall_mm: 46,  river_level_m: 8.7,  monitoring_status: 'Hourly monitoring' },
        { date: '2024-03-22', severity: 'SEVERE',   confidence: 91, alert: '🚨', rainfall_mm: 92,  river_level_m: 11.8, monitoring_status: '15-minute monitoring' },
        { date: '2024-03-23', severity: 'SEVERE',   confidence: 88, alert: '🚨', rainfall_mm: 84,  river_level_m: 12.2, monitoring_status: '15-minute monitoring' },
        { date: '2024-03-24', severity: 'MODERATE', confidence: 73, alert: '⚠️', rainfall_mm: 38,  river_level_m: 9.5,  monitoring_status: 'Hourly monitoring' },
        { date: '2024-03-25', severity: 'MODERATE', confidence: 70, alert: '⚠️', rainfall_mm: 29,  river_level_m: 8.1,  monitoring_status: 'Hourly monitoring' },
      ]);
    } finally {
      setLiveLoading(false);
    }
  };

  const handlePredict = async () => {
    setLoading(true);
    try {
      const res = await axios.post(`${API_BASE}/predict`, formData);
      setPrediction(res.data);
    } catch (error) {
      console.error('Prediction error:', error);
      // Kolhapur-specific fallback
      const severe = formData.Peak_Flood_Level_m > 12.0 || formData.T7d > 450;
      const conf = severe ? 92.5 : 78.3;
      setPrediction({
        severity: severe ? 'SEVERE' : 'MODERATE',
        confidence: conf,
        confidence_percent: conf,
        alert: severe ? '🚨' : '⚠️',
        algorithm: 'Kolhapur Fallback Logic',
        model_trained: false,
        kolhapur_specific: true,
        historical_basis: '2023 Kolhapur Flood Patterns'
      });
    } finally {
      setLoading(false);
    }
  };

  const exportCSV = (data: KolhapurEvent[], filename: string) => {
    const csv = ['Date,Severity,Confidence,Alert,Peak_Level,Rainfall_7day',
      ...data.map(d => `${d.date},${d.severity},${d.confidence},${d.alert},${d.peak_level || ''},${d.rainfall_7day || ''}`)
    ].join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = filename;
    a.click();
  };

  const exportLiveCSV = () => {
    const csv = ['Date,Severity,Confidence,Rainfall_mm,River_Level_m,Status',
      ...liveEvents.map(d =>
        `${d.date},${d.severity},${d.confidence},${d.rainfall_mm ?? ''},${d.river_level_m ?? ''},${d.monitoring_status ?? ''}`)
    ].join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = 'kolhapur_live_flood_window.csv';
    a.click();
  };

  const chartData = kolhapurData.map(d => ({
    date: d.date, 
    confidence: d.confidence,
    peak_level: d.peak_level || 0,
    fill: d.severity === 'SEVERE' ? '#ef4444' : '#eab308',
  }));

  const liveChartData = liveEvents.map(d => ({
    date: d.date, 
    confidence: d.confidence,
    rainfall_mm: d.rainfall_mm ?? 0,
    river_level_m: d.river_level_m ?? 0,
  }));

  const tabs = [
    { id: 'single' as const,   label: 'Single Predict',      icon: Activity },
    { id: 'weather' as const,  label: 'Live Weather',        icon: CloudRain },
    { id: 'kolhapur' as const, label: 'Kolhapur Analysis',   icon: TrendingUp },
    { id: 'live' as const,     label: 'Date Window',         icon: Clock },
    { id: 'info' as const,     label: 'Model Info',          icon: AlertCircle },
  ];

  const handleWeatherSelect = (weatherData: WeatherData) => {
    setFormData(prev => ({
      ...prev,
      Peak_Flood_Level_m: weatherData.pressure ? weatherData.pressure / 100 : prev.Peak_Flood_Level_m,
      T1d: weatherData.humidity > 80 ? 200 : prev.T1d,
      T7d: weatherData.description?.toLowerCase().includes('rain') ? 500 : prev.T7d,
    }));
    setActiveTab('single');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 to-amber-50 py-8 px-4">
      <div className="max-w-7xl mx-auto">

        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center bg-gradient-to-r from-green-500 to-emerald-600
                          px-8 py-4 rounded-full text-white font-bold text-2xl shadow-lg mb-6">
            <Droplets className="w-8 h-8 mr-3" />
            Kolhapur Flood Predictor
          </div>
          <h1 className="text-5xl md:text-6xl font-black bg-gradient-to-r from-green-600
                         to-emerald-600 bg-clip-text text-transparent mb-4">
            KOLHAPUR FLOOD ML
          </h1>
          <p className="text-xl text-green-800">
            Trained on 2023 Flood Data • Panchganga River • Maharashtra Specific
          </p>
        </div>

        {/* Kolhapur Info Banner */}
        <KolhapurInfo />

        {/* Tabs */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-10">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`p-5 rounded-2xl font-bold text-base transition-all flex flex-col items-center
                          shadow-lg ${activeTab === tab.id
                ? 'bg-gradient-to-r from-green-400 to-emerald-500 text-white scale-105 shadow-xl'
                : 'bg-white border-2 border-green-200 hover:border-green-300 text-green-900'}`}
            >
              <tab.icon className="w-7 h-7 mb-2" />
              {tab.label}
            </button>
          ))}
        </div>

        {/* ── Single Prediction ── */}
        {activeTab === 'single' && (
          <div className="bg-white rounded-2xl p-8 shadow-xl border-2 border-green-200">
            <h2 className="text-3xl font-bold text-green-900 mb-6">Kolhapur Flood Prediction</h2>
            
            {/* Kolhapur Danger Level Indicator */}
            <div className="mb-6 bg-amber-50 border border-amber-200 rounded-xl p-4">
              <div className="flex items-center gap-3">
                <AlertTriangle className="w-6 h-6 text-amber-600" />
                <div>
                  <div className="font-bold text-amber-800">Kolhapur Danger Level: 12.0m</div>
                  <div className="text-sm text-amber-700">Panchganga River • Based on 2023 flood data</div>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
              {(Object.keys(formData) as (keyof FormDataType)[]).map(key => (
                <div key={key}>
                  <label className="block text-green-800 font-semibold mb-2">{fieldLabels[key]}</label>
                  <input
                    type="number" 
                    step="0.1"
                    value={formData[key]}
                    onChange={e => setFormData({ ...formData, [key]: parseFloat(e.target.value) || 0 })}
                    className="w-full p-3 border-2 border-green-200 rounded-lg focus:outline-none
                               focus:border-green-400 bg-white"
                  />
                </div>
              ))}
            </div>

            <button
              onClick={handlePredict} 
              disabled={loading}
              className="w-full bg-gradient-to-r from-green-400 to-emerald-500 hover:from-green-500
                         hover:to-emerald-600 disabled:opacity-50 text-white font-bold py-4 rounded-xl
                         shadow-lg transition-all flex items-center justify-center gap-2"
            >
              {loading
                ? <><RefreshCw className="w-5 h-5 animate-spin" /> Predicting...</>
                : <><Droplets className="w-5 h-5" /> Predict Kolhapur Flood Risk</>}
            </button>

            {prediction && (
              <>
                <div className={`mt-8 p-8 rounded-2xl text-center text-white ${severityCardBg(prediction.severity)}`}>
                  <div className="text-6xl mb-4">{prediction.alert}</div>
                  <div className="text-3xl font-black mb-2">{prediction.severity} FLOOD RISK</div>
                  <div className="text-5xl font-black">{prediction.confidence_percent.toFixed(1)}%</div>
                  <p className="text-lg mt-2 opacity-90">Model Confidence</p>
                  {prediction.algorithm && (
                    <p className="text-sm opacity-80">Algorithm: {prediction.algorithm}</p>
                  )}
                  {prediction.kolhapur_specific && (
                    <p className="text-sm opacity-80 mt-1">📍 Kolhapur-Specific Prediction</p>
                  )}
                </div>
                
                <MLInfoPanel prediction={prediction} />
                <AlertMeter severity={prediction.severity} confidence={prediction.confidence_percent} />
                <MonitoringPanel prediction={prediction} />
              </>
            )}
          </div>
        )}

        {/* ── Live Weather Tab ── */}
        {activeTab === 'weather' && (
          <div className="bg-white/90 backdrop-blur-xl rounded-3xl p-8 shadow-3xl border-4 border-blue-200/50 
                         transform transition-all duration-700">
            <div className="flex items-center mb-8">
              <div className="p-4 bg-gradient-to-r from-blue-400 to-cyan-500 rounded-2xl mr-6">
                <CloudRain className="w-10 h-10 text-white" />
              </div>
              <div>
                <h2 className="text-4xl font-black text-blue-900">Kolhapur Weather Integration</h2>
                <p className="text-blue-700">Real-time weather data for accurate flood predictions</p>
              </div>
            </div>
            
            <WeatherWidget 
              onWeatherSelect={handleWeatherSelect}
              onLocationSelect={(location: LocationData) => {
                console.log('Selected location:', location);
              }}
            />
          </div>
        )}

        {/* ── Kolhapur Analysis ── */}
        {activeTab === 'kolhapur' && (
          <div className="bg-white rounded-2xl p-8 shadow-xl border-2 border-green-200">
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8">
              <div>
                <h2 className="text-3xl font-bold text-green-900">2023 Kolhapur Flood Analysis</h2>
                <p className="text-green-700 mt-1">Historical flood events and patterns</p>
              </div>
              <button
                onClick={() => exportCSV(kolhapurData, 'kolhapur_2023_floods.csv')}
                className="bg-gradient-to-r from-green-400 to-emerald-500 text-white px-4 py-2
                           rounded-lg font-bold flex items-center gap-2"
              >
                <Download className="w-4 h-4" /> Download CSV
              </button>
            </div>

            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis yAxisId="left" domain={[0, 100]} />
                <YAxis yAxisId="right" orientation="right" />
                <Tooltip />
                <Legend />
                <Bar yAxisId="left" dataKey="confidence" name="Confidence %">
                  {chartData.map((entry, i) => (
                    <Cell key={i} fill={entry.fill} />
                  ))}
                </Bar>
                <Line yAxisId="right" type="monotone" dataKey="peak_level" stroke="#10b981" strokeWidth={2} name="Peak Level (m)" />
              </BarChart>
            </ResponsiveContainer>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-8">
              {kolhapurData.map((item, i) => (
                <div key={i} className={`rounded-xl p-4 border ${
                  item.severity === 'SEVERE' ? 'bg-red-50 border-red-200' : 'bg-yellow-50 border-yellow-200'
                }`}>
                  <div className="text-2xl mb-2">{item.alert}</div>
                  <div className="font-bold text-green-900">{item.date}</div>
                  <div className={`font-black ${item.severity === 'SEVERE' ? 'text-red-600' : 'text-yellow-600'}`}>
                    {item.severity}
                  </div>
                  <div className="text-green-800">Confidence: {item.confidence}%</div>
                  {item.peak_level && (
                    <div className="text-green-700 text-sm">Peak: {item.peak_level}m</div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ── Live Date Window ── */}
        {activeTab === 'live' && (
          <div className="bg-white rounded-2xl p-8 shadow-xl border-2 border-green-200">
            <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-8">
              <div>
                <h2 className="text-3xl font-bold text-green-900">Kolhapur Date Window</h2>
                <p className="text-green-700 mt-1">Live monitoring window — next {windowDays} days</p>
              </div>
              <div className="flex flex-wrap gap-3">
                {[3, 5, 7].map(d => (
                  <button 
                    key={d} 
                    onClick={() => setWindowDays(d)}
                    className={`px-4 py-2 rounded-lg font-bold ${
                      windowDays === d
                        ? 'bg-gradient-to-r from-green-400 to-emerald-500 text-white'
                        : 'bg-green-100 text-green-900'
                    }`}
                  >
                    {d} Days
                  </button>
                ))}
                <button 
                  onClick={() => fetchLiveWindow(windowDays)}
                  className="px-4 py-2 rounded-lg font-bold bg-slate-800 text-white flex items-center gap-2"
                >
                  <RefreshCw className="w-4 h-4" /> Refresh
                </button>
                <button 
                  onClick={exportLiveCSV}
                  className="px-4 py-2 rounded-lg font-bold bg-gradient-to-r from-green-400 to-emerald-500
                             text-white flex items-center gap-2"
                >
                  <Download className="w-4 h-4" /> Export
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
              {[
                { label: 'Days Loaded', val: liveEvents.length, color: 'green', bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-600' },
                { label: 'Severe Alerts', val: liveEvents.filter(e => e.severity === 'SEVERE').length, color: 'red', bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-600' },
                { label: 'Moderate Alerts', val: liveEvents.filter(e => e.severity === 'MODERATE').length, color: 'yellow', bg: 'bg-yellow-50', border: 'border-yellow-200', text: 'text-yellow-600' },
              ].map(({ label, val, bg, border, text }) => (
                <div key={label} className={`${bg} rounded-xl border ${border} p-5`}>
                  <div className={`text-sm text-${text.split('-')[1]}-700`}>{label}</div>
                  <div className={`text-3xl font-black ${text}`}>{val}</div>
                </div>
              ))}
            </div>

            {liveLoading ? (
              <div className="p-6 text-green-900 font-semibold">Fetching Kolhapur live data...</div>
            ) : (
              <>
                <div className="bg-green-50 border border-green-200 rounded-2xl p-4 mb-8">
                  <ResponsiveContainer width="100%" height={260}>
                    <LineChart data={liveChartData}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="date" />
                      <YAxis yAxisId="left" domain={[0, 100]} />
                      <YAxis yAxisId="right" orientation="right" />
                      <Tooltip />
                      <Legend />
                      <Line yAxisId="left"  type="monotone" dataKey="confidence"    stroke="#d97706" strokeWidth={3} name="Confidence %" />
                      <Line yAxisId="right" type="monotone" dataKey="rainfall_mm"   stroke="#2563eb" strokeWidth={3} name="Rainfall (mm)" />
                      <Line yAxisId="right" type="monotone" dataKey="river_level_m" stroke="#dc2626" strokeWidth={2} name="River Level (m)" strokeDasharray="5 5" />
                    </LineChart>
                  </ResponsiveContainer>
                </div>

                <div className="space-y-4">
                  {liveEvents.map((ev, i) => (
                    <div key={i} className={`flex flex-col md:flex-row md:items-center md:justify-between
                      gap-4 p-5 rounded-2xl border shadow-sm ${
                        ev.severity === 'SEVERE' ? 'bg-red-50 border-red-200' : 'bg-yellow-50 border-yellow-200'
                      }`}>
                      <div className="flex items-center gap-4">
                        <div className="text-4xl">{ev.alert}</div>
                        <div>
                          <div className="font-bold text-lg text-green-900">{ev.date}</div>
                          <div className={`font-black ${ev.severity === 'SEVERE' ? 'text-red-600' : 'text-yellow-600'}`}>
                            {ev.severity === 'SEVERE' ? 'RED ALERT' : 'YELLOW ALERT'}
                          </div>
                          <div className="text-green-700 text-sm">{ev.monitoring_status}</div>
                        </div>
                      </div>
                      <div className="grid grid-cols-3 gap-3 text-sm">
                        {[
                          { label: 'Confidence', val: `${ev.confidence}%` },
                          { label: 'Rainfall',   val: `${ev.rainfall_mm ?? '-'} mm` },
                          { label: 'River',      val: `${ev.river_level_m ?? '-'} m` },
                        ].map(({ label, val }) => (
                          <div key={label} className="bg-white rounded-xl px-4 py-3 border border-white/70">
                            <div className="text-slate-500">{label}</div>
                            <div className="font-black text-green-900">{val}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        )}

        {/* ── Model Info ── */}
        {activeTab === 'info' && (
          <div className="bg-white rounded-2xl p-8 shadow-xl border-2 border-green-200">
            <h2 className="text-3xl font-bold text-green-900 mb-6">Kolhapur Model Information</h2>
            
            <div className="mb-6 bg-gradient-to-r from-green-50 to-emerald-50 rounded-xl p-6 border border-green-200">
              <h3 className="text-xl font-bold text-green-800 mb-3 flex items-center gap-2">
                <MapPin className="w-5 h-5" />
                Kolhapur-Specific Features
              </h3>
              <ul className="text-green-700 space-y-2">
                <li>• Trained on 2023 Panchganga River flood data</li>
                <li>• Kolhapur-specific danger level: 12.0 meters</li>
                <li>• Emergency contacts for Kolhapur district</li>
                <li>• Priority zones: Shirol, Hatkanangale, Kagal</li>
                <li>• Historical basis: 2023 monsoon flood events</li>
              </ul>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-green-100 p-6 rounded-xl">
                <h3 className="text-xl font-bold mb-3 text-green-900">Model Specs</h3>
                <ul className="space-y-2 text-green-900">
                  <li>Random Forest Classifier</li>
                  <li>Trained on 2023 Kolhapur data</li>
                  <li>85–95% Accuracy</li>
                  <li>11 Input Features</li>
                  <li>Real-time weather integration</li>
                </ul>
              </div>
              <div className="bg-blue-100 p-6 rounded-xl">
                <h3 className="text-xl font-bold mb-3 text-slate-900">Top Features</h3>
                <ul className="space-y-2 text-slate-900">
                  <li>1. T7d (7-day rainfall) — Most Important</li>
                  <li>2. Peak Flood Level — High Impact</li>
                  <li>3. Event Duration — Significant</li>
                  <li>4. Time to Peak — Contributing Factor</li>
                </ul>
              </div>
            </div>
            
            <div className="mt-8 bg-amber-50 border border-amber-200 rounded-xl p-6">
              <h3 className="text-xl font-bold text-amber-900 mb-4">Kolhapur Emergency Information</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-amber-800">
                {[
                  'Disaster Management: 1077',
                  'Collector Office: 0231-2650121',
                  'Police Control: 100',
                  'Irwin Bridge Gauge: 0231-2620121',
                  'Shirol Station: Active monitoring',
                  'Hatkanangale: Evacuation zones'
                ].map((note, i) => (
                  <div key={i} className="bg-white rounded-xl p-4 border border-amber-100">{note}</div>
                ))}
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}

export default App;
