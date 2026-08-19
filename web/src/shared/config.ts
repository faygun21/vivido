/**
 * Ortam yapılandırması. Tek nokta — `import.meta.env` başka yerde okunmaz.
 */

/**
 * API kök adresi.
 *
 * ⚠️ `.env` içindeki değer ZATEN `/api/v1` ile biter.
 * İstek yollarına tekrar `/api/v1` eklemeyin — `/auth/login` yeterli.
 */
export const API_BASE_URL: string =
  import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000/api/v1';

/*
 * MSW (sahte API) anahtarı BURADA DEĞİL, `main.tsx` içinde satır içi kontrol
 * edilir. Sebep: buraya bir sabit koyup oradan okursak Vite modül sınırını
 * aşarak sabit katlaması yapamıyor ve MSW'nin ~420 kB'lık parçası üretim
 * çıktısına giriyor (çalışmasa bile indirilir). `import.meta.env.DEV`
 * doğrudan `main.tsx` içinde yazıldığında derleyici tüm dalı eliyor.
 */
