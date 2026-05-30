import React from 'react';
import { useAppState } from '../context/AppContext';
import { useIndianStateModels } from '../hooks/useAppOperations';
import { opsFieldClass, opsLabelClass } from './OpsPrimitives';

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
      <label htmlFor={id} className={`mb-2 block text-left ${opsLabelClass}`}>
        Indian State/UT
      </label>
      <select
        id={id}
        value={selectedState}
        onChange={(e) => selectState(e.target.value)}
        className={`${opsFieldClass} font-mono text-xs font-bold`}
      >
        <option value="">Select State...</option>
        {availableStates.map((state) => (
          <option key={state} value={state}>
            {state}
          </option>
        ))}
      </select>

      {selectedMatrixLabel && (
        <p className="mt-2 text-left text-[10px] font-mono text-[color:var(--ops-text-faint)]">
          Showing {selectedMatrixLabel} state matrix thresholds
        </p>
      )}
    </div>
  );
}
