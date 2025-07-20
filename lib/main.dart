import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:proto_app/admin_dashboard.dart';
import 'package:proto_app/screens/auth/buyer_login_screen.dart';
import 'package:proto_app/screens/splash_screen.dart';
// import 'package:proto_app/screens/auth/login_screen.dart';
import 'package:proto_app/product_page.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karigari App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      
      initialRoute: '/splash',

      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => BuyerLoginScreen(),         // Replace with your actual login page
        '/products': (context) => ProductPage(),
        '/admin_dashboard': (context) => const AdminDashboard(),    // Your product page
      },
    );
  }
}
