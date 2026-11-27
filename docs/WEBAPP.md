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
