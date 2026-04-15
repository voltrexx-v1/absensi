import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // ========== HELPERS ==========
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null) uri = uri.replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    return jsonDecode(response.body);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      print('POST Error: \${response.statusCode} - \${response.body}');
      throw Exception('API POST Error \${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      print('PUT Error: \${response.statusCode} - \${response.body}');
      throw Exception('API PUT Error \${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  static Future<dynamic> _delete(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'), headers: await _headers());
    return jsonDecode(response.body);
  }

  // ========== AUTH ==========
  static Future<Map<String, dynamic>> login(String nik, String password, {String? mobileDeviceId, String? desktopDeviceId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'nik': nik, 
        'password': password,
        'mobileDeviceId': mobileDeviceId,
        'desktopDeviceId': desktopDeviceId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return {'success': true, 'user': UserModel.fromJson(data['user'])};
    }
    return {'success': false, 'message': data['message'] ?? 'Login failed: ${response.statusCode}'};
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Jangan simpan token otomatis, biarkan user login manual
      }
      return {'success': response.statusCode == 201, 'data': data};
    } catch (e) {
      return {'success': false, 'data': {'message': 'Koneksi gagal: $e'}};
    }
  }

  static Future<void> logout() async {
    try {
      await _post('/logout', {});
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ========== FACE AUTH ==========
  static Future<Map<String, dynamic>> registerFace(File imageFile, String userId) async {
    var uri = Uri.parse('$baseUrl/register-face');
    var request = http.MultipartRequest('POST', uri);
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['user_id'] = userId;
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  static Future<Map<String, dynamic>> verifyFace(File imageFile, String userId) async {
    var uri = Uri.parse('$baseUrl/verify-face');
    var request = http.MultipartRequest('POST', uri);
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['user_id'] = userId;
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  // ========== FACE AUTH (WEB / BYTES) ==========
  static Future<Map<String, dynamic>> registerFaceBytes(Uint8List bytes, String userId) async {
    var uri = Uri.parse('$baseUrl/register-face');
    var request = http.MultipartRequest('POST', uri);
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['user_id'] = userId;
    request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'webcam_capture.jpg'));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  static Future<Map<String, dynamic>> verifyFaceBytes(Uint8List bytes, String userId) async {
    var uri = Uri.parse('$baseUrl/verify-face');
    var request = http.MultipartRequest('POST', uri);
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['user_id'] = userId;
    request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'webcam_capture.jpg'));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    return jsonDecode(responseBody);
  }

  static Future<UserModel?> getProfile() async {
    try {
      final data = await _get('/profile');
      return UserModel.fromJson(data['user']);
    } catch (e) { return null; }
  }

  static Future<bool> updateProfile(Map<String, dynamic> payload) async {
    try {
      await _put('/profile', payload);
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> changePassword(String current, String newPass) async {
    try {
      final data = await _post('/change-password', {'current_password': current, 'new_password': newPass});
      return data['message'] != null && !data.containsKey('errors');
    } catch (e) { return false; }
  }

  // ========== USERS ==========
  static Future<List<Map<String, dynamic>>> getUsers({String? role, String? area}) async {
    try {
      Map<String, String> params = {};
      if (role != null) params['role'] = role;
      if (area != null) params['area'] = area;
      final data = await _get('/users', params: params);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>?> getUser(String id) async {
    try {
      final data = await _get('/users/$id');
      return Map<String, dynamic>.from(data['data']);
    } catch (e) { return null; }
  }

  static Future<bool> updateUser(String id, Map<String, dynamic> payload) async {
    try { await _put('/users/$id', payload); return true; } catch (e) { return false; }
  }

  static Future<bool> deleteUser(String id) async {
    try { await _delete('/users/$id'); return true; } catch (e) { return false; }
  }

  static Future<bool> createUser(Map<String, dynamic> payload) async {
    try { await _post('/users', payload); return true; } catch (e) { return false; }
  }

  static Future<bool> resetDevice(String id, {String? field}) async {
    try {
      await _post('/users/$id/reset-device', {'field': field});
      return true;
    } catch (e) { return false; }
  }

  static Future<bool> resetFace(String id) async {
    try {
      await _post('/users/$id/reset-face', {});
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkNik(String nik) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-nik'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'nik': nik}),
      );
      return jsonDecode(response.body)['exists'] ?? false;
    } catch (e) { return false; }
  }

  static Future<bool> checkEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-email'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return jsonDecode(response.body)['exists'] ?? false;
    } catch (e) { return false; }
  }

  // ========== ATTENDANCE ==========
  static Future<Map<String, dynamic>?> clockIn(Map<String, dynamic> payload) async {
    try {
      final data = await _post('/attendance/clock-in', payload);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> clockOut(Map<String, dynamic> payload) async {
    try {
      final data = await _post('/attendance/clock-out', payload);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> getTodayRecord({String? date}) async {
    try {
      Map<String, String> params = {};
      if (date != null) params['date'] = date;
      final data = await _get('/attendance/today', params: params);
      return data['data'] != null ? Map<String, dynamic>.from(data['data']) : null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>> getAttendanceHistory({String? month}) async {
    try {
      Map<String, String> params = {};
      if (month != null) params['month'] = month;
      final data = await _get('/attendance/history', params: params);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getAllAttendance({String? date, String? userId}) async {
    try {
      Map<String, String> params = {};
      if (date != null) params['date'] = date;
      if (userId != null) params['user_id'] = userId;
      final data = await _get('/attendance/all', params: params);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<bool> storeAttendance(Map<String, dynamic> payload) async {
    try { await _post('/attendance/store', payload); return true; } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>> getAttendances() async {
    try {
      final data = await _get('/attendance/all');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<bool> deleteAttendance(String id) async {
    try { await _delete('/attendance/$id'); return true; } catch (e) { return false; }
  }

  // ========== CONFIG ==========
  static Future<dynamic> getConfig(String key) async {
    try {
      final data = await _get('/config/$key');
      return data['data'];
    } catch (e) { return null; }
  }

  static Future<bool> updateConfig(String key, dynamic value) async {
    try { await _put('/config/$key', {'value': value}); return true; } catch (e) { return false; }
  }

  // ========== REQUESTS (Izin/Sakit) ==========
  static Future<List<Map<String, dynamic>>> getRequests({String? userId, String? status, String? area}) async {
    try {
      Map<String, String> params = {};
      if (userId != null) params['user_id'] = userId;
      if (status != null) params['status'] = status;
      if (area != null) params['area'] = area;
      final data = await _get('/requests', params: params);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<bool> createRequest(Map<String, dynamic> payload) async {
    try { await _post('/requests', payload); return true; } catch (e) { return false; }
  }

  static Future<bool> updateRequestStatus(String id, String status) async {
    try { await _put('/requests/$id/status', {'status': status}); return true; } catch (e) { return false; }
  }

  static Future<bool> deleteRequest(String id) async {
    try { await _delete('/requests/$id'); return true; } catch (e) { return false; }
  }

  // ========== TICKETS ==========
  static Future<List<Map<String, dynamic>>> getTickets({String? userId, String? status, String? area}) async {
    try {
      Map<String, String> params = {};
      if (userId != null) params['user_id'] = userId;
      if (status != null) params['status'] = status;
      if (area != null) params['area'] = area;
      final data = await _get('/tickets', params: params);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) { return []; }
  }

  static Future<bool> createTicket(Map<String, dynamic> payload) async {
    try { await _post('/tickets', payload); return true; } catch (e) { return false; }
  }

  static Future<bool> updateTicket(String id, Map<String, dynamic> payload) async {
    try { await _put('/tickets/$id', payload); return true; } catch (e) { return false; }
  }

  static Future<bool> deleteTicket(String id) async {
    try { await _delete('/tickets/$id'); return true; } catch (e) { return false; }
  }
}
