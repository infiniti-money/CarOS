# CarOS Web / PWA
Bản độc lập, không thay thế Flutter native. Không có tài khoản hoặc backend; lưu chỗ đỗ và theme cục bộ. Không tự xin quyền GPS, dừng khi vào nền, không giả tốc độ khi không có dữ liệu. Không dùng trong lúc lái xe.
## Chạy local
```sh
python3 scripts/generate_web_icons.py
node --test webapp/core.test.mjs
python3 -m http.server 8080 --directory webapp
```
Mở http://localhost:8080. GPS, service worker cần HTTPS hoặc localhost. GitHub Pages: Settings > Pages > Build and deployment > Source: GitHub Actions. Workflow webapp.yml sẽ chạy khi merge hoặc dispatch. URL dự kiến: https://infiniti-money.github.io/CarOS/ (chưa xác minh deploy).
## Phạm vi 48 tiêu chí
- #5: lưu chỗ đỗ GPS, mở trên bản đồ ngoài.
- #7, #9, #11: bố cục đáp ứng, hai cột khi rộng, chế độ sáng/tối thủ công (không khẳng định split-screen OS).
- #13–15: liên kết Spotify/Apple Music/Podcast; không OAuth, SDK, radio hoặc điều khiển phát.
- #19: đọc trạng thái bằng TTS nếu có; chưa nhận dạng lệnh giọng nói.
- #36, #38, #40, #42: quyền GPS, lưu/ xuất/xóa cục bộ; không tự gửi vị trí. Không ghi video.
- #43: kiểm thử Node logic, chưa có kiểm thử browser E2E hoặc thiết bị.
- Offline chỉ giao diện, không có tile offline (#6). Không thay thế #1–4, #16–18, #20–35, #37, #39, #41, #44–48 native.
- CarPlay, Android Auto, OBD, Siri, camera nền và ký native vẫn thuộc bản Flutter. Không đánh dấu đạt đầy đủ.

## Bản đồ 2D & giao diện kính
Bản đồ raster Mercator tương tác, nút di chuyển/zoom, kéo thả, định tâm GPS/chỗ đỗ khi có dữ liệu, không tự gửi GPS trước khi bật bản đồ. Tile OSM chỉ tải vùng đang xem, ghi công hiển thị, không prefetch/cache offline trong service worker. Xem https://operations.osmfoundation.org/policies/tiles/ ; cần provider có SLA và giấy phép offline cho triển khai quy mô lớn. Theme kính CSS blur có fallback nền đặc; không phải Apple Liquid Glass native. Không có 3D, ETA hoặc định tuyến nội bộ. Kiểm thử hình học bằng Node, vẫn cần QA browser thật.

## Tuyến đường, ETA, widget và góc nhìn nghiêng
Nhập endpoint OSRM HTTPS hỗ trợ CORS và tọa độ đích; không nhập token bí mật. Chỉ gửi tọa độ sau xác nhận; không tự reroute. Tuyến GeoJSON được kiểm tra, hiện trên map nếu bật; ETA còn lại nội suy theo vị trí gần tuyến, không có traffic. Không có máy chủ mặc định; cần cung cấp provider hợp lệ. Thứ tự widget lưu cục bộ; chỉ ẩn map/media, giữ GPS/route/privacy. Góc nhìn nghiêng CSS là bản đồ phẳng 2D, không phải địa hình hoặc công trình 3D. Kiểm thử Node logic; cần E2E trình duyệt/provider. Không tính hoàn thành #1–4 hoặc #8.

## MapLibre, camera và radio
MapLibre GL JS 6.19.0 được vendored trong workflow từ npm, không tải JavaScript CDN khi chạy; cần WebGL và DEM TileJSON HTTPS có CORS, giấy phép và ghi công. Không chọn nguồn DEM mặc định, không khẳng định có công trình 3D. OSM base chỉ online. Camera dùng getUserMedia/MediaRecorder không âm thanh, giới hạn mục tiêu 60 giây và bộ đệm 32 MiB; thời điểm chunk phụ thuộc browser, không phải quota cứng. Bản ghi chỉ trong phiên, tải thủ công; không ghi nền, không phục hồi khi crash. Radio dùng HTMLAudioElement và URL HTTPS do người dùng cung cấp, không có danh mục đài hoặc bảo đảm codec. Không lưu URL/địa hình/camera vào bộ nhớ lâu dài. Cần QA Safari/Chrome và provider/stream được phép. Tài liệu: https://maplibre.org/maplibre-gl-js/docs/examples/3d-terrain/ ; https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder .

## Browser E2E
CI chạy Chromium Playwright 1.56.1 với GPS mô phỏng của browser, camera giả lập của Chromium, OSRM/DEM/tile/radio fixture chặn mạng. Kiểm tra thao tác GPS, lưu chỗ đỗ, ETA, widget, xóa dữ liệu, MediaRecorder, audio, WebGL MapLibre và offline shell. Không thay thế QA Safari/iOS/Android, nguồn DEM/OSRM/đài thực hoặc camera phần cứng. Deployment phải qua cả Node và E2E.

## Giao diện ô tô WebApp
Launcher biểu tượng tròn tự vẽ, SmartBar cố định có giờ thiết bị và tốc độ GPS thật (— nếu thiếu), màn hình bản đồ/đỗ xe/giải trí/camera/cài đặt riêng và Tổng quan giữ widget cũ. Bàn phím gọi điện xác nhận mở tel:; Contact Picker chỉ nếu trình duyệt hỗ trợ, không đọc lịch sử cuộc gọi hay tự nhập danh bạ. Không sao chép ảnh mẫu, dữ liệu liên hệ, logo độc quyền, trạng thái tài khoản hoặc thời tiết giả. E2E bổ sung chuyển màn hình và bàn phím; runner Ubuntu 24.04 cho Playwright 1.56.1.

## Giao diện v2
Bốn tab điện thoại: yêu thích và danh bạ CarOS lưu số do người dùng tự chọn/nhập, gần đây chỉ ghi yêu cầu mở trình gọi (không khẳng định đã gọi), bàn phím. Không có truy cập lịch sử cuộc gọi hệ thống. Xóa dữ liệu xóa cả mục này. Thời gian đỗ tính từ timestamp đã lưu, khoảng cách đường chim bay chỉ khi GPS còn hợp lệ; ghi chú cục bộ. Tự động sáng/tối theo hệ thống, 3 hình nền CSS, tùy chọn tốc độ SmartBar, chế độ tập trung bản đồ. Không dùng ảnh/danh bạ mẫu làm dữ liệu hoặc tài sản repo; không có backend tài khoản. Cần kiểm thử E2E và thiết bị.

## Đối chiếu ảnh tham chiếu
Tái tạo tỷ lệ ảnh ngang 1536 × 710, launcher hai trang 4×2 (8 và 7 mục), biểu tượng SVG tự vẽ, dock nổi 85,6% chiều rộng, 16,7% chiều cao, tab điện thoại bốn mục và keypad 4×3 đúng thứ tự. Nhãn tiếng Anh theo ảnh mẫu. Không nhập ảnh chụp chứa thông tin cá nhân vào repo. Đồng hồ/GPS lấy dữ liệu thực; thời tiết chưa có nguồn thì —°. Calendar chưa đọc lịch, SMS mở ứng dụng hệ thống, Spotify/Podcasts mở dịch vụ chính thức. Bản đồ dùng nguồn OSM/DEM, không giả Apple Maps. E2E đo bố cục nhưng chưa có đối chiếu pixel hoặc thiết bị thật; không cam kết 100%.

Organize apps: màn hình danh sách với công tắc bật/tắt và nút đổi vị trí; cài đặt không thể bị ẩn, tùy chọn lưu cục bộ, xóa dữ liệu khôi phục launcher.

## Khắc phục cache giao diện
HTML, stylesheet, entrypoint và các module nội bộ sử dụng cùng phiên bản URL v9. Service worker cài đặt shell bằng request cache reload, giữ vòng đời activation mặc định để không tải lại khi người dùng đang thao tác. Khi nâng cấp shell, tăng đồng bộ version các URL và cache name. Nếu một tab cũ vẫn giữ worker v8, đóng các tab CarOS rồi mở lại hoặc mở `?fresh=9` khi có mạng. Không tự xóa dữ liệu người dùng. Bài kiểm thử Chromium kiểm tra tài nguyên không version bị cũ, icon tròn, lưới 4 cột, 8 icon và SmartBar cố định ở viewport ngang nhỏ. Chưa xác minh Safari thật.

## Hướng màn hình mobile (landscape-first)
PWA yêu cầu `orientation: landscape` trong manifest. Trình duyệt hỗ trợ Screen Orientation API có thể khóa ngang sau thao tác người dùng; Safari và một số hệ điều hành có thể từ chối. Khi dọc, banner hướng dẫn xoay máy, giữ chức năng truy cập được và không xoay giả nội dung. Khi ngang, launcher luôn có bốn cột kể cả viewport 568px. Cache shell v10 cập nhật đồng bộ các URL tài nguyên. Kiểm thử Chromium kiểm tra manifest, fallback khi API bị từ chối và hai kích thước ngang; chưa chứng minh khóa hướng trên iPhone/Android thật. Native Flutter sẽ cần thay đổi riêng sau PR OBD-II #31 để không sửa đồng thời lib/main.dart.

## Nghiên cứu CarPlay iOS 3.0.2 — đợt 1
Tham khảo chức năng, không nhập binary, NIB, PNG hay SDK đóng gói. Cài đặt Home hỗ trợ ba kích thước icon; SmartBar chọn tốc độ GPS, pin thiết bị (nếu trình duyệt hỗ trợ và người dùng chọn) hoặc thu gọn. Pin là pin điện thoại, không phải pin xe; không hỗ trợ thì hiển thị —. Không gọi dịch vụ mạng. Tùy chọn lưu cục bộ, xuất/xóa theo cơ chế hiện có. Cache shell v11. Xem [phân tích nguồn](CARPLAY_IOS_302_RESEARCH.md). Chưa nghiệm thu thiết bị thật.
