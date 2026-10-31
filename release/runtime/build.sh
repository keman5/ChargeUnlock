#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
exec python3 -u - <<'PY'
import hashlib
import json
import pathlib
import plistlib
import signal
import subprocess
from urllib.parse import urlparse

# Use the Apple catalog refreshed by xcodebuild, without changing system proxy settings.
catalog = pathlib.Path('/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/com_apple_MobileAsset_iOSSimulatorRuntime.xml')
assets = plistlib.loads(catalog.read_bytes())['Assets']
matches = [a for a in assets if a.get('SimulatorVersion') == '27.1' and a.get('Architectures') == ['arm64']]
assert len(matches) == 1, 'Expected one Apple arm64 iOS 27.1 asset; refresh with xcodebuild first'
asset = matches[0]
url = asset['__BaseURL'] + asset['__RelativePath']
assert urlparse(url).scheme == 'https' and urlparse(url).hostname == 'updates.cdn-apple.com'
expected_hash = asset['_Measurement-SHA256']
assert isinstance(expected_hash, bytes) and len(expected_hash) == 32
build = asset['Build']
assert build.isalnum()
destination = pathlib.Path.home() / 'Downloads' / 'PlugLit-runtime' / build
destination.mkdir(parents=True, exist_ok=True)
(destination / 'apple-catalog.plist').write_bytes(catalog.read_bytes())
archive = destination / 'runtime.aar'
child = None

def stop(signum, frame):
    if child is not None:
        child.terminate()
        child.wait()
    raise SystemExit(128 + signum)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def run(args):
    global child
    child = subprocess.Popen(args)
    result = child.wait()
    child = None
    if result:
        raise SystemExit(result)

print(f'Apple iOS 27.1 {build}: {asset["_DownloadSize"]} bytes', flush=True)
if not archive.exists() or archive.stat().st_size != asset['_DownloadSize']:
    run(['curl', '--fail', '--location', '--proto', '=https', '--retry', '5', '--connect-timeout', '30', '--continue-at', '-', '--output', str(archive), url])
assert archive.stat().st_size == asset['_DownloadSize'], 'Download size mismatch'
digest = hashlib.sha256()
with archive.open('rb') as source:
    for chunk in iter(lambda: source.read(8 * 1024 * 1024), b''):
        digest.update(chunk)
assert digest.digest() == expected_hash, 'Apple catalog SHA-256 mismatch'
print('PASS: official archive size and SHA-256', flush=True)
extracted = destination / 'extracted'
extracted.mkdir(exist_ok=True)
# MobileAsset uses nested asset operations, handled by aa's patch command.
run(['/usr/bin/aa', 'patch', '-i', str(archive), '-dst', str(extracted), '-key-value', 'base64:' + asset['ArchiveDecryptionKey']])
images = list(extracted.rglob('*.dmg'))
assert len(images) == 1, f'Expected one runtime disk image, found {len(images)}'
# CoreSimulator performs its own signature verification before mounting the image.
run(['xcrun', 'simctl', 'runtime', 'add', str(images[0])])
runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
assert any(r['version'] == '27.1' and r['buildversion'] == build and r['isAvailable'] for r in runtimes), 'Runtime not available'
print(f'PASS: iOS 27.1 {build} installed and available', flush=True)
PY
