import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:proto_app/product_page.dart';
import 'package:proto_app/screens/auth/seller_login_screen.dart';

class SellerSignUpScreen extends StatefulWidget {
  const SellerSignUpScreen({super.key});

  @override
  _SellerSignUpScreenState createState() => _SellerSignUpScreenState();
}

class _SellerSignUpScreenState extends State<SellerSignUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _gstNumberController = TextEditingController();

  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _firestore.collection('sellers').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'category': _categoryController.text.trim(),
        'location': _locationController.text.trim(),
        'gstNumber': _gstNumberController.text.trim(),
        'createdAt': Timestamp.now(),
      });

        ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Signup successful. Please login now.')),
  );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SellerLoginPage()),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Seller Sign Up",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 141, 83, 20),
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(_nameController, "Full Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_emailController, "Email", Icons.email),
                const SizedBox(height: 12),
                _buildTextField(_passwordController, "Password", Icons.lock, obscureText: true),
                const SizedBox(height: 12),
                _buildTextField(_shopNameController, "Shop/Brand Name", Icons.store),
                const SizedBox(height: 12),
                _buildTextField(_categoryController, "Business Category", Icons.category),
                const SizedBox(height: 12),
                _buildTextField(_locationController, "Business Location", Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField(_gstNumberController, "GST Number (optional)", Icons.receipt),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 141, 83, 47),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign Up", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
