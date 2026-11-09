"""Install only the pinned, integrity-checked official OpenCV models."""
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "ai/model_manifest.json").read_text())
destination = root / ".local/models"
destination.mkdir(parents=True, exist_ok=True)
for key, model in manifest["models"].items():
    target = destination / model["file"]
    if target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == model["sha256"]:
        print(f"{key}: verified")
        continue
    request = Request(model["url"], headers={"User-Agent": "FYP-model-setup"})
    with urlopen(request, timeout=120) as response:
        data = response.read(50_000_000)
    if len(data) != model["size"] or hashlib.sha256(data).hexdigest() != model["sha256"]:
        raise RuntimeError(f"Integrity check failed for {key}; model was not installed.")
    target.write_bytes(data)
    print(f"{key}: installed and verified")
