import { useState } from 'react';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';

/**
 * ⚠️ Bu bileşen kendi ağ katmanını kuruyordu ve iki şeyi birden bozuyordu:
 *
 * 1. Token'ı `localStorage.getItem('token')` ile okuyordu — projede böyle
 *    bir anahtar YOK. Access token BELLEKTE tutuluyor (`shared/api/tokens.ts`,
 *    K-A), localStorage'da yalnızca `vivido.refreshToken` var. Yani her
 *    istek `Bearer ` (boş) gidiyor, uç noktalar `[Authorize]` olduğu için
 *    401 dönüyordu; `response.ok` false olunca da hata yutuluyor, ekran
 *    sessizce boş kalıyordu.
 * 2. Ham `fetch` kullandığı için 401→refresh→tekrar dene zinciri,
 *    `problem+json` ayrıştırma ve oturum düşme bildirimi devre dışıydı.
 *
 * İkisi de ortak istemciye geçilerek kapandı.
 */
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
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // 1. Skorlanmış ve bütçeye göre filtrelenmiş konutlar.
  //    Oturum kapsamlı: başka hesabın bütçesine göre süzülmüş liste
  //    bu hesaba SIZAMAZ.
  const { data: properties = [], isLoading } = useSessionQuery({
    queryKey: ['properties', 'map'],
    queryFn: () => api.get<PropertyMapItem[]>('/properties'),
  });

  // 2. Seçili konutun detayı. Ayrı bir `useState` + elle fetch yerine
  //    sorgu: seçim değişince kendisi çalışır, önbelleğe girer ve kimlik
  //    değişince diğerleriyle birlikte düşer.
  const { data: selectedProperty = null } = useSessionQuery({
    queryKey: ['properties', 'detail', selectedId],
    queryFn: () => api.get<PropertyDetail>(`/properties/${selectedId}`),
    enabled: selectedId !== null,
  });

  if (isLoading) return <div style={{ padding: '20px' }}>Konutlar ve skorlar yükleniyor, lütfen bekleyin...</div>;

  return (
    <div style={{ display: 'flex', height: '100vh', fontFamily: 'sans-serif' }}>
      
      {/* Sol Taraf: Skor Sıralamasına Göre Konut Listesi */}
      <div style={{ flex: 1, padding: '20px', overflowY: 'auto', borderRight: '1px solid #ccc' }}>
        <h2>Çankaya Uygun Konut Listesi</h2>
        <p style={{ fontSize: '13px', color: '#666' }}>Bütçene ve kriterlerine göre puanlandı.</p>
        
        {properties.map((prop) => (
          <div 
            key={prop.id}
            onClick={() => setSelectedId(prop.id)}
            style={{
              padding: '12px',
              margin: '8px 0',
              borderRadius: '8px',
              border: '1px solid #ddd',
              cursor: 'pointer',
              background: selectedId === prop.id ? '#eef2ff' : '#fff',
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
              onClick={() => setSelectedId(null)}
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