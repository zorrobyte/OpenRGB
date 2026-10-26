# Rig lighting map (ROG Crosshair X870E Edition 20 build)

> **Rebuild after a format:** see [`rig/README.md`](rig/README.md). `rig/setup.ps1` restores everything here in one go.

Notes from mapping this rig's RGB with OpenRGB 1.1 on 2026-10-26.

## Setup facts

- OpenRGB 1.1.0 is installed at `C:\Program Files\OpenRGB` (winget `OpenRGB.OpenRGB`) and is the latest stable release.
- It also runs as a Windows service named **`OpenRGB`** (Automatic, SYSTEM).
  - Config lives in `C:\Program Files\OpenRGB\service_config` and logs in `service_config\logs`.
  - The SDK server listens on `127.0.0.1:6742`.
- The service holds the SMBus, so a second `OpenRGB.exe --list-devices` finds no RAM. The exe prints nothing to stdout either. **Drive the service over the SDK instead** (see below).
- **Armoury Crate conflict:** `ArmouryCrateService` and `LightingService` fight OpenRGB.
  - If the OpenRGB service starts while they run, the log shows `Failed to select PIIX4 port` and the RAM isn't detected.
  - Fix: `Stop-Service ArmouryCrateService,LightingService -Force; Restart-Service OpenRGB -Force`
  - Both are still set to Automatic and come back after a reboot.
  - Re-enable with `Start-Service ArmouryCrateService,LightingService`. They're needed for the GPU and AIO lighting.
- FURY CTRL is **not** installed. The installer is in Downloads, and it isn't needed.

## Device map

| SDK id | Device | Notes |
|---|---|---|
| 0 | Kingston Fury DDR5 DRAM | 4 zones (Fury Slot 1–4) × 12 LEDs = 48. No "Off" mode; use Direct + black. Direct has brightness 0–100. |
| 1 | Razer BlackWidow V4 Pro | |
| 2 | Razer Mouse Dock Pro | |
| 3 | Razer Basilisk V3 Pro 35K | |
| 4 | ASUS ROG CROSSHAIR X870E EDITION 20 (Aura USB `0B05:1BED`) | Direct mode only, **no brightness setting**. Dim by scaling the color. |
| 5 | Razer Kraken Ultimate | |

The SDK ids above are from before the 5090 was added. With our build the 5090 is id 1 and everything after it shifts by one, so look devices up by name. The Ryujin AIO's only LEDs are its fans, on header 5.

### Motherboard ARGB headers (device 4)

All counts were confirmed by eye using blink tests.

| Zone | Header | Drives | LEDs |
|---|---|---|---|
| 0 | Aura Mainboard | Nothing visible | 1 |
| 1 | ARGB Header 1 | Nothing | n/a (left at 60) |
| 2 | ARGB Header 2 | Nothing | n/a (left at 60) |
| 3 | ARGB Header 3 | **Case** strips | **80** |
| 4 | ARGB Header 4 | **PSU** (display + logo) | **18** |
| 5 | ARGB Header 5 | **Radiator fans** | **24** (3 × 8) |

PSU detail:
- **LED 1** drives both the first segment of the PSU display **and** the single logo LED. They're wired together and can't be split.
- LEDs 2–18 are the rest of the display.

Armoury Crate's `C:\Program Files (x86)\LightingService\LastProfile.xml` doesn't help with counts. It says 120 for headers 1–4, which is just the default for headers that can't report a count, and 48 for header 5, which is wrong.

## Current look (saved, loads at boot)

- Board headers and the 5090: RGB `0,3,0` (about 1% green).
- RAM: Direct mode, green `0,255,0`, brightness 1.
- Razer keyboard, mouse, dock and headset: `0,255,0`.

It's saved as the profile `rig-green` (`service_config\profiles\rig-green.json`). `OpenRGB.json` → `ProfileManager` → `service_startup_profile` and `resume_profile` both point at it.
- openrgb-python (SDK v4) **can't** save profiles. The server only accepts saves from a protocol-6 client that sets `NET_CLIENT_FLAG_REQUEST_LOCAL_CLIENT`.
- To save anyway: send packets 50 (name), 40 (protocol 6), 52 (flags `1<<16`), then 151 with the profile name.

