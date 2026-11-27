"""Configure standalone phone background audio; do not use for car host builds."""
import plistlib
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = 'http://schemas.android.com/apk/res/android'
A = '{' + ANDROID + '}'
ET.register_namespace('android', ANDROID)

def configure_android(path):
    tree = ET.parse(path)
    root = tree.getroot()
    app = root.find('application')
    if app is None:
        raise ValueError('Missing application')
    activities = [e for e in app.findall('activity')
        if any(a.get(A+'name') == 'android.intent.action.MAIN' for a in e.findall('intent-filter/action'))]
    if len(activities) != 1:
        raise ValueError('Expected exactly one launcher activity')
    activity = activities[0]
    if activity.get(A+'name') not in ('.MainActivity', 'com.ryanheise.audioservice.AudioServiceActivity'):
        raise ValueError('Unexpected launcher activity; refusing to overwrite')
    activity.set(A+'name', 'com.ryanheise.audioservice.AudioServiceActivity')
    for suffix in ('WAKE_LOCK', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK'):
        name = 'android.permission.' + suffix
        if not any(e.get(A+'name') == name for e in root.findall('uses-permission')):
            root.insert(0, ET.Element('uses-permission', {A+'name': name}))
    def component(tag, name, action, attrs):
        entries = [e for e in app.findall(tag) if e.get(A+'name') == name]
        if len(entries) > 1:
            raise ValueError('Duplicate media component')
        element = entries[0] if entries else ET.SubElement(app, tag, {A+'name': name})
        element.attrib.update(attrs)
        if not any(e.get(A+'name') == action for e in element.findall('intent-filter/action')):
            intent = ET.SubElement(element, 'intent-filter')
            ET.SubElement(intent, 'action', {A+'name': action})
    component('service', 'com.ryanheise.audioservice.AudioService',
        'android.media.browse.MediaBrowserService',
        {A+'exported':'true', A+'foregroundServiceType':'mediaPlayback'})
    component('receiver', 'com.ryanheise.audioservice.MediaButtonReceiver',
        'android.intent.action.MEDIA_BUTTON', {A+'exported':'true'})
    tree.write(path, encoding='utf-8', xml_declaration=True)

def configure_ios(path):
    data = plistlib.loads(path.read_bytes())
    modes = data.setdefault('UIBackgroundModes', [])
    if 'audio' not in modes:
        modes.append('audio')
    path.write_bytes(plistlib.dumps(data))

if __name__ == '__main__':
    if sys.argv[1:] == ['android']:
        configure_android(Path('android/app/src/main/AndroidManifest.xml'))
    elif sys.argv[1:] == ['ios']:
        configure_ios(Path('ios/Runner/Info.plist'))
    else:
        raise SystemExit('Expected android or ios')
