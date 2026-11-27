import sys
import plistlib
from pathlib import Path
import xml.etree.ElementTree as ET

if sys.argv[1] == 'android':
    path = Path('android/app/src/main/AndroidManifest.xml')
    ns = 'http://schemas.android.com/apk/res/android'
    ET.register_namespace('android', ns)
    tree = ET.parse(path)
    root = tree.getroot()
    for permission in ('ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'INTERNET'):
        name = 'android.permission.' + permission
        if not any(e.get('{'+ns+'}name') == name for e in root.findall('uses-permission')):
            root.insert(0, ET.Element('uses-permission', {'{'+ns+'}name': name}))
    tree.write(path, encoding='utf-8', xml_declaration=True)
elif sys.argv[1] == 'ios':
    path = Path('ios/Runner/Info.plist')
    data = plistlib.loads(path.read_bytes())
    data['NSLocationWhenInUseUsageDescription'] = 'Infiniti CarOS dùng vị trí khi bạn bắt đầu hành trình để ước tính tốc độ và quãng đường.'
    path.write_bytes(plistlib.dumps(data))
else:
    raise SystemExit('Expected android or ios')
