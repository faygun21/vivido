import React from 'react';

interface PersonaCardProps {
  code: string;
  displayNameTr: string;
  descriptionTr: string;
  isSelected: boolean;
  onSelect: (code: string) => void;
}

export const PersonaCard: React.FC<PersonaCardProps> = ({ 
  code, 
  displayNameTr, 
  descriptionTr, 
  isSelected, 
  onSelect 
}) => {
  return (
    <div 
      onClick={() => onSelect(code)}
      style={{
        border: isSelected ? '2px solid #007bff' : '1px solid #ccc',
        padding: '16px',
        borderRadius: '8px',
        cursor: 'pointer',
        marginBottom: '12px',
        backgroundColor: isSelected ? '#f8fbff' : '#fff'
      }}
    >
      <h3 style={{ margin: '0 0 8px 0' }}>{displayNameTr}</h3>
      <p style={{ margin: 0, color: '#666' }}>{descriptionTr}</p>
    </div>
  );
};