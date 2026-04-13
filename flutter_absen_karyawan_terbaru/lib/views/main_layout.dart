import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

import 'dashboard_view.dart';
import 'attendance_view.dart';
import 'settings_view.dart' hide HelpView;
import 'request_view.dart';
import 'karyawan_view.dart';
import 'admin_depthead_view.dart';
import 'help_view.dart';

// --- WIDGET JAM TERPISAH (KEAMANAN WITA + STOPWATCH) ---
class LiveClockWidget extends StatefulWidget {
  final TextStyle style;
  final String suffix;
  const LiveClockWidget({super.key, required this.style, this.suffix = ''});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  Timer? _timer;
  String _timeString = '--:--:--';

  DateTime? _ntpSyncTime;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initTimeSync();
  }

  Future<void> _initTimeSync() async {
    try {
      if (!kIsWeb) {
        _ntpSyncTime = await NTP.now(timeout: const Duration(seconds: 3));
        _stopwatch.start();
      }
    } catch (e) {
      debugPrint("Gagal sinkron NTP: $e");
    }

    _getTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _getTime(),
    );
  }

  void _getTime() {
    DateTime realTime;

    if (_ntpSyncTime != null && _stopwatch.isRunning) {
      realTime = _ntpSyncTime!.add(_stopwatch.elapsed);
    } else {
      realTime = DateTime.now();
    }

    DateTime witaTime = realTime.toUtc().add(const Duration(hours: 8));
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH:mm:ss').format(witaTime);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "$_timeString${widget.suffix}",
      style: widget.style,
    );
  }
}

