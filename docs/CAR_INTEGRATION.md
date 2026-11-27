# CarPlay / Android Auto — opt-in prototype

Uses infiniti-money/carplay pinned at b457538fab39aa2cac112bfc4c23cad749ada4dd (strict AndroidX HostValidator patch PR #1, pending CI), originally flutter_carplay by Oğuzhan Atalay, MIT. See upstream LICENSE. Keep the phone interface independent. No vehicle telemetry, video, camera, arbitrary Flutter dashboard, calling or unsafe controls on car display. A native list shows whether a valid saved parking position exists; coordinates stay on phone. Tap to refresh. This is a prototype, not an approved CarPlay driving-task or Android Auto POI app.

## Development
Generate platform scaffolds using Flutter 3.44.2 and run scripts/configure_location.py <platform>. Then run scripts/configure_car_host.py ios --simulator or scripts/configure_car_host.py android --development. Build with --target lib/car_main.dart --dart-define=CAROS_CAR_HOST=true. Ordinary main.dart and standard builds do not start controllers or configure exported service/CarPlay scenes. Use the shared engine and official native templates. The Android service uses a strict AndroidX certificate/package allowlist; emulator hosts might be rejected. No bypass. Android POI category is a development prototype only; production requires actual eligible functionality, review and host/device verification.

## iOS official entitlement
Proposed category: driving task (parking reminder prototype, eligibility not established). Request approval first at https://developer.apple.com/contact/carplay . For an approved app, download the matching unexpired provisioning profile, then run python3 scripts/configure_car_host.py ios --profile /path/to/profile.mobileprovision --bundle-id YOUR_EXACT_BUNDLE_ID . This checks the decoded profile for matching application identifier and com.apple.developer.carplay-driving-task=true before setting the entitlement file. Configure matching bundle ID, team, provisioning profile and signing identity in Xcode. Local profile check is not proof of Apple approval or signature validation; Xcode/Apple signing is authoritative. No device credentials or entitlement grants are fabricated. Simulator configuration does not inject signing entitlement. Never use unrelated categories to bypass restrictions.

Apple: https://developer.apple.com/documentation/carplay/preparing-your-ios-app-for-carplay-development
Android: https://developer.android.com/training/cars/apps/auto
HostValidator: https://developer.android.com/reference/androidx/car/app/CarAppService
Source: https://github.com/infiniti-money/carplay

Future integration: reconcile shared engine registration with the pending SwiftUI glass and FaceControl bridges before combining branches. Test host connect/disconnect, root updates, phone cold launch, valid signatures, unknown hosts, signed iPhone and actual head unit. No claim of production support until these pass.

## iOS build floor
CI initially failed because flutter_carplay requires iOS 14.0 or later while the generated app was 13.0. Both CI workflows now run scripts/configure_ios_floor.py after generating platform scaffolds. This raises only lower deployment targets and preserves higher ones.

## Category-specific prototype
The iOS setup now accepts --category driving-task or --category audio. Each category writes its matching entitlement only after profile validation; the simulator stores the category in Info.plist without granting an entitlement. Dart reads that native configuration and only creates the category-specific list. Audio requires a configured HTTPS radio URL supplied as --dart-define=CAROS_CAR_AUDIO_URL=...; user initiates playback or stop, no auto-start. Playback request is not a claim of audible output. No full Now Playing/remote commands, background audio, audio focus arbitration with the phone screen or Spotify/MusicKit integration yet. Android remains POI development only: do not declare MEDIA before MediaSession and browser/library service are implemented. Navigation remains disabled because the pinned plugin does not expose CPMapTemplate or Android NavigationTemplate; implement actual native navigation surfaces and routing lifecycle before declaring categories. No camera or face control on vehicle display. See https://developer.apple.com/documentation/carplay/cpmaptemplate and https://developer.android.com/training/cars/apps/media .
