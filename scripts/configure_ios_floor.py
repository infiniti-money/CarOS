"""Raise iOS app deployment floor to match flutter_carplay."""
import re
from pathlib import Path

def configure_ios_floor():
    project = Path('ios/Runner.xcodeproj/project.pbxproj')
    text = project.read_text()
    changed, count = re.subn(r'IPHONEOS_DEPLOYMENT_TARGET = (\d+(?:\.\d+)?);', lambda m: 'IPHONEOS_DEPLOYMENT_TARGET = ' + ('14.0' if float(m[1]) < 14 else m[1]) + ';', text)
    if not count:
        raise ValueError('No iOS deployment targets found')
    project.write_text(changed)
    pod = Path('ios/Podfile')
    if pod.exists():
        text = pod.read_text()
        pattern = r"(?m)^\s*#?\s*platform\s+:ios,\s*['\"](\d+(?:\.\d+)?)['\"]"
        text, count = re.subn(pattern, lambda m: "platform :ios, '" + ('14.0' if float(m[1]) < 14 else m[1]) + "'", text)
        if not count:
            text = "platform :ios, '14.0'\n" + text
        pod.write_text(text)

if __name__ == '__main__':
    configure_ios_floor()
