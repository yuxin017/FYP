"""Validate a clone's local AI installation without reading visitor data."""
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.local/python-deps'))
for line in (ROOT / 'ai/requirements.txt').read_text().splitlines():
    if '==' not in line or line.lstrip().startswith('#'):
        continue
    name, version = line.strip().split('==')
    if importlib.metadata.version(name) != version:
        raise RuntimeError(f'Run tool/setup.cmd to restore {name} {version}.')
import cv2
import numpy
import sklearn
import scipy
manifest = json.loads((ROOT / 'ai/model_manifest.json').read_text())
for model in manifest['models'].values():
    file = ROOT / '.local/models' / model['file']
    if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != model['sha256']:
        raise RuntimeError('Run tool/setup.cmd to restore the recognition models.')
print('AI dependencies and recognition model checksums verified.')
