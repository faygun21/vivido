/**
 * Veri ekibinin GeoJSON'larını web/public/geo/ altına kopyalar.
 *
 * Neden script: `data/` veri ekibinin alanı ve doğruluk kaynağı. Dosyaları
 * elle `web/public/` içine kopyalayıp git'e eklersek iki nüsha oluşur ve
 * veri ekibi kaynağı güncellediğinde web sessizce eski veriyi göstermeye
 * devam eder. Kopya her `dev`/`build` öncesi tazeleniyor, git'e girmiyor.
 *
 * Not: pnpm 7'den beri `pre*` script'leri VARSAYILAN OLARAK ÇALIŞMAZ
 * (`enable-pre-post-scripts=false`). Bu yüzden `predev` yerine `dev` ve
 * `build` komutlarının içine açıkça zincirlendi.
 */
import { copyFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = resolve(webRoot, '..', 'data');
const outDir = join(webRoot, 'public', 'geo');

/** kaynak dosya → web'de sunulacak ad */
const FILES = [
  ['cankaya.geojson', 'cankaya.geojson'],
  ['cankaya-ankara-mahalles.geojson', 'cankaya-mahalleler.geojson'],
];

await mkdir(outDir, { recursive: true });

let copied = 0;
for (const [source, target] of FILES) {
  const from = join(dataDir, source);
  if (!existsSync(from)) {
    console.warn(`[sync-geo] ATLANDI, kaynak yok: ${from}`);
    continue;
  }
  await copyFile(from, join(outDir, target));
  copied += 1;
}

console.log(`[sync-geo] ${copied}/${FILES.length} GeoJSON kopyalandı → web/public/geo/`);
