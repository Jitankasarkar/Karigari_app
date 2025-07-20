import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with real notifications or Firebase stream
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text("New Order Received"),
            subtitle: Text("2 minutes ago"),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text("User signed up"),
            subtitle: Text("10 minutes ago"),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text("Stock alert: Product A"),
            subtitle: Text("30 minutes ago"),
          ),
        ],
      ),
    );
  }
}
