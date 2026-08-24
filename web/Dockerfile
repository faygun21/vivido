# Web istemcisi — derle, statik dosyaları nginx ile sun.
#
# ⚠️ BUILD BAĞLAMI DEPO KÖKÜ OLMALI, `web/` DEĞİL:
#     docker build -f web/Dockerfile .
#
# Üç sebep: (1) pnpm workspace kökü lazım, (2) `@vivido/shared` paketi
# `packages/` altında, (3) `web/scripts/sync-geo.mjs` derleme sırasında
# `data/*.geojson` dosyalarını okuyor.
#
# ⚠️ VITE_* değişkenleri DERLEME ANINDA gömülür, çalışma anında okunmaz.
# Staging ve local için AYRI imaj derlenir; aynı imaj iki ortama gitmez.

FROM node:22-alpine AS build
WORKDIR /repo

RUN corepack enable

# ── Bağımlılıklar ──
# Önce yalnızca manifest'ler: kaynak kod değiştiğinde bu katman
# önbellekten gelir ve `pnpm install` tekrar çalışmaz.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/shared/package.json packages/shared/
COPY web/package.json web/

# MSW'nin postinstall'ı `web/public/mockServiceWorker.js` yazmaya çalışıyor
# (pnpm-workspace.yaml → allowBuilds.msw). Klasör yoksa kurulum patlar.
RUN mkdir -p web/public

RUN pnpm install --frozen-lockfile

# ── Kaynak ──
COPY packages/shared packages/shared
COPY web web
# sync-geo.mjs bu ikisini `web/public/geo/` altına kopyalıyor.
# Tüm `data/` klasörünü kopyalamıyoruz — artefaktlar yüzlerce MB.
COPY data/cankaya.geojson data/cankaya-ankara-mahalles.geojson data/

# ── Ortam ──
# Varsayılanlar TEK ORIGIN kurulumuna göre: Caddy `/api` ve `/tiles`
# yollarını arka servislere yönlendiriyor, bu yüzden mutlak adres yok.
# Mutlak adres yazılsaydı domain değiştiğinde imajın yeniden derlenmesi gerekirdi.
ARG VITE_API_BASE_URL=/api/v1
ARG VITE_TILE_URL=/tiles/data/v3.json
ARG VITE_GLYPHS_URL=/tiles/fonts/{fontstack}/{range}.pbf
ARG VITE_USE_RASTER_BASEMAP=false

ENV VITE_API_BASE_URL=$VITE_API_BASE_URL \
    VITE_TILE_URL=$VITE_TILE_URL \
    VITE_GLYPHS_URL=$VITE_GLYPHS_URL \
    VITE_USE_RASTER_BASEMAP=$VITE_USE_RASTER_BASEMAP \
    # ⛔ MSW üretimde ASLA açılmaz. `main.tsx` zaten `import.meta.env.DEV`
    # ile eliyor; bu satır ikinci kemer.
    VITE_USE_MOCKS=false

RUN pnpm --filter web build


FROM nginx:1.27-alpine AS runtime

COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/web/dist /usr/share/nginx/html

EXPOSE 80
