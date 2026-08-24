import { useState, useEffect } from 'react';

interface PropertyMapItem {
  id: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  totalScore: number;
}

interface PropertyDetail {
  id: string;
  externalRef: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  totalScore: number;
}

export function PropertiesMapView() {
  const [properties, setProperties] = useState<PropertyMapItem[]>([]);
  const [selectedProperty, setSelectedProperty] = useState<PropertyDetail | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  // 1. Backend'den skorlanmış ve bütçeye göre filtrelenmiş konutları çekme
  useEffect(() => {
    async function fetchProperties() {
      try {
        const response = await fetch('/api/v1/properties', {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token') || ''}`
          }
        });
        if (response.ok) {
          const data = await response.json();
          setProperties(data);
        }
      } catch (error) {
        console.error("Konutlar yüklenirken hata oluştu:", error);
      } finally {
        setLoading(false);
      }
    }
    fetchProperties();
  }, []);

  // 2. Bir konuta tıklandığında detay verisini çekme
  const handleSelectProperty = async (id: string) => {
    try {
      const response = await fetch(`/api/v1/properties/${id}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token') || ''}`
        }
      });
      if (response.ok) {
        const detailData = await response.json();
        setSelectedProperty(detailData);
      }
    } catch (error) {
      console.error("Konut detayı alınamadı:", error);
    }
  };

  if (loading) return <div style={{ padding: '20px' }}>Konutlar ve skorlar yükleniyor, lütfen bekleyin...</div>;

  return (
    <div style={{ display: 'flex', height: '100vh', fontFamily: 'sans-serif' }}>
      
      {/* Sol Taraf: Skor Sıralamasına Göre Konut Listesi */}
      <div style={{ flex: 1, padding: '20px', overflowY: 'auto', borderRight: '1px solid #ccc' }}>
        <h2>Çankaya Uygun Konut Listesi</h2>
        <p style={{ fontSize: '13px', color: '#666' }}>Bütçene ve kriterlerine göre puanlandı.</p>
        
        {properties.map((prop) => (
          <div 
            key={prop.id}
            onClick={() => handleSelectProperty(prop.id)}
            style={{
              padding: '12px',
              margin: '8px 0',
              borderRadius: '8px',
              border: '1px solid #ddd',
              cursor: 'pointer',
              background: selectedProperty?.id === prop.id ? '#eef2ff' : '#fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 'bold' }}>
              <span>Oda: {prop.roomCount} | {prop.areaM2} m²</span>
              <span style={{ color: '#4f46e5' }}>Skor: {Math.round(prop.totalScore)} / 100</span>
            </div>
            <div style={{ marginTop: '5px', color: '#333', fontSize: '15px' }}>
              Kira: <strong>{prop.monthlyRent} TL</strong>
            </div>
          </div>
        ))}
      </div>

      {/* Sağ Alt Köşe: Detay Paneli */}
      {selectedProperty && (
        <div style={{
          position: 'fixed',
          bottom: '20px',
          right: '20px',
          width: '350px',
          background: '#fff',
          borderRadius: '12px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.2)',
          padding: '20px',
          border: '1px solid #e5e7eb',
          zIndex: 1000
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ margin: '0 0 10px 0' }}>Konut Detayları</h3>
            <button 
              onClick={() => setSelectedProperty(null)}
              style={{ background: 'none', border: 'none', fontSize: '16px', cursor: 'pointer' }}
            >
              ✕
            </button>
          </div>
          <hr style={{ border: '0', borderTop: '1px solid #eee', marginBottom: '10px' }} />
          
          <p><strong>Referans Kodu:</strong> {selectedProperty.externalRef}</p>
          <p><strong>Aylık Kira:</strong> {selectedProperty.monthlyRent} TL</p>
          <p><strong>Alan:</strong> {selectedProperty.areaM2} m²</p>
          <p><strong>Oda Sayısı:</strong> {selectedProperty.roomCount}</p>
          <div style={{ background: '#f8fafc', padding: '10px', borderRadius: '6px', marginTop: '10px' }}>
            <p style={{ margin: '0', color: '#1e293b' }}><strong>Uygunluk Puanı:</strong> {Math.round(selectedProperty.totalScore)}</p>
          </div>
        </div>
      )}

    </div>
  );
}