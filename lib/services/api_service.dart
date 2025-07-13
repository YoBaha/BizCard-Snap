import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = 'http://10.0.2.2:5000';
  String? _token;

  static String get baseUrl => _baseUrl;
  String? get token => _token;

  // Password validation: minimum 8 characters
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    return null;
  }

  Future<Map<String, dynamic>?> signup(String username, String email, String password) async {
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      return {'success': false, 'message': passwordError};
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    print('Signup response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return jsonDecode(response.body); // Return error response for handling
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      return {'success': false, 'message': passwordError};
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    print('Login response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      print('Token set: $_token');
      return data;
    }
    return jsonDecode(response.body); // Return error response for handling
  }

  Future<Map<String, dynamic>?> sendResetCode(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/send-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    print('Send reset code response: ${response.statusCode} - ${response.body}');
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>?> verifyResetCode(String email, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    print('Verify reset code response: ${response.statusCode} - ${response.body}');
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>?> resetPassword(String email, String newPassword) async {
    final passwordError = _validatePassword(newPassword);
    if (passwordError != null) {
      return {'success': false, 'message': passwordError};
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': newPassword}),
    );
    print('Reset password response: ${response.statusCode} - ${response.body}');
    return jsonDecode(response.body);
  }

  Future<Map<String, String>?> uploadImage(String imagePath) async {
    if (_token == null) {
      print('No token available');
      return null;
    }
    print('Uploading image from: $imagePath');
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/extract'));
    try {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      request.headers['Authorization'] = 'Bearer $_token';
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print('Upload response: ${response.statusCode} - $responseBody');
      if (response.statusCode == 200) {
        return Map<String, String>.from(jsonDecode(responseBody));
      } else {
        print('Error response details: $responseBody');
      }
    } catch (e) {
      print('Upload error: $e');
    }
    return null;
  }

  Future<Map<String, String>?> getCurrentUser() async {
    if (_token == null) {
      print('No token available');
      return null;
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/current_user'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    print('Get user response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      return Map<String, String>.from(jsonDecode(response.body));
    }
    return null;
  }

  Future<void> logout() async {
    _token = null;
    print('Logged out, token cleared');
  }

  Future<bool> deleteAccount() async {
    if (_token == null) {
      print('No token available');
      return false;
    }
    final response = await http.delete(
      Uri.parse('$_baseUrl/delete_account'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    print('Delete account response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      _token = null;
      return true;
    }
    return false;
  }

  Future<List<dynamic>?> getCards() async {
    if (_token == null) {
      print('No token available');
      return null;
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/cards'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    print('Get cards response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}