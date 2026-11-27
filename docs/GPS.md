# GPS và hành trình 2.1
Chỉ xin quyền vị trí khi bấm Bắt đầu. Tốc độ lấy từ thiết bị, đổi m/s sang km/h; khoảng cách là ước tính GPS, không phải OBD. Bỏ qua mẫu có độ chính xác thấp và bước nhảy bất thường. Dừng khi ứng dụng ra nền. Lưu tối đa 100 bản tổng kết cục bộ, không lưu tuyến tọa độ. Mở Google Maps ngoài ứng dụng, chưa có bản đồ nhúng hoặc dẫn đường nội bộ. 
Sau flutter create, chạy python3 scripts/configure_location.py android và/hoặc ios trước khi build. Cần thử quyền từ chối, mất GPS, kết thúc và lịch sử trên thiết bị thật.

## Vị trí đỗ xe
Lưu thủ công một tọa độ trên thiết bị khi GPS đang hoạt động và tốc độ không quá 2 km/h. Tìm xe mở Google Maps, người dùng có thể xóa tọa độ. Không đồng bộ lên máy chủ; thao tác khi đã đỗ xe. Tọa độ chỉ gửi tới dịch vụ bản đồ khi người dùng chọn Tìm xe.
