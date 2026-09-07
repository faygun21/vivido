<div align="center">

<img src="web/public/images/logo.svg" width="140" alt="Vivido" />

# Vivido

### Find a rental home that fits *your* life — not just your budget.

Vivido scores every rental listing against the places **you** actually go,
explains the score line by line, and plans the shortest route to visit the
homes you shortlisted.

<!-- ── DEMO BLOCK — delete these lines when the demo server is retired ── -->
[**Live demo →**](https://vividoapp.xyz) &nbsp;·&nbsp; [🇹🇷 Türkçe](README.tr.md) &nbsp;·&nbsp; [Documentation](docs/)

<sub>No account needed to look around — pick **“Continue as guest”**.<br />
The demo runs on a temporary server and will be taken offline at some point.
The screenshots below cover every screen, and the whole stack starts locally
with a single `docker compose` command — see [running it yourself](#running-it-yourself).</sub>
<!-- ── END DEMO BLOCK — after deleting, keep the language/docs links: ──
[🇹🇷 Türkçe](README.tr.md) · [Documentation](docs/)
-->

<br />

![.NET](https://img.shields.io/badge/.NET_10-512BD4?style=flat-square&logo=dotnet&logoColor=white)
![React](https://img.shields.io/badge/React_19-20232A?style=flat-square&logo=react&logoColor=61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![MapLibre](https://img.shields.io/badge/MapLibre-295DAA?style=flat-square&logo=maplibre&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)

</div>

---

## The problem

Every rental site lets you filter by price, size and room count. None of them
answer the question you actually care about:

> *"If I live here, what will my daily life feel like?"*

A flat that is 15% cheaper is a bad deal if the nearest metro stop is a
25-minute walk uphill, the pharmacy is across a highway, and your kid's school
is on the other side of the city. Those costs are real, they are paid every
single day, and no listing page shows them.

**Vivido turns that daily-life question into a number you can compare** — and,
just as importantly, into an explanation you can argue with.

---

## How it works

<table>
<tr>
<td width="50" align="center"><h3>1</h3></td>
<td><b>Tell it who you are</b><br />
Pick one of four ready-made profiles — student, family with kids, remote
worker, or retiree — and enter your monthly rent budget. Each profile comes
with a starting sense of what matters: a student weighs transit and cafés
heavily, a family weighs schools and parks.</td>
</tr>
<tr>
<td align="center"><h3>2</h3></td>
<td><b>Add the places you actually go</b><br />
Your campus, your office, your parents' house. Up to three of these
"anchors", ordered by how much they matter. This is what separates Vivido
from a generic neighbourhood rating: the map is scored around <i>your</i>
life, not an average person's.</td>
</tr>
<tr>
<td align="center"><h3>3</h3></td>
<td><b>See the map score itself</b><br />
Every home gets a single <b>0–100</b> score. High scorers and low scorers are
both shown — hiding the bad ones would just be a filter with extra steps.
Click any home to see <i>why</i> it got that score.</td>
</tr>
<tr>
<td align="center"><h3>4</h3></td>
<td><b>Plan the viewing trip</b><br />
Shortlist 2–8 homes and Vivido computes the shortest route that visits all of
them, then hands it to the mobile app for turn-by-turn navigation on
viewing day.</td>
</tr>
</table>

---

## Screenshots

<div align="center">

<img src="docs/screenshots/01-explore-map.png" alt="Explore map with scored homes" />

**Every home on the map carries its score.** The left panel is your profile,
the right one ranks the best matches. Note the footer: the map data credit and
the *"listing data is synthetic"* label are always visible.

<br />

<table>
<tr>
<td width="50%" align="center"><img src="docs/screenshots/02-score-breakdown.png" width="420" alt="Score breakdown" /></td>
<td width="50%" align="center"><img src="docs/screenshots/06-mobile-navigation.jpeg" width="320" alt="Mobile navigation" /></td>
</tr>
<tr>
<td align="center"><b>Why this score</b><br /><sub>Each criterion with the walking time actually measured against its target. This home scored <b>52.4</b> — low scorers are shown, not filtered away.</sub></td>
<td align="center"><b>Mobile navigation</b><br /><sub>Maneuver card, numbered stops, and the next home in the queue. When the GPS fix is poor the app says so instead of quietly showing a wrong position.</sub></td>
</tr>
</table>

<br />

<img src="docs/screenshots/03-persona-budget.png" alt="Persona selection and budget" />

**Pick the profile closest to your life.** Each one starts with a different
sense of what matters — and you can reorder those criteria yourself in the
step below.

<br />

<img src="docs/screenshots/04-anchors.png" alt="Anchor places" />

**Your regular places, in priority order.** Work, school, gym — dragged into
the order that matters to you. The map re-scores around them.

<br />

<img src="docs/screenshots/05-route.png" alt="Visit route" />

**The viewing route.** Three of eight possible homes selected, the shortest
path through them drawn on the map, with total distance and time.

</div>

---

## What makes the score trustworthy

Most "walkability" numbers are computed as the crow flies. That is fast, and
it is wrong: a park 300 m away across a six-lane road with no crossing is not
a 4-minute walk.

Vivido measures **real walking time along the actual street network**, using a
routing engine over OpenStreetMap data. The difference is not academic — when
we switched from straight-line distance to real routing, measured times went
up by an average factor of **1.37**. Every score computed the old way was
flattering by roughly a third.

Four more things the scoring engine does on purpose:

| | |
|---|---|
| **It shows its work** | Every score comes with a row-by-row table: which criterion, what was measured, what the target was, and exactly how many points it contributed. The rows sum to the total — that's enforced by a unit test, not by convention. |
| **It refuses to average away a dealbreaker** | A home that is excellent at seven things and hopeless at the one thing you said matters most does not get a comfortable average. A "weakest link" penalty scales the whole score down — proportionally to how much you said that criterion matters. |
| **It doesn't pretend to certainty it lacks** | Being 50 m from a market and 500 m from a market are not the same, so the score keeps a slight gradient even inside the "ideal" zone. Before that change, 767 homes were tied at a perfect 100. |
| **It separates budget from fit** | Rent is shown alongside the score, never folded into it. Otherwise you could never tell whether a home scored low because it's far from everything or just because it's expensive. |

---

## Features

### Web

| | Feature |
|---|---|
| ✅ | Account sign-up with e-mail verification, password reset |
| ✅ | **Guest mode** — browse the map without an account |
| ✅ | Profile: one of four personas + monthly rent budget |
| ✅ | Up to 3 "anchor" places, drag-and-drop priority ordering |
| ✅ | Real Çankaya map — streets, buildings, water, green space, 124 neighbourhoods |
| ✅ | Homes scored 0–100 on the map and in a ranked list |
| ✅ | Row-by-row score explanation, strengths and weaknesses |
| ✅ | Points of interest as toggleable map layers (8 categories) |
| ✅ | Area analysis — draw a circle, see what services are inside it |
| ✅ | Favourites and private per-home notes |
| ✅ | Visit route for 2–8 homes, preview before saving, optional scheduled date |
| ✅ | Location search by neighbourhood, address or place name |
| ✅ | Admin panel — user management, system health, usage metrics |

### Mobile (Flutter)

| | Feature |
|---|---|
| ✅ | Same account as web |
| ✅ | Saved routes list |
| ✅ | Route line with numbered home stops on the map |
| ✅ | Step-by-step navigation: maneuver cards, live GPS, automatic step advance, off-route warning |
| ✅ | Score card at each stop, "visited" marking |
| ✅ | Offline-capable session and cached favourites |

---

## The data

Vivido runs on a real geographic dataset for **Çankaya, Ankara** — the pilot
region — built from OpenStreetMap:

| | |
|---|---|
| **124** | neighbourhoods, with real boundaries |
| **8** | point-of-interest categories: market, pharmacy, transit stop, café & restaurant, park, gym, school, health centre |
| **~48,000** | precomputed walking-time measurements between homes and nearby services |
| **~6,000** | rental listings |

> ### ⚠️ The listings are synthetic
> The 6,000 homes are **generated**, not scraped from a real listing site.
> Rent, size and room counts are modelled to be statistically plausible for
> each neighbourhood, and every home is placed on a real building footprint —
> but none of them is a real advertisement.
>
> This is a deliberate choice, and the app labels it visibly everywhere it
> shows a listing. The geography, the walking times and the scoring are all
> real; only the listings are stand-ins.

---

## Built with

| Layer | Stack |
|---|---|
| **API** | .NET 10 · ASP.NET Core · Entity Framework Core |
| **Database** | PostgreSQL + PostGIS |
| **Routing** | OSRM (foot and car profiles) for real travel times |
| **Web** | React 19 · TypeScript · Vite · MapLibre GL JS · TanStack Query · Zustand |
| **Mobile** | Flutter · MapLibre |
| **Map tiles** | Self-hosted vector tiles (Planetiler → tileserver-gl) — no third-party tile service |
| **Data pipeline** | osm2pgsql · Python · OSRM · SQL |
| **Infrastructure** | Docker Compose · Caddy (automatic HTTPS) · GitHub Actions |

The scoring engine is a **pure, dependency-free C# library** — no database, no
HTTP client, no clock. It takes a struct in and returns a score out, which
means the whole thing can be tested in milliseconds against hundreds of cases
without any infrastructure running.

---

## Project status

This was built as an internship project at **Başarsoft**, on a fixed
three-week scope that was deliberately frozen at the start — scope creep was
identified as the project's number-one risk, and new ideas were parked in a
backlog rather than added mid-flight.

Everything in the feature tables above is **working and deployed**. The
honest list of what is *not* done — known gaps, technical debt, and things
that were cut — is kept in the open in
[`docs/04-MEVCUT-DURUM.md`](docs/04-MEVCUT-DURUM.md) (Turkish). That document
also records every real bug found along the way and how it was diagnosed,
which is arguably the more interesting read.

---

## Running it yourself

The demo server is temporary, but the project is not tied to it. Everything —
database, routing engines, map tile server, API and web app — is defined in
Docker Compose, and the ~1 GB of prepared map data is published as a GitHub
release, so no one has to re-run the multi-hour data pipeline.

```bash
git clone https://github.com/faygun21/vivido.git && cd vivido
./data/scripts/00_fetch_artifacts.sh        # prepared map + routing data
cp .env.example .env && cp web/.env.example web/.env
docker compose --profile full up -d         # everything, one command
```

Full instructions, including the local development loop without Docker:
[`docs/KURULUM.md`](docs/KURULUM.md).

---

## Documentation

The project documentation is in **Turkish**.

| Document | What's in it |
|---|---|
| [`docs/KURULUM.md`](docs/KURULUM.md) | **Setup guide** — run the whole stack locally |
| [`docs/04-MEVCUT-DURUM.md`](docs/04-MEVCUT-DURUM.md) | What actually works today, every bug found and fixed, known debt |
| [`docs/02-KARARLAR.md`](docs/02-KARARLAR.md) | Decision log — 18 architectural decisions with their rationale *and* the alternatives that were rejected |
| [`docs/01-PROJE-PLANI.md`](docs/01-PROJE-PLANI.md) | Full technical design: scoring maths, data model, API contract |
| [`docs/00-KAPSAM.md`](docs/00-KAPSAM.md) | Scope contract — what is in, what is explicitly out |
| [`data/README.md`](data/README.md) | The ETL pipeline, end to end |
| [`deploy/README.md`](deploy/README.md) | Deployment and server setup |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Branching, commits, PR rules |

---

## Licence and attribution

Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright)
contributors, licensed under **ODbL 1.0**. Vector tiles are produced with
Planetiler using the OpenMapTiles schema (**CC-BY**). Both attributions are
displayed visibly on the map in the web and mobile apps, and cannot be
dismissed — this is a licence requirement, not a design choice.

Rental listings are synthetic and are labelled as such throughout the
interface.
