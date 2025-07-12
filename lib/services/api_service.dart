import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = 'http://10.0.2.2:5000'; 
  String? _token;


  String? get token => _token;

  Future<Map<String, dynamic>?> signup(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    print('Signup response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
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
    return null;
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
}