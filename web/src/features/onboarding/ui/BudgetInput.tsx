import React from 'react';

interface BudgetInputProps {
  minValue: number | null;
  maxValue: number | null;
  onMinChange: (value: number | null) => void;
  onMaxChange: (value: number | null) => void;
}

export const BudgetInput: React.FC<BudgetInputProps> = ({
  minValue,
  maxValue,
  onMinChange,
  onMaxChange,
}) => {
  return (
    <div style={{ marginTop: '24px', marginBottom: '24px' }}>
      <label
        style={{
          display: 'block',
          marginBottom: '8px',
          fontWeight: 'bold',
        }}
      >
        Aylık Kira Aralığı (TL)
      </label>

      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: '12px',
          width: '100%',
        }}
      >
        <input
          type="number"
          min="0"
          value={minValue ?? ''}
          onChange={(e) =>
            onMinChange(e.target.value ? Number(e.target.value) : null)
          }
          placeholder="Minimum kira"
          aria-label="Minimum aylık kira"
          style={{
            padding: '12px',
            width: '100%',
            borderRadius: '6px',
            border: '1px solid #ccc',
            fontSize: '16px',
            boxSizing: 'border-box',
          }}
        />

        <input
          type="number"
          min="0"
          value={maxValue ?? ''}
          onChange={(e) =>
            onMaxChange(e.target.value ? Number(e.target.value) : null)
          }
          placeholder="Maksimum kira"
          aria-label="Maksimum aylık kira"
          style={{
            padding: '12px',
            width: '100%',
            borderRadius: '6px',
            border: '1px solid #ccc',
            fontSize: '16px',
            boxSizing: 'border-box',
          }}
        />
      </div>
    </div>
  );
};