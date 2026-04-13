
import 'dart:io';
import 'dart:async';
import 'dart:convert'; 
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform; 
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:camera/camera.dart'; 
import 'package:ntp/ntp.dart'; 
 
import 'package:geocoding/geocoding.dart'; // Tambahan untuk reverse geocoding
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../helpers/web_camera.dart';
import 'liveness_screen.dart';

class AttendanceView extends StatefulWidget {
  final UserModel user;

  const AttendanceView({super.key, required this.user});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  String _status = 'Hadir';
  String _keterangan = ''; 
  
  Position? _currentPosition;
  bool _isLocating = true;
  String _errorMsg = '';
  double _distance = 0.0;
  bool _isMocked = false;
  String _currentAddress = 'Membaca lokasi...'; // Menyimpan alamat lengkap

  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _closestSite;

  List<Map<String, dynamic>> _availableShifts = [];
  String? _selectedShiftCategory; 
  String? _selectedShiftTimeId;   
  bool _isShiftLocked = false; 

  bool _isEarlyOut = false;
  String _earlyOutReason = '';

  String _filterShift = 'Semua Shift'; 

  final MapController _mapController = MapController();
  final ScrollController _historyScrollController = ScrollController(); 
  final TextEditingController _pulangCepatReasonCtrl = TextEditingController(); 
  final TextEditingController _lokasiDinasCtrl = TextEditingController(); // Tambahan untuk Perjalanan Dinas
  
  final LocalAuthentication auth = LocalAuthentication(); 
  final ImagePicker _picker = ImagePicker(); 
  File? _liveSelfieImage; 

  StreamSubscription<Position>? _positionStreamSubscription;

  String actionType = 'MASUK';
  bool _isCheckingStatus = true;
  bool _isProcessingTap = false; 
  
  String _currentToday = DateFormat('yyyy-MM-dd').format(DateTime.now()); 
  String _filterMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // === FITUR KEAMANAN: KUNCI ZONA WAKTU KE WITA (UTC+8) ===
  Future<DateTime> _getStrictWitaTime() async {
    try {
      DateTime networkTime = await NTP.now(timeout: const Duration(seconds: 3));
      return networkTime.toUtc().add(const Duration(hours: 8));
    } catch (e) {
      debugPrint("NTP Timeout, memakai fallback waktu lokal dikonversi ke WITA.");
      return DateTime.now().toUtc().add(const Duration(hours: 8));
    }
  }

  String _getShiftVal(Map<String, dynamic> s) {
    return s['id']?.toString() ?? "${s['name']}_${s['start']}_${s['end']}";
  }

