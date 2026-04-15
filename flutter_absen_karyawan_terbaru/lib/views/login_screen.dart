import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  final Function(UserModel) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _mode = 'karyawan';
  String _step = 'select';
  String _errorMsg = '';

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  final TextEditingController _regNamaController = TextEditingController();
  final TextEditingController _regNikController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  final TextEditingController _regConfirmPassController =
      TextEditingController(); // TAMBAHAN KONFIRMASI
  final TextEditingController _regKontakController = TextEditingController();
  final TextEditingController _regAlamatController = TextEditingController();

  String _regJenisKelamin = 'Laki-laki';
  DateTime? _regTanggalLahir;
  String _regAgama = 'Islam';
  String _regDepartemen = 'Umum';
  String _regJabatan = 'Staff';

  List<String> _departemens = ['Umum'];
  List<String> _jabatans = ['Staff'];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  bool _isRegistering = false;
  bool _showRegPassword = false; // <-- STATE BARU: Show Password Register
  bool _showLoginPassword = false;

  final LocalAuthentication auth = LocalAuthentication();
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _passFocusNode = FocusNode();

  List<UserModel> _savedAccounts = [];
  List<String> _availableAreas = [];
  String _selectedArea = "";

  String _currentDeviceId = '';

  int _currentSlideIndex = 0;
  Timer? _sliderTimer;
  final List<String> _sliderImages = [
    'https://plus.unsplash.com/premium_photo-1682142134981-adbd6743819a?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MjF8fHRhbWJhbmd8ZW58MHx8MHx8fDA%3D=80',
    'https://images.unsplash.com/photo-1505833464198-4993b36cdfab?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D=80',
    'https://images.unsplash.com/photo-1523848309072-c199db53f137?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D=80',
    'https://images.unsplash.com/photo-1517999144091-3d9dca6d1e43?q=80&w=627&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D=80',
    'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D=80',
  ];

  @override
  void initState() {
    super.initState();
    _initDeviceFingerprint();
    _loadSavedAccounts();
    _fetchConfigs();
    _startAutoSlider();
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _idFocusNode.dispose();
    _passFocusNode.dispose();
    _idController.dispose();
    _passController.dispose();
    _regNamaController.dispose();
    _regNikController.dispose();
    _regEmailController.dispose();
    _regPassController.dispose();
    _regConfirmPassController.dispose();
    _regKontakController.dispose();
    _regAlamatController.dispose();
    super.dispose();
  }

  void _startAutoSlider() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentSlideIndex = (_currentSlideIndex + 1) % _sliderImages.length;
        });
      }
    });
  }

  Future<void> _initDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('sys_device_uuid');

    if (storedId == null) {
      storedId = await _generateDeviceIdentifier();
      await prefs.setString('sys_device_uuid', storedId);
    }
    setState(() => _currentDeviceId = storedId!);
  }

  Future<String> _generateDeviceIdentifier() async {
    String deviceName = "Unknown Device";
    String hardwareId = "";
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
        deviceName = "Web Browser";
        hardwareId = "WEB-${webInfo.vendor.toString()}";
      } else {
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceName = "${androidInfo.brand} ${androidInfo.model}";
          hardwareId = androidInfo.id; // ID Hardware Android
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceName = "Apple ${iosInfo.utsname.machine}";
          hardwareId =
              iosInfo.identifierForVendor ?? ""; // IDFV iOS (Aman privasi)
        } else if (Platform.isWindows) {
          WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
          deviceName = "Windows PC";
          hardwareId = windowsInfo.deviceId; // ID Windows
        } else if (Platform.isMacOS) {
          MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
          deviceName = "Apple Mac ${macInfo.model}";
          hardwareId = macInfo.systemGUID ?? ""; // GUID MacOS
        } else if (Platform.isLinux) {
          LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
          deviceName = "Linux PC";
          hardwareId = linuxInfo.machineId ?? "";
        }
      }
    } catch (e) {
      debugPrint("Error device info: $e");
    }

    if (hardwareId.isNotEmpty) {
      // Gunakan sebagian Hardware ID agar konsisten walau aplikasi dibersihkan datanya
      String shortId =
          hardwareId.length > 8 ? hardwareId.substring(0, 8) : hardwareId;
      return '$deviceName [$shortId]'.toUpperCase();
    }

    // Fallback jika tidak mendapatkan izin baca hardware ID
    var random = Random();
    String shortTime = DateTime.now().millisecondsSinceEpoch.toString();
    shortTime = shortTime.substring(shortTime.length - 5);
    String uniqueSuffix = '${random.nextInt(9999)}-$shortTime';

    return '$deviceName [$uniqueSuffix]'.toUpperCase();
  }

  Future<void> _fetchConfigs() async {
    try {
      var configVal = await ApiService.getConfig('site');
      if (configVal != null) {
        var data = configVal;

        List<dynamic> locs = data['locations'] ?? [];

        if (mounted) {
          setState(() {
            if (locs.isNotEmpty) {
              List<String> sortedAreas =
                  locs.map((e) => e['siteName'].toString()).toList();
              sortedAreas
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _availableAreas = sortedAreas;
              _selectedArea = sortedAreas.first;
            }

            if (data.containsKey('struktur_organisasi')) {
              _strukturOrganisasi =
                  List<Map<String, dynamic>>.from(data['struktur_organisasi']);

              Set<String> depSet = _strukturOrganisasi
                  .map((e) => e['departemen'].toString())
                  .toSet();
              List<String> sortedDeps = depSet.toList();
              sortedDeps
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              if (sortedDeps.isNotEmpty) {
                _departemens = sortedDeps;
                _regDepartemen = sortedDeps.first;
              }
              _updateJabatanList(_regDepartemen);
            } else {
              List<dynamic> depsData = data['departemens'] ??
                  ['Umum', 'Manajemen Site', 'Maintenance'];
              List<dynamic> jabsData =
                  data['jabatans'] ?? ['Staff', 'Supervisor', 'Manajer'];

              List<String> sortedDeps =
                  depsData.map((e) => e.toString()).toList();
              sortedDeps
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _departemens = sortedDeps;
              if (sortedDeps.isNotEmpty) _regDepartemen = sortedDeps.first;

              List<String> sortedJabs =
                  jabsData.map((e) => e.toString()).toList();
              sortedJabs
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _jabatans = sortedJabs;
              if (sortedJabs.isNotEmpty) _regJabatan = sortedJabs.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch config: $e");
    }
  }

  void _updateJabatanList(String departemen) {
    if (_strukturOrganisasi.isEmpty) return;
    var relatedJabs = _strukturOrganisasi
        .where((e) => e['departemen'] == departemen)
        .map((e) => e['jabatan'].toString())
        .toSet()
        .toList();

    relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _jabatans = relatedJabs;
      if (relatedJabs.isNotEmpty) {
        if (!relatedJabs.contains(_regJabatan)) {
          _regJabatan = relatedJabs.first;
        }
      } else {
        _regJabatan = '';
      }
    });
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accountsJson = prefs.getString('ut_saved_accounts');
    if (accountsJson != null) {
      List<dynamic> decoded = jsonDecode(accountsJson);
      setState(() {
        _savedAccounts =
            decoded.map((item) => UserModel.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveAccountToHistory(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    _savedAccounts.removeWhere((u) => u.id == user.id);
    _savedAccounts.insert(0, user);
    if (_savedAccounts.length > 5)
      _savedAccounts = _savedAccounts.sublist(0, 5);
    await prefs.setString('ut_saved_accounts',
        jsonEncode(_savedAccounts.map((u) => u.toJson()).toList()));
  }

  Future<void> _removeSavedAccount(String nikToRemove) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedAccounts.removeWhere((u) => u.nik == nikToRemove);
      if (_idController.text == nikToRemove) {
        _idController.clear();
      }
      _idFocusNode.unfocus();
    });
    await prefs.setString('ut_saved_accounts',
        jsonEncode(_savedAccounts.map((u) => u.toJson()).toList()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Riwayat akun dihapus dari perangkat ini"),
          backgroundColor: AppColors.emerald500));
    }
  }

  void _directLogin(UserModel user) {
    _saveAccountToHistory(user);
    widget.onLogin(user);
  }

  // --- MODAL LUPA KATA SANDI (UI MENYESUAIKAN TEMA ABSENSI/DARK MODE) ---
  void _showForgotPasswordDialog() {
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController newPassCtrl = TextEditingController();
    TextEditingController confirmPassCtrl = TextEditingController();
    bool isSending = false;
    bool showPassword = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            Widget _buildRowInput(
                String label, TextEditingController controller,
                {bool isObscure = false, String hint = ""}) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text(label,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5))),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: controller,
                              obscureText: isObscure ? !showPassword : false,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: hint,
                                hintStyle:
                                    const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppColors.yellow500, width: 2)),
                              ),
                            ),
                          ))
                    ]),
              );
            }

            return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: 450,
                  decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10))
                      ]),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Dialog (Tema Gelap UT)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        color: AppColors.slate900,
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_reset,
                                color: AppColors.yellow500, size: 24),
                            SizedBox(width: 12),
                            Text("RESET PASSWORD",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),

                      // Body Dialog
                      Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRowInput("Alamat Email", emailCtrl,
                                  hint: "email@contoh.com"),
                              _buildRowInput("Password Baru", newPassCtrl,
                                  isObscure: true, hint: "Sandi Baru"),
                              _buildRowInput(
                                  "Konfirmasi Password", confirmPassCtrl,
                                  isObscure: true, hint: "Ulangi Sandi"),
                              const SizedBox(height: 8),
                              const Text(
                                "*catatan : Password minimal harus 8 Karakter dan mengandung Huruf Besar, Huruf Kecil, Karakter Khusus dan Angka!",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white54,
                                    height: 1.5,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                        value: showPassword,
                                        activeColor: AppColors.yellow500,
                                        checkColor: AppColors.slate900,
                                        side: const BorderSide(
                                            color: Colors.white54),
                                        onChanged: (val) {
                                          setDialogState(() =>
                                              showPassword = val ?? false);
                                        }),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Show Password",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(children: [
                                Expanded(
                                    child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.1),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("BATAL",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1)),
                                )),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.yellow500,
                                      foregroundColor: AppColors.slate900,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: isSending
                                      ? null
                                      : () async {
                                          // VALIDASI KELENGKAPAN & KECOCOKAN
                                          if (emailCtrl.text.trim().isEmpty ||
                                              newPassCtrl.text.trim().isEmpty ||
                                              confirmPassCtrl.text
                                                  .trim()
                                                  .isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Semua kolom harus diisi!"),
                                                    backgroundColor:
                                                        AppColors.rose500));
                                            return;
                                          }
                                          if (newPassCtrl.text !=
                                              confirmPassCtrl.text) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Password Baru dan Konfirmasi Password tidak cocok!"),
                                                    backgroundColor:
                                                        AppColors.rose500));
                                            return;
                                          }

                                          // VALIDASI KEKUATAN SANDI
                                          String newPass = newPassCtrl.text;
                                          bool hasMinLength =
                                              newPass.length >= 8;
                                          bool hasUppercase = newPass
                                              .contains(RegExp(r'[A-Z]'));
                                          bool hasLowercase = newPass
                                              .contains(RegExp(r'[a-z]'));
                                          bool hasDigits = newPass
                                              .contains(RegExp(r'[0-9]'));
                                          bool hasSpecialCharacters =
                                              newPass.contains(RegExp(
                                                  r'[!@#$%^&*(),.?":{}|<>]'));

                                          if (!hasMinLength ||
                                              !hasUppercase ||
                                              !hasLowercase ||
                                              !hasDigits ||
                                              !hasSpecialCharacters) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        "Password tidak memenuhi syarat keamanan!"),
                                                    backgroundColor:
                                                        AppColors.rose500));
                                            return;
                                          }

                                          // PROSES UPDATE DATABASE
                                          setDialogState(
                                              () => isSending = true);
                                          try {
                                            var users =
                                                await ApiService.getUsers();
                                            var userMatch = users
                                                .where((u) =>
                                                    u['email'] ==
                                                    emailCtrl.text.trim())
                                                .toList();

                                            if (userMatch.isNotEmpty) {
                                              var userDoc = userMatch.first;
                                              await ApiService.updateUser(
                                                  userDoc['id'].toString(),
                                                  {'password': newPass});

                                              if (mounted) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                  content: Text(
                                                      "Berhasil! Kata sandi Anda telah diperbarui."),
                                                  backgroundColor:
                                                      AppColors.emerald500,
                                                ));
                                              }
                                            } else {
                                              if (mounted)
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            "Email tidak ditemukan di sistem."),
                                                        backgroundColor:
                                                            AppColors.rose500));
                                            }
                                          } catch (e) {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Terjadi kesalahan jaringan."),
                                                      backgroundColor:
                                                          AppColors.rose500));
                                          } finally {
                                            if (mounted)
                                              setDialogState(
                                                  () => isSending = false);
                                          }
                                        },
                                  child: isSending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              color: AppColors.slate900,
                                              strokeWidth: 2))
                                      : const Text("SIMPAN",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1)),
                                ))
                              ])
                            ],
                          ))
                    ],
                  ),
                ));
          });
        });
  }

  Future<void> _handleManualLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorMsg = '');

    final id = _idController.text.trim().toLowerCase();
    final pass = _passController.text;

    UserModel? user;

    // Semua login kini melalui Laravel API (bypass dihapus)

    try {
      bool isDesktopDevice = false;
      if (kIsWeb) {
        isDesktopDevice = MediaQuery.of(context).size.width >= 900;
      } else {
        isDesktopDevice = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      }

      var loginResult = await ApiService.login(
        id, pass,
        mobileDeviceId: isDesktopDevice ? '' : _currentDeviceId,
        desktopDeviceId: isDesktopDevice ? _currentDeviceId : '',
      );

      if (loginResult['success'] == true) {
        UserModel apiUser = loginResult['user'];
        // Check role alignment
        if ((_mode == 'karyawan' && apiUser.role != 'Karyawan') ||
            (_mode == 'head' && apiUser.role != 'IT') ||
            (_mode == 'admin' && apiUser.role != 'admin')) {
          setState(() => _errorMsg =
              "Gagal masuk: Akun Anda tidak terdaftar sebagai ${_mode == 'admin' ? 'Admin' : _mode == 'head' ? 'IT' : 'Karyawan'}");
          return;
        }
        // [SINKRONISASI AREA PENUGASAN]
        // Jika karyawan memilih area yang berbeda di halaman login, terapkan area tersebut
        if (_mode == 'karyawan' &&
            _selectedArea.isNotEmpty &&
            _selectedArea != apiUser.area) {
          apiUser = UserModel(
            id: apiUser.id,
            namaLengkap: apiUser.namaLengkap,
            role: apiUser.role,
            nik: apiUser.nik,
            departemenId: apiUser.departemenId,
            area: _selectedArea,
            shift: apiUser.shift,
            deviceId: apiUser.deviceId,
          );
          // Update di database secara asinkron (background) agar sinkron ke depannya
          ApiService.updateUser(apiUser.id, {'area': _selectedArea});
        }

        user = apiUser;
        _directLogin(user);
      } else {
        setState(
            () => _errorMsg = loginResult['message']?.toString() ?? "NRP/ID tidak ditemukan atau password salah.");
      }
    } catch (e) {
      setState(() => _errorMsg = "Kesalahan koneksi jaringan.");
    }
  }

  // --- PENAMBAHAN LOCK UNTUK MENCEGAH DOUBLE CLICK BRUTAL SAAT REGISTRASI ---
  Future<void> _handleRegisterKaryawan() async {
    if (_isRegistering) return; // Mencegah double submit jika masih loading

    FocusManager.instance.primaryFocus?.unfocus();

    String nama = _regNamaController.text.trim();
    String nik = _regNikController.text.trim();
    String pass = _regPassController.text.trim();
    String confirmPass = _regConfirmPassController.text.trim();
    String kontak = _regKontakController.text.trim();
    String alamat = _regAlamatController.text.trim();
    String email = _regEmailController.text.trim();

    if (nama.isEmpty ||
        nik.isEmpty ||
        pass.isEmpty ||
        confirmPass.isEmpty ||
        email.isEmpty ||
        _regTanggalLahir == null) {
      setState(() => _errorMsg =
          "Harap isi Nama, NRP, Email, Tanggal Lahir, dan Kata Sandi lengkap!");
      return;
    }

    if (pass != confirmPass) {
      setState(() => _errorMsg = "Kata Sandi Baru dan Konfirmasi tidak cocok!");
      return;
    }

    // VALIDASI PASSWORD KEAMANAN SAAT REGISTRASI
    bool hasMinLength = pass.length >= 8;
    bool hasUppercase = pass.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = pass.contains(RegExp(r'[a-z]'));
    bool hasDigits = pass.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters =
        pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasMinLength ||
        !hasUppercase ||
        !hasLowercase ||
        !hasDigits ||
        !hasSpecialCharacters) {
      setState(() => _errorMsg =
          "Password minimal 8 Karakter (Harus mengandung Huruf Besar, Kecil, Angka, & Karakter Khusus)!");
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMsg = '';
    });

    try {
      // 1. Cek Duplikasi NRP
      bool nikExists = await ApiService.checkNik(nik);

      if (nikExists) {
        setState(
            () => _errorMsg = "NRP/ID tersebut sudah terdaftar di sistem.");
        return;
      }

      // 2. Cek Duplikasi Email (Ekstra Keamanan)
      bool emailExists = await ApiService.checkEmail(email);

      if (emailExists) {
        setState(() =>
            _errorMsg = "Alamat Email tersebut sudah terdaftar di sistem.");
        return;
      }

      bool isDesktopDevice = false;
      if (kIsWeb) {
        isDesktopDevice = MediaQuery.of(context).size.width >= 900;
      } else {
        isDesktopDevice =
            Platform.isWindows || Platform.isMacOS || Platform.isLinux;
      }

      // 3. Daftarkan Role sesuai Mode yang sedang aktif
      String targetRole = _mode == 'head' ? 'Head Area' : 'Karyawan';

      Map<String, dynamic> payload = {
        'nama_lengkap': nama,
        'nik': nik,
        'email': email,
        'password': pass,
        'jenis_kelamin': _regJenisKelamin,
        'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_regTanggalLahir!),
        'agama': _regAgama,
        'alamat': alamat.isNotEmpty ? alamat : '-',
        'kontak': kontak.isNotEmpty ? kontak : '-',
        'departemen_id': _regDepartemen,
        'jabatan': _regJabatan,
        'area': _selectedArea,
        'shift': 'Pagi', // Default awal
        'role': targetRole,
        'status_karyawan': 'Aktif',
        'mobileDeviceId': isDesktopDevice ? '' : _currentDeviceId,
        'desktopDeviceId': isDesktopDevice ? _currentDeviceId : '',
        'created_at': DateTime.now().toIso8601String(),
      };

      var response = await ApiService.register(payload);

      if (response['success'] != true) {
        setState(() => _errorMsg =
            response['data']?['message'] ?? "Gagal mendaftarkan akun.");
        return;
      }

      // Kembali ke form Login setelah sukses register
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Registrasi berhasil! Silakan login untuk melanjutkan."),
          backgroundColor: AppColors.emerald500,
          behavior: SnackBarBehavior.floating,
        ));
      }

      setState(() {
        _step = 'form';
        _errorMsg = '';
      });
    } catch (e) {
      setState(() => _errorMsg = "Gagal mendaftar: Koneksi bermasalah.");
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.slate900,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue500.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                        blurRadius: 180,
                        color: AppColors.blue500.withValues(alpha: 0.15))
                  ]),
            ),
          ),
          isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          Positioned(
            top: MediaQuery.of(context).size.height - 30,
            right: 16,
            child: Text(
                "Device UID: ${_currentDeviceId.length > 25 ? _currentDeviceId.substring(0, 25) : _currentDeviceId}...",
                style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Container(
          // Memastikan form responsif dan mencegah overflow pada lebar 897-903
          constraints: const BoxConstraints(maxWidth: 1000),
          height: 680,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color:
                const Color(0xFF141E2E), // Warna base form desktop bagian kanan
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(32)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 800),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                        child: Container(
                          key: ValueKey<int>(_currentSlideIndex),
                          decoration: BoxDecoration(
                              color: AppColors.slate900,
                              image: DecorationImage(
                                image: NetworkImage(
                                    _sliderImages[_currentSlideIndex]),
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                    AppColors.slate900.withValues(alpha: 0.85),
                                    BlendMode.darken),
                              )),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 56), // Padding responsif disesuaikan
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER PERUSAHAAN + LOGO OBOR DI KANANNYA
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.business,
                                      color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    "PT. UNITED TRACTORS",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 1),
                                  ),
                                ),
                                const SizedBox(width: 110),
                                Image.asset(
                                  'Assets/Images/erasebg-transformed.png',
                                  height: 75,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.local_fire_department,
                                          color: AppColors.yellow500, size: 75),
                                ),
                              ],
                            ),

                            const Spacer(
                                flex: 5), // Mendorong judul teks lebih ke bawah

                            const Text("Sistem\nAbsensi Digital",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing:
                                        -1.5)), // Font diubah ke 40 menyesuaikan responsivitas
                            const SizedBox(height: 24),
                            const Text(
                                "Platform manajemen kehadiran Karyawan yang terintegrasi, real-time, dan mudah digunakan.",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    height: 1.6)),

                            const Spacer(flex: 4),

                            // BARIS BAWAH (VERSI + LOGO MOVING AS ONE)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Flexible(
                                  child: Text("V : 1.0.0",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(_sliderImages.length,
                                      (index) {
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      width:
                                          _currentSlideIndex == index ? 24 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _currentSlideIndex == index
                                            ? AppColors.yellow500
                                            : Colors.white
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),
                                Flexible(
                                  child: Image.asset(
                                    'Assets/Images/movingasone-2.png',
                                    height: 60, // Diperbesar
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Text(
                                      "Moving as one",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Center(
                  // Center secara vertikal untuk mencegah overflow dan menempatkan form di tengah
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 40),
                    child: _step == 'register'
                        ? _buildDesktopRegisterForm()
                        : _buildDesktopLoginForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLoginForm() {
    final List<String> autocompleteOptions = _savedAccounts
        .where((e) {
          if (_mode == 'karyawan') return e.role == 'Karyawan';
          if (_mode == 'head') return e.role == 'Head Area';
          if (_mode == 'admin') return e.role == 'admin';
          return false;
        })
        .map((e) => e.nik)
        .toSet()
        .toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 90, // Ukuran diperbesar
          height: 90, // Ukuran diperbesar
          padding: const EdgeInsets.all(
              4), // Padding diperkecil agar gambar memenuhi
          decoration: BoxDecoration(
            color: Colors
                .transparent, // Background Kuning dihilangkan (transparan)
            borderRadius: BorderRadius.circular(24),
          ),
          child: kIsWeb
              ? Image.network(
                  'UNTR.JK-97580c63.png', // Menggunakan logo UT asli
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.gpp_good, size: 60, color: Colors.white),
                )
              : Image.asset(
                  'web/UNTR.JK-97580c63.png', // Menggunakan logo UT asli
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.gpp_good, size: 60, color: Colors.white),
                ),
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("UNITED TRACTORS Tbk.",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5)),
            SizedBox(height: 8),
            Text("member of ASTRA",
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.blue500,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 48),
        if (_step == 'select') ...[
          _buildDesktopSelectionButton(
              'karyawan', 'KARYAWAN', Icons.person, AppColors.yellow500),
          const SizedBox(height: 16),
          _buildDesktopSelectionButton(
              'admin', 'IT SUPPORT', Icons.security, AppColors.rose500),
        ] else ...[
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white54),
                onPressed: () => setState(() {
                  _step = 'select';
                  _errorMsg = '';
                }),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    side: const BorderSide(color: Colors.transparent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(
                      _mode == 'karyawan'
                          ? Icons.person
                          : (_mode == 'head'
                              ? Icons.supervisor_account
                              : Icons.security),
                      color: _mode == 'karyawan'
                          ? AppColors.yellow500
                          : (_mode == 'head'
                              ? AppColors.blue500
                              : AppColors.rose500),
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Text(
                        "Login ${_mode == 'head' ? 'ADMIN AREA' : _mode == 'admin' ? 'IT SUPPORT' : 'KARYAWAN'}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ],
                ),
              ))
            ],
          ),
          const SizedBox(height: 32),

          // FORM FIELDS
          if (_mode == 'karyawan') ...[
            _buildDesktopInputLabel("AREA PENUGASAN"),
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _availableAreas.contains(_selectedArea)
                  ? _selectedArea
                  : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white54, size: 20),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              decoration: _desktopInputDeco(""),
              onChanged: (String? newValue) =>
                  setState(() => _selectedArea = newValue!),
              items: _availableAreas
                  .toSet()
                  .map((String value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          _buildDesktopInputLabel(_mode == 'head'
              ? "ID ADMIN AREA"
              : _mode == 'admin'
                  ? "ID ADMINISTRATOR"
                  : "NRP KARYAWAN"),
          LayoutBuilder(
            builder: (context, constraints) => RawAutocomplete<String>(
              textEditingController: _idController,
              focusNode: _idFocusNode,
              optionsBuilder: (TextEditingValue v) => v.text == ''
                  ? autocompleteOptions
                  : autocompleteOptions.where(
                      (o) => o.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (String s) => _idController.text = s,
              fieldViewBuilder: (c, t, f, o) {
                return TextField(
                  controller: t,
                  focusNode: f,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passFocusNode.requestFocus(),
                  decoration: _desktopInputDeco(
                      "Masukkan ${_mode == 'head' ? 'Admin Area' : _mode == 'admin' ? 'IT Support' : 'Karyawan'} ID/NRP"),
                );
              },
              optionsViewBuilder: (c, o, opts) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: constraints.maxWidth,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                          color: AppColors.slate800,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5))
                          ]),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: opts.length,
                        itemBuilder: (c, i) {
                          final option = opts.elementAt(i);
                          return InkWell(
                              onTap: () => o(option),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(option,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      GestureDetector(
                                        onTap: () =>
                                            _removeSavedAccount(option),
                                        child: const Icon(Icons.close,
                                            size: 16, color: Colors.white38),
                                      )
                                    ],
                                  )));
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          _buildDesktopInputLabel("KATA SANDI"),
          TextField(
            controller: _passController,
            focusNode: _passFocusNode,
            obscureText: !_showLoginPassword,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleManualLogin(),
            decoration: _desktopInputDeco("Masukkan Kata Sandi").copyWith(
                suffixIcon: IconButton(
              icon: Icon(
                  _showLoginPassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                  size: 18),
              onPressed: () =>
                  setState(() => _showLoginPassword = !_showLoginPassword),
            )),
          ),

          if (_mode != 'admin')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero),
                child: const Text("Lupa Kata Sandi?",
                    style: TextStyle(
                        color: AppColors.yellow500,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          if (_errorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.rose500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _mode == 'karyawan'
                    ? AppColors.yellow500
                    : (_mode == 'head' ? AppColors.blue500 : AppColors.rose500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _handleManualLogin,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("MASUK SEKARANG",
                      style: TextStyle(
                          color: _mode == 'karyawan'
                              ? AppColors.slate900
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      color: _mode == 'karyawan'
                          ? AppColors.slate900
                          : Colors.white,
                      size: 16)
                ],
              ),
            ),
          ),

          if (_mode == 'karyawan' || _mode == 'head') ...[
            const SizedBox(height: 24),
            TextButton(
                onPressed: () => setState(() {
                      _step = 'register';
                      _errorMsg = '';
                    }),
                child: Text(
                    "DAFTAR SEBAGAI ${_mode == 'head' ? 'ADMIN AREA' : 'KARYAWAN BARU'}",
                    style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                        decoration: TextDecoration.underline)))
          ]
        ]
      ],
    );
  }

  Widget _buildDesktopSelectionButton(
      String modeValue, String label, IconData icon, Color iconColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _mode = modeValue;
          _step = 'form';
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20)
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white54),
          onPressed: () => setState(() {
            _step = 'form';
            _errorMsg = '';
          }),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: const BorderSide(color: Colors.transparent)),
        ),
        const SizedBox(height: 16),
        Text(_mode == 'head' ? "Registrasi Admin Area" : "Registrasi Karyawan",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text("Perangkat ini akan dikunci untuk akun Anda.",
            style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "NAMA LENGKAP",
                    TextField(
                        textInputAction: TextInputAction.next,
                        controller: _regNamaController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("Nama Lengkap")))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "NRP / ID PEGAWAI",
                    TextField(
                        textInputAction: TextInputAction.next,
                        controller: _regNikController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("NRP-XXX")))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "ALAMAT EMAIL",
                    TextField(
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        controller: _regEmailController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("email@karyawan.com")))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "NO HANDPHONE",
                    TextField(
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        controller: _regKontakController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("No HP Aktif")))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "JENIS KELAMIN",
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.slate800,
                      initialValue: _regJenisKelamin,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white54),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      decoration: _desktopInputDeco(""),
                      items: ['Laki-laki', 'Perempuan']
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _regJenisKelamin = v!),
                    ))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "TANGGAL LAHIR",
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now());
                        if (picked != null)
                          setState(() => _regTanggalLahir = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                _regTanggalLahir != null
                                    ? DateFormat('dd MMMM yyyy', 'id_ID')
                                        .format(_regTanggalLahir!)
                                    : "Pilih Tanggal",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _regTanggalLahir != null
                                        ? Colors.white
                                        : Colors.white38)),
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.white38),
                          ],
                        ),
                      ),
                    ))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "AGAMA",
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.slate800,
                      initialValue: _regAgama,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white54),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      decoration: _desktopInputDeco(""),
                      items: [
                        'Islam',
                        'Kristen',
                        'Katolik',
                        'Hindu',
                        'Buddha',
                        'Konghucu'
                      ]
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _regAgama = v!),
                    ))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "ALAMAT LENGKAP",
                    TextField(
                        textInputAction: TextInputAction.next,
                        maxLines: 1,
                        controller: _regAlamatController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration:
                            _desktopInputDeco("Alamat Tempat Tinggal")))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "DEPARTEMEN / DIVISI",
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.slate800,
                      initialValue: _departemens.contains(_regDepartemen)
                          ? _regDepartemen
                          : (_departemens.isNotEmpty
                              ? _departemens.first
                              : null),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white54),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      decoration: _desktopInputDeco(""),
                      items: _departemens
                          .toSet()
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _regDepartemen = v!;
                          _updateJabatanList(v);
                        });
                      },
                    ))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "JABATAN / POSISI",
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.slate800,
                      initialValue: _jabatans.contains(_regJabatan)
                          ? _regJabatan
                          : (_jabatans.isNotEmpty ? _jabatans.first : null),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white54),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      decoration: _desktopInputDeco(""),
                      items: _jabatans
                          .toSet()
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _regJabatan = v!),
                    ))),
          ],
        ),
        const SizedBox(height: 16),
        _buildDesktopInputBlock(
            "AREA PENUGASAN",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _availableAreas.contains(_selectedArea)
                  ? _selectedArea
                  : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              decoration: _desktopInputDeco(""),
              items: _availableAreas
                  .toSet()
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedArea = v!),
            )),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _buildDesktopInputBlock(
                    "MASUKKAN KATA SANDI",
                    TextField(
                        textInputAction: TextInputAction.next,
                        controller: _regPassController,
                        obscureText: !_showRegPassword,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("Sandi Baru")))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDesktopInputBlock(
                    "KONFIRMASI KATA SANDI",
                    TextField(
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleRegisterKaryawan(),
                        controller: _regConfirmPassController,
                        obscureText: !_showRegPassword,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        decoration: _desktopInputDeco("Ulangi Sandi")))),
          ],
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                  value: _showRegPassword,
                  activeColor: AppColors.yellow500,
                  checkColor: AppColors.slate900,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (val) =>
                      setState(() => _showRegPassword = val ?? false))),
          const SizedBox(width: 8),
          const Text("Show Password",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          const Expanded(
            child: Text(
                "*catatan : Password minimal harus 8 Karakter dan mengandung Huruf Besar, Huruf Kecil, Karakter Khusus dan Angka!",
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontStyle: FontStyle.italic)),
          )
        ]),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.rose500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: AppColors.yellow500.withValues(alpha: 0.2)),
            onPressed: _isRegistering ? null : _handleRegisterKaryawan,
            child: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.slate900, strokeWidth: 2))
                : const Text("DAFTAR & MASUK",
                    style: TextStyle(
                        color: AppColors.slate900,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildDesktopInputBlock(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        child
      ],
    );
  }

  InputDecoration _desktopInputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }

  // =========================================================================
  // MOBILE LAYOUT
  // =========================================================================
  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          padding: const EdgeInsets.all(24),
          constraints:
              BoxConstraints(maxWidth: _step == 'register' ? 640 : 420),
          decoration: BoxDecoration(
            color: AppColors.slate800.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 10))
            ],
          ),
          child: _step == 'select'
              ? _buildMobileRoleSelection()
              : (_step == 'register'
                  ? _buildMobileRegisterForm()
                  : _buildMobileLoginForm()),
        ),
      ),
    );
  }

  Widget _buildMobileRoleSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24)),
          child: kIsWeb
              ? Image.network(
                  'UNTR.JK-97580c63.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.gpp_good, size: 60, color: Colors.white),
                )
              : Image.asset(
                  'web/UNTR.JK-97580c63.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.gpp_good, size: 60, color: Colors.white),
                ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("UNITED TRACTORS Tbk.",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text("member of ASTRA",
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.blue500,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _mobileRoleButton(
            'KARYAWAN',
            Icons.person,
            AppColors.yellow500,
            () => setState(() {
                  _mode = 'karyawan';
                  _step = 'form';
                })),
        const SizedBox(height: 16),
        _mobileRoleButton(
            'IT SUPPORT',
            Icons.security,
            AppColors.rose500,
            () => setState(() {
                  _mode = 'admin';
                  _step = 'form';
                })),
      ],
    );
  }

  Widget _mobileRoleButton(
      String title, IconData icon, Color hoverColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: hoverColor.withValues(alpha: 0.2),
      highlightColor: hoverColor.withValues(alpha: 0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Row(
          children: [
            Icon(icon, color: hoverColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 2)),
            ),
            Icon(Icons.keyboard_arrow_right,
                color: AppColors.slate500.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLoginForm() {
    Color themeColor = _mode == 'admin'
        ? AppColors.rose500
        : _mode == 'head'
            ? AppColors.blue500
            : AppColors.yellow500;

    final List<String> autocompleteOptions = _savedAccounts
        .where((e) {
          if (_mode == 'karyawan') return e.role == 'Karyawan';
          if (_mode == 'head') return e.role == 'Head Area';
          if (_mode == 'admin') return e.role == 'admin';
          return false;
        })
        .map((e) => e.nik)
        .toSet()
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white54),
              onPressed: () => setState(() {
                _step = 'select';
                _errorMsg = '';
              }),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: const BorderSide(color: Colors.transparent)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(
                    _mode == 'karyawan'
                        ? Icons.person
                        : (_mode == 'head'
                            ? Icons.supervisor_account
                            : Icons.security),
                    color: themeColor,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Text(
                      "Login ${_mode == 'head' ? 'ADMIN AREA' : _mode == 'admin' ? 'IT SUPPORT' : 'KARYAWAN'}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1)),
                ],
              ),
            ))
          ],
        ),
        const SizedBox(height: 32),

        Center(
          child: Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24)),
            child: kIsWeb
                ? Image.network(
                    'UNTR.JK-97580c63.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.verified_user,
                        size: 60,
                        color: _mode == 'karyawan'
                            ? AppColors.slate900
                            : Colors.white),
                  )
                : Image.asset(
                    'web/UNTR.JK-97580c63.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.verified_user,
                        size: 60,
                        color: _mode == 'karyawan'
                            ? AppColors.slate900
                            : Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("UNITED TRACTORS Tbk.",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text("member of ASTRA",
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.blue500,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // FORM FIELDS
        if (_mode == 'karyawan') ...[
          Text("AREA PENUGASAN",
              style: TextStyle(
                  color: themeColor,
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: AppColors.slate800,
            initialValue: _availableAreas.contains(_selectedArea)
                ? _selectedArea
                : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 16),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.slate900.withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: themeColor, width: 2)),
            ),
            onChanged: (String? newValue) =>
                setState(() => _selectedArea = newValue!),
            items: _availableAreas
                .toSet()
                .map((String value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis)))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<String>(
            textEditingController: _idController,
            focusNode: _idFocusNode,
            optionsBuilder: (TextEditingValue v) => v.text == ''
                ? autocompleteOptions
                : autocompleteOptions.where(
                    (o) => o.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (String s) => _idController.text = s,
            fieldViewBuilder: (c, t, f, o) {
              return TextField(
                controller: t,
                focusNode: f,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passFocusNode.requestFocus(),
                decoration: InputDecoration(
                  labelText: _mode == 'head'
                      ? 'ID ADMIN AREA'
                      : _mode == 'admin'
                          ? 'ID IT SUPPORT'
                          : 'NRP KARYAWAN',
                  labelStyle: TextStyle(
                      color: themeColor,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: AppColors.slate900.withValues(alpha: 0.5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: themeColor, width: 2)),
                ),
              );
            },
            optionsViewBuilder: (c, o, opts) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: constraints.maxWidth,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ]),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: opts.length,
                      itemBuilder: (c, i) {
                        final option = opts.elementAt(i);
                        return InkWell(
                            onTap: () => o(option),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(option,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    GestureDetector(
                                      onTap: () => _removeSavedAccount(option),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white38),
                                    )
                                  ],
                                )));
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: _passController,
          focusNode: _passFocusNode,
          obscureText: !_showLoginPassword,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleManualLogin(),
          decoration: InputDecoration(
            labelText: 'KATA SANDI',
            labelStyle: TextStyle(
                color: themeColor,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold),
            filled: true,
            fillColor: AppColors.slate900.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: themeColor, width: 2)),
            suffixIcon: IconButton(
              icon: Icon(
                  _showLoginPassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                  size: 18),
              onPressed: () =>
                  setState(() => _showLoginPassword = !_showLoginPassword),
            ),
          ),
        ),

        if (_mode != 'admin')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero),
              child: Text("Lupa Kata Sandi?",
                  style: TextStyle(
                      color: themeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ),

        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(_errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.rose500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      height: 1.5)),
            ),
          ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 10,
                shadowColor: themeColor.withValues(alpha: 0.3)),
            onPressed: _handleManualLogin,
            child: Text("AKSES SISTEM",
                style: TextStyle(
                    color:
                        _mode == 'karyawan' ? AppColors.slate900 : Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12)),
          ),
        ),

        if (_mode == 'karyawan' || _mode == 'head') ...[
          const SizedBox(height: 24),
          Center(
              child: TextButton(
                  onPressed: () => setState(() {
                        _step = 'register';
                        _errorMsg = '';
                      }),
                  child: Text(
                      "DAFTAR SEBAGAI ${_mode == 'head' ? 'ADMIN AREA' : 'KARYAWAN BARU'}",
                      style: const TextStyle(
                          color: AppColors.slate400,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1,
                          decoration: TextDecoration.underline))))
        ]
      ],
    );
  }

  Widget _buildMobileRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate400),
          onPressed: () => setState(() {
            _step = 'form';
            _errorMsg = '';
          }),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05)),
        ),
        const SizedBox(height: 16),
        Center(
            child: Text(
                _mode == 'head'
                    ? "REGISTRASI ADMIN AREA"
                    : "REGISTRASI KARYAWAN",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5))),
        const SizedBox(height: 8),
        const Center(
            child: Text("PERANGKAT INI AKAN DIKUNCI UNTUK AKUN ANDA",
                style: TextStyle(
                    color: AppColors.amber500,
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center)),
        const SizedBox(height: 32),
        _buildInputColDark(
            "NAMA LENGKAP",
            TextField(
                textInputAction: TextInputAction.next,
                controller: _regNamaController,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("Nama Lengkap"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "NRP / ID PEGAWAI",
            TextField(
                textInputAction: TextInputAction.next,
                controller: _regNikController,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("NRP-XXX"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "ALAMAT EMAIL",
            TextField(
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                controller: _regEmailController,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("email@karyawan.com"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "JENIS KELAMIN",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _regJenisKelamin,
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: _inputDecoDark(""),
              items: ['Laki-laki', 'Perempuan']
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _regJenisKelamin = v!),
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "TANGGAL LAHIR",
            InkWell(
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                  builder: (context, child) =>
                      Theme(data: ThemeData.dark(), child: child!),
                );
                if (picked != null) setState(() => _regTanggalLahir = picked);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                    color: AppColors.slate900.withValues(alpha: 0.5),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        _regTanggalLahir != null
                            ? DateFormat('dd MMMM yyyy', 'id_ID')
                                .format(_regTanggalLahir!)
                            : "Pilih Tanggal",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _regTanggalLahir != null
                                ? Colors.white
                                : Colors.white38)),
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.white54),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "AGAMA",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _regAgama,
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: _inputDecoDark(""),
              items: [
                'Islam',
                'Kristen',
                'Katolik',
                'Hindu',
                'Buddha',
                'Konghucu'
              ]
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _regAgama = v!),
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "NO HANDPHONE",
            TextField(
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                controller: _regKontakController,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("No HP Aktif"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "ALAMAT LENGKAP",
            TextField(
                textInputAction: TextInputAction.next,
                maxLines: 2,
                controller: _regAlamatController,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("Alamat Tempat Tinggal"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "DEPARTEMEN / DIVISI",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _departemens.contains(_regDepartemen)
                  ? _regDepartemen
                  : (_departemens.isNotEmpty ? _departemens.first : null),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: _inputDecoDark(""),
              items: _departemens
                  .toSet()
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _regDepartemen = v!;
                  _updateJabatanList(v);
                });
              },
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "JABATAN / POSISI",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _jabatans.contains(_regJabatan)
                  ? _regJabatan
                  : (_jabatans.isNotEmpty ? _jabatans.first : null),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: _inputDecoDark(""),
              items: _jabatans
                  .toSet()
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _regJabatan = v!),
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "AREA PENUGASAN",
            DropdownButtonFormField<String>(
              isExpanded: true,
              dropdownColor: AppColors.slate800,
              initialValue: _availableAreas.contains(_selectedArea)
                  ? _selectedArea
                  : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
              icon:
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: _inputDecoDark(""),
              items: _availableAreas
                  .toSet()
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedArea = v!),
            )),
        const SizedBox(height: 16),
        _buildInputColDark(
            "KATA SANDI BARU",
            TextField(
                textInputAction: TextInputAction.next,
                controller: _regPassController,
                obscureText: !_showRegPassword,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("Sandi Baru"))),
        const SizedBox(height: 16),
        _buildInputColDark(
            "KONFIRMASI SANDI",
            TextField(
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegisterKaryawan(),
                controller: _regConfirmPassController,
                obscureText: !_showRegPassword,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: _inputDecoDark("Ulangi Sandi"))),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                  value: _showRegPassword,
                  activeColor: AppColors.yellow500,
                  checkColor: AppColors.slate900,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (val) =>
                      setState(() => _showRegPassword = val ?? false))),
          const SizedBox(width: 8),
          const Text("Show Password",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold))
        ]),
        const SizedBox(height: 8),
        const Text(
            "*catatan : Password minimal harus 8 Karakter dan mengandung Huruf Besar, Huruf Kecil, Karakter Khusus dan Angka!",
            style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                height: 1.4)),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text(_errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.rose500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      height: 1.5)),
            ),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 10,
                shadowColor: AppColors.yellow500.withValues(alpha: 0.3)),
            onPressed: _isRegistering ? null : _handleRegisterKaryawan,
            child: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppColors.slate900, strokeWidth: 2))
                : const Text("DAFTAR & MASUK",
                    style: TextStyle(
                        color: AppColors.slate900,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildInputColDark(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.yellow500,
                letterSpacing: 2)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoDark(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: AppColors.slate900.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}
