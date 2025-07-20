import 'package:flutter/material.dart';
import 'package:proto_app/admin_profile_page.dart';
import 'package:proto_app/order_management.dart';
import 'package:proto_app/user_management.dart';
import 'package:proto_app/notification_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_DashboardItem> items = [
      _DashboardItem("Admin Profile", Icons.person, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfilePage()));
      }),
      _DashboardItem("Order Management", Icons.shopping_cart, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderManagementPage()));
      }),
      _DashboardItem("User Management", Icons.people, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
      }),
      _DashboardItem("Notifications", Icons.notifications, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage()));
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.onTap,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.deepPurple.shade50,
                elevation: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 48, color: Colors.deepPurple),
                    const SizedBox(height: 12),
                    Text(item.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardItem(this.label, this.icon, this.onTap);
}
