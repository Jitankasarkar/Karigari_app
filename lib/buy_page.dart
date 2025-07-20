import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proto_app/confirm_page.dart';

class BuyPage extends StatefulWidget {
  final String productName;
  final String productPrice;
  final String productImage;

  const BuyPage({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.productImage,
  });

  @override
  State<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends State<BuyPage> {
  String _selectedPayment = "cod";
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final int deliveryCharge = 50;
  final int platformFee = 5;

  Future<void> _confirmOrder() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userEmail = user?.email ?? 'Unknown';

        await FirebaseFirestore.instance.collection('orders').add({
          'productName': widget.productName,
          'productPrice': widget.productPrice,
          'productImage': widget.productImage,
          'fullName': _nameController.text,
          'address': _addressController.text,
          'phone': _phoneController.text,
          'paymentMethod': _selectedPayment,
          'email': userEmail,
          'timestamp': FieldValue.serverTimestamp(),
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConfirmPage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to confirm order: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int productPrice = int.tryParse(widget.productPrice) ?? 0;
    final int totalPrice = productPrice + deliveryCharge + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: const Color.fromARGB(255, 214, 112, 22),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Product Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.productImage,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 100),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.productName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Price:"),
                                Text("₹$productPrice",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Delivery Fee:"),
                                const Text("₹50"),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Platform Fee:"),
                                Text("₹$platformFee"),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total:",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text("₹$totalPrice",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Shipping Info
              buildSectionCard(
                title: "Shipping Info",
                children: [
                  buildInputField(
                      controller: _nameController,
                      label: "Full Name",
                      icon: Icons.person),
                  const SizedBox(height: 12),
                  buildInputField(
                      controller: _addressController,
                      label: "Address",
                      icon: Icons.home,
                      maxLines: 3),
                  const SizedBox(height: 12),
                  buildInputField(
                      controller: _phoneController,
                      label: "Phone Number",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone),
                ],
              ),

              const SizedBox(height: 20),

              // Payment Method
              buildSectionCard(
                title: "Select Payment",
                children: [
                  buildRadio("cod", "Cash on Delivery", Icons.money),
                  buildRadio("upi", "UPI / Wallet", Icons.account_balance_wallet),
                  buildRadio("card", "Credit / Debit Card", Icons.credit_card),
                ],
              ),

              const SizedBox(height: 100), // space for bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Payable",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("₹$totalPrice",
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _confirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 214, 112, 22),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Center(
                child: Text("Confirm Order",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) =>
          value == null || value.isEmpty ? "Enter $label" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
    );
  }

  Widget buildRadio(String value, String title, IconData icon) {
    return RadioListTile(
      value: value,
      groupValue: _selectedPayment,
      onChanged: (val) => setState(() => _selectedPayment = val.toString()),
      title: Row(
        children: [
          Icon(icon, color: const Color.fromARGB(255, 188, 116, 27)),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
      activeColor: const Color.fromARGB(255, 214, 112, 22),
    );
  }
}
