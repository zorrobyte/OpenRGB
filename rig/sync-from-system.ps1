# Copy the live OpenRGB profiles and Effects Plugin settings back into this repo,
# so rig\setup.ps1 restores exactly what's on the machine now. Commit + push afterwards.
$Rig = $PSScriptRoot
New-Item -ItemType Directory -Force "$Rig\profiles", "$Rig\config\plugin-settings" | Out-Null
Copy-Item "C:\Program Files\OpenRGB\service_config\profiles\*.json" "$Rig\profiles\" -Force
$ps = "$env:APPDATA\OpenRGB\plugins\settings"
if (Test-Path $ps) { Copy-Item "$ps\*" "$Rig\config\plugin-settings\" -Recurse -Force }
git -C $Rig status --short -- .
