import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:proto_app/confirm_page.dart';

class BuyPage extends StatefulWidget {
  // =========================================================
  // SINGLE PRODUCT
  // =========================================================

  final String productId;
  final String productName;
  final String productPrice;
  final String productImage;

  // Original product price before campaign
  final String originalProductPrice;

  // Campaign information
  final String campaignId;
  final String campaignOffer;

  // =========================================================
  // SELLER
  // =========================================================

  final String sellerName;
  final String sellerId;

  // =========================================================
  // CART
  // =========================================================

  final List<Map<String, dynamic>>? cartItems;

  // =========================================================
  // SINGLE PRODUCT CONSTRUCTOR
  // =========================================================

  const BuyPage({
    super.key,
    this.productId = "",
    required this.productName,
    required this.productPrice,
    required this.productImage,
    required this.sellerName,
    required this.sellerId,
    this.originalProductPrice = "",
    this.campaignId = "",
    this.campaignOffer = "",
    this.cartItems,
  });

  // =========================================================
  // CART CONSTRUCTOR
  // =========================================================

  factory BuyPage.fromCart({
    required List<Map<String, dynamic>> cartItems,
  }) {
    return BuyPage(
      productId: "",
      productName: "",
      productPrice: "0",
      productImage: "",
      sellerName: "",
      sellerId: "",
      originalProductPrice: "",
      campaignId: "",
      campaignOffer: "",
      cartItems: cartItems,
    );
  }

  @override
  State<BuyPage> createState() =>
      _BuyPageState();
}

class _BuyPageState extends State<BuyPage> {
  // =========================================================
  // FORM
  // =========================================================

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _nameController =
      TextEditingController();

  final TextEditingController
      _addressController =
      TextEditingController();

  final TextEditingController
      _phoneController =
      TextEditingController();

  // =========================================================
  // PAYMENT
  // =========================================================

  String _selectedPayment = "cod";

  late Razorpay _razorpay;

  bool _isProcessingOrder = false;

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryOrange =
      Color.fromARGB(255, 214, 112, 22);

  static const Color darkOrange =
      Color.fromARGB(255, 141, 83, 20);

  // =========================================================
  // CHARGES
  // =========================================================

  static const int deliveryCharge = 20;
  static const int platformFee = 1;

  // =========================================================
  // IS CART CHECKOUT
  // =========================================================

  bool get _isCartCheckout =>
      widget.cartItems != null;

  // =========================================================
  // CHECKOUT ITEMS OVERRIDE
  // =========================================================

  List<Map<String, dynamic>>?
      _validatedItems;

