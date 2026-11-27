# Infiniti CarOS 2.0
Vietnamese Edition — dashboard độc lập, lấy cảm hứng từ CarOS và Liquid Glass. Không phải sản phẩm của Apple hay CarOS.
## Bản nền tảng
Dashboard, SmartBar, chế độ sáng/tối và kính lưu cục bộ, mở bản đồ và dịch vụ âm nhạc bên ngoài. Không có GPS, kết nối xe hay phát nhạc nội bộ ở bản này.
## Chạy thử
Cần Flutter stable (Dart >=3.5; SDK Flutter hỗ trợ Color.withValues).
```sh
flutter create --platforms=ios,android --org com.infinitimoney --project-name infiniti_caros .
flutter pub get
flutter analyze
flutter test
flutter run
```
Các thư mục native được tạo bởi Flutter; iOS cần macOS/Xcode. CI build APK debug và iOS simulator, không phải IPA ký để cài trên iPhone.
## Lộ trình
Xem [ROADMAP](docs/ROADMAP.md). Giao diện kính hiện là hiệu ứng Flutter, chưa phải Liquid Glass native. Không thao tác khi đang lái xe.