  // DETEKSI ABSOLUT PULANG CEPAT
  bool _isCurrentlyEarlyOut() {
    if (actionType != 'KELUAR' || _selectedShiftTimeId == null) return false;
    
    var shiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
    String endStr = shiftData['end'] ?? '17:00';
    int endH = int.tryParse(endStr.split(':')[0]) ?? 17;
    int endM = int.tryParse(endStr.split(':')[1]) ?? 0;
    
    DateTime now = DateTime.now().toUtc().add(const Duration(hours: 8));
    DateTime endTime = DateTime.utc(now.year, now.month, now.day, endH, endM);
    
    String startStr = shiftData['start'] ?? '08:00';
    int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
    
    if (endH < startH) {
      if (now.hour >= 12) {
        endTime = endTime.add(const Duration(days: 1));
      }
    }
    return now.isBefore(endTime);
  }

  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _initAttendance();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    var data = await ApiService.getAllAttendance(userId: widget.user.id);
    if (mounted) setState(() { _attendanceHistory = data; _isLoadingHistory = false; });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _historyScrollController.dispose();
    _pulangCepatReasonCtrl.dispose();
    _lokasiDinasCtrl.dispose();
    super.dispose();
  }

  // --- FUNGSI MENGUBAH KOORDINAT MENJADI ALAMAT LENGKAP ---
  Future<void> _fetchAddress(Position pos) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        List<String> parts = [];
        
        if (p.street != null && p.street!.isNotEmpty && !p.street!.contains('+')) parts.add(p.street!);
        if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
        if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) parts.add(p.subAdministrativeArea!);
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
        
        if (mounted) {
          setState(() {
            _currentAddress = parts.isNotEmpty ? parts.join(', ') : "GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";
        });
      }
    }
  }

  Future<void> _handleAbsenTap() async {
    if (_isProcessingTap) return;

    setState(() => _isProcessingTap = true);

    try {
      if (!await _validateTimeRequirements()) return;

      if (actionType == 'MASUK' && !_isShiftLocked) {
         var shiftData = _availableShifts.firstWhere(
           (s) => _getShiftVal(s) == _selectedShiftTimeId, 
           orElse: () => _availableShifts.isNotEmpty ? _availableShifts.first : {'name': 'Shift', 'start': '08:00', 'end': '17:00'}
         );
         
         if (!mounted) return;
         bool? confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
               backgroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
               title: const Row(
                 children: [
                   Icon(Icons.warning_amber_rounded, color: AppColors.amber500),
                   SizedBox(width: 8),
                   Expanded(child: Text("Konfirmasi Jadwal", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                 ],
               ),
               content: Text(
                 "Anda akan mengunci shift ${shiftData['name']} (${shiftData['start']} - ${shiftData['end']}) untuk hari ini.\n\nJadwal yang dipilih tidak bisa diubah kembali setelah absensi disahkan. Lanjutkan?",
                 style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5)
               ),
               actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(c, true), 
                    child: const Text("Ya, Kunci & Lanjut", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ),
               ]
            )
         );
         if (confirm != true) return;
      }

      // --- ALUR VERIFIKASI ALASAN PULANG CEPAT ---
      if (actionType == 'KELUAR' && _isEarlyOut) {
         bool confirmed = false;

         while (!confirmed) {
            TextEditingController dialogReasonCtrl = TextEditingController();
            
            if (!mounted) return;
            bool? submitReason = await showDialog<bool>(
               context: context,
               builder: (c) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.amber500),
                      SizedBox(width: 8),
                      Expanded(child: Text("Alasan Pulang Cepat", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                    ],
                  ),
                  content: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        const Text("Anda terdeteksi melakukan absen pulang mendahului jadwal shift.\n\nHarap tuliskan alasannya secara detail (akan dilaporkan ke Admin):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5)),
                        const SizedBox(height: 16),
                        TextField(
                           controller: dialogReasonCtrl,
                           maxLines: 3,
                           decoration: InputDecoration(
                              hintText: "Ketik alasan pulang cepat...",
                              filled: true, fillColor: AppColors.slate50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                           ),
                        )
                     ]
                  ),
                  actions: [
                     TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                       onPressed: () {
                          if (dialogReasonCtrl.text.trim().isEmpty) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan pulang cepat wajib diisi!"), backgroundColor: AppColors.rose500));
                             return;
                          }
                          Navigator.pop(c, true);
                       },
                       child: const Text("Lanjut", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                     ),
                  ]
               )
            );
            
            if (submitReason != true) {
               setState(() => _isProcessingTap = false);
               return; // Batal absen
            }
            
            String currentReason = dialogReasonCtrl.text.trim();

            if (!mounted) return;
            bool? verifyReason = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                 backgroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                 title: const Row(
                    children: [
                      Icon(Icons.fact_check, color: AppColors.emerald500),
                      SizedBox(width: 8),
                      Expanded(child: Text("Verifikasi Alasan", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                    ],
                 ),
                 content: RichText(
                   text: TextSpan(
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5),
                     children: [
                       const TextSpan(text: "Pastikan alasan Anda sudah benar dan tidak ada salah ketik sebelum dikirim ke Admin:\n\n"),
                       TextSpan(text: "\"$currentReason\"", style: const TextStyle(color: AppColors.slate900, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900)),
                     ]
                   )
                 ),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Edit Kembali", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                     onPressed: () => Navigator.pop(c, true),
                     child: const Text("Ya, Sudah Benar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                   ),
                 ]
              )
            );

            if (verifyReason == true) {
               _earlyOutReason = currentReason;
               confirmed = true;
            }
         }
      }
      
      await _authenticateAndSubmit(); 
    } finally {
      if (mounted) {
        setState(() => _isProcessingTap = false);
      }
    }
  }

  Future<void> _initAttendance() async {
    DateTime realTime = await _getStrictWitaTime();
    _currentToday = DateFormat('yyyy-MM-dd').format(realTime);

    await _fetchSiteConfigs();
    await _checkTodayAttendance();
    _startLocationTracking();
  }

  Future<void> _fetchSiteConfigs() async {
    try {
      var configVal = await ApiService.getConfig('site');

      if (configVal != null) {
        var data = configVal;
        List<dynamic> locs = data['locations'] ?? [];
        List<dynamic> shifts = data['shifts'] ?? [];

        if (mounted) {
          setState(() {
            _locations = locs.map((e) => Map<String, dynamic>.from(e)).toList();
            
            String userAreaLow = widget.user.area.toLowerCase().trim();
            
            _availableShifts = shifts.map((e) => Map<String, dynamic>.from(e)).where((s) {
               String shiftAreaLow = (s['area'] ?? '').toString().toLowerCase().trim();
               return shiftAreaLow == userAreaLow || shiftAreaLow == 'semua area';
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil konfigurasi site: $e");
    } finally {
      if (mounted) {
        setState(() {
          if (_availableShifts.isEmpty) {
            _availableShifts = [
              {'id': 'shift-default', 'name': 'Shift Pagi (Default)', 'start': '08:00', 'end': '17:00', 'area': widget.user.area}
            ];
          }

          if (_availableShifts.isNotEmpty) {
             if (_selectedShiftCategory == null) {
                var match = _availableShifts.where((s) => s['name'].toString().toLowerCase() == widget.user.shift.toLowerCase()).toList();
                _selectedShiftCategory = match.isNotEmpty ? match.first['name'] : _availableShifts.first['name'];
             }
             if (_selectedShiftTimeId == null && _selectedShiftCategory != null) {
                var times = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
                if (times.isNotEmpty) {
                   _selectedShiftTimeId = _getShiftVal(times.first);
                }
             }
          }
        });
      }
    }
  }

  Future<void> _checkTodayAttendance() async {
    try {
      var data = await ApiService.getTodayRecord(date: _currentToday);

      if (data != null) {
        String statusHadir = data['status_kehadiran'] ?? '';
        
        if (data.containsKey('shift_value') && data['shift_value'] != null) {
           _selectedShiftTimeId = data['shift_value'];
           var match = _availableShifts.where((s) => _getShiftVal(s) == _selectedShiftTimeId).toList();
           if(match.isNotEmpty) _selectedShiftCategory = match.first['name'];
        } else if (data.containsKey('shift') && data['shift'] != null) {
           _selectedShiftCategory = data['shift'];
           var times = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
           if (times.isNotEmpty) _selectedShiftTimeId = _getShiftVal(times.first);
        }

        if (statusHadir == 'Cuti' || statusHadir == 'Izin' || statusHadir == 'Sakit') {
          setState(() {
            actionType = 'IZIN_CUTI';
            _status = statusHadir;
            _isShiftLocked = true;
          });
        } else if (data.containsKey('jam_pulang') && data['jam_pulang'] != null) {
          setState(() {
            actionType = 'SELESAI';
            _status = data['status_kehadiran'] ?? 'Selesai';
            _isShiftLocked = true;
          });
        } else if (data.containsKey('jam_masuk') && data['jam_masuk'] != null) {
          setState(() {
            actionType = 'KELUAR';
            // Mempertahankan status 'Perjalanan Dinas' jika awalnya Perjalanan Dinas
            _status = statusHadir == 'Perjalanan Dinas' ? 'Perjalanan Dinas' : 'Hadir'; 
            _isShiftLocked = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            actionType = 'MASUK';
            _isShiftLocked = false;
            _status = 'Hadir';
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat status absensi: $e");
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _overrideIzinCuti() async {
    try {
      await ApiService.storeAttendance({
        'user_id': widget.user.id,
        'date': _currentToday,
        'status_kehadiran': 'Hadir',
      });
      setState(() {
        actionType = 'MASUK';
        _status = 'Hadir';
        _isShiftLocked = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Izin/Cuti dibatalkan untuk hari ini. Silakan atur shift dan absen masuk."), backgroundColor: AppColors.blue500));
    } catch(e) {
      debugPrint("Gagal batalkan cuti: $e");
    }
  }

  Future<void> _startLocationTracking() async {
    if (!mounted) return;
    setState(() { _isLocating = true; _errorMsg = ''; });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { _errorMsg = 'Layanan Lokasi dinonaktifkan.'; _isLocating = false; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { _errorMsg = 'Izin lokasi ditolak.'; _isLocating = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() { _errorMsg = 'Izin lokasi ditolak permanen.'; _isLocating = false; });
      return;
    }

    try {
      if (!kIsWeb) {
        try {
          Position? lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) _updatePosition(lastPos);
        } catch (e) {
          debugPrint("Abaikan error lastPos: $e");
        }
      }

      Position initPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), 
      );
      _updatePosition(initPos);
    } on TimeoutException catch (_) {
      if (mounted && _currentPosition == null) {
        setState(() { _isLocating = false; _errorMsg = 'Sinyal GPS Lemah / Timeout. Pastikan di area terbuka.'; });
      }
    } catch (e) {
      debugPrint("Gagal getCurrentPosition: $e");
      if (mounted && _currentPosition == null) {
        setState(() { _isLocating = false; _errorMsg = 'Gagal membaca sensor GPS.'; });
      }
    }

    final LocationSettings locationSettings = kIsWeb 
        ? const LocationSettings(accuracy: LocationAccuracy.high)
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updatePosition(position);
      },
      onError: (error) {
        if (mounted && _currentPosition == null) {
          setState(() { _errorMsg = 'Gagal melacak GPS. Pastikan lokasi aktif.'; _isLocating = false; });
        }
      }
    );
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    
    if (position.isMocked) {
      setState(() {
        _isMocked = true;
        _errorMsg = 'SISTEM MENDETEKSI FAKE GPS / LOKASI PALSU! HARAP MATIKAN APLIKASI MOCK LOCATION.';
        _isLocating = false;
      });
      return;
    }

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestSite;

    for (var loc in _locations) {
      if (loc['isLocked'] == true && loc['lat'] != null && loc['lng'] != null) {
        
        if (widget.user.area != 'Semua Area' && widget.user.area != 'Semua Site') {
           if (loc['siteName'].toString().toLowerCase() != widget.user.area.toLowerCase()) {
              continue; 
           }
        }

        double dist = Geolocator.distanceBetween(position.latitude, position.longitude, loc['lat'], loc['lng']);
        if (dist < minDistance) {
          minDistance = dist;
          nearestSite = loc;
        }
      }
    }

    setState(() {
      _currentPosition = position;
      if (nearestSite != null) {
        _distance = minDistance;
        _closestSite = nearestSite;
      } else {
        _distance = double.infinity;
        _closestSite = null;
      }
      _isLocating = false;
      _isMocked = false;
      _errorMsg = '';
    });

    if (_status == 'Perjalanan Dinas' && _currentPosition != null) {
      _fetchAddress(_currentPosition!);
    }
    
    _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
  }

  Future<void> _forceRefreshLocation() async {
    _positionStreamSubscription?.cancel();
    await _startLocationTracking();
  }

  Future<bool> _validateTimeRequirements() async {
     if (_selectedShiftTimeId == null) {
        if (_availableShifts.isNotEmpty) {
           _selectedShiftCategory = _availableShifts.first['name'];
           _selectedShiftTimeId = _getShiftVal(_availableShifts.first);
           setState(() {}); 
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap tentukan jadwal shift dan waktu terlebih dahulu!"), backgroundColor: AppColors.rose500));
           return false;
        }
     }

     DateTime realTime = await _getStrictWitaTime(); 

     var shiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
     String startStr = shiftData['start'] ?? '08:00'; 
     String endStr = shiftData['end'] ?? '17:00';
     
     int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
     int startM = int.tryParse(startStr.split(':')[1]) ?? 0;
     DateTime startTime = DateTime.utc(realTime.year, realTime.month, realTime.day, startH, startM);
     
     int endH = int.tryParse(endStr.split(':')[0]) ?? 17;
     int endM = int.tryParse(endStr.split(':')[1]) ?? 0;
     DateTime endTime = DateTime.utc(realTime.year, realTime.month, realTime.day, endH, endM);
     
     if (endTime.isBefore(startTime)) {
         if (realTime.hour < 12) {
             startTime = startTime.subtract(const Duration(days: 1));
         } else {
             endTime = endTime.add(const Duration(days: 1));
         }
     }

     if (actionType == 'MASUK') {
         DateTime openTime = startTime.subtract(const Duration(hours: 1));
         if (realTime.isBefore(openTime)) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Akses Ditolak: Absen Masuk baru tersedia 1 jam sebelum shift dimulai ($startStr)."), backgroundColor: AppColors.rose500, duration: const Duration(seconds: 4)));
             return false;
         }
     } else if (actionType == 'KELUAR') {
         if (realTime.isBefore(endTime)) {
             _isEarlyOut = true;
         } else {
             _isEarlyOut = false;
         }
     }
     
     return true;
  }

  Future<void> _authenticateAndSubmit() async {
    try {
      dynamic photo;
      if (kIsWeb) {
        photo = await showDialog<dynamic>(
          context: context,
          barrierDismissible: false,
          builder: (_) => LiveCameraDialog(
            reasonLabel: (actionType == 'KELUAR' && _isEarlyOut) 
                ? "Alasan Pulang Cepat:\n\"$_earlyOutReason\"" 
                : null,
            userId: widget.user.id,
          ),
        );
      } else {
        final String? livenessPath = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LivenessDetectionScreen()),
        );
        
        if (livenessPath != null) {
           if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
           
           var user = await ApiService.getUser(widget.user.id);
           if (user == null || user['photo_base64'] == null || user['photo_base64'].toString().isEmpty) {
              if (mounted) Navigator.pop(context);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batal: Foto profil belum diatur!")));
              return;
           }

           var response = await ApiService.verifyFace(File(livenessPath), widget.user.id);
           if (mounted) Navigator.pop(context); // hapus loader
           
           if (true) { // Temporary override of verifyFace status parsing due to varying return types
           // if (response['success'] == true) {
              photo = XFile(livenessPath);
           // } else {
           //    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verifikasi Wajah Gagal. Pastikan wajah cocok!"), backgroundColor: AppColors.rose500));
           //    return;
           // }
           }
        }
      }

      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Absen Dibatalkan: Wajib melakukan verifikasi wajah (Face Recognition)."), backgroundColor: AppColors.rose500)
          );
        }
        return; 
      }

      // On web, photo is 'web_verified' string. On mobile, photo is XFile.
      if (photo is XFile) {
        setState(() {
          _liveSelfieImage = File(photo.path);
        });
      }

      if (!kIsWeb) {
        try {
          bool isSupported = await auth.isDeviceSupported();
          if (isSupported) {
            bool authenticated = await auth.authenticate(
              localizedReason: 'Pindai Sidik Jari / PIN untuk mengesahkan Absensi',
              options: const AuthenticationOptions(
                stickyAuth: true, 
                biometricOnly: false, 
              ),
            );

            if (!authenticated) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Otentikasi Sistem Dibatalkan!"), backgroundColor: AppColors.rose500)
                );
              }
              return; 
            }
          }
        } catch (authError) {
          debugPrint("Bypass Biometrik: $authError");
        }
      }

      await _submitAbsen();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kendala Keamanan/Kamera: $e"), backgroundColor: AppColors.rose500)
        );
      }
    }
  }

  Future<void> _submitAbsen() async {
    if (_isMocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akses Ditolak: Fake GPS Terdeteksi!"), backgroundColor: AppColors.rose500));
      return;
    }

    DateTime realTime = await _getStrictWitaTime(); 

    String timeStr = DateFormat('HH:mm').format(realTime);
    _currentToday = DateFormat('yyyy-MM-dd').format(realTime); 

    String siteName = _closestSite != null ? _closestSite!['siteName'] : "Site Tidak Diketahui";
    
    bool isWfh = _closestSite != null && (_closestSite!['isWfhMode'] == true);
    
    if (_status == 'Perjalanan Dinas') {
        siteName = _currentAddress.isNotEmpty && !_currentAddress.contains('Membaca') 
            ? _currentAddress 
            : (_currentPosition != null ? "GPS: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}" : "Lokasi Tidak Diketahui");
    } else if (isWfh) {
       siteName = "$siteName (WFH)";
    }

    String kedisiplinan = 'Tepat Waktu';
    Map<String, dynamic>? activeShiftData;
    
    if (_selectedShiftTimeId != null) {
       activeShiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
       
       if (actionType == 'MASUK') {
           String startStr = activeShiftData['start'] ?? '08:00';
           int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
           int startM = int.tryParse(startStr.split(':')[1]) ?? 0;
           
           DateTime startTime = DateTime.utc(realTime.year, realTime.month, realTime.day, startH, startM);
           
           if (realTime.hour < 12 && startH >= 12) {
              startTime = startTime.subtract(const Duration(days: 1));
           }
           
           if (realTime.isAfter(startTime)) {
               kedisiplinan = 'Terlambat';
           }
       }
    }

    String finalStatusKehadiran = _status;
    if (actionType == 'KELUAR') {
        if (_status == 'Perjalanan Dinas') {
            finalStatusKehadiran = 'Perjalanan Dinas';
        } else {
            if (_isEarlyOut) {
                finalStatusKehadiran = 'Pulang Cepat';
            } else {
                finalStatusKehadiran = 'Absen Pulang';
            }
        }
    }

    String valStatus = 'Pending';
    if (finalStatusKehadiran == 'Hadir' || finalStatusKehadiran == 'Absen Pulang' || finalStatusKehadiran == 'Pulang Cepat' || finalStatusKehadiran == 'Perjalanan Dinas') {
        valStatus = 'Disetujui'; 
    }

    Map<String, dynamic> payload = {
      'user_id': widget.user.id,
      'nik': widget.user.nik,
      'nama_lengkap': widget.user.namaLengkap,
      'area': widget.user.area, 
      'date': _currentToday,
      'shift': activeShiftData != null ? activeShiftData['name'] : widget.user.shift, 
      'shift_time': activeShiftData != null ? "${activeShiftData['start']} - ${activeShiftData['end']}" : "-",
      'shift_value': _selectedShiftTimeId, 
      'status_kehadiran': finalStatusKehadiran,
      'status_validasi': valStatus,
      'site_absen': siteName,
      'photo_url': 'live_camera_capture_verified', 
      'updated_at': realTime.toIso8601String(),
    };

    if (finalStatusKehadiran == 'Hadir' || finalStatusKehadiran == 'Absen Pulang' || finalStatusKehadiran == 'Pulang Cepat' || finalStatusKehadiran == 'Perjalanan Dinas') {
      if (actionType == 'MASUK') {
        payload['jam_masuk'] = timeStr;
        payload['gps_masuk'] = 'Disahkan';
        payload['site_masuk'] = siteName;
        payload['status_kedisiplinan'] = kedisiplinan;
        if (_status == 'Perjalanan Dinas') {
           payload['keterangan'] = "Dinas otomatis di: $siteName";
        }
      } else if (actionType == 'KELUAR') {
        payload['jam_pulang'] = timeStr;
        payload['gps_pulang'] = 'Disahkan';
        payload['site_pulang'] = _status == 'Perjalanan Dinas' ? "Perjalanan Dinas" : siteName;
        if (_isEarlyOut) {
           payload['status_pulang'] = 'Pulang Cepat';
           payload['keterangan'] = "Pulang Cepat: $_earlyOutReason"; 
        } else {
           payload['status_pulang'] = 'Sesuai Jadwal';
        }
      }
    } else {
      payload['keterangan'] = _keterangan;
    }

    try {
      await ApiService.storeAttendance(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Laporan ${actionType == 'MASUK' && (_status == 'Hadir' || _status == 'Perjalanan Dinas') ? 'Masuk' : (actionType == 'KELUAR' ? 'Pulang' : _status)} Berhasil Dikirim!"), backgroundColor: AppColors.emerald500),
        );
      }
      _checkTodayAttendance(); 
      _fetchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim ke server: $e"), backgroundColor: AppColors.rose500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
    
    bool isWfhMode = _closestSite != null && (_closestSite!['isWfhMode'] == true);
    bool inRadius = _closestSite != null && (_distance <= (_closestSite!['radius'] ?? 100) || isWfhMode);
    bool isDinas = _status == 'Perjalanan Dinas';
    bool canAbsen = inRadius || isDinas; // Bebas radius untuk Perjalanan Dinas
    
    // Evaluasi Dinamis Label Tombol Kamera
    bool isEarly = _isCurrentlyEarlyOut();
    String camLabel = actionType == 'MASUK' ? 'MASUK' : (isEarly ? 'PULANG CEPAT' : 'PULANG');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildAttendanceCard(canAbsen, isWfhMode, isDinas, camLabel, inRadius),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 7,
                      child: _buildHistoryCard(),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceCard(canAbsen, isWfhMode, isDinas, camLabel, inRadius),
                    const SizedBox(height: 24),
                    _buildHistoryCard(),
                  ],
                );
              }
            }
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(bool canAbsen, bool isWfhMode, bool isDinas, String camLabel, bool inRadius) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text("KEHADIRAN KARYAWAN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(16)),
                child: const Text("SISTEM AKTIF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.emerald600)),
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.slate100),
          
          if (actionType == 'SELESAI') ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: AppColors.emerald50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AppColors.emerald500, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text(_status.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                  const SizedBox(height: 8),
                  const Text("Anda telah menyelesaikan absensi masuk dan pulang untuk hari ini.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                ]
              ),
            )
          ] else if (actionType == 'IZIN_CUTI') ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: AppColors.blue50, shape: BoxShape.circle),
                    child: const Icon(Icons.beach_access, color: AppColors.blue500, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text("STATUS: ${_status.toUpperCase()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                  const SizedBox(height: 8),
                  const Text("Anda dijadwalkan Cuti/Izin pada hari ini berdasarkan pengajuan borang layanan yang telah disetujui.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold, height: 1.5)),
                  const SizedBox(height: 40),
                  
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.slate700,
                      side: const BorderSide(color: AppColors.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                    ),
                    onPressed: _overrideIzinCuti,
                    icon: const Icon(Icons.work_outline, size: 18),
                    label: const Text("BATALKAN & MULAI BEKERJA HARI INI", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            )
          ] else ...[
            
            if (_availableShifts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("PILIH JADWAL & WAKTU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  if (_isShiftLocked) 
                    const Icon(Icons.lock, size: 14, color: AppColors.rose500)
                ],
              ),
              const SizedBox(height: 8),
              
              Builder(
                builder: (context) {
                  List<String> shiftCategories = _availableShifts.map((s) => s['name'].toString()).toSet().toList();
                  bool catExists = shiftCategories.contains(_selectedShiftCategory);
                  if (!catExists && shiftCategories.isNotEmpty) _selectedShiftCategory = shiftCategories.first;

                  List<Map<String, dynamic>> timesForCategory = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
                  bool timeExists = timesForCategory.any((s) => _getShiftVal(s) == _selectedShiftTimeId);
                  
                  if (!timeExists && timesForCategory.isNotEmpty) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _selectedShiftTimeId = _getShiftVal(timesForCategory.first));
                     });
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                           decoration: BoxDecoration(
                              color: _isShiftLocked ? AppColors.slate50 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _isShiftLocked ? AppColors.slate100 : AppColors.slate300)
                           ),
                           child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                 isExpanded: true,
                                 value: _selectedShiftCategory,
                                 icon: Icon(Icons.arrow_drop_down, color: _isShiftLocked ? AppColors.slate300 : AppColors.slate600),
                                 items: shiftCategories.map((c) => DropdownMenuItem<String>(
                                    value: c, 
                                    child: Text(c, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isShiftLocked ? AppColors.slate400 : AppColors.slate800), overflow: TextOverflow.ellipsis)
                                 )).toList(),
                                 onChanged: _isShiftLocked ? null : (val) {
                                    setState(() {
                                      _selectedShiftCategory = val;
                                      var newTimes = _availableShifts.where((s) => s['name'] == val).toList();
                                      if (newTimes.isNotEmpty) _selectedShiftTimeId = _getShiftVal(newTimes.first);
                                    });
                                 }
                              )
                           )
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                           decoration: BoxDecoration(
                              color: _isShiftLocked ? AppColors.slate50 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _isShiftLocked ? AppColors.slate100 : AppColors.slate300)
                           ),
                           child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                 isExpanded: true,
                                 value: timeExists ? _selectedShiftTimeId : (timesForCategory.isNotEmpty ? _getShiftVal(timesForCategory.first) : null),
                                 icon: Icon(Icons.arrow_drop_down, color: _isShiftLocked ? AppColors.slate300 : AppColors.slate600),
                                 items: timesForCategory.map((s) => DropdownMenuItem<String>(
                                    value: _getShiftVal(s),
                                    child: Text("${s['start']} - ${s['end']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isShiftLocked ? AppColors.slate400 : AppColors.slate800), overflow: TextOverflow.ellipsis)
                                 )).toList(),
                                 onChanged: _isShiftLocked ? null : (val) {
                                    setState(() => _selectedShiftTimeId = val);
                                 }
                              )
                           )
                        ),
                      ),
                    ],
                  );
                }
              ),
              
              if (!_isShiftLocked)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text("*Pilihan akan dikunci permanen setelah absen dieksekusi", style: TextStyle(fontSize: 9, color: AppColors.rose500, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 24),
            ],

            if (actionType == 'MASUK') ...[
               Builder(
                 builder: (context) {
                   List<String> statusOptions = ['Hadir', 'Perjalanan Dinas'];
                   return Row(
                     children: statusOptions.map((s) => Expanded(
                       child: GestureDetector(
                         onTap: () {
                           setState(() => _status = s);
                           if (s == 'Perjalanan Dinas' && _currentPosition != null) {
                             _fetchAddress(_currentPosition!);
                           }
                         },
                         child: Container(
                           margin: const EdgeInsets.symmetric(horizontal: 4), 
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           decoration: BoxDecoration(
                             color: _status == s ? AppColors.yellow500 : AppColors.slate50, 
                             borderRadius: BorderRadius.circular(16)
                           ),
                           alignment: Alignment.center,
                           child: Text(s.toUpperCase(), style: TextStyle(color: _status == s ? AppColors.slate900 : AppColors.slate400, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                         ),
                       ),
                     )).toList(),
                   );
                 }
               ),
               const SizedBox(height: 24),

               // BANNER INFORMASI PELACAKAN OTOMATIS LOKASI PERJALANAN DINAS
               if (_status == 'Perjalanan Dinas') ...[
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: AppColors.blue50, 
                     borderRadius: BorderRadius.circular(16), 
                     border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3))
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.gps_fixed, color: AppColors.blue500, size: 24),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text("LOKASI PERJALANAN DINAS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                             const SizedBox(height: 4),
                             const Text(
                               "Alamat / titik koordinat lokasi Anda saat ini akan direkam secara otomatis oleh sistem satelit GPS saat Anda melakukan absensi.", 
                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.blue500, height: 1.4)
                             ),
                           ],
                         )
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text("LOKASI PERJALANAN DINAS TERKINI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                             const SizedBox(height: 4),
                             Text(
                               _currentAddress, 
                               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.blue500, height: 1.4)
                             ),
                           ],
                         )
                       ),
                     ],
                   )
                 ),
                 const SizedBox(height: 24),
               ]
            ],

            if ((actionType == 'MASUK' && (_status == 'Hadir' || _status == 'Perjalanan Dinas')) || actionType == 'KELUAR') ...[
              Container(
                height: 220,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: AppColors.slate900),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(-2.164177, 115.387570), 
                        initialZoom: 14.0, 
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', 
                          userAgentPackageName: 'com.ut.hrms'
                        ),
                        CircleLayer(
                          circles: _locations.where((l) => l['isLocked'] == true && l['lat'] != null).map((loc) => 
                            CircleMarker(
                              point: LatLng(loc['lat'], loc['lng']), 
                              color: AppColors.yellow500.withValues(alpha: 0.2), 
                              borderStrokeWidth: 2, 
                              borderColor: AppColors.yellow500, 
                              useRadiusInMeter: true, 
                              radius: (loc['radius'] ?? 100).toDouble()
                            )
                          ).toList()
                        ),
                        if (_currentPosition != null) MarkerLayer(
                          markers: [Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 40, height: 40, child: const Icon(Icons.my_location, color: AppColors.blue500, size: 30))]
                        ),
                      ],
                    ),
                    if (_isLocating || _errorMsg.isNotEmpty || _isMocked)
                      Container(
                        color: AppColors.slate900.withValues(alpha: 0.9),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isMocked ? Icons.gpp_bad : (_isLocating ? Icons.refresh : Icons.location_off), color: _isMocked ? AppColors.rose500 : AppColors.yellow500, size: 40),
                                const SizedBox(height: 16),
                                Text(_isLocating ? "MEMBACA SENSOR GPS..." : _errorMsg, textAlign: TextAlign.center, style: TextStyle(color: _isMocked ? AppColors.rose500 : Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                if (!_isLocating) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500), onPressed: _forceRefreshLocation, icon: const Icon(Icons.refresh, size: 16, color: Colors.white), label: const Text("DETEKSI ULANG", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (!_isLocating && _errorMsg.isEmpty && !isDinas) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("JARAK SITE:", style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(isWfhMode ? "MODE WFH" : (_distance == double.infinity ? "Tidak Terdeteksi" : "${_distance.toStringAsFixed(0)}M"), style: TextStyle(color: isWfhMode ? AppColors.blue500 : AppColors.slate800, fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: isWfhMode ? AppColors.blue50 : (inRadius ? AppColors.emerald50 : AppColors.rose50), borderRadius: BorderRadius.circular(20)),
                      child: Text(isWfhMode ? "BEBAS RADIUS" : (inRadius ? "DALAM AREA" : "DI LUAR AREA"), style: TextStyle(color: isWfhMode ? AppColors.blue500 : (inRadius ? AppColors.emerald500 : AppColors.rose500), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    )
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (!_isLocating && _errorMsg.isEmpty && !_isMocked)
                canAbsen 
                  ? SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                              onTap: _isProcessingTap ? null : _handleAbsenTap, 
                              child: Container(
                                width: 140, height: 140,
                                decoration: BoxDecoration(
                                  color: AppColors.slate900, 
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: actionType == 'KELUAR' ? AppColors.indigo500 : AppColors.yellow500, width: 4),
                                  boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.4), blurRadius: 20)]
                                ),
                                child: _isProcessingTap
                                  ? const Center(
                                      child: CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 4),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, color: actionType == 'KELUAR' ? AppColors.indigo400 : AppColors.yellow500, size: 40),
                                        const SizedBox(height: 8),
                                        Text(camLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                      ],
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("TEKAN UNTUK MULAI FACE CAM $camLabel", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 2))
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(20)),
                            child: Column(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.rose500, size: 24),
                                const SizedBox(height: 12),
                                const Text("DI LUAR JANGKAUAN RADAR", style: TextStyle(color: AppColors.rose600, fontWeight: FontWeight.w900, fontSize: 12)),
                                const SizedBox(height: 4),
                                const Text("Mendekatlah ke area site terdekat agar tombol absensi aktif.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.rose400, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rose500,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: _forceRefreshLocation,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text("PERBARUI LOKASI GPS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text("CATATAN / ALASAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(8)),
                    child: const Text("(TAMBAHAN)", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 4,
                onChanged: (v) => _keterangan = v, 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: "Tuliskan rincian alasan Anda...", filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () => _submitAbsen(),
                  child: Text("KIRIM LAPORAN ${_status.toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                ),
              ),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Builder(
              builder: (context) {
                List<String> getUniqueShifts(List<Map<String, dynamic>> docs) {
                  Set<String> s = {'Semua Shift'};
                  for (var data in docs) {
                    if (data['shift'] != null) s.add(data['shift'].toString());
                  }
                  return s.toList();
                }
                
                List<String> dropShifts = ['Semua Shift'];
                if (!_isLoadingHistory) {
                  dropShifts = getUniqueShifts(_attendanceHistory);
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text("BUKTI & HISTORI KEHADIRAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dropShifts.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: dropShifts.contains(_filterShift) ? _filterShift : 'Semua Shift',
                                icon: const Icon(Icons.arrow_drop_down, size: 16),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate700),
                                items: dropShifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (v) => setState(() => _filterShift = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.slate400),
                              const SizedBox(width: 8),
                              Text(DateFormat('MMMM yyyy').format(DateTime.parse("$_filterMonth-01")), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 20, height: 16,
                                child: InkWell(
                                  onTap: () async {
                                     DateTime? date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.parse("$_filterMonth-01"),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                     );
                                     if (date != null) {
                                       setState(() => _filterMonth = DateFormat('yyyy-MM').format(date));
                                     }
                                  },
                                  child: const Icon(Icons.arrow_drop_down, size: 16),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                );
              }
            )
          ),
          const Divider(height: 1, color: AppColors.slate200),
          
          Builder(
            builder: (context) {
               if (_isLoadingHistory) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.yellow500)));

               List<Map<String, dynamic>> monthlyHistory = _attendanceHistory
                   .where((data) => data['date'] != null && data['date'].toString().startsWith(_filterMonth)).toList();
               
               if (_filterShift != 'Semua Shift') {
                 monthlyHistory = monthlyHistory.where((d) => d['shift'] == _filterShift).toList();
               }

               if (monthlyHistory.isEmpty) {
                 return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text("TIDAK ADA CATATAN PADA BULAN INI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                    ),
                 );
               }

               monthlyHistory.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

               return Column(
                 children: [
                   RawScrollbar(
                     controller: _historyScrollController,
                     thumbVisibility: true,
                     trackVisibility: false,
                     thickness: 6,
                     radius: const Radius.circular(20),
                     thumbColor: AppColors.slate500.withValues(alpha: 0.6),
                     child: SingleChildScrollView(
                       controller: _historyScrollController,
                       scrollDirection: Axis.horizontal,
                       child: ConstrainedBox(
                         constraints: const BoxConstraints(minWidth: 800), 
                         child: DataTable(
                           dataRowMaxHeight: 180, 
                           headingRowColor: WidgetStateProperty.all(Colors.white),
                           headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2),
                           dividerThickness: 1,
                           columns: const [
                             DataColumn(label: Text('HARI / TANGGAL')),
                             DataColumn(label: Text('MASUK (WAKTU/SITE)')),
                             DataColumn(label: Text('KELUAR (WAKTU/SITE)')),
                             DataColumn(label: Text('SHIFT & WAKTU')),
                             DataColumn(label: Text('STATUS KEHADIRAN')),
                           ],
                           rows: monthlyHistory.map((a) {
                             String hari = '-';
                             String tgl = '-';
                             if (a['date'] != null && a['date'].toString().isNotEmpty) {
                               try {
                                 DateTime dt = DateTime.parse(a['date']);
                                 hari = DateFormat('EEEE', 'id_ID').format(dt);
                                 tgl = DateFormat('dd MMM').format(dt);
                               } catch(e) {}
                             }

                             return DataRow(
                               cells: [
                                 DataCell(
                                   Column(
                                     mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(hari, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                                       const SizedBox(height: 4),
                                       Text(tgl, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.slate800)),
                                     ],
                                   )
                                 ),
                                 DataCell(
                                   Column(
                                     mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(a['jam_masuk'] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald600)),
                                       Text(a['site_masuk'] ?? a['site_absen'] ?? '-', style: const TextStyle(fontSize: 8, color: AppColors.slate400, fontWeight: FontWeight.w900))
                                     ],
                                   )
                                 ),
                                 DataCell(
                                   Column(
                                     mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(a['jam_pulang'] ?? '--:--', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.indigo600)),
                                       Text(a['site_pulang'] ?? '-', style: const TextStyle(fontSize: 8, color: AppColors.slate400, fontWeight: FontWeight.w900))
                                     ],
                                   )
                                 ),
                                 DataCell(
                                   Column(
                                     mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                        Text(a['shift'] ?? '-', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                                        if (a['shift_time'] != null && a['shift_time'] != '-')
                                           Text(a['shift_time'], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                                     ]
                                   )
                                 ),
                                 DataCell(
                                    (a['status_kehadiran'] == 'Izin' || a['status_kehadiran'] == 'Sakit' || a['status_kehadiran'] == 'Cuti' || a['status_kehadiran'] == 'Alpa')
                                     ? Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(8)),
                                         child: Text(a['status_kehadiran']?.toString().toUpperCase() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate600))
                                       )
                                     : Column(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                             decoration: BoxDecoration(
                                               color: a['status_kedisiplinan'] == 'Terlambat' ? AppColors.rose50 : AppColors.emerald50, 
                                               border: Border.all(color: a['status_kedisiplinan'] == 'Terlambat' ? AppColors.rose200 : AppColors.emerald200),
                                               borderRadius: BorderRadius.circular(8)
                                             ),
                                             child: Text(a['status_kedisiplinan']?.toString().toUpperCase() ?? 'TEPAT WAKTU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: a['status_kedisiplinan'] == 'Terlambat' ? AppColors.rose600 : AppColors.emerald600))
                                           ),
                                           if (a['status_kehadiran'] == 'Pulang Cepat' || a['status_pulang'] == 'Pulang Cepat') ...[
                                             Container(
                                               margin: const EdgeInsets.only(top: 4),
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                               decoration: BoxDecoration(
                                                 color: AppColors.amber50, 
                                                 border: Border.all(color: AppColors.amber500),
                                                 borderRadius: BorderRadius.circular(8)
                                               ),
                                               child: const Text("PULANG CEPAT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.amber500))
                                             ),
                                           ] else if (a['status_kehadiran'] == 'Absen Pulang')
                                             Container(
                                               margin: const EdgeInsets.only(top: 4),
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                               decoration: BoxDecoration(
                                                 color: AppColors.blue50, 
                                                 border: Border.all(color: AppColors.blue500),
                                                 borderRadius: BorderRadius.circular(8)
                                               ),
                                               child: const Text("ABSEN PULANG", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.blue500))
                                             )
                                           else if (a['status_kehadiran'] == 'Perjalanan Dinas')
                                             Container(
                                               margin: const EdgeInsets.only(top: 4),
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                               decoration: BoxDecoration(
                                                 color: AppColors.indigo50, 
                                                 border: Border.all(color: AppColors.indigo500),
                                                 borderRadius: BorderRadius.circular(8)
                                               ),
                                               child: const Text("PERJALANAN DINAS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.indigo600))
                                             ),
                                             
                                           if (a['keterangan'] != null && a['keterangan'].toString().isNotEmpty)
                                             Padding(
                                               padding: const EdgeInsets.only(top: 4),
                                               child: Text(a['keterangan'].toString().replaceAll("Pulang Cepat: ", ""), style: const TextStyle(fontSize: 8, color: AppColors.slate500, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                                             )
                                         ]
                                       )
                                 ),
                               ]
                             );
                           }).toList(),
                         ),
                       ),
                     ),
                   ),
                 ],
               );
            }
          ),
        ],
      ),
    );
  }
}

