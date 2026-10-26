# Point ProfileManager startup/resume profiles at a profile, preserving duplicate keys in OpenRGB.json.
import json, sys

path, name = sys.argv[1], sys.argv[2]

class Pairs(list):
    pass

def enc(o, ind=0):
    pad = "    " * (ind + 1)
    if isinstance(o, Pairs):
        if not o: return "{}"
        return "{\n" + ",\n".join(pad + json.dumps(k) + ": " + enc(v, ind + 1) for k, v in o) + "\n" + "    " * ind + "}"
    if isinstance(o, list):
        if not o: return "[]"
        return "[\n" + ",\n".join(pad + enc(v, ind + 1) for v in o) + "\n" + "    " * ind + "]"
    return json.dumps(o)

data = json.load(open(path, encoding="utf-8"), object_pairs_hook=Pairs)
pm = next((v for k, v in data if k == "ProfileManager"), None)
if pm is None:
    pm = Pairs(); data.append(("ProfileManager", pm))
for key in ("service_startup_profile", "resume_profile"):
    entry = Pairs([("enabled", True), ("name", name)])
    for i, (k, v) in enumerate(pm):
        if k == key: pm[i] = (k, entry); break
    else:
        pm.append((key, entry))
open(path, "w", encoding="utf-8").write(enc(data) + "\n")
print(enc(pm))
