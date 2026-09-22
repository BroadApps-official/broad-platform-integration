#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import sys

derived, example = map(Path, sys.argv[1:])
tokens = (b'BroadRUBilling', b'RUCheckout', b'RUCatalogProduct', b'ruBilling')
for config in ('Debug-iphonesimulator', 'Release-iphoneos'):
    app = derived / 'Build/Products' / config / 'BroadAppleOnlyTemplate.app'
    if not app.is_dir():
        raise SystemExit(f'Missing app: {app}')
    for path in app.rglob('*'):
        if any(token.decode() in path.name for token in tokens):
            raise SystemExit(f'Unexpected optional billing artifact: {path.name}')
        if not path.is_file():
            continue
        kind = subprocess.run(['file', '-b', str(path)], capture_output=True, text=True, check=True).stdout
        if 'Mach-O' not in kind:
            continue
        result = subprocess.run(['xcrun', 'nm', '-a', str(path)], capture_output=True, check=True)
        symbols = subprocess.run(['xcrun', 'swift-demangle'], input=result.stdout, capture_output=True, check=True).stdout
        strings = subprocess.run(['strings', '-a', str(path)], capture_output=True, check=True).stdout
        if any(token in symbols or token in strings for token in tokens):
            raise SystemExit(f'Unexpected RU symbol in {path.name}')
resolved = example / 'BroadAppleOnlyTemplate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
pins = json.loads(resolved.read_text())['pins']
if any('ru-billing' in pin['identity'] for pin in pins):
    raise SystemExit('Apple-only package resolution fetched RU billing')
print('Apple-only Debug/Release passed: no RU package, linked symbols or artifacts.')