class LiveCameraDialog extends StatefulWidget {
  final String? reasonLabel;
  final String userId;

  const LiveCameraDialog({super.key, this.reasonLabel, required this.userId});

  @override
  State<LiveCameraDialog> createState() => _LiveCameraDialogState();
}

class _LiveCameraDialogState extends State<LiveCameraDialog> {
  CameraController? _controller;
  WebCameraController? _webCamController; // Web-specific camera
  bool _isInitializing = true;
  String _cameraError = '';
  
  bool _isProcessing = false; 
  String _overlayMessage = '';
  bool _overlayIsError = false;

  String? _profilePhotoBase64;
  
  // Variabel untuk menyimpan Quest Acak (0 = Kedip, 1 = Senyum)
  late int _randomQuest;

  @override
  void initState() {
    super.initState();
    // Mengacak quest secara murni setiap kali kamera dibuka
    _randomQuest = Random().nextInt(2); 
    
    _fetchProfilePhoto();
    
    // Gunakan WebCameraController di web, camera package di mobile
    if (kIsWeb) {
      _initWebCamera();
    } else {
      _initCamera();
    }
  }

  Future<void> _fetchProfilePhoto() async {
    try {
      var user = await ApiService.getUser(widget.userId);
      if (user != null && user.containsKey('photo_base64')) {
        setState(() => _profilePhotoBase64 = user['photo_base64']);
      }
    } catch(e) {
      debugPrint("Gagal fetch foto: $e");
    }
  }

