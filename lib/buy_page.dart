import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:proto_app/confirm_page.dart';

class BuyPage extends StatefulWidget {
  final String productName;
  final String productPrice;
  final String productImage;

  const BuyPage({
    Key? key,
    required this.productName,
    required this.productPrice,
    required this.productImage,
  }) : super(key: key);

  @override
  State<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends State<BuyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedPayment = "cod";
  late Razorpay _razorpay;

  final int deliveryCharge = 20;
  final int platformFee = 1;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _saveOrder(status: 'done', payId: response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  Future<void> _saveOrder({required String status, String? payId}) async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "guest";

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'productName': widget.productName,
        'productPrice': widget.productPrice,
        'productImage': widget.productImage,
        'fullName': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'paymentMethod': _selectedPayment,
        'paymentStatus': status,
        'paymentId': payId ?? '',
        'email': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ConfirmPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Order save failed: $e")),
      );
    }
  }

  void _startOnlinePayment(int amount) {
    var options = {
      'key': 'rzp_test_soO0DVUQSdQ81X',
      'amount': amount * 100,
      'name': widget.productName,
      'description': 'Order Payment',
      'prefill': {
        'contact': _phoneController.text,
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      }
    };
    _razorpay.open(options);
  }

  void _confirmOrder() {
    if (!_formKey.currentState!.validate()) return;

    final int price = int.tryParse(widget.productPrice) ?? 0;
    final total = price + deliveryCharge + platformFee;

    if (_selectedPayment == "cod") {
      _saveOrder(status: "pending");
    } else {
      _startOnlinePayment(total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int price = int.tryParse(widget.productPrice) ?? 0;
    final int total = price + deliveryCharge + platformFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: const TextStyle(color: Colors.white),),
        backgroundColor: const Color.fromARGB(255, 222, 128, 47)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: Image.network(widget.productImage,
                          height: 200, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.productName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("₹${widget.productPrice}",
                              style: const TextStyle(fontSize: 18, color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Shipping Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: "Full Name", border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? "Enter your name" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                    labelText: "Shipping Address", border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? "Enter your address" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: "Phone Number", border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? "Enter your phone" : null,
              ),

              const SizedBox(height: 20),
              const Text("Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              RadioListTile(
                title: const Text("Cash on Delivery (COD)"),
                value: "cod",
                groupValue: _selectedPayment,
                onChanged: (value) => setState(() => _selectedPayment = value!),
              ),
              RadioListTile(
                title: const Text("Card/UPI (Razorpay)"),
                value: "online",
                groupValue: _selectedPayment,
                onChanged: (value) => setState(() => _selectedPayment = value!),
              ),
             

              const SizedBox(height: 20),
              const Divider(thickness: 1),
              const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSummaryRow("Item Price", price),
              _buildSummaryRow("Delivery Charge", deliveryCharge),
              _buildSummaryRow("Platform Fee", platformFee),
              const Divider(thickness: 1),
              _buildSummaryRow("Total", total, isBold: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 222, 128, 47),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16)),
          onPressed: _confirmOrder,
          child: Text(
            "Pay ₹$total",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold),
              
            ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                )),
          Text("₹$amount",
              style: TextStyle(fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,)),
        ],
      ),
    );
  }
}
