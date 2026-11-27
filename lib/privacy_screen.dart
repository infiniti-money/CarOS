import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart' as sharing;
import 'package:shared_preferences/shared_preferences.dart';
import 'privacy_records.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final selected = <PersonalRecord>{};
  bool busy = false;
  String status = 'Chọn dữ liệu muốn xuất hoặc xóa.';
  static const labels = {
    PersonalRecord.trips: 'Lịch sử hành trình',
    PersonalRecord.parking: 'Vị trí đỗ xe (tọa độ chính xác)',
    PersonalRecord.playback: 'Phiên phát đã lưu',
  };

  Future<void> export(BuildContext anchor) async {
    if (busy || selected.isEmpty) return;
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final selection = Set<PersonalRecord>.of(selected);
    setState(() => busy = true);
    try {
      await widget.prefs.reload();
      if (!mounted) return;
      final text = exportPersonalRecords(widget.prefs, selection);
      final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Xem trước dữ liệu xuất'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Chọn ứng dụng nhận')),
        ],
      ));
      if (!mounted || approved != true) return;
      final result = await sharing.SharePlus.instance.share(sharing.ShareParams(
        text: text, sharePositionOrigin: origin,
      ));
      if (mounted) {
        setState(() => status = result.status == sharing.ShareResultStatus.dismissed ?
          'Đã đóng bảng chia sẻ.' : 'Đã mở bảng chia sẻ; CarOS không xác nhận dữ liệu đã được gửi.');
      }
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể xuất dữ liệu.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    if (busy || selected.isEmpty) return;
    final selection = Set<PersonalRecord>.of(selected);
    setState(() => busy = true);
    try {
      final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Xóa dữ liệu đã chọn?'),
        content: Text('${selection.map((x) => labels[x]).join('\n')}\n\nKhông thể hoàn tác. Hãy kết thúc hành trình và phiên phát trước khi xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận xóa')),
        ],
      ));
      if (!mounted || approved != true) return;
      await widget.prefs.reload();
      final failed = await deletePersonalRecords(widget.prefs, selection);
      if (mounted) {
        setState(() {
          selected.removeAll(selection.difference(failed));
          status = failed.isEmpty ? 'Đã xóa dữ liệu đã chọn.' : 'Một số mục chưa xóa được: ${failed.map((x) => labels[x]).join(', ')}';
        });
      }
    } catch (_) {
      if (mounted) setState(() => status = 'Không thể hoàn thành yêu cầu xóa.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> permissions() async {
    try {
      if (await Geolocator.openAppSettings()) return;
    } catch (_) {}
    if (mounted) setState(() => status = 'Hãy mở Cài đặt hệ thống để quản lý quyền CarOS.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quyền riêng tư và dữ liệu')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Chọn riêng từng nhóm. Dữ liệu vị trí và hành trình có thể nhạy cảm. Không có mục nào được chọn mặc định.'),
      for (final item in PersonalRecord.values)
        CheckboxListTile(title: Text(labels[item]!), value: selected.contains(item),
          onChanged: busy ? null : (checked) => setState(() {
            if (checked == true) { selected.add(item); } else { selected.remove(item); }
          })),
      const Text('Kết thúc hành trình đang ghi trước khi xóa. Dữ liệu mới vẫn có thể được tạo sau khi xóa. Phiên phát xuất tên và thời điểm, không xuất URL. Video quản lý riêng trong Dash Cam.'),
      Wrap(spacing: 8, children: [
        Builder(builder: (anchor) => FilledButton(onPressed: busy || selected.isEmpty ? null : () => export(anchor), child: const Text('Xuất dữ liệu đã chọn'))),
        OutlinedButton(onPressed: busy || selected.isEmpty ? null : remove, child: const Text('Xóa dữ liệu đã chọn')),
      ]),
      const Divider(),
      ListTile(title: const Text('Quản lý quyền hệ điều hành'), subtitle: const Text('Vị trí, camera, micro, danh bạ và lịch theo cài đặt thiết bị'), onTap: busy ? null : permissions),
      Text(status),
    ]),
  );
}
