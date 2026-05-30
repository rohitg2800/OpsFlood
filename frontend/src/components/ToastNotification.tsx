import React, { useEffect, useState } from 'react';
import { X, AlertTriangle, AlertCircle, Info, CheckCircle } from 'lucide-react';

export interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info' | 'critical';
  title: string;
  message: string;
  duration?: number;
}

interface ToastNotificationProps {
  toasts: Toast[];
  onRemove: (id: string) => void;
}

export const ToastNotification: React.FC<ToastNotificationProps> = ({
  toasts,
  onRemove,
}) => {
  return (
    <div className="fixed top-4 right-4 z-50 space-y-3 max-w-sm">
      {toasts.map((toast) => (
        <ToastItem key={toast.id} toast={toast} onRemove={onRemove} />
      ))}
    </div>
  );
};

const ToastItem: React.FC<{ toast: Toast; onRemove: (id: string) => void }> = ({
  toast,
  onRemove,
}) => {
  const [isExiting, setIsExiting] = useState(false);

  useEffect(() => {
    const duration = toast.duration || 5000;
    const timer = setTimeout(() => {
      setIsExiting(true);
      setTimeout(() => onRemove(toast.id), 300);
    }, duration);

    return () => clearTimeout(timer);
  }, [toast.id, toast.duration, onRemove]);

  const getIcon = () => {
    switch (toast.type) {
      case 'success':
        return <CheckCircle className="w-5 h-5 text-emerald-400" />;
      case 'error':
        return <AlertCircle className="w-5 h-5 text-[#ff0037]" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-amber-400" />;
      case 'critical':
        return <AlertTriangle className="w-5 h-5 text-[#ff0037] animate-pulse" />;
      default:
        return <Info className="w-5 h-5 text-blue-400" />;
    }
  };

  const getStyles = () => {
    switch (toast.type) {
      case 'success':
        return 'bg-emerald-500/10 border-emerald-500/30 shadow-[0_18px_60px_rgba(16,185,129,0.15)]';
      case 'error':
        return 'bg-[#ff0037]/10 border-[#ff0037]/30 shadow-[0_18px_60px_rgba(255,0,55,0.15)]';
      case 'warning':
        return 'bg-amber-500/10 border-amber-500/30 shadow-[0_18px_60px_rgba(245,158,11,0.15)]';
      case 'critical':
        return 'bg-[#ff0037]/15 border-[#ff0037]/40 shadow-[0_18px_60px_rgba(255,0,55,0.2)] animate-critical-pulse';
      default:
        return 'bg-blue-500/10 border-blue-500/30 shadow-[0_18px_60px_rgba(59,130,246,0.15)]';
    }
  };

  return (
    <div
      className={`relative p-4 rounded-2xl border backdrop-blur-xl ring-1 ring-white/5 transition-all duration-300 ${
        isExiting ? 'animate-slide-out-right opacity-0' : 'animate-slide-in-right'
      } ${getStyles()}`}
    >
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 mt-0.5">{getIcon()}</div>
        <div className="flex-1 min-w-0">
          <h4 className="text-sm font-black text-white">{toast.title}</h4>
          <p className="text-xs text-slate-300 mt-1">{toast.message}</p>
        </div>
        <button
          onClick={() => {
            setIsExiting(true);
            setTimeout(() => onRemove(toast.id), 300);
          }}
          className="flex-shrink-0 p-1 rounded-lg hover:bg-white/10 transition-colors"
        >
          <X className="w-4 h-4 text-slate-400" />
        </button>
      </div>

      {/* Progress Bar */}
      <div className="absolute bottom-0 left-0 right-0 h-1 bg-white/5 rounded-b-2xl overflow-hidden">
        <div
          className={`h-full ${
            toast.type === 'critical' || toast.type === 'error'
              ? 'bg-[#ff0037]'
              : toast.type === 'warning'
              ? 'bg-amber-500'
              : toast.type === 'success'
              ? 'bg-emerald-500'
              : 'bg-blue-500'
          } animate-progress-stripe`}
          style={{
            animationDuration: `${toast.duration || 5000}ms`,
          }}
        />
      </div>
    </div>
  );
};

export default ToastNotification;
