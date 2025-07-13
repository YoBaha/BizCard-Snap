import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  Map<String, String> extractedData = {};
  bool isLoading = false;

 
  Future<Map<String, dynamic>> _fetchUserData() async {
    final userData = await _apiService.getCurrentUser();
    final cards = await _apiService.getCards();
    return {
      'username': userData?['username'] ?? 'Guest',
      'email': userData?['email'] ?? 'N/A',
      'cardCount': cards != null ? cards.length.toString() : '0',
    };
  }

  // Save image temporarily for upload
  Future<String> _saveImageTemporarily(XFile image) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/temp_image.png';
    await image.saveTo(path);
    return path;
  }

  // Upload image and process scanned card data
  Future<void> _uploadImage() async {
    if (_apiService.token == null) {
      setState(() {
        extractedData = {"error": "Please log in again"};
      });
      print('No token available');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isLoading = true);

    try {
      final imagePath = await _saveImageTemporarily(image);
      final result = await _apiService.uploadImage(imagePath);
      setState(() {
        extractedData = result ?? {"error": "Failed to process image"};
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        extractedData = {"error": "Error: $e"};
        isLoading = false;
      });
    }
  }

  // Show image quality popup before scanning
  Future<void> _showQualityPopup() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Image Quality Tip', style: TextStyle(decoration: TextDecoration.none)),
          content: const Text(
            'Image quality matters for a better scan. Please ensure the business card is clear, well-lit, and in focus.',
            style: TextStyle(fontSize: 16, decoration: TextDecoration.none),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(decoration: TextDecoration.none)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _uploadImage();
              },
              child: const Text('Continue', style: TextStyle(decoration: TextDecoration.none)),
            ),
          ],
        );
      },
    );
  }

  // Search company on Google
  Future<void> _searchCompany(String? companyName) async {
    if (companyName == null || companyName.isEmpty) return;
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(companyName)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching search: $e', style: const TextStyle(decoration: TextDecoration.none))),
      );
    }
  }

  // Send email
  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final url = Uri.parse('mailto:$email?subject=Contact from BizCard Snap');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email app', style: TextStyle(decoration: TextDecoration.none))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching email app: $e', style: const TextStyle(decoration: TextDecoration.none))),
      );
    }
  }

  // Save contact to device
  Future<void> _saveToContacts(String? phone, String? personName) async {
    if (phone == null || phone.isEmpty) return;

    if (await FlutterContacts.requestPermission()) {
      try {
        final firstPhone = phone.split(';')[0].trim();
        final contact = Contact()
          ..name.first = (personName ?? '').split(' ').first
          ..name.last = (personName ?? '').split(' ').length > 1 ? (personName ?? '').split(' ').last : ''
          ..phones = [Phone(firstPhone.replaceAll(RegExp(r'[\s-]'), ''))];

        await contact.insert();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact saved successfully', style: TextStyle(decoration: TextDecoration.none))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e', style: const TextStyle(decoration: TextDecoration.none))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied', style: TextStyle(decoration: TextDecoration.none))),
      );
    }
  }

  // Launch URL
  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching URL: $e', style: const TextStyle(decoration: TextDecoration.none))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building HomePage');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6441A5), Color(0xFF2a0845)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome message
                        FutureBuilder<Map<String, dynamic>>(
                          future: _fetchUserData(),
                          builder: (context, snapshot) {
                            String username = 'Guest';
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              username = 'Loading...';
                            } else if (snapshot.hasData) {
                              username = snapshot.data!['username'];
                            } else if (snapshot.hasError) {
                              print('Error fetching user data: ${snapshot.error}');
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, $username',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Ready to scan some of your business cards?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        // Scan button
                        Center(
                          child: GestureDetector(
                            onTap: isLoading ? null : () async => await _showQualityPopup(),
                            child: Container(
                              width: 200,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      )
                                    : const Text(
                                        'Scan Card Info',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Scanned Card Data
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (extractedData.isEmpty || extractedData.containsKey("error")) ...[
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.image,
                                          size: 100,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No card scanned yet',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                        if (extractedData.containsKey("error"))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: Text(
                                              extractedData["error"]!,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  ...extractedData.entries.map((entry) {
                                    if (entry.key != "error") {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF18181B),
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      entry.value,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white,
                                                        decoration: TextDecoration.none,
                                                      ),
                                                      textAlign: TextAlign.right,
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (entry.key == "Company Name" && entry.value.isNotEmpty)
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.search, color: Colors.white, size: 20),
                                                        onPressed: () => _searchCompany(entry.value),
                                                      ),
                                                    ),
                                                  if (entry.key == "Email" && entry.value.isNotEmpty)
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFFef473a), Color(0xFFcb2d3e)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.email, color: Colors.white, size: 20),
                                                        onPressed: () => _sendEmail(entry.value),
                                                      ),
                                                    ),
                                                  if (entry.key == "Phone" && entry.value.isNotEmpty)
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                                                        onPressed: () => _saveToContacts(entry.value, extractedData["Person Name"]),
                                                      ),
                                                    ),
                                                  if (entry.key == "QR URL" && entry.value.isNotEmpty)
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.link, color: Colors.white, size: 20),
                                                        onPressed: () => _launchURL(entry.value),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }).toList(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Your Data Card
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Your Data',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF18181B),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                                      onPressed: () => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder<Map<String, dynamic>>(
                                future: _fetchUserData(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    print('Error fetching user data: ${snapshot.error}');
                                    return const Text(
                                      'Error fetching data',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.redAccent,
                                        decoration: TextDecoration.none,
                                      ),
                                    );
                                  }
                                  final username = snapshot.data?['username'] ?? 'Guest';
                                  final email = snapshot.data?['email'] ?? 'N/A';
                                  final cardCount = snapshot.data?['cardCount'] ?? '0';
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Username',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF18181B),
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                decoration: TextDecoration.none,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Email',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF18181B),
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                decoration: TextDecoration.none,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Cards Scanned',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF18181B),
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            Text(
                                              cardCount,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Why Upload a Business Card?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF18181B),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Digitizing your business card helps you:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '• Keep contacts organized',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const Text(
                                '• Instantly extract key information',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const Text(
                                '• Never lose a connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const Text(
                                '• Easily share your professional identity',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Secure, fast, and paperless.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B32B2), Color(0xFF1488CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ExpansionTile(
                            title: const Text(
                              'Tips for Better Scans',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF18181B),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            collapsedBackgroundColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            iconColor: Colors.white,
                            collapsedIconColor: Colors.white,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '📷 Use natural light',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '🔍 Align card properly',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '💡 Avoid blurry images',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}