  // =========================================================
  // SAFE INT CONVERSION
  // =========================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(
          value
                  ?.toString()
                  .replaceAll(',', '')
                  .trim() ??
              "",
        ) ??
        0;
  }

  // =========================================================
  // SAFE DOUBLE CONVERSION
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value
                  ?.toString()
                  .replaceAll(',', '')
                  .trim() ??
              "",
        ) ??
        0;
  }

  // =========================================================
  // FORMAT PRICE
  // =========================================================

  String _formatPrice(double value) {
    final rounded = value.round();

    return rounded.toString();
  }

  // =========================================================
  // CHECKOUT ITEMS
  // =========================================================

  List<Map<String, dynamic>> get _items {
    // =======================================================
    // USE VALIDATED ITEMS AFTER PRICE VERIFICATION
    // =======================================================

    if (_validatedItems != null) {
      return _validatedItems!;
    }

    // =======================================================
    // CART CHECKOUT
    // =======================================================

    if (_isCartCheckout) {
      return widget.cartItems!.map((item) {
        final quantity =
            _toInt(item["quantity"]);

        return {
          "cartId":
              (item["cartId"] ?? "")
                  .toString(),

          "productId":
              (item["productId"] ?? "")
                  .toString(),

          "title":
              (item["title"] ?? "")
                  .toString(),

          "description":
              (item["description"] ?? "")
                  .toString(),

          // Actual price customer pays
          "price":
              (item["price"] ?? "0")
                  .toString(),

          // Original price before campaign
          "originalPrice":
              (item["originalPrice"] ??
                      item["price"] ??
                      "0")
                  .toString(),

          // Campaign information
          "campaignId":
              (item["campaignId"] ?? "")
                  .toString(),

          "campaignOffer":
              (item["campaignOffer"] ?? "")
                  .toString(),

          "imageUrl":
              (item["imageUrl"] ?? "")
                  .toString(),

          "sellerName":
              (item["sellerName"] ??
                      "Local Artisan")
                  .toString(),

          "sellerId":
              (item["sellerId"] ?? "")
                  .toString(),

          "quantity":
              quantity > 0 ? quantity : 1,
        };
      }).toList();
    }

    // =======================================================
    // SINGLE PRODUCT
    // =======================================================

    return [
      {
        "cartId": "",

        "productId":
            widget.productId,

        "title":
            widget.productName,

        "description": "",

        // Actual price customer pays
        "price":
            widget.productPrice,

        // Original price before campaign
        "originalPrice":
            widget.originalProductPrice
                    .isNotEmpty
                ? widget.originalProductPrice
                : widget.productPrice,

        // Campaign information
        "campaignId":
            widget.campaignId,

        "campaignOffer":
            widget.campaignOffer,

        "imageUrl":
            widget.productImage,

        "sellerName":
            widget.sellerName,

        "sellerId":
            widget.sellerId,

        "quantity": 1,
      },
    ];
  }

  // =========================================================
  // INIT STATE
  // =========================================================

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

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _razorpay.clear();

    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // =========================================================
  // PAYMENT SUCCESS
  // =========================================================

  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) {
    _saveOrders(
      status: "done",
      payId: response.paymentId,
    );
  }

  // =========================================================
  // PAYMENT FAILURE
  // =========================================================

  void _handlePaymentError(
    PaymentFailureResponse response,
  ) {
    if (!mounted) return;

    setState(() {
      _isProcessingOrder = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Payment failed: "
          "${response.message ?? "Please try again."}",
        ),
        backgroundColor:
            Colors.red.shade700,
      ),
    );
  }

  // =========================================================
  // EXTERNAL WALLET
  // =========================================================

  void _handleExternalWallet(
    ExternalWalletResponse response,
  ) {
    if (!mounted) return;

    setState(() {
      _isProcessingOrder = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "External wallet selected: "
          "${response.walletName ?? "Wallet"}",
        ),
      ),
    );
  }

  // =========================================================
  // SAVE ORDERS
  // =========================================================

  Future<void> _saveOrders({
    required String status,
    String? payId,
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        _isProcessingOrder = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Please log in before placing an order.",
          ),
        ),
      );

      return;
    }

    try {
      final firestore =
          FirebaseFirestore.instance;

      final batch = firestore.batch();

      // =====================================================
      // CREATE ONE ORDER PER PRODUCT
      // =====================================================

      for (final item in _items) {
        final orderRef =
            firestore.collection("orders").doc();

        final price =
            _toInt(item["price"]);

        final quantity =
            _toInt(item["quantity"]) > 0
                ? _toInt(item["quantity"])
                : 1;

        final itemTotal =
            price * quantity;

        batch.set(
          orderRef,
          {
            // =================================================
            // PRODUCT
            // =================================================

            "productId":
                item["productId"] ?? "",

            "productName":
                item["title"] ?? "",

            // Actual price paid
            "productPrice":
                item["price"] ?? "0",

            // Original price before campaign
            "originalProductPrice":
                item["originalPrice"] ??
                    item["price"] ??
                    "0",

            // Campaign information
            "campaignId":
                item["campaignId"] ?? "",

            "campaignOffer":
                item["campaignOffer"] ?? "",

            "productImage":
                item["imageUrl"] ?? "",

            "quantity": quantity,

            "itemTotal": itemTotal,

            // =================================================
            // SELLER
            // =================================================

            "sellerId":
                item["sellerId"] ?? "",

            "sellerName":
                item["sellerName"] ??
                    "Local Artisan",

            // =================================================
            // CUSTOMER
            // =================================================

            "userId":
                currentUser.uid,

            "email":
                currentUser.email ?? "",

            "fullName":
                _nameController.text.trim(),

            "address":
                _addressController.text.trim(),

            "phone":
                _phoneController.text.trim(),

            // =================================================
            // PAYMENT
            // =================================================

            "paymentMethod":
                _selectedPayment,

            "paymentStatus":
                status,

            "paymentId":
                payId ?? "",

            // =================================================
            // ORDER STATUS
            // =================================================

            "orderStatus":
                status == "done"
                    ? "confirmed"
                    : "pending",

            // =================================================
            // TIMESTAMP
            // =================================================

            "timestamp":
                FieldValue.serverTimestamp(),
          },
        );
      }

      // =====================================================
      // COMMIT ORDERS
      // =====================================================

      await batch.commit();

      // =====================================================
      // CLEAR ONLY CHECKED-OUT CART ITEMS
      // =====================================================

      if (_isCartCheckout) {
        final cartBatch =
            firestore.batch();

        for (final item in _items) {
          final cartId =
              (item["cartId"] ?? "")
                  .toString();

          if (cartId.isNotEmpty) {
            final cartRef = firestore
                .collection("users")
                .doc(currentUser.uid)
                .collection("cart")
                .doc(cartId);

            cartBatch.delete(cartRef);
          }
        }

        await cartBatch.commit();
      }

      // =====================================================
      // FINISH
      // =====================================================

      if (!mounted) return;

      setState(() {
        _isProcessingOrder = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const ConfirmPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessingOrder = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text("Order save failed: $e"),
          backgroundColor:
              Colors.red.shade700,
        ),
      );
    }
  }

  // =========================================================
  // START ONLINE PAYMENT
  // =========================================================

  void _startOnlinePayment(
    int amount,
  ) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    final options = {
      "key":
          "rzp_test_soO0DVUQSdQ81X",

      // Razorpay expects paise
      "amount": amount * 100,

      "name": "Karigari",

      "description":
          _isCartCheckout
              ? "Karigari Cart Checkout"
              : "Payment for ${widget.productName}",

      "prefill": {
        "contact":
            _phoneController.text.trim(),
        "email":
            currentUser?.email ?? "",
      },

      "theme": {
        "color": "#D67016",
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessingOrder = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Unable to open payment: $e",
          ),
          backgroundColor:
              Colors.red.shade700,
        ),
      );
    }
  }

  // =========================================================
  // GET CAMPAIGN DISCOUNT
  // =========================================================

  double _getDiscountPercentage(
    Map<String, dynamic> campaign,
  ) {
    final offer =
        (campaign['offer'] ?? "")
            .toString()
            .trim();

    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*%',
    ).firstMatch(offer);

    return double.tryParse(
          match?.group(1) ?? "",
        ) ??
        0;
  }

  // =========================================================
  // GET CURRENT ACTIVE CAMPAIGN PRICE
  // =========================================================

  Future<double?> _getCurrentCampaignPrice(
    String productId,
    double originalPrice,
  ) async {
    if (productId.isEmpty) {
      return null;
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection('campaigns')
            .where(
              'enabled',
              isEqualTo: true,
            )
            .get();

    for (final doc
        in snapshot.docs) {
      final data = doc.data();

      final status =
          (data['status'] ?? "")
              .toString();

      final campaignProductId =
          (data['productId'] ?? "")
              .toString();

      if (status == 'Active' &&
          campaignProductId ==
              productId) {
        final discount =
            _getDiscountPercentage(data);

        if (discount > 0) {
          final campaignPrice =
              originalPrice *
              (1 - discount / 100);

          // Same rounding used everywhere.
          return campaignPrice
              .roundToDouble();
        }
      }
    }

    return null;
  }

  // =========================================================
  // CONFIRM ORDER
  // =========================================================

  Future<void> _confirmOrder() async {
    if (_isProcessingOrder) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "There are no items to purchase.",
          ),
        ),
      );

      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    // =======================================================
    // VALIDATE CURRENT PRICES
    // =======================================================

    try {
      final updatedItems =
          <Map<String, dynamic>>[];

      bool priceChanged = false;

      for (final originalItem
          in _items) {
        final item =
            Map<String, dynamic>.from(
          originalItem,
        );

        final productId =
            (item["productId"] ?? "")
                .toString();

        final currentCheckoutPrice =
            _toDouble(item["price"]);

        // ---------------------------------------------------
        // FETCH CURRENT PRODUCT
        // ---------------------------------------------------

        double originalPrice =
            _toDouble(
          item["originalPrice"],
        );

        if (productId.isNotEmpty) {
          final productDoc =
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .get();

          if (productDoc.exists) {
            final productData =
                productDoc.data();

            final databasePrice =
                _toDouble(
              productData?['price'],
            );

            if (databasePrice > 0) {
              originalPrice =
                  databasePrice;
            }
          }
        }

        // ---------------------------------------------------
        // CHECK CURRENT ACTIVE CAMPAIGN
        // ---------------------------------------------------

        final campaignPrice =
            await _getCurrentCampaignPrice(
          productId,
          originalPrice,
        );

        final effectivePrice =
            campaignPrice ??
                originalPrice;

        // ---------------------------------------------------
        // COMPARE WITH CHECKOUT PRICE
        // ---------------------------------------------------

        if (effectivePrice.round() !=
            currentCheckoutPrice
                .round()) {
          priceChanged = true;
        }

        // ---------------------------------------------------
        // UPDATE CAMPAIGN INFORMATION
        // ---------------------------------------------------

        if (campaignPrice != null) {
          final campaignSnapshot =
              await FirebaseFirestore
                  .instance
                  .collection(
                      'campaigns')
                  .where(
                    'enabled',
                    isEqualTo: true,
                  )
                  .get();

          for (final doc
              in campaignSnapshot.docs) {
            final data = doc.data();

            final status =
                (data['status'] ??
                        "")
                    .toString();

            final campaignProductId =
                (data['productId'] ??
                        "")
                    .toString();

            if (status == 'Active' &&
                campaignProductId ==
                    productId) {
              item["campaignId"] =
                  doc.id;

              item["campaignOffer"] =
                  (data['offer'] ?? "")
                      .toString();

              break;
            }
          }
        } else {
          // Campaign no longer active.
          item["campaignId"] = "";
          item["campaignOffer"] = "";
        }

        item["price"] =
            _formatPrice(
          effectivePrice,
        );

        item["originalPrice"] =
            _formatPrice(
          originalPrice,
        );

        updatedItems.add(item);
      }

      // =====================================================
      // CAMPAIGN EXPIRED / PRICE CHANGED
      // =====================================================

      if (priceChanged) {
        if (!mounted) return;

        setState(() {
          _isProcessingOrder = false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "A campaign has ended or changed. "
              "The price is no longer available. "
              "Please review your cart.",
            ),
            duration:
                Duration(seconds: 4),
          ),
        );

        return;
      }

      // =====================================================
      // SAVE VALIDATED ITEMS
      // =====================================================

      if (!mounted) return;

      setState(() {
        _validatedItems =
            updatedItems;
      });

      // =====================================================
      // CALCULATE TOTAL
      // =====================================================

      int subtotal = 0;

      for (final item
          in updatedItems) {
        final price =
            _toInt(item["price"]);

        final quantity =
            _toInt(item["quantity"]) > 0
                ? _toInt(
                    item["quantity"],
                  )
                : 1;

        subtotal +=
            price * quantity;
      }

      final total =
          subtotal +
              deliveryCharge +
              platformFee;

      // =====================================================
      // COD
      // =====================================================

      if (_selectedPayment == "cod") {
        await _saveOrders(
          status: "pending",
        );

        return;
      }

      // =====================================================
      // ONLINE PAYMENT
      // =====================================================

      _startOnlinePayment(total);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessingOrder = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Could not verify prices: $e",
          ),
          backgroundColor:
              Colors.red.shade700,
        ),
      );
    }
  }

  // =========================================================
  // CALCULATE SUBTOTAL
  // =========================================================

  int _calculateSubtotal() {
    int subtotal = 0;

    for (final item in _items) {
      final price =
          _toInt(item["price"]);

      final quantity =
          _toInt(item["quantity"]) > 0
              ? _toInt(
                  item["quantity"],
                )
              : 1;

      subtotal +=
          price * quantity;
    }

    return subtotal;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final subtotal =
        _calculateSubtotal();

    final total =
        subtotal +
            deliveryCharge +
            platformFee;

    return Scaffold(
      backgroundColor:
          Colors.grey.shade50,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            primaryOrange,
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            110,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =================================================
              // YOUR ITEMS
              // =================================================

              const Text(
                "Your Items",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              ..._items.map(
                (item) =>
                    _buildProductCard(item),
              ),

              const SizedBox(
                  height: 22),

              // =================================================
              // SHIPPING
              // =================================================

              _buildSectionTitle(
                "Shipping Details",
              ),

              const SizedBox(
                  height: 12),

              // =================================================
              // NAME
              // =================================================

              TextFormField(
                controller:
                    _nameController,
                textCapitalization:
                    TextCapitalization
                        .words,
                decoration:
                    InputDecoration(
                  labelText:
                      "Full Name",
                  prefixIcon:
                      const Icon(
                    Icons.person_outline,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      Colors.white,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return "Enter your name";
                  }

                  if (value
                          .trim()
                          .length <
                      2) {
                    return "Enter a valid name";
                  }

                  return null;
                },
              ),

              const SizedBox(
                  height: 12),

              // =================================================
              // ADDRESS
              // =================================================

              TextFormField(
                controller:
                    _addressController,
                maxLines: 3,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    InputDecoration(
                  labelText:
                      "Shipping Address",
                  prefixIcon:
                      const Padding(
                    padding:
                        EdgeInsets.only(
                      bottom: 45,
                    ),
                    child: Icon(
                      Icons
                          .location_on_outlined,
                    ),
                  ),
                  alignLabelWithHint:
                      true,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      Colors.white,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return "Enter your address";
                  }

                  if (value
                          .trim()
                          .length <
                      10) {
                    return "Enter a complete address";
                  }

                  return null;
                },
              ),

              const SizedBox(
                  height: 12),

              // =================================================
              // PHONE
              // =================================================

              TextFormField(
                controller:
                    _phoneController,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                decoration:
                    InputDecoration(
                  labelText:
                      "Phone Number",
                  prefixIcon:
                      const Icon(
                    Icons.phone_outlined,
                  ),
                  counterText: "",
                  prefixText:
                      "+91  ",
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      Colors.white,
                ),
                validator: (value) {
                  final phone =
                      value?.trim() ??
                          "";

                  if (phone.isEmpty) {
                    return "Enter your phone number";
                  }

                  if (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(phone)) {
                    return "Enter a valid 10-digit phone number";
                  }

                  return null;
                },
              ),

              const SizedBox(
                  height: 24),

              // =================================================
              // PAYMENT
              // =================================================

              _buildSectionTitle(
                "Payment Method",
              ),

              const SizedBox(
                  height: 10),

              _buildPaymentOption(
                title:
                    "Cash on Delivery",
                subtitle:
                    "Pay when your order arrives",
                value: "cod",
                icon: Icons
                    .payments_outlined,
              ),

              const SizedBox(
                  height: 10),

              _buildPaymentOption(
                title:
                    "Card / UPI",
                subtitle:
                    "Secure payment through Razorpay",
                value: "online",
                icon: Icons
                    .account_balance_wallet_outlined,
              ),

              const SizedBox(
                  height: 24),

              // =================================================
              // ORDER SUMMARY
              // =================================================

              _buildSectionTitle(
                "Order Summary",
              ),

              const SizedBox(
                  height: 12),

              Container(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      "Item Total",
                      subtotal,
                    ),

                    _buildSummaryRow(
                      "Delivery Charge",
                      deliveryCharge,
                    ),

                    _buildSummaryRow(
                      "Platform Fee",
                      platformFee,
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 10,
                      ),
                      child: Divider(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    _buildSummaryRow(
                      "Total",
                      total,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // =====================================================
      // BOTTOM PAY BUTTON
      // =====================================================

      bottomNavigationBar:
          SafeArea(
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            12,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(0.08),
                blurRadius: 14,
                offset:
                    const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child:
                ElevatedButton(
              onPressed:
                  _isProcessingOrder
                      ? null
                      : _confirmOrder,
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    darkOrange,
                disabledBackgroundColor:
                    Colors.grey.shade400,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child:
                  _isProcessingOrder
                      ? const SizedBox(
                          height: 23,
                          width: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2.5,
                            color:
                                Colors.white,
                          ),
                        )
                      : Text(
                          _selectedPayment ==
                                  "cod"
                              ? "Place Order • ₹$total"
                              : "Pay ₹$total",
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(
    String title,
  ) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // =========================================================
  // PAYMENT OPTION
  // =========================================================

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final selected =
        _selectedPayment == value;

    return InkWell(
      borderRadius:
          BorderRadius.circular(14),
      onTap: _isProcessingOrder
          ? null
          : () {
              setState(() {
                _selectedPayment =
                    value;
              });
            },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? primaryOrange
                  .withOpacity(0.08)
              : Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primaryOrange
                : Colors.grey.shade300,
            width:
                selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color: selected
                    ? primaryOrange
                    : Colors
                        .grey.shade100,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
            ),

            const SizedBox(
                width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(
                      height: 3),

                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            Radio<String>(
              value: value,
              groupValue:
                  _selectedPayment,
              activeColor:
                  primaryOrange,
              onChanged:
                  _isProcessingOrder
                      ? null
                      : (newValue) {
                          if (newValue ==
                              null) {
                            return;
                          }

                          setState(() {
                            _selectedPayment =
                                newValue;
                          });
                        },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    Map<String, dynamic> item,
  ) {
    final title =
        (item["title"] ?? "")
            .toString();

    final image =
        (item["imageUrl"] ?? "")
            .toString();

    final seller =
        (item["sellerName"] ??
                "Local Artisan")
            .toString();

    final price =
        _toInt(item["price"]);

    final originalPrice =
        _toInt(
      item["originalPrice"],
    );

    final quantity =
        _toInt(item["quantity"]) > 0
            ? _toInt(item["quantity"])
            : 1;

    final itemTotal =
        price * quantity;

    final campaignOffer =
        (item["campaignOffer"] ?? "")
            .toString()
            .trim();

    final hasCampaign =
        campaignOffer.isNotEmpty &&
            originalPrice > price;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(10),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================
          // IMAGE
          // ===================================================

          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _imagePlaceholder();
                    },
                  )
                : _imagePlaceholder(),
          ),

          const SizedBox(
              width: 12),

          // ===================================================
          // INFO
          // ===================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                // TITLE

                Text(
                  title.isEmpty
                      ? "Product"
                      : title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                    height: 4),

                // SELLER

                Text(
                  "Sold by: $seller",
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),

                const SizedBox(
                    height: 6),

                // =================================================
                // CAMPAIGN BADGE
                // =================================================

                if (hasCampaign) ...[
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color: primaryOrange
                          .withOpacity(
                        0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .local_offer_rounded,
                          size: 13,
                          color:
                              primaryOrange,
                        ),
                        const SizedBox(
                            width: 4),
                        Text(
                          campaignOffer,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                darkOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                      height: 6),
                ],

                // =================================================
                // PRICE
                // =================================================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (hasCampaign) ...[
                            Text(
                              "₹$originalPrice",
                              style:
                                  TextStyle(
                                fontSize: 12,
                                color: Colors
                                    .grey
                                    .shade500,
                                decoration:
                                    TextDecoration
                                        .lineThrough,
                              ),
                            ),
                            const SizedBox(
                                width: 7),
                          ],

                          Text(
                            "₹$price × $quantity",
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      "₹$itemTotal",
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            darkOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // IMAGE PLACEHOLDER
  // =========================================================

  Widget _imagePlaceholder() {
    return Container(
      width: 82,
      height: 82,
      color: Colors.grey.shade100,
      child: Icon(
        Icons
            .image_not_supported_outlined,
        color:
            Colors.grey.shade400,
        size: 30,
      ),
    );
  }

  // =========================================================
  // SUMMARY ROW
  // =========================================================

  Widget _buildSummaryRow(
    String label,
    int amount, {
    bool isBold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize:
                  isBold ? 17 : 15,
              fontWeight: isBold
                  ? FontWeight.bold
                  : FontWeight.normal,
              color:
                  Colors.grey.shade800,
            ),
          ),
          Text(
            "₹$amount",
            style: TextStyle(
              fontSize:
                  isBold ? 18 : 15,
              fontWeight: isBold
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isBold
                  ? darkOrange
                  : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}