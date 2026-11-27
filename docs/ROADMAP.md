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
| 1 | Bản đồ | 2D/3D và ban đêm | Một phần | Bản đồ 2D, tile ngày/đêm theo cấu hình và giao diện; chưa có 3D; cần provider/QA |
| 2 | Bản đồ | Dẫn đường giọng Việt | Một phần | docs/NAVIGATION.md; test/navigation_test.dart; cần GPS/TTS thật |
| 3 | Bản đồ | ETA và quãng đường còn lại | Một phần | estimateRouteProgress: GPS thật, chiếu lên tuyến và ước tính phần còn lại; cần QA thực địa |
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
| 16 | Giải trí | Nhạc nền | Một phần | Bản điện thoại: just_audio_background, service Android / iOS audio mode; rời màn hình Giải trí dừng; cần thiết bị |
| 17 | Giải trí | Điều khiển màn hình khóa | Một phần | Bản điện thoại: MediaItem và remote controls từ just_audio_background; cần QA màn hình khóa |
| 18 | Giải trí | Khôi phục phiên phát | Một phần | playback_session.dart: lưu/khôi phục thủ công, không tự phát; cần CI và kiểm thử audio thiết bị |
| 19 | Trợ lý | Nhận diện giọng Việt | Một phần | docs/COMMUNICATION.md; cần micro/locale thật |
| 20 | Trợ lý | Mở ứng dụng | Một phần | docs/COMMUNICATION.md: lệnh giới hạn và xác nhận |
| 21 | Trợ lý | Gọi điện/đọc thông báo | Một phần | docs/COMMUNICATION.md: tel sau xác nhận; chưa đọc thông báo |
| 22 | Trợ lý | Lịch/nhắc việc | Một phần | docs/COMMUNICATION.md: chỉ đọc lịch |
| 23 | Trợ lý | Siri Shortcuts | Chưa xác minh | Cần App Intents và thiết bị |
| 24 | Trợ lý | Rảnh tay | Chưa xác minh | docs/COMMUNICATION.md: push-to-talk, không nghe nền |
| 25 | Xe | CarPlay thiết bị thật | Vướng | docs/CAR_INTEGRATION.md: entitlement, xe thật |
| 26 | Xe | Android Auto thiết bị thật | Vướng | docs/CAR_INTEGRATION.md: host và phê duyệt |
| 27 | Xe | Bluetooth tự kết nối | Một phần | BLE FFE0/FFE1, ghi nhớ opt-in, retry giới hạn khi màn hình mở; cần adapter thật |
| 28 | Xe | OBD-II tùy chọn | Một phần | Mode 01 chỉ đọc, ELM327 BLE UART FFE0/FFE1; cần QA xe thật |
| 29 | Xe | Thông số xe thực tế | Một phần | 5 PID tiêu chuẩn, không giả số, stale/mất kết nối ẩn; cần xác minh ECU thật |
| 30 | Xe | Phát hiện mất kết nối | Một phần | CarAudioGate và BLE disconnect/retry; cần host/adapter thật |
| 31 | Camera | Quản lý dung lượng | Một phần | docs/DASHCAM.md; test/dashcam_test.dart; cần test dung lượng thật |
| 32 | Camera | Ghi vòng lặp | Một phần | docs/DASHCAM.md: foreground; cần thiết bị |
| 33 | Camera | Khóa video sự kiện | Một phần | docs/DASHCAM.md: marker bảo vệ thủ công |
| 34 | Camera | Xuất/chia sẻ | Một phần | Dash Cam: bảng chia sẻ hệ điều hành, thao tác rõ ràng; cần QA iOS/Android |
| 35 | Camera | Khôi phục gián đoạn | Một phần | Nhận diện tệp .part và dọn có xác nhận; chưa khôi phục video hỏng/crash-proof |
| 36 | Camera | Quyền riêng tư | Một phần | docs/DASHCAM.md: lưu riêng, không upload; cần kiểm tra quyền |
| 37 | An toàn | SOS thủ công | Một phần | safety_screen.dart: mở trình gọi sau xác nhận, không tự gọi; cần thiết bị |
| 38 | An toàn | Chia sẻ vị trí tự nguyện | Một phần | safety_policy.dart: vị trí một lần, xem trước/sao chép tự nguyện, không tự gửi; cần thiết bị |
| 39 | An toàn | Hạn chế thao tác khi lái | Một phần | docs/DASHCAM.md: gate Face Control; cần toàn app |
| 40 | An toàn | Quản lý quyền | Một phần | PrivacyScreen mở cài đặt ứng dụng; cần test từ chối/thu hồi quyền trên thiết bị |
| 41 | An toàn | Bảo mật token | Chưa xác minh | Cần secure storage khi có OAuth |
| 42 | An toàn | Xóa/xuất dữ liệu cá nhân | Một phần | Xuất/xóa có chọn lọc lịch sử, chỗ đỗ, phiên phát; video quản lý riêng; cần QA |
| 43 | Hệ thống | Hồi quy toàn bộ | Một phần | PR #24: 7 job CI đạt (45983606954, 45983607041, 45983607587); main sau merge cần CI và QA thiết bị |
| 44 | Hệ thống | RAM/CPU/pin/nhiệt | Vướng | Cần đo thiết bị thật |
| 45 | Hệ thống | Dependency/bảo mật | Một phần | CI thư viện 45958039759 đạt; cần audit bảo mật |
| 46 | Hệ thống | APK/IPA ký hợp lệ | Vướng | Cần chứng chỉ và profile được cấp quyền |
| 47 | Hệ thống | Cập nhật/rollback | Chưa xác minh | Cần quy trình và kiểm thử |
| 48 | Hệ thống | Workflow kiểm tra 15 phút | Một phần | Monitor mở rộng app/dependency/host; PR #27 run 45984492091 đạt; chưa thấy schedule run |

Monitor cấu hình cron `7,22,37,52 * * * *` UTC; chạy lịch có thể trễ. Không coi monitor xanh là CI build xanh. Không phát hành chính thức khi chưa được cấp quyền.

## Tích hợp tiếp theo
Main `d22697e592a3a4be06d528b2fa7995bc6eeaa109` chứa PR #24 và toàn bộ ancestry #21–23; ba PR cũ đã đóng. PR #26 tích hợp thêm #25 (quyền riêng tư) và #27 (CI Monitor) với lịch sử commit nguyên vẹn, cần CI mới trên main. Chưa nghiệm thu đủ 48 tiêu chí; không tính PR xanh thay cho kiểm thử thiết bị thực tế.
