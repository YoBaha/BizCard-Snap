import 'package:flutter/material.dart';
import 'package:bizcard_snap/pages/home_page.dart';
import 'package:bizcard_snap/pages/camera_page.dart';
import 'package:bizcard_snap/pages/card_vault_page.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[
    HomePage(),
    CameraPage(),
    CardVaultPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      print('Tapped index: $index');
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building BottomNavBar with index: $_selectedIndex');
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Mode')), // Temporary app bar
      body: Container(color: Colors.grey[200], child: _pages[_selectedIndex]), // Simplified body
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.card_travel), label: 'Card Vault'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
      ),
    );
  }
}