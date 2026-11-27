from pathlib import Path

def configure_glass():
    target = Path('ios/Runner/AppDelegate.swift')
    marker = '// INFINITI_GLASS_BRIDGE'
    text = target.read_text()
    if marker in text:
        return
    needle = 'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)'
    if needle not in text:
        raise RuntimeError('Unsupported AppDelegate template; review UIScene registration')
    text = text.replace(needle, needle + '\n    registerInfinitiGlass(engineBridge.pluginRegistry)\n    registerInfinitiFace(engineBridge.pluginRegistry)\n    registerInfinitiShortcuts(engineBridge.pluginRegistry)', 1)
    source = Path('native/ios/GlassBar.swift').read_text() + '\n' + Path('native/ios/FaceControl.swift').read_text() + '\n' + Path('native/ios/AppShortcuts.swift').read_text()
    target.write_text(text + '\n' + marker + '\n' + source)
