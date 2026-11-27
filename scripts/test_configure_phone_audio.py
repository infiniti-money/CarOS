import plistlib
import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET
from configure_phone_audio import A, configure_android, configure_ios

class PhoneAudioTest(unittest.TestCase):
    def test_manifest_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AndroidManifest.xml'
            path.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name=".MainActivity"><intent-filter><action android:name="android.intent.action.MAIN"/></intent-filter></activity></application></manifest>')
            configure_android(path)
            configure_android(path)
            root = ET.parse(path).getroot()
            self.assertEqual(len(root.findall('uses-permission')), 3)
            self.assertEqual(len(root.findall('application/service')), 1)
            self.assertEqual(root.find('application/service').get(A+'foregroundServiceType'), 'mediaPlayback')
            self.assertEqual(root.find('application/activity').get(A+'name'), 'com.ryanheise.audioservice.AudioServiceActivity')
            self.assertEqual(len(root.findall('application/receiver')), 1)
    def test_custom_activity_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AndroidManifest.xml'
            original = '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name=".CustomActivity"><intent-filter><action android:name="android.intent.action.MAIN"/></intent-filter></activity></application></manifest>'
            path.write_text(original)
            with self.assertRaises(ValueError):
                configure_android(path)
            self.assertEqual(path.read_text(), original)
    def test_ios_preserves_modes_and_adds_audio_once(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Info.plist'
            path.write_bytes(plistlib.dumps({'UIBackgroundModes':['fetch']}))
            configure_ios(path)
            configure_ios(path)
            self.assertEqual(plistlib.loads(path.read_bytes())['UIBackgroundModes'], ['fetch','audio'])

if __name__ == '__main__':
    unittest.main()
