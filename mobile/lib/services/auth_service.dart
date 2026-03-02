import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // Use 10.0.2.2 for Android emulator -> localhost
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('aegis_token');
    if (_token != null) {
      await fetchUser();
    }
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('aegis_token', _token!);
        await fetchUser();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String phone, String password, String guardianPhone) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'guardian_phone': guardianPhone,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('aegis_token', _token!);
        await fetchUser();
        return true;
      }
      return false;
    } catch (e) {
      print('Signup error: $e');
      return false;
    }
  }

  Future<void> fetchUser() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        _user = jsonDecode(res.body);
        notifyListeners();
      } else {
        await logout();
      }
    } catch (e) {
      print('Fetch user error: $e');
    }
  }

  Future<bool> updateGuardian(String newGuardian) async {
    if (_token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/update-guardian'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token'
        },
        body: jsonEncode({'guardian_phone': newGuardian}),
      );
      if (res.statusCode == 200) {
        if (_user != null) {
          _user!['guardian_phone'] = newGuardian;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Update guardian error: $e');
      return false;
    }
  }

  Future<void> triggerSosAlert() async {
    if (_token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/sos-alert'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      print('SOS Alert triggered to backend.');
    } catch (e) {
      print('SOS Alert error: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aegis_token');
    notifyListeners();
  }
}
