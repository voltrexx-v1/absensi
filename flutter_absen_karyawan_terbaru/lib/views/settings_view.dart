import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../helpers/web_camera.dart';
import 'admin_config_view.dart';

class SettingsView extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final Function(String) onChangeView;
  final VoidCallback onProfileUpdated;

  const SettingsView({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onChangeView,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _activeSetting = 'menu'; // 'menu', 'shift', 'departemen', 'devices', 'profile'
  String _selectedShiftArea = 'Semua Area';
  String _deviceFilterArea = 'Semua Area';

  // NOTIFICATION STATE
  bool _ringtoneEnabled = true;
  String _selectedRingtone = 'Default';
  final List<String> _ringtones = ['Default', 'Chime', 'Beep', 'Bell', 'Percussive', 'Sirene'];

  late Future<Map<String, dynamic>?> _configFuture;
  int _configRefreshKey = 0;

  Future<Map<String, dynamic>?> _loadConfig() async {
    // Tambahkan timestamp anti-cache agar browser (Chrome) tidak menyimpan data lama
    var data = await ApiService.getConfig('site?t=${DateTime.now().millisecondsSinceEpoch}');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ringtoneEnabled = prefs.getBool('ringtone_enabled') ?? true;
        _selectedRingtone = prefs.getString('ringtone_selected') ?? 'Default';
      });
    }
  }

  Future<void> _saveNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ringtone_enabled', _ringtoneEnabled);
    await prefs.setString('ringtone_selected', _selectedRingtone);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Pengaturan notifikasi berhasil disimpan!"), 
        backgroundColor: AppColors.emerald500
      ));
    }
  }

  Future<void> _resetDefaultRingtone() async {
    if (mounted) {
      setState(() {
        _ringtoneEnabled = true;
        _selectedRingtone = 'Default';
      });
    }
    await _saveNotificationPrefs();
  }

  @override
  void initState() {
    super.initState();
    _configFuture = _loadConfig();
    _loadNotificationPrefs();
  }

  void _showDevDialog(String title) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.construction, color: AppColors.yellow500),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
          ],
        ),
        content: const Text(
          "Fitur ini masih dalam tahap pengembangan dan akan segera tersedia pada pembaruan sistem mendatang.",
          style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.bold, height: 1.5)
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () => Navigator.pop(c),
            child: const Text("Mengerti", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_activeSetting == 'profile') return _buildProfileView();
    if (_activeSetting == 'notifikasi') return _buildNotifikasiView();
    
    if (widget.user.role != 'admin') {
      return _buildRegularProfile();
    }

    if (_activeSetting == 'menu') return _buildMainMenu();
    if (_activeSetting == 'shift') return _buildShiftView();
    if (_activeSetting == 'departemen') return _buildDepartemenView();
    if (_activeSetting == 'devices') return _buildManageDevicesView();
    
    return _buildMainMenu();
  }

  Widget _buildRegularProfile() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getUser(widget.user.id),
      builder: (context, snapshot) {
        String name = widget.user.namaLengkap;
        String nik = widget.user.nik;
        String role = widget.user.role;
        String? photoBase64;
        bool isProfileComplete = true;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.emerald500));
        }

        if (snapshot.hasData && snapshot.data != null) {
          var data = snapshot.data!;
          name = data['nama_lengkap'] ?? name;
          nik = data['nik'] ?? nik;
          role = data['role'] ?? role;
          photoBase64 = data['photo_base64'];

          String kontak = data['kontak'] ?? '-';
          String alamat = data['alamat'] ?? '-';
          String tglLahir = data['tanggal_lahir'] ?? '';
          String photo = data['photo_base64'] ?? '';
          String email = data['email'] ?? '';
          if (kontak == '-' || kontak.isEmpty || alamat == '-' || alamat.isEmpty || tglLahir.isEmpty || photo.isEmpty || email.isEmpty) {
              isProfileComplete = false;
          }
        } else {
          isProfileComplete = false;
        }
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PENGATURAN AKUN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate900)),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate200, width: 2)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.slate100,
                      backgroundImage: isProfileComplete && photoBase64 != null && photoBase64.isNotEmpty ? MemoryImage(base64Decode(photoBase64)) : null,
                      child: (!isProfileComplete || photoBase64 == null || photoBase64.isEmpty) 
                          ? const Icon(Icons.person, size: 36, color: AppColors.slate400) 
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                          const SizedBox(height: 4),
                          Text(nik, style: const TextStyle(fontSize: 14, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.yellow500, borderRadius: BorderRadius.circular(8)),
                            child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildMenuItem(
                icon: Icons.person, 
                title: "Profil Saya", 
                subtitle: "Lihat dan edit informasi profil Anda", 
                showBadge: !isProfileComplete, 
                onTap: () => setState(() => _activeSetting = 'profile')
              ),
              _buildMenuItem(icon: Icons.notifications, title: "Notifikasi", subtitle: "Atur preferensi notifikasi", onTap: () => setState(() => _activeSetting = 'notifikasi')),
              
              _buildMenuItem(icon: Icons.lock_outline, title: "Ganti Password", subtitle: "Perbarui kata sandi akun Anda", onTap: () => _showChangePasswordDialog()),
              
              _buildMenuItem(icon: Icons.help, title: "Bantuan & Support", subtitle: "Pusat bantuan dan kontak CS", onTap: () => widget.onChangeView('help')),
              _buildMenuItem(
                icon: Icons.logout, title: "Keluar", subtitle: "Keluar dari aplikasi", isDestructive: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text("Konfirmasi Keluar", style: TextStyle(fontWeight: FontWeight.w900)), 
                      content: const Text("Apakah Anda yakin ingin keluar dari aplikasi?", style: TextStyle(fontWeight: FontWeight.bold)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))), 
                        ElevatedButton(
                          onPressed: () { Navigator.pop(context); widget.onLogout(); }, 
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                          child: const Text("Keluar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNotifikasiView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _activeSetting = 'menu'), icon: const Icon(Icons.arrow_back, color: AppColors.slate800)),
              const SizedBox(width: 16),
              const Text("PENGATURAN NOTIFIKASI", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate900)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate200, width: 2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Suara & Getar", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800, fontSize: 16)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("Aktifkan Nada Dering", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate700)),
                  subtitle: const Text("Mainkan suara saat ada notifikasi pesan atau aktivitas baru", style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                  value: _ringtoneEnabled,
                  activeColor: AppColors.emerald500,
                  onChanged: (val) {
                    setState(() => _ringtoneEnabled = val);
                    _saveNotificationPrefs();
                  },
                ),
                const Divider(height: 32, color: AppColors.slate200),
                const Text("Pilihan Nada Dering", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _ringtoneEnabled ? AppColors.slate50 : AppColors.slate100, 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedRingtone,
                      onChanged: _ringtoneEnabled ? (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedRingtone = newValue);
                          _saveNotificationPrefs();
                        }
                      } : null,
                      items: _ringtones.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _resetDefaultRingtone, 
                    icon: const Icon(Icons.restore, color: AppColors.blue500), 
                    label: const Text("Kembalikan ke Default", style: TextStyle(color: AppColors.blue500, fontWeight: FontWeight.bold))
                  ),
                )
              ],
            ),
          )
        ]
      )
    );
  }

  void _showChangePasswordDialog() {
    String currentPass = '';
    String newPass = '';
    String confirmPass = '';
    bool isSubmitting = false;
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitPassword() async {
              if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua kolom password harus diisi!"), backgroundColor: AppColors.rose500));
                return;
              }

              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Baru dan Konfirmasi Password tidak cocok!"), backgroundColor: AppColors.rose500));
                return;
              }

              // Validasi Kekuatan Password
              bool hasMinLength = newPass.length >= 8;
              bool hasUppercase = newPass.contains(RegExp(r'[A-Z]'));
              bool hasLowercase = newPass.contains(RegExp(r'[a-z]'));
              bool hasDigits = newPass.contains(RegExp(r'[0-9]'));
              bool hasSpecialCharacters = newPass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

              if (!hasMinLength || !hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Password tidak memenuhi syarat keamanan!"), 
                  backgroundColor: AppColors.rose500
                ));
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await ApiService.updateUser(widget.user.id, {
                  'password': newPass,
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password berhasil diperbarui!"), backgroundColor: AppColors.emerald500));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal memperbarui password."), backgroundColor: AppColors.rose500));
                }
              } finally {
                 if (mounted) setDialogState(() => isSubmitting = false);
              }
            }

            Widget _buildRowInput(String label, ValueChanged<String> onChanged) {
               return Padding(
                 padding: const EdgeInsets.only(bottom: 16),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     Expanded(
                       flex: 2,
                       child: Text(label, style: const TextStyle(color: AppColors.slate700, fontSize: 11, fontWeight: FontWeight.w900))
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       flex: 4,
                       child: SizedBox(
                         height: 44,
                         child: TextField(
                           obscureText: !showPassword,
                           onChanged: onChanged,
                           style: const TextStyle(fontSize: 13, color: AppColors.slate900, fontWeight: FontWeight.bold),
                           decoration: InputDecoration(
                             filled: true,
                             fillColor: AppColors.slate50,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                           ),
                         ),
                       )
                     )
                   ]
                 ),
               );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 450,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200)
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Dialog (UT Theme)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: AppColors.slate900,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_reset, color: AppColors.yellow500, size: 24),
                          SizedBox(width: 12),
                          Text("GANTI PASSWORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    
                    // Body Dialog
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRowInput("Password Lama", (v) => currentPass = v),
                          _buildRowInput("Password Baru", (v) => newPass = v),
                          _buildRowInput("Konfirmasi Password", (v) => confirmPass = v),
                          
                          const SizedBox(height: 8),
                          const Text(
                            "*catatan : Password minimal harus 8 Karakter dan mengandung Huruf Besar, Huruf Kecil, Karakter Khusus dan Angka!",
                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.slate500, height: 1.5, fontWeight: FontWeight.bold),
                          ),
                          
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                width: 20, height: 20,
                                child: Checkbox(
                                  value: showPassword,
                                  activeColor: AppColors.yellow500,
                                  checkColor: AppColors.slate900,
                                  side: const BorderSide(color: AppColors.slate300),
                                  onChanged: (val) {
                                    setDialogState(() => showPassword = val ?? false);
                                  }
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("Show Password", style: TextStyle(color: AppColors.slate700, fontSize: 11, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.slate100,
                                    foregroundColor: AppColors.slate700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("BATAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                )
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.yellow500,
                                    foregroundColor: AppColors.slate900,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: isSubmitting ? null : submitPassword,
                                  child: isSubmitting 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.slate900, strokeWidth: 2))
                                    : const Text("SIMPAN", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                )
                              )
                            ]
                          )
                        ],
                      )
                    )
                  ],
                ),
              )
            );
          },
        );
      }
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false, bool showBadge = false}) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(border: Border.all(color: AppColors.slate100), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDestructive ? AppColors.rose50 : AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: isDestructive ? AppColors.rose500 : AppColors.slate600, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w900, color: isDestructive ? AppColors.rose500 : AppColors.slate800)),
                          // INDIKATOR MERAH DI SAMPING TULISAN
                          if (showBadge) ...[
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rose500, shape: BoxShape.circle)),
                          ]
                        ],
                      ), 
                      const SizedBox(height: 2), 
                      Text(subtitle, style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.slate400, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.slate300, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainMenu() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PENGATURAN SISTEM", style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
          SizedBox(height: isMobile ? 24 : 32),
          _buildMenuCard(title: "Radar & Lokasi Site", subtitle: "Konfigurasi titik pusat GPS, radius absensi, dan area.", icon: Icons.location_on, onTap: () async { 
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminConfigView())); 
            if (mounted) setState(() { _configFuture = _loadConfig(); });
          }),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Pengaturan Shift (Waktu)", subtitle: "Kelola aturan jam masuk dan jam pulang untuk setiap site.", icon: Icons.timer, onTap: () => setState(() => _activeSetting = 'shift')),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Departemen & Jabatan", subtitle: "Kelola daftar divisi dan posisi untuk data karyawan.", icon: Icons.work, onTap: () => setState(() => _activeSetting = 'departemen')),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Kelola Perangkat", subtitle: "Reset pengikatan perangkat (Device Lock) karyawan.", icon: Icons.devices, onTap: () => setState(() => _activeSetting = 'devices')),
          const SizedBox(height: 16),
          
          // MENGGUNAKAN FUTUREBUILDER UNTUK MENDETEKSI TIKET OPEN
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.getTickets(),
            builder: (context, snapshot) {
              int pendingTicketsCount = 0;
              if (snapshot.hasData) {
                var docs = snapshot.data!.where((t) => t['status'] == 'Open').toList();
                if (widget.user.role == 'Head Area') {
                  docs = docs.where((d) => d['area'] == widget.user.area).toList();
                }
                pendingTicketsCount = docs.length;
              }
              return _buildMenuCard(
                title: "Pusat Bantuan", 
                subtitle: "Kelola tiket keluhan dan permintaan bantuan.", 
                icon: Icons.chat, 
                showBadge: pendingTicketsCount > 0,
                badgeCount: pendingTicketsCount,
                onTap: () { widget.onChangeView('admin_tickets'); }
              );
            }
          ),
          
          const SizedBox(height: 16),
          _buildMenuCard(title: "Ganti Password", subtitle: "Perbarui kata sandi akun Admin", icon: Icons.lock_outline, onTap: () => _showChangePasswordDialog()),
          
          const SizedBox(height: 32),
          InkWell(
            onTap: widget.onLogout, borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.rose100)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.rose200)), child: const Icon(Icons.logout, color: AppColors.rose500, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text("KELUAR PORTAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 14, color: AppColors.rose600)), const SizedBox(height: 4), Text("Akhiri sesi Anda dan keluar dari sistem secara aman.", style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.slate500, fontWeight: FontWeight.bold))],
                    ),
                  ),
                  if (!isMobile) const Icon(Icons.close, color: AppColors.rose400, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap, bool showBadge = false, int badgeCount = 0}) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.yellow50, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: AppColors.slate800, size: isMobile ? 24 : 28)),
            SizedBox(width: isMobile ? 16 : 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Row(
                    children: [
                      Text(title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 13 : 15, color: AppColors.slate800)),
                      // INDIKATOR MERAH / ANGKA DI PUSAT BANTUAN ADMIN
                      if (showBadge || badgeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: badgeCount > 0 ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,
                          width: badgeCount > 0 ? null : 8,
                          height: badgeCount > 0 ? null : 8,
                          decoration: BoxDecoration(color: AppColors.rose500, borderRadius: BorderRadius.circular(8)),
                          child: badgeCount > 0 ? Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)) : null,
                        ),
                      ]
                    ],
                  ), 
                  const SizedBox(height: 6), 
                  Text(subtitle, style: TextStyle(fontSize: isMobile ? 10 : 12, color: AppColors.slate500, fontWeight: FontWeight.bold))
                ]
              )
            ),
            if (!isMobile) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.chevron_right, color: AppColors.slate400, size: 16)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PROFILE VIEW ---
  Widget _buildProfileView() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getUser(widget.user.id),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
        
        var userData = userSnap.data ?? <String, dynamic>{};

        // FIX: Fallback ke data internal model jika di database tidak ditemukan
        // Ini memastikan akun bypass/demo tetap menampilkan Nama dan NRP secara default
        userData['nama_lengkap'] = userData['nama_lengkap'] ?? widget.user.namaLengkap;
        userData['nik'] = userData['nik'] ?? widget.user.nik;
        userData['role'] = userData['role'] ?? widget.user.role;
        userData['area'] = userData['area'] ?? widget.user.area;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _configFuture,
          builder: (context, configSnap) {
            if (!configSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
            var configData = configSnap.data ?? {};

            return _ProfileForm(
              userData: userData,
              configData: configData,
              userId: widget.user.id,
              userRole: widget.user.role, 
              onBack: () => setState(() => _activeSetting = 'menu'),
              onProfileUpdated: widget.onProfileUpdated,
            );
          }
        );
      }
    );
  }

  // WIDGET MANAGE DEVICES
  Widget _buildManageDevicesView() {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double padding = isMobile ? 16 : 32;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _configFuture,
      builder: (context, configSnap) {
        List<String> availableAreas = ['Semua Area'];
        if (configSnap.hasData && configSnap.data != null) {
          var data = configSnap.data!;
          List<dynamic> locs = data['locations'] ?? [];
          if (locs.isNotEmpty) {
            var areaList = locs.map((e) => e['siteName'].toString()).toList();
            areaList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            availableAreas.addAll(areaList);
          }
        }

        if (!availableAreas.contains(_deviceFilterArea)) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) setState(() => _deviceFilterArea = 'Semua Area');
           });
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBack("Kelola Perangkat"),
              SizedBox(height: padding),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(isMobile ? 24 : 40), 
                  border: Border.all(color: AppColors.slate200), 
                  boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isMobile 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DAFTAR PERANGKAT KARYAWAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildAreaDropdown(availableAreas, isMobile),
                          ]
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("DAFTAR PERANGKAT KARYAWAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)),
                            _buildAreaDropdown(availableAreas, isMobile),
                          ]
                        ),
                    const SizedBox(height: 24),
                    
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: ApiService.getUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
                        if (snapshot.hasError) return const Text("Terjadi kesalahan memuat data", style: TextStyle(color: AppColors.rose500));
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Tidak ada data karyawan.", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold));

                        var users = snapshot.data!.where((data) {
                          bool isNotAdmin = data['role'] != 'admin'; 
                          bool isAreaMatch = _deviceFilterArea == 'Semua Area' || (data['area'] ?? '') == _deviceFilterArea;
                          return isNotAdmin && isAreaMatch;
                        }).toList();

                        users.sort((a, b) => ((a['nama_lengkap'] ?? '').toString().compareTo((b['nama_lengkap'] ?? '').toString())));

                        if (users.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text("Tidak ada data karyawan di area yang dipilih.", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const Divider(height: 32, color: AppColors.slate100),
                          itemBuilder: (context, index) {
                            var userData = users[index];
                            String userId = userData['id'].toString();
                            String name = userData['nama_lengkap'] ?? 'Tanpa Nama';
                            String nik = userData['nik'] ?? '-';
                            String area = userData['area'] ?? 'Belum Diatur';
                            
                            String mobileId = userData['mobileDeviceId'] ?? '';
                            String desktopId = userData['desktopDeviceId'] ?? '';
                            if (userData['device'] != null) {
                               mobileId = userData['device']['mobileDeviceId'] ?? mobileId;
                               desktopId = userData['device']['desktopDeviceId'] ?? desktopId;
                            }
                            
                            if (mobileId.isEmpty && desktopId.isEmpty && userData.containsKey('device_id') && userData['device_id'] != null) {
                               mobileId = userData['device_id'].toString(); 
                            }

                            bool isMobileBound = mobileId.isNotEmpty;
                            bool isDesktopBound = desktopId.isNotEmpty;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800)),
                                const SizedBox(height: 4),
                                Text("$nik â€¢ Area: ${area.toUpperCase()}", style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                const SizedBox(height: 16),
                                Flex(
                                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                                  children: [
                                    Expanded(
                                      flex: isMobile ? 0 : 1,
                                      child: _buildDeviceCard(
                                        title: "Handphone (Mobile)",
                                        isBound: isMobileBound,
                                        deviceId: mobileId,
                                        onReset: () => _resetDevice(userId, name, 'mobileDeviceId', 'Handphone'),
                                      ),
                                    ),
                                    if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
                                    Expanded(
                                      flex: isMobile ? 0 : 1,
                                      child: _buildDeviceCard(
                                        title: "Desktop (PC/Laptop)",
                                        isBound: isDesktopBound,
                                        deviceId: desktopId,
                                        onReset: () => _resetDevice(userId, name, 'desktopDeviceId', 'Desktop'),
                                      ),
                                    ),
                                  ]
                                )
                              ],
                            );
                          }
                        );
                      }
                    )
                  ]
                )
              ),
              const SizedBox(height: 100),
            ],
          )
        );
      }
    );
  }

  Widget _buildAreaDropdown(List<String> availableAreas, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: availableAreas.contains(_deviceFilterArea) ? _deviceFilterArea : 'Semua Area',
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
          onChanged: (String? newValue) => setState(() => _deviceFilterArea = newValue!),
          items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildDeviceCard({required String title, required bool isBound, required String deviceId, required VoidCallback onReset}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBound ? AppColors.slate50 : Colors.white,
        border: Border.all(color: isBound ? AppColors.slate200 : AppColors.slate100),
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(title.contains("Handphone") ? Icons.smartphone : Icons.computer, size: 16, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                ]
              ),
              Icon(isBound ? Icons.lock : Icons.lock_open, size: 16, color: isBound ? AppColors.rose500 : AppColors.emerald500),
            ]
          ),
          const SizedBox(height: 12),
          Text(isBound ? "Terikat (ID: ${deviceId.length > 8 ? deviceId.substring(0,8) : deviceId}...)" : "Belum Terikat", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isBound ? AppColors.rose600 : AppColors.emerald600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBound ? AppColors.slate900 : AppColors.slate100,
                foregroundColor: isBound ? Colors.white : AppColors.slate400,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
              onPressed: isBound ? onReset : null,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(isBound ? "Reset" : "Aman", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
            )
          )
        ]
      )
    );
  }

  void _resetDevice(String docId, String userName, String fieldName, String deviceType) async {
     bool confirm = await showDialog(
       context: context,
       builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Reset $deviceType?", style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text("Aksi ini akan menghapus pengikatan $deviceType dan mengizinkan '$userName' untuk login di perangkat $deviceType baru. Lanjutkan?", style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
             TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
             ElevatedButton(
                onPressed: () => Navigator.pop(c, true), 
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                child: const Text("Reset", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
             ),
          ]
       )
     );

     if (confirm == true) {
        try {
           await ApiService.resetDevice(docId, field: fieldName);
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perangkat $deviceType berhasil di-reset!"), backgroundColor: AppColors.emerald500));
           setState(() {}); // Refresh UI
        } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal reset perangkat."), backgroundColor: AppColors.rose500));
        }
     }
  }

  Widget _buildShiftView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    double padding = isMobile ? 16 : 32;

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('shift_$_configRefreshKey'),
      future: _loadConfig(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(padding), child: const Text("Terjadi kesalahan memuat data konfigurasi", style: TextStyle(color: AppColors.rose500))));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(padding: EdgeInsets.all(padding), child: const CircularProgressIndicator(color: AppColors.yellow500)),
          );
        }

        List<dynamic> shiftsData = [];
        List<String> availableAreas = ['Semua Area'];

        var data = snapshot.data ?? <String, dynamic>{};
        shiftsData = data['shifts'] ?? [];

        List<dynamic> locsData = data['locations'] ?? [];
        if (locsData.isNotEmpty) {
          availableAreas.addAll(locsData.map((e) => e['siteName'].toString()));
        }

        if (!availableAreas.contains(_selectedShiftArea)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedShiftArea = 'Semua Area');
          });
        }

        List<Map<String, dynamic>> shifts = shiftsData.map((e) => Map<String, dynamic>.from(e)).toList();
        
        List<Map<String, dynamic>> filteredShifts = shifts.where((s) {
          if (_selectedShiftArea == 'Semua Area') return true; // Show all shifts
          String sArea = s['area'] ?? 'Semua Area';
          return sArea == _selectedShiftArea || sArea == 'Semua Area';
        }).toList();

        var pagiShifts = filteredShifts.where((s) => !s['name'].toString().toLowerCase().contains('malam')).toList();
        var malamShifts = filteredShifts.where((s) => s['name'].toString().toLowerCase().contains('malam')).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBack("Pengaturan Shift Kerja"),
              SizedBox(height: padding),

              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 24 : 40), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: isMobile 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedShiftArea, icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                    onChanged: (String? newValue) => setState(() => _selectedShiftArea = newValue!),
                                    items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () => _showShiftDialog(null, shifts, availableAreas), borderRadius: BorderRadius.circular(24),
                                  child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle), child: const Icon(Icons.add, size: 24, color: AppColors.slate900)),
                                ),
                              )
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: AppColors.slate400),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedShiftArea, icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                        onChanged: (String? newValue) => setState(() => _selectedShiftArea = newValue!),
                                        items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()))).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                            onTap: () => _showShiftDialog(null, shifts, availableAreas), borderRadius: BorderRadius.circular(24),
                            child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle), child: const Icon(Icons.add, size: 24, color: AppColors.slate900)),
                          ),
                        ],
                      ),
                    ),

                    if (pagiShifts.isEmpty && malamShifts.isEmpty)
                       Padding(
                         padding: EdgeInsets.all(padding),
                         child: Center(child: Text("Belum ada shift terdaftar di ${_selectedShiftArea.toUpperCase()}.", style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                       )
                    else ...[
                       if (pagiShifts.isNotEmpty) ...[
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                           color: AppColors.slate50,
                           child: Row(children: const [Icon(Icons.wb_sunny, size: 18, color: AppColors.amber500), SizedBox(width: 8), Text("KELOMPOK PAGI / SIANG", style: TextStyle(fontSize: 11, color: AppColors.amber500, fontWeight: FontWeight.w900))]),
                         ),
                         ListView.separated(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: pagiShifts.length,
                           separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                           itemBuilder: (context, index) => _buildShiftCard(pagiShifts[index], shifts, availableAreas),
                         ),
                       ],
                       if (malamShifts.isNotEmpty) ...[
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                           color: AppColors.slate50,
                           child: Row(children: const [Icon(Icons.nightlight_round, size: 18, color: AppColors.indigo500), SizedBox(width: 8), Text("KELOMPOK MALAM", style: TextStyle(fontSize: 11, color: AppColors.indigo500, fontWeight: FontWeight.w900))]),
                         ),
                         ListView.separated(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: malamShifts.length,
                           separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                           itemBuilder: (context, index) => _buildShiftCard(malamShifts[index], shifts, availableAreas),
                         ),
                       ]
                    ]

                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> s, List<Map<String, dynamic>> allShifts, List<String> availableAreas) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(s['name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800), overflow: TextOverflow.ellipsis),
                    ),
                    if (s['area'] != null && s['area'].toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.blue200)),
                        child: Text(s['area'].toString().toUpperCase(), style: const TextStyle(color: AppColors.blue600, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(8)),
                      child: Text("IN: ${s['start']}", style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(8)),
                      child: Text("OUT: ${s['end']}", style: const TextStyle(color: AppColors.rose600, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                    ),
                  ],
                )
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppColors.slate400), 
                tooltip: "Edit Shift",
                onPressed: () => _showShiftDialog(s, allShifts, availableAreas)
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.rose400),
                tooltip: "Hapus Shift",
                onPressed: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Hapus Shift?"), content: Text("Yakin ingin menghapus shift ${s['name']}?"),
                      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red)))],
                    ),
                  );
                  if (confirm) {
                    List<Map<String, dynamic>> updated = List.from(allShifts)..removeWhere((item) => item['id'] == s['id']);
                    var currentData = Map<String, dynamic>.from(await ApiService.getConfig('site') ?? {});
                    currentData['shifts'] = updated;
                    bool success = await ApiService.updateConfig('site', currentData);
                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shift berhasil dihapus!"), backgroundColor: AppColors.emerald500));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus shift."), backgroundColor: AppColors.rose500));
                      }
                      setState(() => _configRefreshKey++);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShiftDialog(Map<String, dynamic>? shiftToEdit, List<Map<String, dynamic>> currentShifts, List<String> availableAreas) {
    String name = shiftToEdit?['name'] ?? 'Pagi';
    String start = shiftToEdit?['start'] ?? '08:00';
    String end = shiftToEdit?['end'] ?? '17:00';
    String shiftArea = shiftToEdit?['area'] ?? _selectedShiftArea;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            bool isSubmittingShift = false;

            void submitShift() async {
              if (isSubmittingShift) return;
              setDialogState(() => isSubmittingShift = true);

              List<Map<String, dynamic>> updatedShifts = List.from(currentShifts);
              if (shiftToEdit == null) {
                bool exists = updatedShifts.any((e) => e['name'] == name && e['area'] == shiftArea);
                if (exists) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Shift $name sudah ada di area ini!"), backgroundColor: AppColors.rose500));
                   setDialogState(() => isSubmittingShift = false);
                   return;
                }
                updatedShifts.add({'id': 'shift-${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'start': start, 'end': end, 'area': shiftArea});
              } else {
                int idx = updatedShifts.indexWhere((e) => e['id'] == shiftToEdit['id']);
                if (idx != -1) { updatedShifts[idx] = {'id': shiftToEdit['id'], 'name': name, 'start': start, 'end': end, 'area': shiftArea}; }
              }

              var currentData = Map<String, dynamic>.from(await ApiService.getConfig('site?t=${DateTime.now().millisecondsSinceEpoch}') ?? {});
              currentData['shifts'] = updatedShifts;
              bool success = await ApiService.updateConfig('site', currentData);
              
              if (success && mounted) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shift berhasil disimpan!"), backgroundColor: AppColors.emerald500));
                setState(() => _configRefreshKey++);
              } else if (mounted) {
                setDialogState(() => isSubmittingShift = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan shift. Coba lagi."), backgroundColor: AppColors.rose500));
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
              title: Row(
                children: [
                  Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.amber500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.timer, color: Colors.white, size: isMobile ? 20 : 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(shiftToEdit == null ? "TAMBAH SHIFT" : "EDIT SHIFT", style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w900))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("KATEGORI SHIFT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: ['Pagi', 'Malam', 'Siang', 'General'].contains(name) ? name : 'Pagi',
                      decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                      items: ['Pagi', 'Malam', 'Siang', 'General'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          name = v!;
                          // Auto-set default times based on shift category
                          switch (name) {
                            case 'Pagi':
                              start = '08:00';
                              end = '17:00';
                              break;
                            case 'Siang':
                              start = '13:00';
                              end = '22:00';
                              break;
                            case 'Malam':
                              start = '18:00';
                              end = '06:00';
                              break;
                            case 'General':
                              start = '08:00';
                              end = '17:00';
                              break;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text("AREA SHIFT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: availableAreas.contains(shiftArea) ? shiftArea : availableAreas.first,
                      decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                      items: availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setDialogState(() => shiftArea = v!),
                    ),
                    const SizedBox(height: 24),
                    
                    if (isMobile) ...[
                      const Text("JAM MASUK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(start.split(':')[0]) ?? 8, minute: int.tryParse(start.split(':')[1]) ?? 0));
                          if (picked != null) setDialogState(() => start = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                        },
                        child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                      ),
                      const SizedBox(height: 24),
                      const Text("JAM PULANG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(end.split(':')[0]) ?? 17, minute: int.tryParse(end.split(':')[1]) ?? 0));
                          if (picked != null) setDialogState(() => end = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                        },
                        child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("JAM MASUK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(start.split(':')[0]) ?? 8, minute: int.tryParse(start.split(':')[1]) ?? 0));
                                    if (picked != null) setDialogState(() => start = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                                  },
                                  child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("JAM PULANG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(end.split(':')[0]) ?? 17, minute: int.tryParse(end.split(':')[1]) ?? 0));
                                    if (picked != null) setDialogState(() => end = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                                  },
                                  child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Tutup", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isSubmittingShift ? null : submitShift,
                  child: isSubmittingShift
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDepartemenView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    double padding = isMobile ? 16 : 32;

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('dept_$_configRefreshKey'),
      future: _loadConfig(),
      builder: (context, snapshot) {
        
        if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(padding), child: const Text("Terjadi kesalahan memuat data", style: TextStyle(color: AppColors.emerald500))));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(padding: EdgeInsets.all(padding), child: const CircularProgressIndicator(color: AppColors.emerald500)),
          );
        }

        List<Map<String, dynamic>> strukturOrganisasi = [];
        
        // Always provide a fallback dictionary if null
        var data = snapshot.data ?? <String, dynamic>{};
          
          if (data.containsKey('struktur_organisasi')) {
            strukturOrganisasi = List<Map<String, dynamic>>.from(
              (data['struktur_organisasi'] as List).map((e) => Map<String, dynamic>.from(e))
            );
          } else {
            // Migrasi otomatis jika data struktur_organisasi belum ada di database
            List<dynamic> oldDeps = data['departemens'] ?? ['Umum'];
            List<dynamic> oldJabs = data['jabatans'] ?? ['Staff'];
            
            strukturOrganisasi = [
              {'departemen': oldDeps.isNotEmpty ? oldDeps.first : 'Umum', 'jabatan': oldJabs.isNotEmpty ? oldJabs.first : 'Staff'}
            ];
          }

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBack("DEPARTEMEN & JABATAN"),
              SizedBox(height: padding),
              _buildStrukturGrouped(strukturOrganisasi),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStrukturGrouped(List<Map<String, dynamic>> strukturList) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    // Kelompokkan data berdasarkan Departemen
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (int i = 0; i < strukturList.length; i++) {
      String dep = strukturList[i]['departemen'].toString();
      if (!groupedData.containsKey(dep)) {
        groupedData[dep] = [];
      }
      String jab = strukturList[i]['jabatan'].toString();
      if (jab.isNotEmpty) {
        groupedData[dep]!.add({
          'originalIndex': i,
          'jabatan': jab,
        });
      }
    }

    // URUTKAN DAFTAR DEPARTEMEN DARI A - Z
    var sortedEntries = groupedData.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(isMobile ? 24 : 40), 
        border: Border.all(color: AppColors.slate200), 
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("STRUKTUR ORGANISASI PERUSAHAAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500, 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: () => _showStrukturDialog(null, null, strukturList),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("Departemen Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  )
                ]
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "STRUKTUR ORGANISASI PERUSAHAAN",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)
                    )
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500, 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: () => _showStrukturDialog(null, null, strukturList),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("Departemen Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  )
                ],
              ),
          const SizedBox(height: 32),

          if (sortedEntries.isEmpty)
             const Center(
               child: Padding(
                 padding: EdgeInsets.all(40), 
                 child: Text("Belum ada data struktur organisasi", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
               )
             ),

          ...sortedEntries.map((entry) {
            String depName = entry.key;
            List<Map<String, dynamic>> jabs = entry.value;

            // URUTKAN DAFTAR JABATAN DI DALAM DEPARTEMEN DARI A - Z
            jabs.sort((a, b) => a['jabatan'].toString().toLowerCase().compareTo(b['jabatan'].toString().toLowerCase()));

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER DEPARTEMEN ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: const Border(bottom: BorderSide(color: AppColors.slate200))
                    ),
                    child: isMobile 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.domain, color: AppColors.slate500, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("DEPARTEMEN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                                      Text(depName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate800)),
                                    ],
                                  ),
                                ),
                              ]
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: AppColors.slate400),
                                      tooltip: 'Edit Departemen',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDepartemenDialog(depName, strukturList)
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16, color: AppColors.rose400),
                                      tooltip: 'Hapus Departemen',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        bool confirm = await showDialog(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text("Hapus Departemen?"),
                                            content: Text("Yakin ingin menghapus departemen '$depName' beserta seluruh jabatan di dalamnya?"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                                            ],
                                          )
                                        );
                                        if (confirm == true) {
                                          List<Map<String, dynamic>> updated = List.from(strukturList);
                                          updated.removeWhere((item) => item['departemen'] == depName);
                                          await _saveStrukturOrganisasi(updated);
                                        }
                                      }
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showStrukturDialog(null, {'departemen': depName, 'jabatan': ''}, strukturList, lockDepartemen: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.add, size: 12, color: AppColors.slate600),
                                        SizedBox(width: 4),
                                        Text("JABATAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1))
                                      ],
                                    )
                                  )
                                )
                              ],
                            )
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.domain, color: AppColors.slate500, size: 24),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("DEPARTEMEN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                                    Text(depName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800)),
                                  ],
                                ),
                              ]
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: AppColors.slate400),
                                  tooltip: 'Edit Departemen',
                                  onPressed: () => _showEditDepartemenDialog(depName, strukturList)
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.rose400),
                                  tooltip: 'Hapus Departemen',
                                  onPressed: () async {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Hapus Departemen?"),
                                        content: Text("Yakin ingin menghapus departemen '$depName' beserta seluruh jabatan di dalamnya?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                                        ],
                                      )
                                    );
                                    if (confirm == true) {
                                      List<Map<String, dynamic>> updated = List.from(strukturList);
                                      updated.removeWhere((item) => item['departemen'] == depName);
                                      await _saveStrukturOrganisasi(updated);
                                    }
                                  }
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showStrukturDialog(null, {'departemen': depName, 'jabatan': ''}, strukturList, lockDepartemen: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.add, size: 14, color: AppColors.slate600),
                                        SizedBox(width: 4),
                                        Text("JABATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1))
                                      ],
                                    )
                                  )
                                )
                              ],
                            )
                          ],
                        ),
                  ),

                  // --- LIST JABATAN DI BAWAH DEPARTEMEN ---
                  if (jabs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text("Belum ada jabatan di departemen ini", style: TextStyle(color: AppColors.slate400, fontStyle: FontStyle.italic)),
                    )
                  else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: jabs.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (context, index) {
                      var jabData = jabs[index];
                      int origIdx = jabData['originalIndex'];
                      String jabName = jabData['jabatan'];

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.badge, size: 16, color: AppColors.slate400),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(jabName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13, color: AppColors.slate700))),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: AppColors.slate400),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showStrukturDialog(origIdx, {'departemen': depName, 'jabatan': jabName}, strukturList, lockDepartemen: true)
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.rose400),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Hapus Jabatan?"),
                                        content: Text("Yakin ingin menghapus posisi '$jabName' dari departemen '$depName'?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red)))
                                        ],
                                      )
                                    );
                                    if (confirm) {
                                      List<Map<String, dynamic>> updated = List.from(strukturList);
                                      int count = updated.where((item) => item['departemen'] == depName).length;
                                      if (count <= 1) {
                                        // Jika INI adalah jabatan terakhir, jangan hapus departemen-nya
                                        int index = updated.indexWhere((item) => item == strukturList[origIdx]);
                                        updated[index] = {'departemen': depName, 'jabatan': ''};
                                      } else {
                                        updated.removeAt(origIdx);
                                      }
                                      await _saveStrukturOrganisasi(updated);
                                    }
                                  }
                                )
                              ]
                            )
                          ],
                        )
                      );
                    }
                  )
                ],
              )
            );
          }).toList(),
        ],
      )
    );
  }

  void _showStrukturDialog(int? indexToEdit, Map<String, dynamic>? itemToEdit, List<Map<String, dynamic>> currentList, {bool lockDepartemen = false}) {
    String departemen = itemToEdit != null ? itemToEdit['departemen'] : '';
    String jabatan = itemToEdit != null ? itemToEdit['jabatan'] : '';
    bool isEdit = indexToEdit != null;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
        bool isSubmittingStruktur = false;

        void submitStruktur() async {
          if (departemen.trim().isEmpty || jabatan.trim().isEmpty) return;
          if (isSubmittingStruktur) return;
          setDialogState(() => isSubmittingStruktur = true);
          FocusManager.instance.primaryFocus?.unfocus(); 
          
          List<Map<String, dynamic>> updatedList = List.from(currentList);

          if (isEdit) {
            updatedList[indexToEdit] = {
              'departemen': departemen.trim(),
              'jabatan': jabatan.trim()
            };
          } else {
            updatedList.add({
              'departemen': departemen.trim(),
              'jabatan': jabatan.trim()
            });
          }

          bool success = await _saveStrukturOrganisasi(updatedList);
          if (success && mounted) {
            Navigator.of(dialogContext).pop();
          } else if (mounted) {
            setDialogState(() => isSubmittingStruktur = false);
          }
        }

        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
          title: Row(
            children: [
              Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.emerald500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.work, color: Colors.white, size: isMobile ? 20 : 24)),
              const SizedBox(width: 16),
              Expanded(child: Text(isEdit ? "EDIT POSISI" : "TAMBAH POSISI BARU", style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("NAMA DEPARTEMEN / DIVISI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => departemen = v,
                  controller: TextEditingController(text: departemen)..selection = TextSelection.collapsed(offset: departemen.length),
                  enabled: !lockDepartemen,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(), 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: lockDepartemen ? AppColors.slate500 : AppColors.slate800),
                  decoration: InputDecoration(
                    hintText: "Contoh: IT, Umum, Finance...", 
                    filled: true, fillColor: lockDepartemen ? AppColors.slate100 : AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
                const SizedBox(height: 24),
                const Text("NAMA JABATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => jabatan = v, 
                  controller: TextEditingController(text: jabatan)..selection = TextSelection.collapsed(offset: jabatan.length),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    submitStruktur();
                  },
                  decoration: InputDecoration(
                    hintText: "Contoh: IT Support, Manager...", 
                    filled: true, fillColor: AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dialogContext);
              }, 
              child: const Text("Tutup", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: isSubmittingStruktur ? null : submitStruktur,
              child: isSubmittingStruktur
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
          },
        );
      },
    );
  }

  void _showEditDepartemenDialog(String oldDepName, List<Map<String, dynamic>> currentList) {
    String newDepName = oldDepName;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
        bool isSubmittingEdit = false;

        void submitEdit() async {
          if (newDepName.trim().isEmpty || newDepName.trim() == oldDepName) return;
          if (isSubmittingEdit) return;
          setDialogState(() => isSubmittingEdit = true);
          FocusManager.instance.primaryFocus?.unfocus();
          
          List<Map<String, dynamic>> updatedList = List.from(currentList);
          for (int i = 0; i < updatedList.length; i++) {
            if (updatedList[i]['departemen'] == oldDepName) {
              updatedList[i]['departemen'] = newDepName.trim();
            }
          }

          bool success = await _saveStrukturOrganisasi(updatedList);
          if (success && mounted) {
            Navigator.of(dialogContext).pop();
          } else if (mounted) {
            setDialogState(() => isSubmittingEdit = false);
          }
        }

        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
          title: Row(
            children: [
              Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.blue500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.domain, color: Colors.white, size: isMobile ? 20 : 24)),
              const SizedBox(width: 16),
              Expanded(child: Text("EDIT DEPARTEMEN", style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("NAMA DEPARTEMEN / DIVISI BARU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => newDepName = v, 
                  controller: TextEditingController(text: newDepName)..selection = TextSelection.collapsed(offset: newDepName.length),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    submitEdit();
                  },
                  decoration: InputDecoration(
                    hintText: "Contoh: IT, Umum, Finance...", 
                    filled: true, fillColor: AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dialogContext);
              }, 
              child: const Text("Tutup", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: isSubmittingEdit ? null : submitEdit,
              child: isSubmittingEdit
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
          },
        );
      },
    );
  }

  Future<bool> _saveStrukturOrganisasi(List<Map<String, dynamic>> strukturList) async {
    Set<String> deps = {};
    Set<String> jabs = {};
    
    for(var item in strukturList) {
      if (item['departemen'].toString().isNotEmpty) deps.add(item['departemen']);
      if (item['jabatan'].toString().isNotEmpty) jabs.add(item['jabatan']);
    }

    var currentData = Map<String, dynamic>.from(await ApiService.getConfig('site') ?? {});
    currentData['struktur_organisasi'] = strukturList;
    currentData['departemens'] = deps.toList();
    currentData['jabatans'] = jabs.toList();
    
    bool success = await ApiService.updateConfig('site', currentData);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil menyimpan struktur organisasi!"), backgroundColor: AppColors.emerald500));
      setState(() => _configRefreshKey++);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan struktur."), backgroundColor: AppColors.rose500));
    }
    
    return success;
  }

  Widget _buildHeaderBack(String title) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.slate500, size: isMobile ? 20 : 28),
          onPressed: () => setState(() => _activeSetting = 'menu'),
          style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(isMobile ? 8 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.slate200))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(title.toUpperCase(), style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// --- CLASS _ProfileForm (UI Form Edit Profil) ---
class _ProfileForm extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> configData;
  final String userId;
  final String userRole; // <-- Ditambahkan User Role 
  final VoidCallback onBack;
  final VoidCallback onProfileUpdated;

  const _ProfileForm({
    required this.userData,
    required this.configData,
    required this.userId,
    required this.userRole,
    required this.onBack,
    required this.onProfileUpdated,
  });

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _kontakCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController(); // TAMBAHAN EMAIL
  final TextEditingController _alamatCtrl = TextEditingController();
  final TextEditingController _nikCtrl = TextEditingController(); // NRP Controller

  String _agama = 'Islam';
  String _area = '';
  String _departemen = '';
  String _jabatan = '';
  String? _photoBase64;
  
  DateTime? _tanggalLahir;
  String _jenisKelamin = 'Laki-laki';
  
  bool _isSaving = false;
  bool _isEditMode = false; // Status mode edit aktif/tidak

  List<String> _availableAreas = [];
  List<String> _departemens = [];
  List<String> _jabatans = [];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    List<dynamic> locs = widget.configData['locations'] ?? [];
    if (locs.isNotEmpty) {
      _availableAreas = locs.map((e) => e['siteName'].toString()).toList();
      _availableAreas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      _availableAreas = ['Semua Area'];
    }

    if (widget.configData.containsKey('struktur_organisasi')) {
      _strukturOrganisasi = List<Map<String, dynamic>>.from(widget.configData['struktur_organisasi']);
      Set<String> deps = _strukturOrganisasi.map((e) => e['departemen'].toString()).toSet();
      _departemens = deps.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      _departemens = List<String>.from(widget.configData['departemens'] ?? ['Umum'])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    _namaCtrl.text = widget.userData['nama_lengkap'] ?? '';
    _nikCtrl.text = widget.userData['nik'] ?? '';
    _kontakCtrl.text = widget.userData['kontak'] ?? '';
    _emailCtrl.text = widget.userData['email'] ?? ''; 
    _alamatCtrl.text = widget.userData['alamat'] ?? '';
    _agama = widget.userData['agama'] ?? 'Islam';
    
    _jenisKelamin = widget.userData['jenis_kelamin'] ?? 'Laki-laki';
    if (!['Laki-laki', 'Perempuan'].contains(_jenisKelamin)) _jenisKelamin = 'Laki-laki';
    
    if (widget.userData['tanggal_lahir'] != null && widget.userData['tanggal_lahir'].toString().isNotEmpty) {
      try {
         _tanggalLahir = DateTime.parse(widget.userData['tanggal_lahir']);
      } catch (e) {
         _tanggalLahir = null;
      }
    }
    
    _area = widget.userData['area'] ?? '';
    if (!_availableAreas.contains(_area)) _area = _availableAreas.isNotEmpty ? _availableAreas.first : '';

    _departemen = widget.userData['departemen_id'] ?? '';
    bool isKaryawan = widget.userRole == 'Karyawan';
    
    if (!_departemens.contains(_departemen)) {
        if (!isKaryawan) {
             _departemen = _departemens.isNotEmpty ? _departemens.first : '';
        } else if (_departemen.isNotEmpty) {
             _departemens.add(_departemen);
        }
    }

    _updateJabatanList(_departemen);
    _jabatan = widget.userData['jabatan'] ?? '';
    if (!_jabatans.contains(_jabatan)) {
        if (!isKaryawan) {
             _jabatan = _jabatans.isNotEmpty ? _jabatans.first : '';
        } else if (_jabatan.isNotEmpty) {
             _jabatans.add(_jabatan);
        }
    }

    _photoBase64 = widget.userData['photo_base64'];
  }

  void _updateJabatanList(String departemen) {
    if (_strukturOrganisasi.isEmpty) {
       _jabatans = List<String>.from(widget.configData['jabatans'] ?? ['Staff'])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
       return;
    }
    var relatedJabs = _strukturOrganisasi
        .where((e) => e['departemen'] == departemen)
        .map((e) => e['jabatan'].toString())
        .toSet()
        .toList();
        
    relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    setState(() {
      _jabatans = relatedJabs.isNotEmpty ? relatedJabs : ['Staff'];
      if (!_jabatans.contains(_jabatan)) {
        _jabatan = _jabatans.first;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      // GUARD: Cek apakah foto sudah dikunci (lebih dari 2x ganti)
      int currentCount = widget.userData['photo_change_count'] != null 
          ? int.tryParse(widget.userData['photo_change_count'].toString()) ?? 0 
          : 0;
      if (widget.userRole == 'Karyawan' && currentCount >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("⛔ Foto profil sudah dikunci (batas 3x). Hubungi Admin untuk reset."),
            backgroundColor: AppColors.rose500
          ));
        }
        return;
      }
      // Tampilkan pilihan metode
      String? sourceChoice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Metode Pengambilan Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.blue500),
                title: const Text("Ambil Foto dari Kamera Langsung", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.blue500),
                title: const Text("Pilih File Foto dari Perangkat", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
        )
      );

      if (sourceChoice == null) return; // Batal

      Uint8List? imageBytes;

      if (sourceChoice == 'camera') {
        if (kIsWeb) {
          // === WEB: Gunakan HTML5 getUserMedia untuk capture wajah ===
          imageBytes = await _captureWebcamForRegistration();
          if (imageBytes == null) return; // User cancelled
        } else {
          // === MOBILE: Gunakan kamera ===
          final XFile? image = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 600,
            maxHeight: 600,
            imageQuality: 70,
            preferredCameraDevice: CameraDevice.front,
          );
          if (image == null) return;
          imageBytes = await image.readAsBytes();
        }
      } else if (sourceChoice == 'gallery') {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 600,
          maxHeight: 600,
          imageQuality: 70,
        );
        if (image == null) return;
        imageBytes = await image.readAsBytes();
      }


      // Tampilkan dialog loading Server AI
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Row(
              children: [
                SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(color: AppColors.blue500, strokeWidth: 3)
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text("Mendaftarkan wajah ke Server AI...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800))
                ),
              ],
            ),
          )
        );
      }

      // REGISTER FACE KE PYTHON AI SERVICE (semua platform)
      var response = await ApiService.registerFaceBytes(imageBytes!, widget.userId);

      if (mounted) Navigator.pop(context); // Tutup dialog loading

      if (response['success'] == true) {
         setState(() {
           _photoBase64 = base64Encode(imageBytes!);
           int currentCount = widget.userData['photo_change_count'] != null ? int.tryParse(widget.userData['photo_change_count'].toString()) ?? 0 : 0;
           widget.userData['photo_change_count'] = currentCount + 1;
         });
         widget.onProfileUpdated();
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("✅ Wajah berhasil dipindai dan didaftarkan ke sistem AI."),
             backgroundColor: AppColors.emerald500
           ));
         }
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text("❌ Gagal mendaftarkan wajah: ${response['message']}"),
             backgroundColor: AppColors.rose500
           ));
         }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memproses foto: $e"), backgroundColor: AppColors.rose500));
      }
    }
  }

  /// Capture webcam foto untuk registrasi wajah di Web
  Future<Uint8List?> _captureWebcamForRegistration() async {
    return await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WebCamCaptureDialog(),
    );
  }

  Future<void> _saveProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_namaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama lengkap wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }
    if (_nikCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NRP wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alamat Email wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }

    // --- TAMBAHAN VALIDASI WAJIB FOTO PROFIL UNTUK FACECAM ---
    if (_photoBase64 == null || _photoBase64!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Akses Ditolak: Foto Profil wajib diunggah! Wajah Anda diperlukan untuk validasi Face Recognition saat absensi."), 
        backgroundColor: AppColors.rose500,
        duration: Duration(seconds: 5),
      ));
      return; // Hentikan proses simpan jika foto tidak ada
    }
    // ---------------------------------------------------------

    setState(() => _isSaving = true);
    try {
      await ApiService.updateUser(widget.userId, {
        'nama_lengkap': _namaCtrl.text.trim(),
        'nik': _nikCtrl.text.trim(), // SIMPAN NRP
        'email': _emailCtrl.text.trim(), // SIMPAN EMAIL
        'kontak': _kontakCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'agama': _agama,
        'jenis_kelamin': _jenisKelamin,
        if (_tanggalLahir != null) 'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_tanggalLahir!),
        'departemen_id': _departemen,
        'jabatan': _jabatan,
        'area': _area,
        if (_photoBase64 != null) 'photo_base64': _photoBase64,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Berhasil Diperbarui!"), backgroundColor: AppColors.emerald500));
        widget.onProfileUpdated();
        setState(() => _isEditMode = false); // Mengunci form kembali
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan profil."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    bool isComplete = (_photoBase64 != null && _photoBase64!.isNotEmpty) &&
                      (_tanggalLahir != null) &&
                      (_emailCtrl.text.isNotEmpty) &&
                      (_kontakCtrl.text.isNotEmpty && _kontakCtrl.text != '-') &&
                      (_alamatCtrl.text.isNotEmpty && _alamatCtrl.text != '-');

    // LOGIKA KUNCI DATA UNTUK KARYAWAN BIASA
    bool isKaryawan = widget.userRole == 'Karyawan';
    // Foto dikunci jika usernya karyawan DAN sudah mengganti foto >= 3 kali
    int changeCount = widget.userData['photo_change_count'] != null ? int.tryParse(widget.userData['photo_change_count'].toString()) ?? 0 : 0;
    bool isPhotoLocked = isKaryawan && (changeCount >= 3);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.slate500, size: isMobile ? 20 : 24),
                onPressed: widget.onBack,
                style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(isMobile ? 8 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.slate200))),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text("PROFIL SAYA", style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
              
              // TOMBOL EDIT & BATAL
              if (!_isEditMode)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow500,
                    foregroundColor: AppColors.slate900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12)
                  ),
                  onPressed: () => setState(() => _isEditMode = true),
                  icon: Icon(Icons.edit, size: isMobile ? 14 : 16),
                  label: Text("Edit Profil", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 10 : 12, letterSpacing: 1)),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.slate500),
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _initData(); // Revert ke data semula
                    });
                  },
                  icon: Icon(Icons.close, size: isMobile ? 14 : 16),
                  label: Text("Batal", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 10 : 12)),
                )
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          if (!isComplete)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.rose200)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.rose500),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Profil Anda belum lengkap! Harap lengkapi semua data diri termasuk Alamat Email dan Foto Profil (Wajah).", style: TextStyle(color: AppColors.rose600, fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              )
            ),

          // PEMBERITAHUAN BAHWA BEBERAPA DATA DIKUNCI OLEH ADMIN (KHUSUS KARYAWAN SAAT EDIT MODE)
          if (_isEditMode && isKaryawan)
             Container(
               margin: const EdgeInsets.only(bottom: 24),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.blue500)),
               child: Row(
                 children: [
                   const Icon(Icons.lock_outline, color: AppColors.blue500),
                   const SizedBox(width: 12),
                   Expanded(child: Text(isPhotoLocked ? "INFO: Foto Profil (Wajah), Departemen, dan Jabatan telah dikunci oleh sistem. Hubungi HR / Admin jika Anda ingin mereset perubahan." : "INFO: Departemen dan Jabatan telah ditetapkan oleh sistem. Hubungi HR / Admin jika Anda memiliki kendala data.", style: const TextStyle(color: AppColors.blue500, fontWeight: FontWeight.bold, fontSize: 11))),
                 ],
               )
             ),

          Container(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 24 : 40), border: Border.all(color: AppColors.slate100), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.slate200, width: 2)),
                        child: CircleAvatar(
                          radius: isMobile ? 40 : 56,
                          backgroundColor: AppColors.slate100,
                          backgroundImage: _photoBase64 != null && _photoBase64!.isNotEmpty ? MemoryImage(base64Decode(_photoBase64!)) : null,
                          child: _photoBase64 == null || _photoBase64!.isEmpty
                            ? Text(_namaCtrl.text.isNotEmpty ? _namaCtrl.text[0].toUpperCase() : 'U', style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w900, color: AppColors.slate400))
                            : null,
                        ),
                      ),
                      if (_isEditMode && !isPhotoLocked) // TOMBOL KAMERA HILANG JIKA SUDAH DIKUNCI
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 8 : 10),
                            decoration: BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(Icons.camera_alt, size: isMobile ? 16 : 20, color: AppColors.slate900),
                          ),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(
                  _isEditMode && !isPhotoLocked 
                    ? "📸 Pilih / Ambil Foto Wajah\n(Sisa ganti foto: ${3 - changeCount}x)" 
                    : "Foto Profil (Wajah) Terkunci (Hubungi Admin)", 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1, height: 1.5)
                )),
                const SizedBox(height: 40),

                // BARIS 1: NAMA LENGKAP & NIK
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("NAMA LENGKAP", TextField(controller: _namaCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("Nama Lengkap"))),
                       const SizedBox(height: 16),
                       _buildInputCol("NRP", TextField(controller: _nikCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("NRP-XXX"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("NAMA LENGKAP", TextField(controller: _namaCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("Nama Lengkap")))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("NRP", TextField(controller: _nikCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("NRP-XXX")))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _jenisKelamin = v!) : null,
                       )),
                       const SizedBox(height: 16),
                       _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: _isEditMode ? () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _tanggalLahir ?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _tanggalLahir = picked);
                          } : null,
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(color: _isEditMode ? AppColors.slate50 : AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_tanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _tanggalLahir != null ? (_isEditMode ? AppColors.slate800 : AppColors.slate500) : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                       )),
                     ]
                   )
                 : Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(child: _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _jenisKelamin = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: _isEditMode ? () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _tanggalLahir ?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _tanggalLahir = picked);
                          } : null,
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(color: _isEditMode ? AppColors.slate50 : AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_tanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _tanggalLahir != null ? (_isEditMode ? AppColors.slate800 : AppColors.slate500) : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                       ))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _agama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _agama = v!) : null,
                       )),
                       const SizedBox(height: 16),
                       _buildInputCol("NO. TELEPON", TextField(controller: _kontakCtrl, enabled: _isEditMode, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("No. HP Aktif"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _agama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _agama = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("NO. TELEPON", TextField(controller: _kontakCtrl, enabled: _isEditMode, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("No. HP Aktif")))),
                     ],
                   ),
                const SizedBox(height: 16),

                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("ALAMAT EMAIL", TextField(controller: _emailCtrl, enabled: _isEditMode, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("email@karyawan.com"))),
                       const SizedBox(height: 16),
                       _buildInputCol("ALAMAT LENGKAP", TextField(controller: _alamatCtrl, enabled: _isEditMode, maxLines: 2, textInputAction: TextInputAction.done, style: _textStyle(), decoration: _inputDeco("Alamat Lengkap Karyawan"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("ALAMAT EMAIL", TextField(controller: _emailCtrl, enabled: _isEditMode, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("email@karyawan.com")))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("ALAMAT LENGKAP", TextField(controller: _alamatCtrl, enabled: _isEditMode, maxLines: 2, textInputAction: TextInputAction.done, style: _textStyle(), decoration: _inputDeco("Alamat Lengkap Karyawan")))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("DEPARTEMEN / DIVISI", isKaryawan 
                         ? TextField(controller: TextEditingController(text: _departemen), enabled: false, style: _textStyle(isLocked: true), decoration: _inputDeco("", isLocked: true))
                         : DropdownButtonFormField<String>(
                            isExpanded: true, initialValue: _departemen, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                            items: _departemens.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (_isEditMode && !isKaryawan) ? (v) { setState(() { _departemen = v!; _updateJabatanList(v); }); } : null,
                         )),
                       const SizedBox(height: 16),
                       _buildInputCol("JABATAN / POSISI", isKaryawan 
                         ? TextField(controller: TextEditingController(text: _jabatan), enabled: false, style: _textStyle(isLocked: true), decoration: _inputDeco("", isLocked: true))
                         : DropdownButtonFormField<String>(
                            isExpanded: true, initialValue: _jabatan, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                            items: _jabatans.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _jabatan = v!) : null,
                         )),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("DEPARTEMEN / DIVISI", isKaryawan 
                         ? TextField(controller: TextEditingController(text: _departemen), enabled: false, style: _textStyle(isLocked: true), decoration: _inputDeco("", isLocked: true))
                         : DropdownButtonFormField<String>(
                            isExpanded: true, initialValue: _departemen, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                            items: _departemens.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (_isEditMode && !isKaryawan) ? (v) { setState(() { _departemen = v!; _updateJabatanList(v); }); } : null,
                         ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("JABATAN / POSISI", isKaryawan 
                         ? TextField(controller: TextEditingController(text: _jabatan), enabled: false, style: _textStyle(isLocked: true), decoration: _inputDeco("", isLocked: true))
                         : DropdownButtonFormField<String>(
                            isExpanded: true, initialValue: _jabatan, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                            items: _jabatans.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _jabatan = v!) : null,
                         ))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? _buildInputCol("AREA PENUGASAN", DropdownButtonFormField<String>(
                      isExpanded: true, initialValue: _area, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                      items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _area = v!) : null,
                   ))
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("AREA PENUGASAN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _area, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _area = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       const Expanded(child: SizedBox()), // Placeholder for balance
                     ],
                   ),

                if (_isEditMode) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 10, shadowColor: AppColors.slate900.withValues(alpha: 0.3)),
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                    ),
                  )
                ]
              ],
            ),
          )
        ]
      )
    );
  }

  Widget _buildInputCol(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  TextStyle _textStyle({bool isLocked = false}) {
    return TextStyle(fontWeight: FontWeight.bold, color: (_isEditMode && !isLocked) ? AppColors.slate800 : AppColors.slate500);
  }

  InputDecoration _inputDeco(String hint, {bool isLocked = false}) {
    return InputDecoration(
      hintText: hint, 
      filled: true, 
      fillColor: (_isEditMode && !isLocked) ? AppColors.slate50 : AppColors.slate100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}

/// Dialog khusus untuk capture webcam di web (registrasi wajah)
class _WebCamCaptureDialog extends StatefulWidget {
  @override
  State<_WebCamCaptureDialog> createState() => _WebCamCaptureDialogState();
}

class _WebCamCaptureDialogState extends State<_WebCamCaptureDialog> {
  WebCameraController? _webCam;
  bool _isInitializing = true;
  String _error = '';
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initWebcam();
  }

  Future<void> _initWebcam() async {
    try {
      _webCam = WebCameraController();
      await _webCam!.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) setState(() { _error = "Gagal mengakses webcam: $e"; _isInitializing = false; });
    }
  }

  @override
  void dispose() { _webCam?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("REGISTRASI WAJAH", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: AppColors.blue500.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.blue500, size: 20), SizedBox(width: 10),
              Expanded(child: Text("Arahkan wajah Anda ke kamera secara jelas.\nFoto ini akan menjadi data profil dan acuan verifikasi AI.", style: TextStyle(color: AppColors.blue500, fontSize: 10, fontWeight: FontWeight.bold, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.yellow500, width: 2)),
              clipBehavior: Clip.antiAlias,
              child: _isInitializing ? const Center(child: CircularProgressIndicator(color: AppColors.yellow500))
                : _error.isNotEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, style: const TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)))
                : buildWebCameraPreview(_webCam!),
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow500, foregroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: (_isInitializing || _error.isNotEmpty || _isCapturing) ? null : () async {
                setState(() => _isCapturing = true);
                try {
                  final bytes = await _webCam!.capture();
                  if (bytes != null && mounted) { Navigator.pop(context, bytes); } else { setState(() => _isCapturing = false); }
                } catch (e) { setState(() { _error = "Gagal menangkap gambar: $e"; _isCapturing = false; }); }
              },
              icon: _isCapturing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate900)) : const Icon(Icons.camera_alt, size: 18),
              label: Text(_isCapturing ? "MEMPROSES..." : "AMBIL FOTO WAJAH", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            )),
          ]),
        ]),
      ),
    );
  }
}
