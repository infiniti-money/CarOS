# Lộ trình Infiniti CarOS
- 2.0: Dashboard tiếng Việt, SmartBar, giao diện kính Flutter, tùy chọn lưu cục bộ, mở dịch vụ ngoài. Native Liquid Glass chưa triển khai.
- 2.1: GPS thật, quyền vị trí, lịch sử hành trình, bản đồ và đỗ xe.
- 2.2: phát nhạc/radio/podcast; Spotify và Apple Music theo quyền/API chính thức.
- 2.3: trợ lý tiếng Việt, liên lạc, lịch.
- 2.4: camera hành trình, điều khiển khuôn mặt chỉ khi an toàn, Shortcuts.
- 2.5: chia sẻ hành trình tự nguyện, SOS thủ công, tự động hóa.
- 3.0: kiểm thử thiết bị và xe, ký ứng dụng, phân phối.
## Điều kiện hoàn thành
Không giả tốc độ, kết nối xe, quyền hoặc trạng thái phát nhạc. Không dùng tài sản độc quyền của CarOS. Tích hợp thư viện carplay ở bước sau, giữ giấy phép MIT và ghi công. Apple CarPlay cần entitlement phù hợp; Android Auto cần phê duyệt danh mục. Không thao tác cài đặt khi lái xe.

