import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class DashboardView extends StatefulWidget {
  final UserModel user;
  const DashboardView({super.key, required this.user});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<Map<String, dynamic>> _allAttendance = [];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final attendance = await ApiService.getAllAttendance();
      final requests = await ApiService.getRequests();
      final users = await ApiService.getUsers();
      if (mounted) {
        setState(() {
          _allAttendance = attendance;
          _allRequests = requests;
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal load data dashboard: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: AppColors.yellow500)));
    }

    bool isSuperAdmin = widget.user.role == 'admin';
    DateTime witaTime = DateTime.now().toUtc().add(const Duration(hours: 8));
    String today = DateFormat('yyyy-MM-dd').format(witaTime);
    String dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(witaTime);

    String activeShift = '-';
    if (!isSuperAdmin) {
      var todayRecord = _allAttendance.where((a) => a['user_id'].toString() == widget.user.id && a['date'] == today).toList();
      if (todayRecord.isNotEmpty) {
        if (todayRecord.first['shift'] != null && todayRecord.first['shift'].toString().isNotEmpty && todayRecord.first['shift'] != '-') {
          activeShift = todayRecord.first['shift'];
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingCard(isSuperAdmin, dateStr, activeShift),
          const SizedBox(height: 24),
          if (isSuperAdmin) _buildAdminStats(today) else _buildEmployeeStats(today),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(bool isSuperAdmin, String dateStr, String activeShift) {
    IconData shiftIcon = activeShift == '-' ? Icons.pending_actions : (activeShift.toLowerCase().contains('malam') ? Icons.nightlight_round : Icons.wb_sunny);
    String shiftLabel = activeShift == '-' ? "SHIFT: -" : "SHIFT ${activeShift.toUpperCase()}";

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isSuperAdmin ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: isSuperAdmin ? Colors.transparent : AppColors.slate100),
        boxShadow: isSuperAdmin ? [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr.toUpperCase(), style: TextStyle(color: AppColors.slate400, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(isSuperAdmin ? "RINGKASAN SISTEM" : "HALO, ${widget.user.namaLengkap.split(' ')[0].toUpperCase()}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, color: isSuperAdmin ? Colors.white : AppColors.slate800)),
          const SizedBox(height: 24),
          if (!isSuperAdmin)
            Wrap(spacing: 12, runSpacing: 12, children: [
              _badge(widget.user.area.isEmpty ? "SITE TABALONG" : widget.user.area, AppColors.yellow500, AppColors.slate900),
              _badge(shiftLabel, AppColors.slate900, Colors.white, icon: shiftIcon),
            ])
          else
            Text("Pantau aktivitas kehadiran dan status karyawan secara real-time.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmployeeStats(String today) {
    var todayRecord = _allAttendance.where((a) => a['user_id'].toString() == widget.user.id && a['date'] == today).toList();
    String jamMasuk = '--:--', jamPulang = '--:--';
    if (todayRecord.isNotEmpty) {
      jamMasuk = todayRecord.first['jam_masuk'] ?? '--:--';
      jamPulang = todayRecord.first['jam_pulang'] ?? '--:--';
    }
    int totalBorang = _allRequests.where((r) => r['user_id'].toString() == widget.user.id).length;
    int hariAktif = _allAttendance.where((a) {
      String status = a['status_kehadiran'] ?? '';
      return a['user_id'].toString() == widget.user.id && (status == 'Hadir' || status == 'Absen Pulang' || status == 'Pulang Cepat');
    }).length;

    return Column(children: [
      Row(children: [Expanded(child: _statCard("WAKTU MASUK", jamMasuk, Icons.wb_sunny, AppColors.emerald50)), const SizedBox(width: 16), Expanded(child: _statCard("WAKTU KELUAR", jamPulang, Icons.nightlight_round, AppColors.indigo50))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _statCard("BORANG", totalBorang.toString(), Icons.description, AppColors.blue50)), const SizedBox(width: 16), Expanded(child: _statCard("HARI AKTIF", hariAktif.toString(), Icons.check_circle, AppColors.amber50))]),
    ]);
  }

  Widget _buildAdminStats(String today) {
    int totalKaryawan = _allUsers.length;
    List<String> userIds = _allUsers.map((u) => u['id'].toString()).toList();
    var todayAtt = _allAttendance.where((a) => a['date'] == today && userIds.contains(a['user_id'].toString())).toList();
    int hadirHariIni = todayAtt.where((a) { String s = a['status_kehadiran'] ?? ''; return s == 'Hadir' || s == 'Absen Pulang' || s == 'Pulang Cepat'; }).length;
    int izinSakit = todayAtt.where((a) => a['status_kehadiran'] == 'Izin' || a['status_kehadiran'] == 'Sakit').length;
    int belumAbsen = totalKaryawan - hadirHariIni - izinSakit;
    if (belumAbsen < 0) belumAbsen = 0;

    return Column(children: [
      Row(children: [Expanded(child: _statCard("TOTAL KARYAWAN", totalKaryawan.toString(), Icons.people, AppColors.blue50)), const SizedBox(width: 16), Expanded(child: _statCard("HADIR HARI INI", hadirHariIni.toString(), Icons.check_circle, AppColors.emerald50))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _statCard("IZIN / SAKIT", izinSakit.toString(), Icons.description, AppColors.amber50)), const SizedBox(width: 16), Expanded(child: _statCard("BELUM ABSEN", belumAbsen.toString(), Icons.location_off, AppColors.rose50))]),
      const SizedBox(height: 24),
      Container(width: double.infinity, padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: AppColors.slate100)),
        child: Column(children: [Icon(Icons.shield, size: 64, color: AppColors.slate200), const SizedBox(height: 16), const Text("SISTEM AKTIF & TERLINDUNGI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1)), const SizedBox(height: 8), const Text("Semua layanan dan sensor GPS beroperasi secara normal.", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold, letterSpacing: 1))])),
    ]);
  }

  Widget _badge(String text, Color bg, Color textCol, {IconData? icon}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 12, color: textCol), const SizedBox(width: 6)], Text(text, style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2))]));
  }

  Widget _statCard(String label, String value, IconData icon, Color bgColor) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(40), border: Border.all(color: AppColors.slate100)),
      child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: AppColors.slate500)), const SizedBox(height: 16), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2), textAlign: TextAlign.center), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.slate800))]));
  }
}
