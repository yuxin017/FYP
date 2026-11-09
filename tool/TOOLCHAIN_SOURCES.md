# Pinned toolchain sources

The Windows bootstrap uses the versions, URLs and SHA256 digests in
`tool/toolchains.json`. It verifies downloads before extraction and execution.

- Flutter 3.41.0 / Dart 3.11.0: [official archive](https://docs.flutter.dev/install/archive);
  [release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json).
- Node 22.23.4: [official distribution checksums](https://nodejs.org/dist/v22.23.4/SHASUMS256.txt).
- Python 3.12.14: [Astral python-build-standalone release 20260901](https://github.com/astral-sh/python-build-standalone/releases/tag/20260901).
  This is the standalone Python distribution also used by uv. Its Windows asset
  digest was checked against the publisher's release metadata.
- Firebase CLI 15.35.0: npm dependency pinned in `tool/firebase/package.json`;
  its dependency graph and registry integrity values are in the adjacent lockfile.
- AI package versions: `ai/requirements.txt`. Model hashes, source revisions and
  licences: `ai/model_manifest.json` and `ai/licenses/`.

Runtime locations are discovered or installed on each PC and recorded in the
ignored `.local/runtime.json`. No author-specific runtime paths or credentials
need to be copied into a clone.
