# Mochy iOS 0.1 — bản thử đang phát triển

Bản chuyển đổi không chính thức dựa trên [Mochy Music 8.3.2](https://github.com/realidkroo/Mochy-Music/tree/Mochy-8.3.2). GPL-3.0, xem LICENSE. Không phải APK được đổi đuôi.

## Tình trạng thật

- Đã viết mã nguồn SwiftUI cho giao diện tìm kiếm, thư viện và trình phát file nhạc.
- **Đã build thành công bằng Xcode và xuất IPA arm64 chưa ký. Chưa chạy trên iPhone thật.**
- Build: https://github.com/anhtuan119/Mochy-iOS/actions/runs/42173326166
- IPA SHA-256: `6e2cbeb0ceddf04b03fc01d4b1c86c1fc24722dd51a22055305674b01b01c101`.
- Đã kiểm tra ZIP, Mach-O arm64, bundle ID, iOS tối thiểu 17.0, audio background mode và đối chiếu checksum artifact.
- Mã nguồn đã được đưa lên `anhtuan119/Mochy-iOS`; xem GitHub Actions để biết kết quả build thực tế.
- Tìm kiếm YouTube Music dùng cấu trúc WEB_REMIX của bản Android, chưa thử kết nối thực tế; API không chính thức có thể thay đổi.
- Bài online mở trang YouTube trong WKWebView, không phải engine phát native của Android. Không có phát nền online, tải nhạc online, đồng bộ tài khoản, module, EQ hay toàn bộ giao diện Android.

## Chức năng đã triển khai trong mã nguồn

- Tìm bài/ca sĩ, lưu kết quả vào thư viện.
- Nhập nhiều file audio từ ứng dụng Tệp, lưu trong sandbox, thư viện JSON ghi nguyên tử.
- AVPlayer: phát/dừng, tua, trước/sau, hàng đợi local, thông tin và nút màn hình khoá.
- Xử lý mất tai nghe, gián đoạn audio, file không hỗ trợ và lỗi lưu.
- Không yêu cầu đăng nhập, khoá API hoặc chứng chỉ trong mã nguồn.

## Xuất IPA không cần Mac cá nhân

1. Đưa toàn bộ nội dung thư mục này vào gốc repo, bao gồm `.github/workflows/ios.yml`.
2. GitHub Actions → Build Mochy iOS → Run workflow (hoặc push vào main).
3. Khi build thành công, tải artifact `Mochy-iOS-0.1-UNSIGNED`, giải nén lấy IPA.
4. IPA chưa ký, cần ký lại bằng phương thức cài iOS hợp lệ của bạn. Đổi đuôi hoặc tải IPA không tự làm nó cài được.

Workflow chạy trên macOS, dùng Xcode build cho thiết bị arm64; kiểm tra executable, bundle ID, plist, audio background mode trước khi đóng gói. Có compiler log nếu lỗi. Build thành công chỉ chứng minh biên dịch/đóng gói, không thay thế test thiết bị.

## Kiểm thử còn phải làm

- Ký và cài IPA lên iPhone; kiểm tra mở app không crash.
- Tìm một bài tiếng Việt; thử offline và truy vấn không có kết quả.
- Mở bài YouTube, nhấn play; đóng trang thì âm thanh web dừng.
- Nhập MP3/M4A từ Tệp, phát/tua/chuyển bài, khoá màn hình, rút tai nghe.
- Lưu/xoá bài, thoát và mở lại; xác nhận thư viện giữ nguyên.
- Kiểm tra chữ lớn, VoiceOver và iPhone 14 Pro Max.

## Ghi nhận

`ios/Mochy.xcodeproj/project.pbxproj` được sửa từ project iOS Mochy 8.3.2; cấu hình WEB_REMIX và mô hình parse kết quả dựa trên module innertube cùng phiên bản. Giao diện và trình phát Swift của bản thử được viết mới. Nguồn gốc, tác giả và giấy phép upstream được giữ qua liên kết trên cùng LICENSE.
