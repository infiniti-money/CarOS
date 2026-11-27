"""Opt-in car host setup. Default app configuration is untouched.
Run after flutter create and configure_location.py. iOS device profile is checked
locally; this never requests Apple approval or installs a signing identity.
"""
import argparse
import datetime
import plistlib
import subprocess
from pathlib import Path
import xml.etree.ElementTree as ET

NS = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', NS)
A = '{' + NS + '}'
KEY = 'com.apple.developer.carplay-driving-task'
BUNDLE = 'com.infinitimoney.infinitiCaros'

def verify_profile(profile, bundle):
    data = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(profile)]))
    ent = data.get('Entitlements', {})
    expiration = data.get('ExpirationDate')
    now = datetime.datetime.now(datetime.timezone.utc)
    if expiration is None:
        raise ValueError('Profile has no expiration')
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=datetime.timezone.utc)
    if expiration <= now:
        raise ValueError('Provisioning profile expired')
    app_id = ent.get('application-identifier', '')
    if app_id.split('.', 1)[-1] != bundle or ent.get(KEY) is not True:
        raise ValueError('Profile does not match bundle and approved driving-task entitlement')

def ios(args):
    if not args.simulator:
        if not args.profile or not args.bundle_id:
            raise ValueError('Device build requires --profile and --bundle-id')
        verify_profile(args.profile, args.bundle_id)
    runner = Path('ios/Runner')
    plist = runner / 'Info.plist'
    data = plistlib.loads(plist.read_bytes())
    manifest = data.setdefault('UIApplicationSceneManifest', {})
    configs = manifest.setdefault('UISceneConfigurations', {})
    manifest['UIApplicationSupportsMultipleScenes'] = False
    configs['CPTemplateApplicationSceneSessionRoleApplication'] = [{
        'UISceneConfigurationName': 'CarPlay Configuration',
        'UISceneDelegateClassName': 'flutter_carplay.FlutterCarPlaySceneDelegate',
    }]
    configs['UIWindowSceneSessionRoleApplication'] = [{
        'UISceneConfigurationName': 'Default Configuration',
        'UISceneDelegateClassName': '$(PRODUCT_MODULE_NAME).InfinitiPhoneScene',
    }]
    plist.write_bytes(plistlib.dumps(data))
    app = runner / 'AppDelegate.swift'
    app.write_text(Path('native/car/CarAppDelegate.swift').read_text())
    if not args.simulator:
        (runner / 'CarPlay.entitlements').write_bytes(plistlib.dumps({KEY: True}))
        # Signing identity, team, profile and bundle must still be configured in Xcode.
        # No blanket entitlement is enabled in the ordinary phone build.
        for name in ('Debug', 'Release', 'Profile'):
            config = Path('ios/Flutter') / (name + '.xcconfig')
            if config.exists():
                text = config.read_text()
                marker = 'CODE_SIGN_ENTITLEMENTS = Runner/CarPlay.entitlements'
                if marker not in text:
                    config.write_text(text + '\n' + marker + '\n')
        print('Profile matches entitlement; select matching team/profile and bundle in Xcode.')

def android(args):
    if not args.development:
        raise ValueError('POI template prototype requires --development; no production service is enabled')
    app = Path('android/app/src/main')
    path = app / 'AndroidManifest.xml'
    tree = ET.parse(path)
    root = tree.getroot()
    def unique(parent, tag, name, attrs):
        node = next((e for e in parent.findall(tag) if e.get(A + 'name') == name), None)
        if node is None:
            node = ET.SubElement(parent, tag, {A + 'name': name})
        node.attrib.update(attrs)
        return node
    unique(root, 'uses-feature', 'android.software.car.app.library', {A+'required':'false'})
    application = root.find('application')
    if application is None:
        raise ValueError('Application manifest missing')
    unique(application, 'meta-data', 'com.google.android.gms.car.application', {A+'resource':'@xml/automotive_app_desc'})
    unique(application, 'meta-data', 'androidx.car.app.minCarApiLevel', {A+'value':'1'})
    service = unique(application, 'service', 'com.oguzhnatly.flutter_android_auto.AndroidAutoService', {A+'exported':'true'})
    if service.find('intent-filter') is None:
        intent = ET.SubElement(service, 'intent-filter')
        ET.SubElement(intent, 'action', {A+'name':'androidx.car.app.CarAppService'})
        ET.SubElement(intent, 'category', {A+'name':'androidx.car.app.category.POI'})
    tree.write(path, encoding='utf-8', xml_declaration=True)
    res = app / 'res/xml/automotive_app_desc.xml'
    res.parent.mkdir(parents=True, exist_ok=True)
    res.write_text('<automotiveApp><uses name="template"/></automotiveApp>\n')
    activities = list(app.glob('kotlin/**/MainActivity.kt'))
    if len(activities) != 1:
        raise ValueError('Expected exactly one Kotlin MainActivity')
    activity = activities[0]
    package = next(line for line in activity.read_text().splitlines() if line.startswith('package '))
    activity.write_text(package + '\n' + Path('native/car/MainActivity.body.kt').read_text())

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['ios', 'android'])
    parser.add_argument('--simulator', action='store_true')
    parser.add_argument('--development', action='store_true')
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--bundle-id')
    args = parser.parse_args()
    if args.platform == 'ios':
        ios(args)
    else:
        android(args)
