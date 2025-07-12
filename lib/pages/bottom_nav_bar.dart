import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import 'package:bizcard_snap/pages/home_page.dart';
import 'package:bizcard_snap/pages/camera_page.dart';
import 'package:bizcard_snap/pages/card_vault_page.dart';
import 'package:bizcard_snap/services/api_service.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int selected = 0;
  final PageController controller = PageController();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    print('BottomNavBar initialized');
    if (_apiService.token == null) {
      print('No token found, redirecting to login');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building BottomNavBar, selected index: $selected');
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: controller,
        children: const [
          HomePage(),
          CameraPage(),
          CardVaultPage(),
        ],
        onPageChanged: (index) {
          print('Page changed to index: $index');
          setState(() {
            selected = index;
          });
        },
      ),
      bottomNavigationBar: StylishBottomBar(
        option: AnimatedBarOptions(
          iconStyle: IconStyle.animated,
          barAnimation: BarAnimation.liquid,
          opacity: 0.3,
        ),
        items: [
          BottomBarItem(
            icon: const Icon(Icons.home, color: Colors.white70),
            title: const Text(
              'Home',
              style: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
            ),
            backgroundColor: const Color(0xFF2a0845),
            selectedColor: Colors.white,
            selectedIcon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home, color: Colors.white),
            ),
          ),
          BottomBarItem(
            icon: const Icon(Icons.camera_alt, color: Colors.white70),
            title: const Text(
              'Camera',
              style: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
            ),
            backgroundColor: const Color(0xFF2a0845),
            selectedColor: Colors.white,
            selectedIcon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
          BottomBarItem(
            icon: const Icon(Icons.card_travel, color: Colors.white70),
            title: const Text(
              'Card Vault',
              style: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
            ),
            backgroundColor: const Color(0xFF2a0845),
            selectedColor: Colors.white,
            selectedIcon: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_travel, color: Colors.white),
            ),
          ),
        ],
        currentIndex: selected,
        onTap: (index) {
          print('Nav bar item tapped: $index');
          setState(() {
            selected = index;
            controller.jumpToPage(index);
          });
        },
        hasNotch: false,
        backgroundColor: const Color(0xFF2a0845),
        elevation: 8,
      ),
      // Comment out StylishBottomBar and uncomment this to test with standard BottomNavigationBar
      /*
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.card_travel), label: 'Card Vault'),
        ],
        currentIndex: selected,
        backgroundColor: Color(0xFF2a0845),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        onTap: (index) {
          print('Nav bar item tapped: $index');
          setState(() {
            selected = index;
            controller.jumpToPage(index);
          });
        },
      ),
      */
    );
  }
}