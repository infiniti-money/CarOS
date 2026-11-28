# Nghiên cứu tham chiếu CarPlay iOS 3.0.2 (28/11/2026)
## Nguồn và phạm vi
ZIP người dùng cung cấp, SHA-256 55950e2f677fdd79eefc8f907fbb4d135778eae40576650523750d979d784ba4. 650 entries (446 files, 204 directories), 43,154,784 bytes uncompressed. Phân tích tĩnh ZIP, plist, NIB headers, tên/tỷ lệ PNG, localization tiếng Anh; không chạy binary hoặc scripts, không xác minh hành vi runtime. Không có mã nguồn đầy đủ hoặc giấy phép phân phối lại app được tìm thấy; giấy phép OSS Google SDK không phải giấy phép app. Không đưa file gốc vào repo.
## Kiến trúc gói
DEBIAN/control xác định com.jujucool290.carplayios 3.0.2, iphoneos-arm, firmware >=9.0, libactivator, BigBoss. Applications/CarPlay.app/CarPlay 29,085,488 bytes, Mach-O fat header. Info.plist: build 3000, Xcode 11.3, iOS SDK 13.2, hai hướng landscape, audio background, iPhone/iPad, khai báo quyền camera, danh bạ, vị trí, media/photos; mô tả quyền trống. ATS cho phép arbitrary loads: không sao chép. GoogleMaps/GooglePlaces bundle 3.8.0, dữ liệu Core Data cache, Assets.car, fonts và sprites. XCTest/XCTAutomationSupport, dylib hỗ trợ và test bundle/dSYM: không phải source app và không chứng minh test pass. 67 NIBArchive, 31 thư mục NIB chính, 192 PNG (122 ở root app), 155 .strings, 33 locale chính; không có vi.lproj trong app. en.lproj/Localizable.strings 175 mục. preinst/postinst và deamonFusion.sh có thao tác cài đặt hệ thống; không chạy/port.
## Nhóm màn hình, tài nguyên và hướng triển khai độc lập
| Nhóm | Bằng chứng tĩnh | CarOS / đề xuất |
|---|---|---|
| Launcher | Dashboard, Background, Configuration, Widgets; icon size, reorder/page, status bar trái/phải | Landscape PWA #38, hai trang SVG; đợt 1 kích thước icon; tùy chọn vị trí dock sau |
| Maps | Map, Plans, Navigation, GoogleMaps, NavigationGoogleMaps, Destinations, Localisation; icon POI, pin | OSM/MapLibre và OSRM cấu hình; bổ sung tìm POI hợp lệ, night mode, offline có quyền, hướng dẫn Việt |
| Phone | Communication, Clavier; keypad 131x138 PNG, tabs 96x96, favorites/recents/voicemail | Web keypad và danh bạ cục bộ; native dùng API quyền OS, không giả lịch sử/voicemail |
| Audio | Musique, Lecture, Spotify, SpotifyLecture, PodcastLecture; 62x62 media controls, 49x53 skip 15s | Radio thật hoặc liên kết chính thức; Spotify OAuth/MusicKit cần quyền; media queue/resume |
| Widgets | Wspeed/Wbattery/Wweather/WCamera/Wdriver/Wlocation (100x100); strings speed/battery/weather/preview | Đợt 1 pin thiết bị opt-in và GPS; weather nguồn thật có đồng ý; camera trạng thái/preview sau |
| Safety | Safely, SafetyReglages, Alert; clip duration/count, protected clips, camera angle and foreground restriction | Native dashcam quản lý vòng lặp, bảo vệ, xuất; Web hiện clip ngắn khi đã đỗ; ưu tiên an toàn |
| Trợ lý | SiriCopilote, Driver; start/stop gắn nguồn sạc, lời chào, thao tác status bar | Trợ lý Việt opt-in, shortcut hệ thống; không coi sạc là bằng chứng đang lái, không khóa máy tự động |
| Account | Activation, Achat, APropos, Merci | Không nhập license hoặc logic thanh toán của app khác, không dùng khóa trích từ binary |
## Thiết kế
PNG ứng dụng root thường 180–199 px; thời tiết 32/64 px theo ngày/đêm; biểu tượng điều khiển keypad/tabs có nhóm riêng; không chứng minh tỷ lệ màn hình hoặc layout pixel chỉ từ kích cỡ asset. Tạo SVG/CSS riêng, nền và hệ icon độc lập. Giữ SmartBar dưới theo ảnh mẫu CarOS, cho phép cấu hình bổ sung nếu kiểm thử đạt. Mặc định landscape, fallback dọc Safari. Ưu tiên chạm lớn, tránh chỉnh cài đặt khi lái.
## Trình tự
1. Launcher size và widget pin (đợt này, CI pending; không tính nghiệm thu 48).
2. Dock tùy chọn, điều khiển âm lượng trong app, thư viện audio/POI và bản địa hóa Việt.
3. Camera vòng lặp/khóa sự kiện và quyền riêng tư, native orientation sau #31.
4. Đối chứng thiết bị thật, provider/entitlement, bảo mật, hiệu năng và CI; không đánh dấu hoàn thành chỉ bằng NIB hoặc strings.
