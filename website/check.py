from pathlib import Path
from html.parser import HTMLParser
import json

root = Path(__file__).parent / 'dist'
class Check(HTMLParser):
    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        for name in ['href', 'src']:
            value = attributes.get(name, '')
            if value.startswith('/'):
                target = root / value.lstrip('/')
                assert target.exists(), f'Missing local target: {value}'
        if tag == 'img': assert 'alt' in attributes

for file in root.rglob('*.html'):
    text = file.read_text()
    assert 'lang="zh-CN"' in text
    Check().feed(text)
settings = json.loads((root.parent/'site.json').read_text())
assert '@' in settings['supportEmail']
assert '尚未在 App Store 上架' in (root/'updates/index.html').read_text()
print('Website: internal links, image alternatives, locale and honest release status passed')
