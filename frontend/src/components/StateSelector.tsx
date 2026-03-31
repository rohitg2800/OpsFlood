import React from 'react';
import { useAppState } from '../context/AppContext';
import { useIndianStateModels } from '../hooks/useAppOperations';

interface StateSelectorProps {
  id?: string;
  className?: string;
}

export function StateSelector({ id = 'state-select', className = '' }: StateSelectorProps) {
  const { state } = useAppState();
  const { selectedState, selectState, availableStates } = useIndianStateModels();
  const selectedMatrixLabel = state.prediction.selectedState || selectedState || 'Selected state';

  return (
    <div className={`flex flex-col ${className}`}>
      <label htmlFor={id} className="mb-2 block text-left text-[10px] font-black text-[#bc9437] uppercase tracking-[0.3em]">
        Indian State/UT
      </label>
      <select
        id={id}
        value={selectedState}
        onChange={(e) => selectState(e.target.value)}
        className="w-full rounded-md border border-[#ff9b2f]/35 bg-[#f59e0b]/14 px-4 py-3 font-mono text-xs font-bold text-white shadow-[inset_0_2px_4px_rgba(0,0,0,0.35)] outline-none transition-all focus:bg-[#f59e0b]/22 focus:ring-4 focus:ring-[#f59e0b]/18"
      >
        <option value="">Select State...</option>
        {availableStates.map((state) => (
          <option key={state} value={state}>
            {state}
          </option>
        ))}
      </select>

      {selectedMatrixLabel && (
        <p className="mt-2 text-left text-[9px] text-slate-500 font-mono">
          Showing {selectedMatrixLabel} state matrix thresholds
        </p>
      )}
    </div>
  );
}
