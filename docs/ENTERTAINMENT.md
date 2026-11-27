# Entertainment v2.2 — giai đoạn A
Radio: nhập URL HTTPS hợp pháp, phát trực tiếp bằng just_audio. Podcast: nhập RSS HTTPS trực tiếp, đọc enclosure audio, giới hạn 2 MB và 100 tập. Không có danh mục đài xác minh hoặc phát nền. URL nguồn do người dùng nhập, không lưu tài khoản.
Spotify: hiện chỉ mở dịch vụ chính thức. Giai đoạn B cần ứng dụng đăng ký tại Spotify Developer Dashboard, Client ID, redirect URI đã đăng ký và OAuth Authorization Code + PKCE; không nhúng client secret. Web API điều khiển thiết bị Spotify, không cung cấp luồng MP3. Playback cần Premium hợp lệ và thiết bị khả dụng. https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
Apple Music: hiện chỉ mở dịch vụ chính thức. Giai đoạn C cần App ID có MusicKit, quyền MusicAuthorization, kiểm tra MusicSubscription và ApplicationMusicPlayer native; kiểm thử trên iPhone ký hợp lệ. https://developer.apple.com/musickit/
Không tuyên bố hai tích hợp API đã hoàn thành. CI và kiểm thử âm thanh trên thiết bị thật là điều kiện trước khi phát hành.

## 2.2 hardening
RSS sử dụng client riêng cho mỗi lần tải, giới hạn kích thước cả header và dữ liệu, timeout tải thân phản hồi, đóng kết nối khi kết thúc hoặc rời màn hình. Tập đã kết thúc có thể phát lại từ đầu. Bổ sung test HTTP lỗi, giới hạn dữ liệu và UTF-8 tiếng Việt. Chưa hỗ trợ RSS redirect, phát nền hoặc xác thực dịch vụ.
