# One-shot rebuild of the rig's RGB setup on a fresh Windows install.
# Run from an elevated PowerShell:  powershell -ExecutionPolicy Bypass -File rig\setup.ps1
# Every step is idempotent; re-running it is safe.

param(
    [string]$Dev   = "$env:USERPROFILE\dev",
    [string]$Fork  = "https://github.com/zorrobyte/OpenRGB.git",
    [string]$Branch = "asus-astral-5090-edition20",
    [string]$EffectsRepo   = "https://gitlab.com/OpenRGBDevelopers/OpenRGBEffectsPlugin.git",
    [string]$EffectsCommit = "2087656e24fecd1378d0fbacfcd7e3ff1ba627b1",
    [string]$QtVer = "6.8.3",
    [switch]$SkipVendorCleanup
)
$ErrorActionPreference = "Stop"
$Rig     = $PSScriptRoot
$Tools   = "$Dev\tools"
$QtBin   = "$Tools\Qt\$QtVer\msvc2022_64\bin"
$Install = "C:\Program Files\OpenRGB"
$SvcCfg  = "$Install\service_config"

function Step($m) { Write-Host "`n=== $m" -ForegroundColor Green }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this from an elevated (Administrator) PowerShell."
}

#--------------------------------------------------------------------------------
Step "Prerequisites (winget): git, uv, Python, VS Build Tools, PawnIO, OpenRGB"
#--------------------------------------------------------------------------------
$pkgs = @(
    @{ id = "Git.Git" },
    @{ id = "astral-sh.uv" },
    @{ id = "Python.Python.3.13" },
    @{ id = "namazso.PawnIO" },
    @{ id = "OpenRGB.OpenRGB" },
    @{ id = "Microsoft.VisualStudio.2022.BuildTools"; extra = "--override `"--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended`"" }
)
foreach ($p in $pkgs) {
    winget list --id $p.id -e --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "installing $($p.id)"
        Invoke-Expression "winget install --id $($p.id) -e --silent --accept-package-agreements --accept-source-agreements $($p.extra)"
    } else { Write-Host "$($p.id) already installed" }
}
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

#--------------------------------------------------------------------------------
if (-not $SkipVendorCleanup) {
Step "Vendor RGB software: keep it from fighting OpenRGB"
#--------------------------------------------------------------------------------
    # Armoury Crate / Aura: uninstall with ASUS's tool if present (GUI, needs clicks), then disable leftovers.
    if (Get-Service ArmouryCrateService -ErrorAction SilentlyContinue) {
        $ac = "$env:TEMP\ac-uninstall"
        New-Item -ItemType Directory -Force $ac | Out-Null
        Invoke-WebRequest "https://dlcdnets.asus.com/pub/ASUS/mb/14Utilities/Armoury_Crate_Uninstall_Tool.zip" -OutFile "$ac\tool.zip"
        Expand-Archive "$ac\tool.zip" -DestinationPath "$ac\x" -Force
        $exe = Get-ChildItem "$ac\x" -Recurse -Filter "Armoury Crate Uninstall Tool.exe" | Select-Object -First 1
        if ((Get-AuthenticodeSignature $exe.FullName).Status -ne "Valid") { throw "ASUS uninstall tool signature invalid" }
        Write-Host "Launching Armoury Crate Uninstall Tool - click through it, then press Enter here."
        Start-Process $exe.FullName -WorkingDirectory $exe.DirectoryName
        Read-Host | Out-Null
    }
    $asus = 'ArmouryCrateService','LightingService','Aura Wallpaper Service','ROG Live Service','AsusROGLSLService',
            'AsusUpdateCheck','asus','asusm','AsusFanControlService','AsusCertService','asComSvc'
    foreach ($s in $asus) {
        if (Get-Service -Name $s -ErrorAction SilentlyContinue) {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s -StartupType Disabled
            Write-Host "disabled $s"
        }
    }
    # Razer: Chroma SDK services off. (Synapse was removed entirely; if you reinstall it, set lighting brightness to Off.)
    foreach ($s in 'Razer Chroma SDK Server','Razer Chroma SDK Service','Razer Chroma SDK Diagnostic Service','Razer Chroma Stream Server') {
        if (Get-Service -Name $s -ErrorAction SilentlyContinue) {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s -StartupType Disabled
            Write-Host "disabled $s"
        }
    }
    # Windows Dynamic Lighting off (it drives Razer devices through LampArray).
    New-Item -Path HKCU:\Software\Microsoft\Lighting -Force | Out-Null
    Set-ItemProperty HKCU:\Software\Microsoft\Lighting -Name AmbientLightingEnabled -Value 0 -Type DWord
}

#--------------------------------------------------------------------------------
Step "Qt $QtVer (msvc2022_64) and jom into $Tools"
#--------------------------------------------------------------------------------
New-Item -ItemType Directory -Force "$Tools\Qt", "$Tools\jom" | Out-Null
if (-not (Test-Path "$QtBin\qmake.exe")) {
    uv tool run --from aqtinstall aqt install-qt windows desktop $QtVer win64_msvc2022_64 -m qt5compat --outputdir "$Tools\Qt"
}
if (-not (Test-Path "$Tools\jom\jom.exe")) {
    Invoke-WebRequest https://download.qt.io/official_releases/jom/jom.zip -OutFile "$Tools\jom\jom.zip"
    Expand-Archive "$Tools\jom\jom.zip" -DestinationPath "$Tools\jom" -Force
}

#--------------------------------------------------------------------------------
Step "Clone and build our OpenRGB fork ($Branch)"
#--------------------------------------------------------------------------------
New-Item -ItemType Directory -Force $Dev | Out-Null
if (-not (Test-Path "$Dev\OpenRGB\.git")) {
    git clone --branch $Branch $Fork "$Dev\OpenRGB"
    git -C "$Dev\OpenRGB" remote add upstream https://gitlab.com/CalcProgrammer1/OpenRGB.git
}
$forkCommit = (git -C "$Dev\OpenRGB" rev-parse "origin/$Branch").Trim()
cmd /c "`"$Rig\build-openrgb.bat`" `"$Dev\OpenRGB`" `"$QtBin`" `"$Tools\jom`""
if ($LASTEXITCODE -ne 0) { throw "OpenRGB build failed ($LASTEXITCODE)" }

#--------------------------------------------------------------------------------
Step "Clone and build the Effects Plugin against the fork"
#--------------------------------------------------------------------------------
$fx = "$Dev\OpenRGBEffectsPlugin"
if (-not (Test-Path "$fx\.git")) { git clone --recurse-submodules $EffectsRepo $fx }
git -C $fx checkout -q $EffectsCommit
git -C $fx submodule update --init --recursive
git -C "$fx\OpenRGB" fetch -q "$Dev\OpenRGB" $forkCommit
git -C "$fx\OpenRGB" checkout -q $forkCommit
cmd /c "`"$Rig\build-effects.bat`" `"$fx`" `"$QtBin`" `"$Tools\jom`""
if ($LASTEXITCODE -ne 0) { throw "Effects plugin build failed ($LASTEXITCODE)" }

#--------------------------------------------------------------------------------
Step "Install our OpenRGB build over $Install and (re)create the service"
#--------------------------------------------------------------------------------
if (Get-Service OpenRGB -ErrorAction SilentlyContinue) { Stop-Service OpenRGB -Force }
Get-Process OpenRGB -ErrorAction SilentlyContinue | Stop-Process -Force
Copy-Item "$Dev\OpenRGB\release\*" $Install -Recurse -Force
Copy-Item "$QtBin\Qt6Core5Compat.dll", "$QtBin\Qt6OpenGL.dll" $Install -Force
if (-not (Get-Service OpenRGB -ErrorAction SilentlyContinue)) {
    New-Service -Name OpenRGB -BinaryPathName "`"$Install\OpenRGB.exe`"" -DisplayName OpenRGB -StartupType Automatic | Out-Null
}
Set-Service OpenRGB -StartupType Automatic

#--------------------------------------------------------------------------------
Step "Profiles and startup profile"
#--------------------------------------------------------------------------------
New-Item -ItemType Directory -Force "$SvcCfg\profiles" | Out-Null
Copy-Item "$Rig\profiles\*.json" "$SvcCfg\profiles\" -Force
Start-Service OpenRGB        # first start writes OpenRGB.json with defaults
Start-Sleep 20
Stop-Service OpenRGB -Force
$py = (Get-Command python).Source
& $py -I "$Rig\tools\set_startup_profile.py" "$SvcCfg\OpenRGB.json" rig-green
Start-Service OpenRGB

#--------------------------------------------------------------------------------
Step "Effects Plugin for the GUI (per user)"
#--------------------------------------------------------------------------------
$plug = "$env:APPDATA\OpenRGB\plugins"
New-Item -ItemType Directory -Force "$plug\settings\effect-profiles" | Out-Null
Copy-Item "$fx\release\OpenRGBEffectsPlugin.dll" $plug -Force
if (Test-Path "$Rig\config\plugin-settings") { Copy-Item "$Rig\config\plugin-settings\*" "$plug\settings\" -Recurse -Force }

Step "Done. Open OpenRGB (it connects to the service) and check the device list."
Write-Host "Expected: Kingston Fury DDR5 DRAM, ASUS ROG ASTRAL GeForce RTX 5090 OC EDITION 20, ROG CROSSHAIR X870E EDITION 20, Razer devices."