class MainLayout extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const MainLayout({super.key, required this.user, required this.onLogout});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _currentView = 'dashboard';

  Widget _buildBody(bool isProfileComplete) {
    switch (_currentView) {
      case 'dashboard':
        return DashboardView(user: widget.user);
      case 'attendance':
        if (widget.user.role == 'admin') return _unauthorizedAccess();
        if (!isProfileComplete) return _incompleteProfileAccess();
        return AttendanceView(user: widget.user);
      case 'karyawan':
        if (widget.user.role != 'admin') return _unauthorizedAccess();
        return KaryawanView(user: widget.user);
      case 'requests':
        if (widget.user.role == 'Karyawan' || widget.user.role == 'admin') return _unauthorizedAccess(); // Dilarang untuk Karyawan dan IT Support
        return RequestView(user: widget.user);
      case 'pengaturan':
        return SettingsView(
          user: widget.user,
          onLogout: widget.onLogout,
          onChangeView: (view) {
            if (_currentView != view) {
              setState(() => _currentView = view);
            }
          },
        );
      case 'help':
      case 'admin_tickets':
        return HelpView(
          user: widget.user,
          onBack: () {
            if (_currentView != 'pengaturan') {
              setState(() => _currentView = 'pengaturan');
            }
          },
        );
      default:
        return DashboardView(user: widget.user);
    }
  }

  Widget _unauthorizedAccess() {
    return const Center(
      child: Text(
        "Akses Ditolak. Anda tidak memiliki izin untuk halaman ini.",
        style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _incompleteProfileAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: AppColors.rose50, shape: BoxShape.circle),
              child: const Icon(Icons.portrait,
                  size: 64, color: AppColors.rose500),
            ),
            const SizedBox(height: 24),
            const Text(
              "PROFIL BELUM LENGKAP",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate800),
            ),
            const SizedBox(height: 8),
            const Text(
              "Akses absensi terkunci sementara.\nAnda wajib mengunggah Foto Profil dan melengkapi data diri lainnya agar dapat melakukan kehadiran.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.slate500,
                  fontWeight: FontWeight.bold,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow500,
                foregroundColor: AppColors.slate900,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() => _currentView = 'pengaturan');
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Lengkapi Profil Sekarang",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.user.role == 'admin';
    bool isHead = widget.user.role == 'Head Area';
    bool isKaryawan = widget.user.role == 'Karyawan';

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: FutureBuilder<Map<String, dynamic>?>(
          future: ApiService.getUser(widget.user.id),
          builder: (context, snapshot) {
            bool isProfileComplete = true;
            String? photoBase64;
            String namaLengkap = widget.user.namaLengkap;
            String nik = widget.user.nik;
            Map<String, dynamic> userData = {};

            if (snapshot.hasData && snapshot.data != null) {
              userData = snapshot.data!;
              String kontak = userData['kontak'] ?? '-';
              String alamat = userData['alamat'] ?? '-';
              String tglLahir = userData['tanggal_lahir'] ?? '';

              photoBase64 = userData['photo_base64'];
              namaLengkap = userData['nama_lengkap'] ?? widget.user.namaLengkap;
              nik = userData['nik'] ?? widget.user.nik;

              if (!isAdmin) {
                if (kontak == '-' ||
                    kontak.isEmpty ||
                    alamat == '-' ||
                    alamat.isEmpty ||
                    tglLahir.isEmpty ||
                    photoBase64 == null ||
                    photoBase64.isEmpty) {
                  isProfileComplete = false;
                }
              }
            } else {
              if (!isAdmin) isProfileComplete = false;
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 800;

                Widget mainContent;

                if (isDesktop) {
                  mainContent = Row(
                    children: [
                      Container(
                        width: 280,
                        color: AppColors.slate900,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.slate800),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: kIsWeb
                                        ? Image.network(
                                            'UNTR.JK-97580c63.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.security,
                                              size: 32,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Image.asset(
                                            'web/UNTR.JK-97580c63.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.security,
                                              size: 32,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            "UNITED TRACTORS",
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2),
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 1.0),
                                            child: Text(
                                              "member of ASTRA",
                                              style: TextStyle(
                                                color: AppColors.blue500,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDesktopNavItem(
                                      'dashboard',
                                      'Beranda',
                                      Icons.dashboard,
                                    ),
                                    if (isKaryawan || isHead)
                                      _buildDesktopNavItem(
                                        'attendance',
                                        'Kehadiran',
                                        Icons.event_available,
                                      ),
                                    if (isHead) // Hanya muncul untuk Head Area
                                      _buildDesktopNavItem(
                                        'requests',
                                        'Layanan Mandiri',
                                        Icons.assignment,
                                      ),
                                    if (isAdmin) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 32,
                                          top: 32,
                                          bottom: 12,
                                        ),
                                        child: Text(
                                          "MANAJEMEN",
                                          style: TextStyle(
                                            color: AppColors.slate500,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      _buildDesktopNavItem(
                                        'karyawan',
                                        'Data Karyawan',
                                        Icons.people,
                                      ),
                                    ],
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 32,
                                        top: 32,
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        "AKUN & SISTEM",
                                        style: TextStyle(
                                          color: AppColors.slate500,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                    _buildDesktopNavItem(
                                      'pengaturan',
                                      'Pengaturan',
                                      Icons.settings,
                                      showBadge: !isProfileComplete && !isAdmin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isAdmin)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.slate800),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.yellow500,
                                      radius: 20,
                                      backgroundImage: photoBase64 != null &&
                                              photoBase64.isNotEmpty
                                          ? MemoryImage(
                                              base64Decode(photoBase64))
                                          : null,
                                      child: photoBase64 == null ||
                                              photoBase64.isEmpty
                                          ? Text(
                                              namaLengkap.isNotEmpty
                                                  ? namaLengkap[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: AppColors.slate900,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  namaLengkap.toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ),
                                              if (photoBase64 != null && photoBase64.isNotEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4.0),
                                                  child: Text("✅", style: TextStyle(fontSize: 10)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            userData.containsKey('jabatan') && userData['jabatan'] != null
                                                ? userData['jabatan'].toString().toUpperCase()
                                                : widget.user.role.toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.slate400,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Konten Utama
                      Expanded(
                        child: Column(
                          children: [
                            // Topbar Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: AppColors.slate100),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.blue50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          size: 20,
                                          color: AppColors.blue500,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        widget.user.role == 'admin'
                                            ? "Sistem Pemantauan UT"
                                            : widget.user.area.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate900,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.slate900
                                              .withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: AppColors.yellow500,
                                        ),
                                        const SizedBox(width: 12),
                                        const LiveClockWidget(
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "WITA",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (!isProfileComplete &&
                                _currentView == 'dashboard' &&
                                !isAdmin)
                              Container(
                                margin:
                                    const EdgeInsets.fromLTRB(32, 24, 32, 0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.rose50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.rose200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: AppColors.rose500, size: 24),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Text(
                                        "Profil Anda belum lengkap! Silakan lengkapi data diri (termasuk foto profil) di menu Pengaturan agar data absensi dan borang lebih akurat.",
                                        style: TextStyle(
                                            color: AppColors.rose600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.rose500,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => setState(
                                          () => _currentView = 'pengaturan'),
                                      child: const Text("Lengkapi Sekarang",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                    )
                                  ],
                                ),
                              ),

                            // View Body: Passing nilai kelengkapan profil ke fungsi ini
                            Expanded(child: _buildBody(isProfileComplete)),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  mainContent = Column(
                    children: [
                      AppBar(
                        backgroundColor: AppColors.slate900,
                        elevation: 0,
                        title: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: kIsWeb
                                  ? Image.network(
                                      'UNTR.JK-97580c63.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.security,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Image.asset(
                                      'web/UNTR.JK-97580c63.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.security,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      "UNITED TRACTORS",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(right: 1.0),
                                      child: Text(
                                        "member of ASTRA",
                                        style: TextStyle(
                                          color: AppColors.blue500,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 8,
                                          letterSpacing: 1.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.slate800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.yellow500,
                                ),
                                SizedBox(width: 6),
                                LiveClockWidget(
                                  suffix: ' WITA',
                                  style: TextStyle(
                                    color: AppColors.yellow500,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // BANNER NOTIFIKASI MOBILE
                      if (!isProfileComplete &&
                          _currentView == 'dashboard' &&
                          !isAdmin)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.rose50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.rose200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.rose500, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Profil Anda Belum Lengkap!",
                                      style: TextStyle(
                                          color: AppColors.rose600,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Lengkapi data diri dan foto profil Anda di menu Pengaturan agar data sistem lebih akurat.",
                                style: TextStyle(
                                    color: AppColors.rose500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rose500,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => setState(
                                      () => _currentView = 'pengaturan'),
                                  child: const Text("Lengkapi Sekarang",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ),
                              )
                            ],
                          ),
                        ),

                      // View Body: Passing nilai kelengkapan profil ke fungsi ini
                      Expanded(
                          child:
                              SafeArea(child: _buildBody(isProfileComplete))),

                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: SafeArea(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMobileNavItem(
                                'dashboard',
                                'Beranda',
                                Icons.dashboard,
                              ),
                              if (isKaryawan || isHead)
                                _buildMobileNavItem(
                                  'attendance',
                                  'Absen',
                                  Icons.event_available,
                                ),
                              if (isAdmin)
                                _buildMobileNavItem(
                                  'karyawan',
                                  'Karyawan',
                                  Icons.people,
                                ),
                              if (isHead) // Hanya muncul untuk Head Area
                                _buildMobileNavItem(
                                  'requests',
                                  'Form',
                                  Icons.assignment,
                                ),
                              _buildMobileNavItem(
                                'pengaturan',
                                'Setelan',
                                Icons.settings,
                                showBadge: !isProfileComplete && !isAdmin,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    Positioned.fill(child: mainContent),
                  ],
                );
              },
            );
          }),
    );
  }

  Widget _buildDesktopNavItem(String id, String label, IconData icon,
      {bool showBadge = false}) {
    bool isActive = _currentView == id;
    return InkWell(
      onTap: () {
        if (_currentView != id) {
          setState(() => _currentView = id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.yellow500 : AppColors.slate500,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isActive ? AppColors.yellow500 : AppColors.slate400,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (showBadge)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.rose500, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(String id, String label, IconData icon,
      {bool showBadge = false}) {
    bool isActive = _currentView == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentView != id) {
            setState(() => _currentView = id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(clipBehavior: Clip.none, children: [
                  Icon(
                    icon,
                    color: isActive ? AppColors.yellow500 : AppColors.slate400,
                    size: 22,
                  ),
                  if (showBadge)
                    Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppColors.rose500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isActive
                                      ? AppColors.yellow500
                                      : Colors.white,
                                  width: 1.5)),
                        ))
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.yellow500 : AppColors.slate400,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
