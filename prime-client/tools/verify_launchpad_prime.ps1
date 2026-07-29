# Verifie que le Launchpad et le dossier prime-client correspondent au flux Godot attendu.
param(
    [string]$LaunchpadExe = "J:\swgemu\dist\win-unpacked\LBG Launchpad.exe",
    [string]$PrimeClientDir = "J:\swgemu\clients\prime-client"
)

function Find-LaunchpadConfig {
    param([string]$ExePath)
    if ($ExePath -and (Test-Path -LiteralPath $ExePath)) {
        $dir = Split-Path -Parent $ExePath
        $cfg = Join-Path $dir "launchpad.config.json"
        if (Test-Path -LiteralPath $cfg) { return $cfg }
    }
    foreach ($c in @(
            "J:\swgemu\dist\win-unpacked\launchpad.config.json",
            "J:\swgemu\dist\launchpad.config.json"
        )) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

$configPath = Find-LaunchpadConfig -ExePath $LaunchpadExe
Write-Host "=== LBG Launchpad / Prime ==="
if (-not $configPath) {
    Write-Host "ECHEC: launchpad.config.json introuvable (a cote de LBG Launchpad.exe)"
    exit 1
}
Write-Host "Config: $configPath"

$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$prime = $cfg.profiles | Where-Object { $_.id -eq "prime" } | Select-Object -First 1
if (-not $prime) {
    Write-Host "ECHEC: profil 'prime' absent"
    exit 1
}

Write-Host ""
Write-Host "Profil Prime:"
Write-Host ("  gameDir  = {0}" -f $prime.gameDir)
Write-Host ("  gameExe  = {0}" -f $prime.gameExe)
Write-Host ("  clientKind = {0}" -f $prime.clientKind)
Write-Host ("  launchArgs = {0}" -f ($prime.launchArgs -join " "))

$issues = @()

if ($prime.clientKind -ne "godot") {
    $issues += "clientKind devrait etre 'godot' (pas lbgemu/SWG retail)"
}
$exeLower = [string]$prime.gameExe
if ($exeLower -match "lbgemu|SWGEmu\.exe" -and $exeLower -notmatch "Godot") {
    $issues += "gameExe pointe encore vers le client retail PreCu/Prime-lbg"
}
if ($prime.gameDir -match "prime-lbg|StarWarsGalaxies") {
    $issues += "gameDir pointe vers l'ancien client retail, pas prime-client Godot"
}

$resolvedDir = [string]$prime.gameDir
if (-not (Test-Path -LiteralPath $resolvedDir)) {
    $issues += "gameDir inexistant: $resolvedDir"
}

$projectGodot = Join-Path $resolvedDir "project.godot"
if (-not (Test-Path -LiteralPath $projectGodot)) {
    $issues += "project.godot absent dans gameDir"
}

$buildInfo = Join-Path $resolvedDir "assets\build_info.json"
if (Test-Path -LiteralPath $buildInfo) {
    $bi = Get-Content -LiteralPath $buildInfo -Raw | ConvertFrom-Json
    Write-Host ""
    Write-Host "build_info.json (copie jouee):"
    Write-Host ("  synced_at = {0}" -f $bi.synced_at)
    Write-Host ("  map_config_schema = {0}" -f $bi.map_config_schema)
} else {
    $issues += "assets/build_info.json absent — lancer sync_prime_client_to_j.sh depuis WSL"
}

$wm = Join-Path $resolvedDir "scripts\world_map.gd"
if (Test-Path -LiteralPath $wm) {
    $hasBounds = Select-String -LiteralPath $wm -Pattern "texture_core3_bounds" -Quiet
    Write-Host ""
    Write-Host ("world_map.gd calage bounds: {0}" -f $(if ($hasBounds) { "oui" } else { "NON (vieille version?)" }))
    if (-not $hasBounds) {
        $issues += "world_map.gd sans texture_core3_bounds — sync incomplete"
    }
}

if ($PrimeClientDir -ne $resolvedDir) {
    Write-Host ""
    Write-Host "Note: tu as passe -PrimeClientDir $PrimeClientDir mais le Launchpad utilise $resolvedDir"
}

Write-Host ""
if ($issues.Count -gt 0) {
    Write-Host "PROBLEMES:"
    foreach ($i in $issues) { Write-Host "  - $i" }
    Write-Host ""
    Write-Host "Fix: WSL -> bash tools/sync_prime_client_to_j.sh"
    Write-Host "     Launchpad -> galaxie Prime + JOUER (pas PreCu SWGEmu)"
    exit 2
}

Write-Host "OK — le Launchpad devrait ouvrir Godot sur la bonne copie."
Write-Host "Si Godot Editor ouvre un autre dossier (WSL, autre lecteur), ce n'est pas le Launchpad."
