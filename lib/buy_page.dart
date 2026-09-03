import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:proto_app/confirm_page.dart';
import 'package:proto_app/product_detail_page.dart';

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

class _BuyPageState extends State<BuyPage> with SingleTickerProviderStateMixin {
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
  // CAMPAIGN MARQUEE
  // =========================================================

  late final AnimationController _campaignAnimationController;

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeCampaignsStream() {
    return FirebaseFirestore.instance
        .collection('campaigns')
        .where('enabled', isEqualTo: true)
        .snapshots();
  }

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

    _campaignAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

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
    _campaignAnimationController.dispose();
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
            "sellerNotification": true,
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
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final total = subtotal + deliveryCharge + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),

      // =========================================================
      // APP BAR
      // =========================================================

      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        toolbarHeight: 74,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Checkout",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Almost there! Review and place your order.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),

      // =========================================================
      // BODY
      // =========================================================

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 105),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =======================================================
              // FULL-WIDTH CONTINUOUS CAMPAIGN STRIP
              // =======================================================

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _activeCampaignsStream(),
                builder: (context, campaignSnapshot) {
                  final docs = campaignSnapshot.hasData
                      ? campaignSnapshot.data!.docs.where((doc) {
                          final data = doc.data();
                          return data['enabled'] == true &&
                              (data['status'] ?? '').toString() == 'Active';
                        }).toList()
                      : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  if (docs.isEmpty) {
                    return const SizedBox(height: 10);
                  }

                  return _buildCampaignMarquee(docs);
                },
              ),

              // =====================================================
              // MAIN CHECKOUT CONTENT
              // =====================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // YOUR ITEMS
                    // =================================================

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Items (${_items.length})",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF292329),
                          ),
                        ),
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 21,
                          color: primaryOrange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    ..._items.map((item) => _buildProductCard(item)),

                    const SizedBox(height: 18),

                    // =================================================
                    // SHIPPING DETAILS
                    // =================================================

                    Row(
                      children: [
                        const Text(
                          "Shipping Details",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF292329),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 19,
                          color: primaryOrange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      "We'll deliver to the address below",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF1E4D8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.035),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildNameField(),
                          const SizedBox(height: 9),
                          _buildAddressField(),
                          const SizedBox(height: 9),
                          _buildPhoneField(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // DELIVERY ASSURANCE
                    // =================================================

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8EC),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFE6EBD8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5E5),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.local_shipping_outlined,
                              color: Color(0xFF3C9251),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Fast & Reliable Delivery",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF292329),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Your order will be delivered to your doorstep safely.",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF696969),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF3C9251),
                            size: 26,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // PAYMENT
                    // =================================================

                    _buildSectionTitle("Payment Method"),

                    const SizedBox(height: 9),

                    _buildPaymentOption(
                      title: "Cash on Delivery",
                      subtitle: "Pay when your order arrives",
                      value: "cod",
                      icon: Icons.payments_outlined,
                    ),

                    const SizedBox(height: 9),

                    _buildPaymentOption(
                      title: "Card / UPI",
                      subtitle: "Secure payment through Razorpay",
                      value: "online",
                      icon: Icons.account_balance_wallet_outlined,
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // ORDER SUMMARY
                    // =================================================

                    _buildSectionTitle("Order Summary"),

                    const SizedBox(height: 9),

                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: const Color(0xFFEDE7E2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.035),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow("Item Total", subtotal),
                          _buildSummaryRow("Delivery Charge", deliveryCharge),
                          _buildSummaryRow("Platform Fee", platformFee),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Divider(
                              color: Colors.grey.shade300,
                              height: 1,
                            ),
                          ),
                          _buildSummaryRow(
                            "Total Amount",
                            total,
                            isBold: true,
                          ),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Inclusive of all charges",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // =========================================================
      // BOTTOM PLACE ORDER
      // =========================================================

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessingOrder ? null : _confirmOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    disabledBackgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isProcessingOrder
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedPayment == "cod"
                                  ? "Place Order • ₹$total"
                                  : "Pay ₹$total",
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 5),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: Color(0xFF4D8D56),
                  ),
                  SizedBox(width: 5),
                  Text(
                    "Secure payments. 100% safe.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CAMPAIGN MARQUEE
  // =========================================================

  Widget _buildCampaignMarquee(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> campaignDocs,
) {
  final screenWidth = MediaQuery.of(context).size.width;

  // No campaigns → don't show the campaign area.
  if (campaignDocs.isEmpty) {
    return const SizedBox.shrink();
  }

  // One campaign → keep it static.
  if (campaignDocs.length == 1) {
    return SizedBox(
      width: screenWidth,
      height: 126,
      child: ClipRect(
        child: _buildCompactCampaignCard(
          campaignDocs.first.data(),
        ),
      ),
    );
  }

  final cardWidth = screenWidth;
  final sequenceWidth = cardWidth * campaignDocs.length;

  return SizedBox(
    width: screenWidth,
    height: 126,
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _campaignAnimationController,
        builder: (context, child) {
          final progress = _campaignAnimationController.value;

          final offsetX =
              -sequenceWidth + (sequenceWidth * progress);

          return Transform.translate(
            offset: Offset(offsetX, 0),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: SizedBox(
                width: sequenceWidth * 2,
                height: 126,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int copy = 0; copy < 2; copy++)
                      for (final doc in campaignDocs)
                        SizedBox(
                          width: cardWidth,
                          height: 126,
                          child: _buildCompactCampaignCard(
                            doc.data(),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
  // =========================================================
  // COMPACT CAMPAIGN CARD
  // =========================================================

  Widget _buildCompactCampaignCard(Map<String, dynamic> data) {
    final productId = (data['productId'] ?? '').toString();
    final name = (data['name'] ?? 'Special Offer').toString();
    final message = (data['message'] ?? '').toString();
    final offer = (data['offer'] ?? '').toString();
    final imageUrl = (data['productImageUrl'] ?? '').toString();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: productId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .get(),
      builder: (context, snapshot) {
        final product = snapshot.data?.data();

        return GestureDetector(
          onTap: () {
            if (productId.isEmpty || product == null) return;

            final productTitle = (product["title"] ?? "").toString();
            final productDescription =
                (product["description"] ?? "").toString();
            final productPrice = (product["price"] ?? "0").toString();
            final productImage = (product["imageUrl"] ?? "").toString();
            final sellerName =
                (product["sellerName"] ?? "").toString().trim();
            final sellerId = (product["sellerId"] ?? "").toString();

            ProductDetailPage.open(context, {
              "productId": productId,
              "title": productTitle,
              "description": productDescription,
              "price": productPrice,
              "imageUrl": productImage,
              "sellerName":
                  sellerName.isNotEmpty ? sellerName : "Local Artisan",
              "sellerId": sellerId,
            });
          },
          child: Container(
            width: double.infinity,
            height: 126,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFFF4E6),
                  Color(0xFFFFE4CA),
                ],
              ),
              border: const Border(
                top: BorderSide(
                  color: Color(0xFFF0C994),
                  width: 1.1,
                ),
                bottom: BorderSide(
                  color: Color(0xFFF0C994),
                  width: 1.1,
                ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  flex: 58,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      15,
                      10,
                      7,
                      9,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryOrange,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                color: Colors.white,
                                size: 11,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SPECIAL OFFER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF292329),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.2,
                              height: 1.18,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (offer.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDDBB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              offer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: darkOrange,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 42,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFFFE8CF),
                            child: const Icon(
                              Icons.local_offer_outlined,
                              color: darkOrange,
                              size: 34,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFFFE8CF),
                          child: const Icon(
                            Icons.local_offer_outlined,
                            color: darkOrange,
                            size: 34,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // SHIPPING FIELD HELPERS
  // =========================================================

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF292329),
      ),
      decoration: _checkoutInputDecoration(
        label: "Full Name",
        icon: Icons.person_outline,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Enter your name";
        }
        if (value.trim().length < 2) {
          return "Enter a valid name";
        }
        return null;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF292329),
      ),
      decoration: _checkoutInputDecoration(
        label: "Shipping Address",
        icon: Icons.location_on_outlined,
        alignLabelWithHint: true,
        iconTopPadding: 7,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Enter your address";
        }
        if (value.trim().length < 10) {
          return "Enter a complete address";
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF292329),
      ),
      decoration: _checkoutInputDecoration(
        label: "Phone Number",
        icon: Icons.phone_outlined,
        prefixText: "+91  ",
      ).copyWith(counterText: ""),
      validator: (value) {
        final phone = value?.trim() ?? "";
        if (phone.isEmpty) {
          return "Enter your phone number";
        }
        if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
          return "Enter a valid 10-digit phone number";
        }
        return null;
      },
    );
  }

  InputDecoration _checkoutInputDecoration({
    required String label,
    required IconData icon,
    bool alignLabelWithHint = false,
    double iconTopPadding = 0,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 13.5,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: primaryOrange,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(top: iconTopPadding),
        child: Icon(
          icon,
          size: 21,
          color: const Color(0xFF4E4A4E),
        ),
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: Color(0xFF4E4A4E),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      alignLabelWithHint: alignLabelWithHint,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      filled: true,
      fillColor: const Color(0xFFFFFEFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFF0DDD0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFF0DDD0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: primaryOrange,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFD85C52),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFD85C52),
          width: 1.3,
        ),
      ),
      errorStyle: const TextStyle(
        fontSize: 10,
        height: 1.1,
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: Color(0xFF292329),
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
    final selected = _selectedPayment == value;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: _isProcessingOrder
          ? null
          : () {
              setState(() {
                _selectedPayment = value;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? primaryOrange.withOpacity(0.075)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? primaryOrange
                : const Color(0xFFE6E2DF),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? primaryOrange
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : Colors.grey.shade700,
                size: 23,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF292329),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPayment,
              activeColor: primaryOrange,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
              onChanged: _isProcessingOrder
                  ? null
                  : (newValue) {
                      if (newValue == null) return;
                      setState(() {
                        _selectedPayment = newValue;
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

  Widget _buildProductCard(Map<String, dynamic> item) {
    final title = (item["title"] ?? "").toString();
    final image = (item["imageUrl"] ?? "").toString();
    final seller =
        (item["sellerName"] ?? "Local Artisan").toString();
    final price = _toInt(item["price"]);
    final originalPrice = _toInt(item["originalPrice"]);
    final quantity =
        _toInt(item["quantity"]) > 0
            ? _toInt(item["quantity"])
            : 1;
    final itemTotal = price * quantity;

    final campaignOffer =
        (item["campaignOffer"] ?? "").toString().trim();
    final hasCampaign =
        campaignOffer.isNotEmpty && originalPrice > price;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDE6E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _imagePlaceholder();
                    },
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? "Product" : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    height: 1.08,
                    color: Color(0xFF292329),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Sold by: $seller",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 5),
                if (hasCampaign) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primaryOrange.withOpacity(.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      campaignOffer,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: darkOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (hasCampaign) ...[
                            Text(
                              "₹$originalPrice",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                decoration:
                                    TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              "₹$price × $quantity",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "₹$itemTotal",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: darkOrange,
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
      width: 86,
      height: 86,
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade400,
        size: 28,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight:
                  isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold
                  ? const Color(0xFF292329)
                  : Colors.grey.shade800,
            ),
          ),
          Text(
            "₹$amount",
            style: TextStyle(
              fontSize: isBold ? 18 : 13,
              fontWeight:
                  isBold ? FontWeight.w900 : FontWeight.w600,
              color: isBold
                  ? primaryOrange
                  : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
