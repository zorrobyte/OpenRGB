# Flash the Razer Kraken headset between red and green until stopped.
import sys, time
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

interval = float(sys.argv[1]) if len(sys.argv) > 1 else 0.5
c = OpenRGBClient('127.0.0.1', 6742, 'headset_flash')
k = next(d for d in c.devices if 'Kraken' in d.name)
k.set_mode('Direct')
colors = [RGBColor(255, 0, 0), RGBColor(0, 255, 0)]
i = 0
while True:
    k.set_color(colors[i % 2], fast=True)
    i += 1
    time.sleep(interval)
