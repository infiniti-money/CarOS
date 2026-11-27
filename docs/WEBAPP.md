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
