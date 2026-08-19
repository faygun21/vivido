import React from 'react';

interface BudgetInputProps {
  value: number | null;
  onChange: (value: number | null) => void;
}

export const BudgetInput: React.FC<BudgetInputProps> = ({ value, onChange }) => {
  return (
    <div style={{ marginTop: '24px', marginBottom: '24px' }}>
      <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>
        Aylık Kira Bütçesi (TL)
      </label>
      <input 
        type="number" 
        value={value || ''} 
        onChange={(e) => onChange(e.target.value ? Number(e.target.value) : null)}
        placeholder="Örn: 20000 (Boş bırakılabilir)"
        style={{ 
          padding: '12px', 
          width: '100%', 
          borderRadius: '6px',
          border: '1px solid #ccc',
          fontSize: '16px'
        }}
      />
    </div>
  );
};