## Ma trận nghiệm thu 48 tiêu chí — 2026-11-27
Mốc đối chiếu: `cc26926d2a17d5814a7e9f38daa48b55c1829774`. CI main [45964311888](https://github.com/infiniti-money/CarOS/actions/runs/45964311888) đạt verify và ios. PR #18 đã merge; head của #8–15 và #17 đều là tổ tiên của main. Không merge lại. Trạng thái Một phần/Vướng/Chưa xác minh không tính là Đạt. Hiện 0/48 được xác nhận nghiệm thu đầy đủ theo ma trận này; không có nghĩa là chưa triển khai chức năng nào. Chỉ chuyển Đạt khi có bằng chứng kiểm thử đúng SHA, phạm vi chức năng và thiết bị/provider nếu cần. Tài liệu mô tả không thay thế kiểm thử.

| ID | Nhóm | Tiêu chí | Trạng thái | Bằng chứng hiện có / việc còn thiếu |
|---|---|---|---|---|
| 1 | Bản đồ | 2D/3D và ban đêm | Một phần | docs/NAVIGATION.md: bản đồ 2D; chưa xác minh 3D/đêm |
| 2 | Bản đồ | Dẫn đường giọng Việt | Một phần | docs/NAVIGATION.md; test/navigation_test.dart; cần GPS/TTS thật |
| 3 | Bản đồ | ETA và quãng đường còn lại | Một phần | docs/NAVIGATION.md: tổng tuyến; cần xác minh cập nhật còn lại |
| 4 | Bản đồ | Đổi tuyến | Một phần | docs/NAVIGATION.md: heuristic opt-in; cần thực địa |
| 5 | Bản đồ | Lưu vị trí đỗ | Một phần | docs/GPS.md; test/trip_test.dart; cần thiết bị |
| 6 | Bản đồ | Bản đồ ngoại tuyến | Chưa xác minh | Cần nguồn tile có giấy phép và kiểm thử mất mạng |
| 7 | Launcher | Ngang/dọc | Một phần | docs/DESIGN.md; test/dashboard_test.dart; cần thiết bị |
| 8 | Launcher | Widget tùy chỉnh | Một phần | launcher_prefs.dart: lưu thứ tự/ẩn launcher; widget tự do chưa có; cần kiểm thử UI |
| 9 | Launcher | Chia đôi màn hình | Một phần | docs/DESIGN.md: hai cột, chưa xác minh split-screen OS |
| 10 | Launcher | Hình nền và biểu tượng | Một phần | launcher_editor.dart: ba nền gradient, ẩn/sắp xếp biểu tượng; chưa chọn ảnh cá nhân |
| 11 | Launcher | Sáng/tối tự động | Một phần | lib/main.dart: theo platformBrightness khi bật; chuyển thủ công tắt tự động; cần QA thiết bị |
| 12 | Launcher | Liquid Glass native | Một phần | native/ios/GlassBar.swift; docs/DESIGN.md; cần QA thật |
| 13 | Giải trí | Spotify API/OAuth | Vướng | docs/ENTERTAINMENT.md: cần Client ID/redirect và tài khoản hợp lệ |
| 14 | Giải trí | Apple Music/MusicKit | Vướng | docs/ENTERTAINMENT.md: cần quyền MusicKit và thiết bị ký |
| 15 | Giải trí | Radio/podcast | Một phần | docs/ENTERTAINMENT.md; test/entertainment_test.dart |
| 16 | Giải trí | Nhạc nền | Chưa xác minh | docs/ENTERTAINMENT.md: chưa hỗ trợ |
| 17 | Giải trí | Điều khiển màn hình khóa | Chưa xác minh | Cần media session và test thật |
| 18 | Giải trí | Khôi phục phiên phát | Chưa xác minh | Cần lưu phiên và test |
| 19 | Trợ lý | Nhận diện giọng Việt | Một phần | docs/COMMUNICATION.md; cần micro/locale thật |
| 20 | Trợ lý | Mở ứng dụng | Một phần | docs/COMMUNICATION.md: lệnh giới hạn và xác nhận |
| 21 | Trợ lý | Gọi điện/đọc thông báo | Một phần | docs/COMMUNICATION.md: tel sau xác nhận; chưa đọc thông báo |
| 22 | Trợ lý | Lịch/nhắc việc | Một phần | docs/COMMUNICATION.md: chỉ đọc lịch |
| 23 | Trợ lý | Siri Shortcuts | Chưa xác minh | Cần App Intents và thiết bị |
| 24 | Trợ lý | Rảnh tay | Chưa xác minh | docs/COMMUNICATION.md: push-to-talk, không nghe nền |
| 25 | Xe | CarPlay thiết bị thật | Vướng | docs/CAR_INTEGRATION.md: entitlement, xe thật |
| 26 | Xe | Android Auto thiết bị thật | Vướng | docs/CAR_INTEGRATION.md: host và phê duyệt |
| 27 | Xe | Bluetooth tự kết nối | Chưa xác minh | Cần quyền OS và test thiết bị |
| 28 | Xe | OBD-II tùy chọn | Chưa xác minh | Cần adapter và giao thức |
| 29 | Xe | Thông số xe thực tế | Chưa xác minh | docs/CAR_INTEGRATION.md: không telemetry |
| 30 | Xe | Phát hiện mất kết nối | Một phần | lib/car_connection.dart; test/car_connection_test.dart; cần host thật |
| 31 | Camera | Quản lý dung lượng | Một phần | docs/DASHCAM.md; test/dashcam_test.dart; cần test dung lượng thật |
| 32 | Camera | Ghi vòng lặp | Một phần | docs/DASHCAM.md: foreground; cần thiết bị |
| 33 | Camera | Khóa video sự kiện | Một phần | docs/DASHCAM.md: marker bảo vệ thủ công |
| 34 | Camera | Xuất/chia sẻ | Chưa xác minh | Cần luồng xuất và quyền |
| 35 | Camera | Khôi phục gián đoạn | Một phần | docs/DASHCAM.md: staging/lifecycle; chưa crash-proof |
| 36 | Camera | Quyền riêng tư | Một phần | docs/DASHCAM.md: lưu riêng, không upload; cần kiểm tra quyền |
| 37 | An toàn | SOS thủ công | Chưa xác minh | Cần luồng xác nhận và test |
| 38 | An toàn | Chia sẻ vị trí tự nguyện | Chưa xác minh | Cần consent và thu hồi |
| 39 | An toàn | Hạn chế thao tác khi lái | Một phần | docs/DASHCAM.md: gate Face Control; cần toàn app |
| 40 | An toàn | Quản lý quyền | Một phần | docs/GPS.md; docs/COMMUNICATION.md; cần test từ chối/thu hồi |
| 41 | An toàn | Bảo mật token | Chưa xác minh | Cần secure storage khi có OAuth |
| 42 | An toàn | Xóa/xuất dữ liệu cá nhân | Một phần | docs/GPS.md: xóa tọa độ; cần toàn bộ dữ liệu |
| 43 | Hệ thống | Hồi quy toàn bộ | Một phần | CI main 45964311888 đạt; chưa đủ thiết bị thật |
| 44 | Hệ thống | RAM/CPU/pin/nhiệt | Vướng | Cần đo thiết bị thật |
| 45 | Hệ thống | Dependency/bảo mật | Một phần | CI thư viện 45958039759 đạt; cần audit bảo mật |
| 46 | Hệ thống | APK/IPA ký hợp lệ | Vướng | Cần chứng chỉ và profile được cấp quyền |
| 47 | Hệ thống | Cập nhật/rollback | Chưa xác minh | Cần quy trình và kiểm thử |
| 48 | Hệ thống | Workflow kiểm tra 15 phút | Một phần | .github/workflows/ci-monitor.yml; PR run 45944847971 đạt; chưa thấy schedule run |

Monitor cấu hình cron `7,22,37,52 * * * *` UTC; chạy lịch có thể trễ. Không coi monitor xanh là CI build xanh. Không phát hành chính thức khi chưa được cấp quyền.