## Vendor software status

- Armoury Crate and Razer Chroma were uninstalled; the ASUS services had been disabled first.
- Razer Synapse is still installed for DPI and macros, with **lighting brightness set to Off in Synapse**. With brightness off, Synapse leaves the lights to OpenRGB.
- Windows Dynamic Lighting is off (`HKCU\Software\Microsoft\Lighting\AmbientLightingEnabled = 0`).

## RTX 5090 Edition 20

- PCI subsystem `1043:8A8C`, with an ENE SMBus controller at `0x67` on NvAPI I2C. Registers `0xA0`–`0xAF` read back `0x00`–`0x0F`. It has 20 LEDs in one zone.
- Support is added on branch `asus-astral-5090-edition20` (2 lines). That build is installed over `C:\Program Files\OpenRGB`.
- To roll back: `winget install --force OpenRGB.OpenRGB`.
- Build setup: Qt 6.8.3 msvc2022_64 and jom in `~/dev/tools`, using `qmake` + `jom` + `windeployqt` (same steps as `scripts/build-windows.bat`).

## Driving it from Python

```powershell
uv venv orgbvenv; uv pip install --python orgbvenv\Scripts\python.exe openrgb-python
```

```python
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

c = OpenRGBClient('127.0.0.1', 6742, 'claude')

# RAM: green at 1 %
ram = c.devices[0]
m = ram.modes[0]          # Direct
m.brightness = 1
ram.set_mode(m)
ram.set_color(RGBColor(0, 255, 0))

# Board headers: dim green everywhere
mb = c.devices[4]
mb.set_mode('Direct')
mb.set_color(RGBColor(0, 3, 0))
```

Gotchas:
- `zone.resize(n)` blacks out the **other** zones on the board, so re-apply colors after resizing.
- Zone sizes are held by the service and reset when it restarts. Re-apply `resize(80/18/24)` on zones 3/4/5 until a profile is saved.

### Blink test used to count LEDs

Lights the first `lo` LEDs solid and blinks LEDs `lo+1..hi` on the given zone.

```python
# flash.py <half_seconds> <lo> <zone> [hi]
import sys, time
from openrgb import OpenRGBClient as C
from openrgb.utils import RGBColor
c = C('127.0.0.1', 6742, 'claude'); z = c.devices[4].zones[int(sys.argv[3])]
G, K = RGBColor(0, 255, 0), RGBColor(0, 0, 0)
lo = int(sys.argv[2]); hi = int(sys.argv[4]) if len(sys.argv) > 4 else lo + 1
for t in range(int(sys.argv[1])):
    n = hi if t % 2 == 0 else lo
    z.set_colors([G if i < n else K for i in range(len(z.leds))]); time.sleep(0.5)
```

## Repo

- Fork: https://github.com/zorrobyte/OpenRGB (`origin`); `upstream` is `CalcProgrammer1/OpenRGB`, a GitHub mirror.
- The canonical repo and merge requests are at https://gitlab.com/CalcProgrammer1/OpenRGB. `glab` isn't logged in yet.
- The Aura USB header limit is `AURA_ADDRESSABLE_MAX_LEDS = 500` (`Controllers/AsusAuraUSBController/AsusAuraUSBController/RGBController_AsusAuraUSB.h`).

## Effects Plugin

- Built from https://gitlab.com/OpenRGBDevelopers/OpenRGBEffectsPlugin at commit `2087656`, with its `OpenRGB` submodule pointed at our fork commit.
- It's installed to `%APPDATA%\OpenRGB\plugins\OpenRGBEffectsPlugin.dll` and runs inside the OpenRGB GUI, which connects to the service as a client. Effects stop when the GUI closes; minimized to the tray is fine.
- Effect settings live in `%APPDATA%\OpenRGB\plugins\settings`. `rig/sync-from-system.ps1` copies them into the repo.
