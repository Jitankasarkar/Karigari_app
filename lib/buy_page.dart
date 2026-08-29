import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:proto_app/confirm_page.dart';

class BuyPage extends StatefulWidget {
  // ---------------------------------------------------------
  // PRODUCT INFORMATION
  // ---------------------------------------------------------

  final String productName;
  final String productPrice;
  final String productImage;

  // ---------------------------------------------------------
  // SELLER INFORMATION
  // ---------------------------------------------------------

  final String sellerName;
  final String sellerId;

  const BuyPage({
    Key? key,
    required this.productName,
    required this.productPrice,
    required this.productImage,
    required this.sellerName,
    required this.sellerId,
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

  // ---------------------------------------------------------
  // CHARGES
  // ---------------------------------------------------------

  final int deliveryCharge = 20;
  final int platformFee = 1;

  // ---------------------------------------------------------
  // INITIALIZE RAZORPAY
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  // ---------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------

  @override
  void dispose() {
    _razorpay.clear();

    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // =========================================================
  // RAZORPAY PAYMENT SUCCESS
  // =========================================================

  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) {
    _saveOrder(
      status: 'done',
      payId: response.paymentId,
    );
  }

  // =========================================================
  // RAZORPAY PAYMENT FAILURE
  // =========================================================

  void _handlePaymentError(
    PaymentFailureResponse response,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message}',
        ),
      ),
    );
  }

  // =========================================================
  // EXTERNAL WALLET
  // =========================================================

  void _handleExternalWallet(
    ExternalWalletResponse response,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName}',
        ),
      ),
    );
  }

  // =========================================================
  // SAVE ORDER TO FIRESTORE
  // =========================================================

  Future<void> _saveOrder({
    required String status,
    String? payId,
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    final userEmail =
        currentUser?.email ?? "guest";

    final userId =
        currentUser?.uid ?? "";

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .add({

        // -----------------------------------------------------
        // PRODUCT INFORMATION
        // -----------------------------------------------------

        'productName': widget.productName,

        'productPrice': widget.productPrice,

        'productImage': widget.productImage,

        // -----------------------------------------------------
        // SELLER INFORMATION
        //
        // This is important for the Razorpay Buildathon.
        // It connects the order to the seller.
        // -----------------------------------------------------

        'sellerId': widget.sellerId,

        'sellerName': widget.sellerName,

        // -----------------------------------------------------
        // CUSTOMER INFORMATION
        // -----------------------------------------------------

        'userId': userId,

        'email': userEmail,

        'fullName': _nameController.text.trim(),

        'address': _addressController.text.trim(),

        'phone': _phoneController.text.trim(),

        // -----------------------------------------------------
        // PAYMENT INFORMATION
        // -----------------------------------------------------

        'paymentMethod': _selectedPayment,

        'paymentStatus': status,

        'paymentId': payId ?? '',

        // -----------------------------------------------------
        // ORDER TIMESTAMP
        // -----------------------------------------------------

        'timestamp': FieldValue.serverTimestamp(),
      });

      // -------------------------------------------------------
      // GO TO CONFIRMATION PAGE
      // -------------------------------------------------------

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const ConfirmPage(),
        ),
      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Order save failed: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // START RAZORPAY PAYMENT
  // =========================================================

  void _startOnlinePayment(int amount) {

    var options = {

      // -------------------------------------------------------
      // YOUR RAZORPAY TEST KEY
      // -------------------------------------------------------

      'key': 'rzp_test_soO0DVUQSdQ81X',

      // Razorpay expects amount in paise
      'amount': amount * 100,

      // -------------------------------------------------------
      // PAYMENT WINDOW
      // -------------------------------------------------------

      'name': 'Karigari',

      'description':
          'Payment for ${widget.productName}',

      // -------------------------------------------------------
      // CUSTOMER DETAILS
      // -------------------------------------------------------

      'prefill': {
        'contact': _phoneController.text.trim(),
        'email':
            FirebaseAuth.instance.currentUser?.email ?? '',
      },
    };

    _razorpay.open(options);
  }

  // =========================================================
  // CONFIRM ORDER
  // =========================================================

  void _confirmOrder() {

    // Validate shipping form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int price =
        int.tryParse(widget.productPrice) ?? 0;

    final total =
        price +
        deliveryCharge +
        platformFee;

    // -------------------------------------------------------
    // CASH ON DELIVERY
    // -------------------------------------------------------

    if (_selectedPayment == "cod") {

      _saveOrder(
        status: "pending",
      );

    }

    // -------------------------------------------------------
    // ONLINE PAYMENT
    // -------------------------------------------------------

    else {

      _startOnlinePayment(total);
    }
  }

  // =========================================================
  // BUILD UI
  // =========================================================

  @override
  Widget build(BuildContext context) {

    final int price =
        int.tryParse(widget.productPrice) ?? 0;

    final int total =
        price +
        deliveryCharge +
        platformFee;

    return Scaffold(

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(

        title: const Text(
          "Checkout",
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        backgroundColor:
            const Color.fromARGB(
          255,
          222,
          128,
          47,
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Form(

          key: _formKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // =================================================
              // PRODUCT CARD
              // =================================================

              Card(
                elevation: 4,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // -------------------------------------------
                    // PRODUCT IMAGE
                    // -------------------------------------------

                    ClipRRect(

                      borderRadius:
                          const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),

                      child: Image.network(

                        widget.productImage,

                        height: 200,

                        width: double.infinity,

                        fit: BoxFit.cover,

                        errorBuilder:
                            (context, error, stackTrace) {
                          return const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                "Image failed to load",
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // -------------------------------------------
                    // PRODUCT INFORMATION
                    // -------------------------------------------

                    Padding(
                      padding:
                          const EdgeInsets.all(12),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          Text(
                            widget.productName,

                            style:
                                const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "₹${widget.productPrice}",

                            style:
                                const TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // -------------------------------------
                          // SELLER
                          // -------------------------------------

                          Row(
                            children: [

                              Icon(
                                Icons.storefront,
                                size: 17,
                                color:
                                    Colors.grey[700],
                              ),

                              const SizedBox(width: 6),

                              Text(
                                "Sold by: ",

                                style:
                                    TextStyle(
                                  fontSize: 14,
                                  color:
                                      Colors.grey[700],
                                ),
                              ),

                              Expanded(
                                child: Text(
                                  widget.sellerName,

                                  style:
                                      const TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // SHIPPING DETAILS
              // =================================================

              const Text(
                "Shipping Details",

                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // -------------------------------------------------
              // FULL NAME
              // -------------------------------------------------

              TextFormField(

                controller:
                    _nameController,

                decoration:
                    const InputDecoration(
                  labelText: "Full Name",
                  border:
                      OutlineInputBorder(),
                ),

                validator: (value) {

                  if (value == null ||
                      value.trim().isEmpty) {

                    return "Enter your name";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------
              // ADDRESS
              // -------------------------------------------------

              TextFormField(

                controller:
                    _addressController,

                maxLines: 2,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Shipping Address",
                  border:
                      OutlineInputBorder(),
                ),

                validator: (value) {

                  if (value == null ||
                      value.trim().isEmpty) {

                    return "Enter your address";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // -------------------------------------------------
              // PHONE
              // -------------------------------------------------

              TextFormField(

                controller:
                    _phoneController,

                decoration:
                    const InputDecoration(
                  labelText:
                      "Phone Number",
                  border:
                      OutlineInputBorder(),
                ),

                keyboardType:
                    TextInputType.phone,

                validator: (value) {

                  if (value == null ||
                      value.trim().isEmpty) {

                    return "Enter your phone";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // =================================================
              // PAYMENT METHOD
              // =================================================

              const Text(
                "Payment Method",

                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              // -------------------------------------------------
              // COD
              // -------------------------------------------------

              RadioListTile<String>(

                title:
                    const Text(
                  "Cash on Delivery (COD)",
                ),

                value: "cod",

                groupValue:
                    _selectedPayment,

                onChanged: (value) {

                  setState(() {

                    _selectedPayment =
                        value!;
                  });
                },
              ),

              // -------------------------------------------------
              // RAZORPAY
              // -------------------------------------------------

              RadioListTile<String>(

                title:
                    const Text(
                  "Card/UPI (Razorpay)",
                ),

                value: "online",

                groupValue:
                    _selectedPayment,

                onChanged: (value) {

                  setState(() {

                    _selectedPayment =
                        value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // =================================================
              // ORDER SUMMARY
              // =================================================

              const Divider(
                thickness: 1,
              ),

              const Text(
                "Order Summary",

                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              _buildSummaryRow(
                "Item Price",
                price,
              ),

              _buildSummaryRow(
                "Delivery Charge",
                deliveryCharge,
              ),

              _buildSummaryRow(
                "Platform Fee",
                platformFee,
              ),

              const Divider(
                thickness: 1,
              ),

              _buildSummaryRow(
                "Total",
                total,
                isBold: true,
              ),
            ],
          ),
        ),
      ),

      // =======================================================
      // BOTTOM PAY BUTTON
      // =======================================================

      bottomNavigationBar:

          Padding(
        padding:
            const EdgeInsets.all(16),

        child: ElevatedButton(

          style:
              ElevatedButton.styleFrom(

            backgroundColor:
                const Color.fromARGB(
              255,
              222,
              128,
              47,
            ),

            padding:
                const EdgeInsets.symmetric(
              vertical: 14,
            ),

            textStyle:
                const TextStyle(
              fontSize: 16,
            ),
          ),

          onPressed:
              _confirmOrder,

          child: Text(

            "Pay ₹$total",

            style:
                const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ORDER SUMMARY ROW
  // =========================================================

  Widget _buildSummaryRow(
    String label,
    int amount, {
    bool isBold = false,
  }) {

    return Padding(

      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),

      child: Row(

        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [

          Text(
            label,

            style: TextStyle(
              fontSize: 16,

              fontWeight:
                  isBold
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),

          Text(
            "₹$amount",

            style: TextStyle(
              fontSize: 16,

              fontWeight:
                  isBold
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}