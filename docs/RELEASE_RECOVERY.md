# Kiểm tra gói thử nghiệm và rollback
CI đính kèm APK debug và apk-manifest.json (SHA-256, kích thước, commit checkout thực tế, version/build từ pubspec). Không phải bản phát hành ký chính thức. Manifest không tự chứng minh nguồn gốc hoặc chữ ký: chỉ tải từ GitHub Actions của repo và run đã xác minh, đối chiếu commit. PR CI có thể build merge commit tạm.
```sh
python3 scripts/apk_manifest.py verify --apk app-debug.apk --manifest apk-manifest.json
python3 scripts/apk_manifest.py rollback-plan --current current.json --candidate apk-manifest.json --apk app-debug.apk
```
Rollback-plan yêu cầu build thấp hơn, commit khác, checksum khớp, cùng ứng dụng/kênh debug. Không cài đặt, không xóa, không tải tự động. Manifest chỉ là metadata khai báo; dùng Android SDK apksigner verify --print-certs và apkanalyzer manifest application-id/version-code để xác minh chính APK, chứng chỉ và thiết bị. So sánh chứng chỉ với bản đang cài và nguồn tin cậy. Backup dữ liệu được hỗ trợ, thử trên thiết bị không sản xuất. Android có thể từ chối downgrade hoặc chữ ký khác (debug key trên runner có thể thay đổi). Ưu tiên bản forward-fix ký cùng khóa, versionCode tăng; không tự gỡ app để ép downgrade. Kiểm thử migration/rollback thật, iOS TestFlight hoặc phân phối đã ký và chính sách dữ liệu vẫn chưa xác minh.
Mỗi build phát hành cần versionCode riêng, không dùng lại +6 cho các bản khác nhau.
