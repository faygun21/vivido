# ══════════════════════════════════════════════════════════════
#  Vivido — GitHub deposu kurulumu
#
#  ÖNKOŞUL:  gh auth login    (tarayıcı açılır, bir kez yapılır)
#
#  Kullanım:
#     .\.github\setup-repo.ps1
#     .\.github\setup-repo.ps1 -Collaborators 'ahmet','ayse','mehmet'
# ══════════════════════════════════════════════════════════════

param(
  [string]   $Owner         = 'faygun21',
  [string]   $RepoName      = 'vivido',
  [string[]] $Collaborators = @()
)

$ErrorActionPreference = 'Stop'
$repo = "$Owner/$RepoName"

function Step($msg) { Write-Host "`n▸ $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }

# ─── 0) Oturum kontrolü ───
Step "GitHub oturumu kontrol ediliyor"

gh auth status 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
  Write-Host "`n✗ GitHub'a giriş yapılmamış. Önce şunu çalıştır:`n" -ForegroundColor Red
  Write-Host "    gh auth login`n" -ForegroundColor White
  exit 1
}

Ok "Oturum açık"

# ─── 1) Depoyu oluştur ve gönder ───
Step "Depo oluşturuluyor: $repo (private)"

gh repo view $repo 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
  Warn "Depo zaten var, oluşturma atlandı"

  git remote get-url origin 2>&1 | Out-Null

  if ($LASTEXITCODE -ne 0) {
    git remote add origin "https://github.com/$repo.git"
  }

  git push -u origin main
}
else {
  gh repo create $RepoName --private --source=. --remote=origin --push
}

Ok "Depo hazır → https://github.com/$repo"

# ─── 2) Etiketler ───
Step "Issue etiketleri oluşturuluyor"

$labels = @(
  @{
    n = 'area:api'
    c = '1D76DB'
    d = 'Backend / .NET'
  },
  @{
    n = 'area:web'
    c = '0E8A16'
    d = 'React web uygulaması'
  },
  @{
    n = 'area:mobile'
    c = '5319E7'
    d = 'Flutter / Dart'
  },
  @{
    n = 'area:data'
    c = 'B08800'
    d = 'ETL, veri şeması, seed'
  },
  @{
    n = 'area:devops'
    c = '5D6D7E'
    d = 'CI, Docker, altyapı'
  },
  @{
    n = 'type:task'
    c = 'C2E0C6'
    d = 'Yapılacak iş'
  },
  @{
    n = 'type:bug'
    c = 'D73A4A'
    d = 'Hata'
  },
  @{
    n = 'type:nice-to-have'
    c = 'EEEEEE'
    d = 'v1 kapsamı DIŞI — backlog/v2.md'
  },
  @{
    n = 'blocked'
    c = 'E99695'
    d = 'Başka bir işi bekliyor'
  },
  @{
    n = 'needs-repro'
    c = 'FBCA04'
    d = 'Tekrar üretilemedi'
  }
)

foreach ($i in 1..7) {
  $labels += @{
    n = "W$i"
    c = '0052CC'
    d = "Web gereksinimi W$i"
  }
}

foreach ($i in 1..5) {
  $labels += @{
    n = "M$i"
    c = '6F42C1'
    d = "Mobil gereksinimi M$i"
  }
}

foreach ($l in $labels) {
  gh label create $l.n `
    --color $l.c `
    --description $l.d `
    --repo $repo `
    --force 2>&1 | Out-Null
}

Ok "$($labels.Count) etiket hazır"

# ─── 3) Milestone'lar ───
Step "Milestone'lar oluşturuluyor"

$milestones = @(
  'M1 İskelet ve kontratlar',
  'M2 Profil ve anchor',
  'M3 Skor motoru',
  'M4 İlk gerçek demo',
  'M5 Ziyaret rotası',
  'M6 Navigasyon',
  'M7 Özellik dondurma',
  'M8 Teslim'
)

foreach ($m in $milestones) {
  gh api "repos/$repo/milestones" `
    -f title="$m" 2>&1 | Out-Null
}

Ok "8 milestone hazır"

# ─── 4) Collaborator'lar ───
if ($Collaborators.Count -gt 0) {
  Step "Ekip üyeleri ekleniyor"

  foreach ($c in $Collaborators) {
    gh api `
      -X PUT `
      "repos/$repo/collaborators/$c" `
      -f permission=push 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
      Ok "$c davet edildi"
    }
    else {
      Warn "$c eklenemedi — kullanıcı adı doğru mu?"
    }
  }
}
else {
  Warn "Collaborator verilmedi. Sonra eklemek için:"
  Write-Host `
    "    gh api -X PUT repos/$repo/collaborators/KULLANICI -f permission=push" `
    -ForegroundColor DarkGray
}

# ─── 5) Branch koruma ───
# NOT:
# CI kontrolleri ilk PR açılana kadar GitHub'da "bilinmiyor" olabilir.
# Bu nedenle zorunlu status check listesi ilk başarılı PR'dan sonra
# repository ayarlarından tanımlanabilir.

Step "main dalı korunuyor"

$protection = @{
  required_status_checks = @{
    strict   = $true
    contexts = @()
  }

  enforce_admins = $false

  required_pull_request_reviews = @{
    required_approving_review_count = 1
    dismiss_stale_reviews           = $true
  }

  restrictions = $null

  allow_force_pushes = $false
  allow_deletions    = $false

  required_linear_history = $true
} | ConvertTo-Json -Depth 10

$tmp = New-TemporaryFile

Set-Content `
  -Path $tmp `
  -Value $protection `
  -Encoding utf8

gh api `
  -X PUT `
  "repos/$repo/branches/main/protection" `
  --input $tmp `
  -H "Accept: application/vnd.github+json" `
  2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
  Ok "main korumalı: PR + 1 onay, force-push kapalı"
}
else {
  Warn "Branch koruma ayarlanamadı (private repo + ücretsiz planda kısıtlı olabilir)"
}

Remove-Item $tmp -Force

# ─── Özet ───
Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Depo hazır: https://github.com/$repo" -ForegroundColor White
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "Sıradaki adımlar:"
Write-Host "  1. Arkadaşlarına README'deki kurulum adımlarını gönder"
Write-Host "  2. İlk PR açıldıktan sonra CI kontrollerini zorunlu yap:"
Write-Host "     Settings → Branches → main → Require status checks" -ForegroundColor DarkGray
Write-Host "  3. Hafta 1 işleri: db/schema/001_initial.sql ve api/openapi.yaml"
Write-Host "  4. Mobil frontend: Flutter + Dart`n"