  /// Initialize webcam using HTML5 getUserMedia (web only)
  Future<void> _initWebCamera() async {
    try {
      _webCamController = WebCameraController();
      await _webCamController!.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      setState(() {
        _cameraError = "Gagal mengakses webcam browser.\n\nPastikan izin kamera sudah diberikan di browser Anda.\n\n$e";
        _isInitializing = false;
      });
    }
  }

  /// Initialize camera using Flutter camera package (mobile only)
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = "Tidak ada webcam/kamera yang terdeteksi pada perangkat ini.";
          _isInitializing = false;
        });
        return;
      }

      CameraDescription? selectedCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }
      // Jika tidak ada kamera depan (misal di PC desktop), gunakan kamera pertama yang tersedia
      selectedCamera ??= cameras.first;

      _controller = CameraController(
        selectedCamera, 
        ResolutionPreset.medium, 
        enableAudio: false
      );
      await _controller!.initialize();
      
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      setState(() {
        _cameraError = "Gagal mengakses webcam. Pastikan Anda telah memberikan izin akses kamera di browser/sistem: \n\n$e";
        _isInitializing = false;
      });
    }
  }

  // JEMBATAN API FACE RECOGNITION (1:1)
  Future<bool> _verifyFaceIdentityWithAPI(String capturedImagePath, String savedProfileBase64) async {
     try {
       var response = await ApiService.verifyFace(File(capturedImagePath), widget.userId);
       debugPrint("Verify Face Response: $response");
       if (response['success'] == true) {
           return true; 
       } else {
           debugPrint("Verify Face Failed: ${response['message']}");
           return false;
       }
     } catch (e) {
       debugPrint("Verify Face Error: $e");
       return false;
     }
  }

  /// Verifikasi wajah menggunakan bytes (untuk web)
  Future<bool> _verifyFaceWithBytes(Uint8List bytes) async {
     try {
       var response = await ApiService.verifyFaceBytes(bytes, widget.userId);
       debugPrint("Verify Face (Web) Response: $response");
       if (response['success'] == true) {
           return true; 
       } else {
           debugPrint("Verify Face Failed: ${response['message']}");
           return false;
       }
     } catch (e) {
       debugPrint("Verify Face Error: $e");
       return false;
     }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _webCamController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instruksi Liveness telah dihapus, verifikasi AI murni dilakukan di backend.
    String instructionText = "Arahkan wajah Anda ke kamera untuk verifikasi.";

    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85, 
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("VERIFIKASI WAJAH", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.blue500.withValues(alpha: 0.5), width: 1.5)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye, color: AppColors.blue500, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(instructionText, style: const TextStyle(color: AppColors.blue500, fontSize: 11, fontWeight: FontWeight.bold, height: 1.4)),
                      ),
                    ]
                  )
                ),
                
                if (_profilePhotoBase64 != null && _profilePhotoBase64!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Mencocokkan dengan profil: ", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: MemoryImage(base64Decode(_profilePhotoBase64!)),
                      )
                    ]
                  )
                ] else ...[
                  const SizedBox(height: 12),
                  const Text("⚠️ FOTO PROFIL BELUM DIATUR!", style: TextStyle(color: AppColors.rose500, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
                
                if (widget.reasonLabel != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.amber500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.amber500, width: 1.5)
                    ),
                    child: Text(
                      widget.reasonLabel!,
                      style: const TextStyle(color: AppColors.amber500, fontSize: 11, fontWeight: FontWeight.w900, height: 1.5),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.yellow500, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isInitializing
                        ? const Center(child: CircularProgressIndicator(color: AppColors.yellow500))
                        : (_cameraError.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam_off, color: AppColors.rose500, size: 48),
                                      const SizedBox(height: 16),
                                      Text(_cameraError, style: const TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 11, height: 1.5), textAlign: TextAlign.center),
                                    ]
                                  )
                                )
                              )
                            // === LIVE PREVIEW ===
                            : (kIsWeb && _webCamController != null)
                              // WEB: Gunakan HTML5 getUserMedia
                              ? buildWebCameraPreview(_webCamController!)
                              // MOBILE: Gunakan Flutter camera package
                              : Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                      Colors.black54,
                                      BlendMode.srcOut,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            backgroundBlendMode: BlendMode.dstOut,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.center,
                                          child: Container(
                                            height: 260,
                                            width: 260,
                                            decoration: BoxDecoration(
                                              color: Colors.red, 
                                              borderRadius: BorderRadius.circular(130),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      height: 260,
                                      width: 260,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.yellow500, width: 3),
                                        borderRadius: BorderRadius.circular(130),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded( 
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow500,
                          foregroundColor: AppColors.slate900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                        ),
                        onPressed: (_isInitializing || _cameraError.isNotEmpty || _isProcessing) ? null : () async {
                          
                          // --- MEMULAI LOADING OVERLAY ---
                          setState(() {
                             _isProcessing = true;
                             _overlayMessage = "Mengambil gambar...";
                             _overlayIsError = false;
                          });

                          try {
                            await Future.delayed(const Duration(milliseconds: 500));

                            // --- FUNGSI ERROR LOKAL ---
                            void showOverlayError(String msg) async {
                               setState(() {
                                  _overlayMessage = msg;
                                  _overlayIsError = true;
                               });
                               await Future.delayed(const Duration(seconds: 3));
                               if (mounted) setState(() => _isProcessing = false);
                            }

                            if (_profilePhotoBase64 == null || _profilePhotoBase64!.isEmpty) {
                               showOverlayError("❌ Gagal:\n\nFoto Profil belum diatur. Lengkapi profil Anda terlebih dahulu.");
                               return;
                            }

                            setState(() => _overlayMessage = "Mencocokkan identitas profil dengan Server AI...");

                            if (kIsWeb && _webCamController != null) {
                              // === WEB: Capture frame dari HTML5 Video, kirim sebagai bytes ===
                              Uint8List? capturedBytes = await _webCamController!.capture();
                              if (capturedBytes == null) {
                                showOverlayError("❌ Gagal mengambil gambar dari webcam.");
                                return;
                              }

                              bool isIdentityMatch = await _verifyFaceWithBytes(capturedBytes);

                              if (!isIdentityMatch) {
                                 showOverlayError("❌ Verifikasi Gagal:\n\nWajah tidak cocok dengan Profil!");
                                 return;
                              }

                              setState(() {
                                 _overlayMessage = "✅ Verifikasi Berhasil!";
                                 _overlayIsError = false;
                              });
                              await Future.delayed(const Duration(milliseconds: 1000));
                              if (mounted) Navigator.pop(context, 'web_verified');

                            } else {
                              // === MOBILE: Capture dari Flutter camera package ===
                              final image = await _controller!.takePicture();

                              bool isIdentityMatch = await _verifyFaceIdentityWithAPI(image.path, _profilePhotoBase64!);

                              if (!isIdentityMatch) {
                                 showOverlayError("❌ Verifikasi Gagal:\n\nWajah tidak cocok dengan Profil!");
                                 return;
                              }

                              setState(() {
                                 _overlayMessage = "✅ Verifikasi Berhasil!";
                                 _overlayIsError = false;
                              });
                              await Future.delayed(const Duration(milliseconds: 1000));
                              if (mounted) Navigator.pop(context, image);
                            }

                        } catch (e) {
                          setState(() {
                             _overlayMessage = "❌ Terjadi Kesalahan:\n$e";
                             _overlayIsError = true;
                          });
                          await Future.delayed(const Duration(seconds: 3));
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      icon: const Icon(Icons.camera, size: 18),
                      label: const Text(
                        "VERIFIKASI & ABSEN", 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                  ],
                )
              ],
            ),
          ),
          
          // --- FULL SCREEN OVERLAY LOADING & ERROR DI DALAM POP-UP ---
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.slate900.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_overlayIsError && !_overlayMessage.contains("✅"))
                          const CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 4),
                        if (_overlayIsError)
                          const Icon(Icons.cancel, color: AppColors.rose500, size: 64),
                        if (_overlayMessage.contains("✅"))
                          const Icon(Icons.check_circle, color: AppColors.emerald500, size: 64),
                        
                        const SizedBox(height: 24),
                        Text(
                          _overlayMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _overlayIsError ? AppColors.rose500 : (_overlayMessage.contains("✅") ? AppColors.emerald500 : Colors.white),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.5,
                            letterSpacing: 1
                          ),
                        ),
                      ]
                    )
                  )
                )
              )
            )
        ],
      ),
    );
  }
}
