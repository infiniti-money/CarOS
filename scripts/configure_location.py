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
    for permission in ('ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'INTERNET', 'RECORD_AUDIO', 'CAMERA', 'READ_CONTACTS', 'READ_CALENDAR', 'WRITE_CALENDAR'):
        name = 'android.permission.' + permission
        if not any(e.get('{'+ns+'}name') == name for e in root.findall('uses-permission')):
            root.insert(0, ET.Element('uses-permission', {'{'+ns+'}name': name}))
    queries = root.find('queries')
    if queries is None:
        queries = ET.SubElement(root, 'queries')
    if not any(e.get('{'+ns+'}name') == 'android.speech.RecognitionService' for e in queries.findall('intent/action')):
        intent = ET.SubElement(queries, 'intent')
        ET.SubElement(intent, 'action', {'{'+ns+'}name': 'android.speech.RecognitionService'})
    if not any(e.get('{'+ns+'}name') == 'android.intent.action.TTS_SERVICE' for e in queries.findall('intent/action')):
        intent = ET.SubElement(queries, 'intent')
        ET.SubElement(intent, 'action', {'{'+ns+'}name': 'android.intent.action.TTS_SERVICE'})
    gradle = Path('android/app/build.gradle.kts')
    if gradle.exists():
        gradle.write_text(gradle.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 24'))
    tree.write(path, encoding='utf-8', xml_declaration=True)
elif sys.argv[1] == 'ios':
    path = Path('ios/Runner/Info.plist')
    data = plistlib.loads(path.read_bytes())
    data['NSLocationWhenInUseUsageDescription'] = 'Infiniti CarOS dùng vị trí khi bạn bắt đầu hành trình để ước tính tốc độ và quãng đường.'
    data['NSCameraUsageDescription'] = 'Quay video hành trình khi bạn chủ động bật camera.'
    data['NSMicrophoneUsageDescription'] = 'Dùng micro khi bạn bật trợ lý giọng nói.'
    data['NSSpeechRecognitionUsageDescription'] = 'Nhận dạng lệnh tiếng Việt khi bạn yêu cầu.'
    data['NSContactsUsageDescription'] = 'Hiển thị danh bạ để bạn chọn người gọi.'
    data['NSCalendarsUsageDescription'] = 'Hiển thị lịch sắp tới khi bạn yêu cầu.'
    data['NSCalendarsFullAccessUsageDescription'] = 'Đọc lịch sắp tới; CarOS không sửa lịch trong phiên bản này.'
    data['CFBundleDevelopmentRegion'] = 'vi'
    data['CFBundleLocalizations'] = ['vi']
    path.write_bytes(plistlib.dumps(data))
    from configure_glass import configure_glass
    configure_glass()
else:
    raise SystemExit('Expected android or ios')
