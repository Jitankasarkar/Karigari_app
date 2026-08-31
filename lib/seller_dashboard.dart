import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/screens/seller_home_page.dart';
import 'package:proto_app/screens/seller_upload_product_page.dart';
import 'package:proto_app/screens/seller_analytics_page.dart';
import 'package:proto_app/screens/seller_insights.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _currentIndex = 0;

  // All four pages stay mounted inside the IndexedStack.
  // SellerAnalyticsPage publishes its live analytics through
  // SellerAnalyticsPage.latestAnalytics, and SellerInsights listens to it.
  final List<Widget> _pages = const [
    SellerHomePage(),
    SellerUploadProductPage(),
    SellerAnalyticsPage(),
    SellerInsights(),
  ];

  final List<String> _titles = const [
    'Home',
    'Upload Product',
    'Analytics',
    'AI Growth',
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/splash',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 228, 128, 47),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Growth',
          ),
        ],
      ),
    );
  }
}
