# Rig RGB setup kit

This rebuilds the OpenRGB setup from `../RIG_LIGHTING.md` on a freshly formatted machine.

## One-shot restore

From an **elevated** PowerShell:

```powershell
winget install --id Git.Git -e
git clone --branch rig-notes https://github.com/zorrobyte/OpenRGB.git $env:USERPROFILE\dev\rig
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dev\rig\rig\setup.ps1
```

`setup.ps1` is idempotent. It does the following:
1. Installs Git, uv, Python 3.13, the .NET 10 SDK, PawnIO, OpenRGB (which provides the service) and the VS 2022 C++ Build Tools via winget.
2. If Armoury Crate is present, runs ASUS's signed uninstall tool (you click through it). Then it disables the leftover ASUS and Razer Chroma services and turns off Windows Dynamic Lighting.
3. Installs Qt 6.8.3 msvc2022_64 (via aqtinstall) and jom into `~/dev/tools`.
4. Clones the fork's `asus-astral-5090-edition20` branch (RTX 5090 Edition 20 support) to `~/dev/OpenRGB` and builds it.
5. Copies the build over `C:\Program Files\OpenRGB`, creating the `OpenRGB` service if it's missing.
6. Restores `profiles\*.json` into the service, and sets `rig-green` as the startup and resume profile.
7. Sets up the Rog20 master app (`zorrobyte/asus-20th-lcd-reactor`, branch `master-app`) in `~/Projects`: uninstalls FanControl and removes the old Effects Plugin, builds the Rog20Monitor engine and Rog20Control UI, restores `configog20\settings.json` (screens, fan curves, lighting), and registers the elevated `Rog20Monitor` logon task. The engine runs the fans and drives every light through the OpenRGB service's SDK, so the OpenRGB GUI isn't needed.

## Keeping the repo current

After changing lighting, fan curves or screen settings:

```powershell
powershell -File rig\sync-from-system.ps1   # pulls live OpenRGB profiles and the Rog20 settings into the repo
git add rig; git commit -m "Update rig settings"; git push
```

## Tools (`tools/`)

| Script | What it does |
|---|---|
| `orgb_profile.py load\|save <name>` | Loads or saves a profile on the service. Needs only Python's standard library (SDK protocol 6 plus the local-client flag, which openrgb-python can't do). |
| `set_startup_profile.py <OpenRGB.json> <name>` | Points `service_startup_profile` and `resume_profile` at a profile, keeping duplicate keys in the file intact. |
| `headset_flash.py [interval]` | Flashes the Kraken headset red and green (needs `openrgb-python`). |
| `nvprobe.py` | Read-only NvAPI I2C probe that checks for the ENE controller at 0x67 on the GPU. |

## Manual bits not covered

- The motherboard ARGB header LED counts (case 80, PSU 18, fans 24) are stored in the `rig-green` profile. If a profile ever loses them, re-measure with the blink test in `RIG_LIGHTING.md`.
- If Razer Synapse is reinstalled, set each device's lighting brightness to **Off**, or it will override OpenRGB at boot.
