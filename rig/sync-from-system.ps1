# Copy the live OpenRGB profiles and the Rog20 app settings back into this repo,
# so rig\setup.ps1 restores exactly what's on the machine now. Commit + push afterwards.
$Rig = $PSScriptRoot
New-Item -ItemType Directory -Force "$Rig\profiles", "$Rig\config\rog20" | Out-Null
Copy-Item "C:\Program Files\OpenRGB\service_config\profiles\*.json" "$Rig\profiles\" -Force
foreach ($f in 'settings.json', 'pins.json') {
    $src = "$env:APPDATA\Rog20Monitor\$f"
    if (Test-Path $src) { Copy-Item $src "$Rig\config\rog20\" -Force }
}
git -C $Rig status --short -- .
