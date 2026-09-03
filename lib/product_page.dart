import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:proto_app/buy_page.dart';
import 'package:proto_app/product_detail_page.dart';
import 'package:proto_app/add_to_cart_page.dart';
import 'package:proto_app/widgets/ai_assistant.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // =========================================================
  // SEARCH
  // =========================================================

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryOrange = Color.fromARGB(255, 214, 112, 22);

  static const Color darkOrange = Color.fromARGB(255, 141, 83, 20);

  static const Color cardBackground = Color.fromARGB(255, 249, 243, 251);

  // =========================================================
  // FIRESTORE
  // =========================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // HOME-PAGE CAROUSELS
  // =========================================================

  final PageController _campaignPageController = PageController();
  final PageController _listingPageController = PageController();

  Timer? _campaignTimer;
  Timer? _listingTimer;

  int _campaignIndex = 0;
  int _listingIndex = 0;

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    _campaignTimer?.cancel();
    _listingTimer?.cancel();
    _campaignPageController.dispose();
    _listingPageController.dispose();
    super.dispose();
  }

  // =========================================================
  // CURRENT USER
  // =========================================================

  String? get _userId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // =========================================================
  // CART REFERENCE
  // =========================================================

  CollectionReference<Map<String, dynamic>>? get _cartReference {
    final uid = _userId;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore.collection('users').doc(uid).collection('cart');
  }

  // =========================================================
  // OPEN AI ASSISTANT
  // =========================================================

  void _openAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      enableDrag: true,
      builder: (assistantContext) {
        return const AIAssistant();
      },
    );
  }

  // =========================================================
  // OPEN CART
  // =========================================================

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddToCartPage()),
    );
  }

  // =========================================================
  // ACTIVE CAMPAIGNS STREAM
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeCampaignsStream() {
    return _firestore
        .collection('campaigns')
        .where('enabled', isEqualTo: true)
        .snapshots();
  }

  // =========================================================
  // ACTIVE FEATURED LISTINGS STREAM
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeListingsStream() {
    return _firestore
        .collection('listing')
        .where('enabled', isEqualTo: true)
        .snapshots();
  }

  // =========================================================
  // PARSE PRICE
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0.0;
  }

  // =========================================================
  // SAFE INTEGER CONVERSION
  // =========================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        )?.round() ??
        0;
  }

  // =========================================================
  // GET DISCOUNT PERCENTAGE
  //
  // Example:
  // "20% off" -> 20
  // "10% off" -> 10
  // =========================================================

  double _getDiscountPercentage(Map<String, dynamic> campaign) {
    final offer = (campaign['offer'] ?? '').toString().trim();

    if (offer.isEmpty) {
      return 0;
    }

    final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(offer);

    if (match == null) {
      return 0;
    }

    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  // =========================================================
  // CALCULATE CAMPAIGN PRICE
  // =========================================================

  double _getCampaignPrice(double originalPrice, double discountPercentage) {
    if (originalPrice <= 0 || discountPercentage <= 0) {
      return originalPrice;
    }

    if (discountPercentage > 100) {
      return originalPrice;
    }

    final discounted = originalPrice * (1 - discountPercentage / 100);

    // Keep all prices consistent with the cart
    // and checkout, which use whole rupees.
    return discounted.roundToDouble();
  }

  // =========================================================
  // FORMAT PRICE
  // =========================================================

  String _formatPrice(double value) {
    final rounded = value.round();

    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
  }

  // =========================================================
  // FIND ACTIVE CAMPAIGN FOR PRODUCT
  // =========================================================

  Map<String, dynamic>? _campaignForProduct(
    String productId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> campaignDocs,
  ) {
    for (final doc in campaignDocs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();

      final campaignProductId = (data['productId'] ?? '').toString();

      if (status == 'Active' && campaignProductId == productId) {
        return {...data, 'campaignId': doc.id};
      }
    }

    return null;
  }

  // =========================================================
  // GET CURRENT CAMPAIGN DIRECTLY FROM FIRESTORE
  //
  // This is intentionally queried again when the user
  // presses Buy. That means the price used in the cart
  // is the latest price, not an old UI snapshot.
  // =========================================================

  Future<Map<String, dynamic>?> _getCurrentCampaign(String productId) async {
    if (productId.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _firestore
          .collection('campaigns')
          .where('enabled', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final status = (data['status'] ?? '').toString();

        final campaignProductId = (data['productId'] ?? '').toString();

        if (status == 'Active' && campaignProductId == productId) {
          return {...data, 'campaignId': doc.id};
        }
      }
    } catch (_) {
      // If campaign lookup fails, the product's
      // original price will be used.
    }

    return null;
  }

  // =========================================================
  // ADD PRODUCT TO CART
  //
  // IMPORTANT:
  // The effective campaign price is calculated here.
  //
  // If the product has an active campaign:
  //     cart price = discounted price
  //
  // If there is no campaign:
  //     cart price = original price
  //
  // The original price and campaign metadata are also
  // stored so AddToCartPage / BuyPage can display them.
  // =========================================================

  Future<bool> _addToCart(
    String productId,
    Map<String, dynamic> product, {
    bool openCartAfterAdding = false,
  }) async {
    final cart = _cartReference;

    if (cart == null) {
      _showMessage("Please log in to add items to cart.");
      return false;
    }

    final originalPrice = _toDouble(product['price']);

    // ---------------------------------------------------------
    // Get the latest campaign at click time
    // ---------------------------------------------------------

    final campaign = await _getCurrentCampaign(productId);

    double effectivePrice = originalPrice;

    String campaignId = '';
    String campaignOffer = '';

    if (campaign != null) {
      final discountPercentage = _getDiscountPercentage(campaign);

      if (discountPercentage > 0) {
        effectivePrice = _getCampaignPrice(originalPrice, discountPercentage);

        campaignId = (campaign['campaignId'] ?? '').toString();

        campaignOffer = (campaign['offer'] ?? '').toString();
      }
    }

    final cartItem = cart.doc(productId);

    try {
      final existing = await cartItem.get();

      if (existing.exists) {
        final existingData = existing.data() ?? {};

        final currentQuantity = _toInt(existingData['quantity']);

        // -----------------------------------------------------
        // Update price every time the user presses Buy.
        //
        // This is important because a campaign might have
        // started, ended, or changed since the item was
        // originally placed in the cart.
        // -----------------------------------------------------

        await cartItem.update({
          'price': _formatPrice(effectivePrice),
          'originalPrice': _formatPrice(originalPrice),
          'campaignId': campaignId,
          'campaignOffer': campaignOffer,
          'quantity': currentQuantity + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final sellerName = (product['sellerName'] ?? '').toString().trim();

        await cartItem.set({
          'productId': productId,

          'title': (product['title'] ?? '').toString(),

          'description': (product['description'] ?? '').toString(),

          // ---------------------------------------------------
          // EFFECTIVE PRICE
          //
          // This is what the buyer actually sees/pay for.
          // ---------------------------------------------------
          'price': _formatPrice(effectivePrice),

          // ---------------------------------------------------
          // ORIGINAL PRICE
          // ---------------------------------------------------
          'originalPrice': _formatPrice(originalPrice),

          // ---------------------------------------------------
          // CAMPAIGN INFORMATION
          // ---------------------------------------------------
          'campaignId': campaignId,

          'campaignOffer': campaignOffer,

          'imageUrl': (product['imageUrl'] ?? '').toString(),

          'sellerId': (product['sellerId'] ?? '').toString(),

          'sellerName': sellerName.isNotEmpty ? sellerName : 'Local Artisan',

          'quantity': 1,

          'addedAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _showAddedToCartDialog(
        productTitle: (product['title'] ?? 'Handmade item').toString(),
        price: _formatPrice(effectivePrice),
        offer: campaignOffer.isNotEmpty ? campaignOffer : null,
      );

      // Kept for compatibility with the existing caller.
      if (openCartAfterAdding && mounted) {
        _openCart();
      }

      return true;
    } catch (e) {
      _showMessage("Could not add to cart: $e");

      return false;
    }
  }

  // =========================================================
  // CHANGE CART QUANTITY
  // =========================================================

  Future<void> _changeQuantity(String productId, int change) async {
    final cart = _cartReference;

    if (cart == null) {
      return;
    }

    final cartItem = cart.doc(productId);

    try {
      final snapshot = await cartItem.get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() ?? {};

      final currentQuantity = _toInt(data['quantity']);

      final newQuantity = currentQuantity + change;

      if (newQuantity <= 0) {
        await cartItem.delete();
        return;
      }

      await cartItem.update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage("Could not update cart: $e");
    }
  }

  // =========================================================
  // PRODUCT QUANTITY STREAM
  // =========================================================

  Stream<int> _productQuantityStream(String productId) {
    final cart = _cartReference;

    if (cart == null) {
      return Stream.value(0);
    }

    return cart.doc(productId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return 0;
      }

      final data = snapshot.data();

      return _toInt(data?['quantity']);
    });
  }

  // =========================================================
  // ADDED TO CART DIALOG
  // =========================================================

  Future<void> _showAddedToCartDialog({
    required String productTitle,
    required String price,
    String? offer,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF7F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF0F806A),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Added to cart',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF252225),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  productTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (offer != null && offer.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          offer,
                          style: const TextStyle(
                            color: primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        color: darkOrange,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Continue shopping',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _openCart();
                  },
                  child: const Text(
                    'View cart',
                    style: TextStyle(color: darkOrange, fontWeight: FontWeight.w800),
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
  // SHOW MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkOrange,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
  }
  // =========================================================
  // OPEN PRODUCT DETAILS
  // =========================================================

  void _openProductDetails(String productId, Map<String, dynamic> product) {
    final productTitle = (product["title"] ?? "").toString();

    final productDescription = (product["description"] ?? "").toString();

    final productPrice = (product["price"] ?? "0").toString();

    final productImage = (product["imageUrl"] ?? "").toString();

    final sellerName = (product["sellerName"] ?? "").toString().trim();

    final sellerId = (product["sellerId"] ?? "").toString();

    ProductDetailPage.open(context, {
      "productId": productId,
      "title": productTitle,
      "description": productDescription,
      "price": productPrice,
      "imageUrl": productImage,
      "sellerName": sellerName.isNotEmpty ? sellerName : "Local Artisan",
      "sellerId": sellerId,
    });
  }

  // =========================================================
  // OPEN BUY PAGE
  // =========================================================

  void _openBuyPage(String productId, Map<String, dynamic> product) {
    final productTitle = (product["title"] ?? "").toString();

    final productPrice = (product["price"] ?? "0").toString();

    final productImage = (product["imageUrl"] ?? "").toString();

    final sellerName = (product["sellerName"] ?? "").toString().trim();

    final sellerId = (product["sellerId"] ?? "").toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyPage(
          productId: productId,
          productName: productTitle,
          productPrice: productPrice,
          productImage: productImage,
          sellerName: sellerName.isNotEmpty ? sellerName : "Local Artisan",
          sellerId: sellerId,
        ),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
  }

  // =========================================================
  // CAROUSEL HELPERS
  // =========================================================

  void _startCampaignCarousel(int count) {
    if (count <= 1) {
      _campaignTimer?.cancel();
      _campaignTimer = null;
      _campaignIndex = 0;
      return;
    }
    if (_campaignTimer != null) return;

    _campaignTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_campaignPageController.hasClients) return;
      _campaignIndex = (_campaignIndex + 1) % count;
      _campaignPageController.animateToPage(
        _campaignIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _startListingCarousel(int count) {
    if (count <= 1) {
      _listingTimer?.cancel();
      _listingTimer = null;
      _listingIndex = 0;
      return;
    }
    if (_listingTimer != null) return;

    _listingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_listingPageController.hasClients) return;
      _listingIndex = (_listingIndex + 1) % count;
      _listingPageController.animateToPage(
        _listingIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // =========================================================
  // FEATURED LISTING
  // =========================================================

  Widget _buildFeaturedListingSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> listingDocs,
  ) {
    final activeListings = listingDocs.where((doc) {
      final data = doc.data();
      return data['enabled'] == true &&
          (data['status'] ?? '').toString() == 'Approved';
    }).toList();

    if (activeListings.isEmpty) return const SizedBox.shrink();
    _startListingCarousel(activeListings.length);

    return SizedBox(
      height: 214,
      child: PageView.builder(
        controller: _listingPageController,
        itemCount: activeListings.length,
        physics: activeListings.length == 1
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        onPageChanged: (index) => _listingIndex = index,
        itemBuilder: (context, index) {
          final data = activeListings[index].data();
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: _buildFeaturedListingCard(data),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedListingCard(Map<String, dynamic> data) {
    final productId = (data['productId'] ?? '').toString();
    final title = (data['title'] ?? data['productName'] ?? 'Featured item').toString();
    final description = (data['description'] ?? '').toString();
    final imageUrl = (data['productImageUrl'] ?? '').toString();
    final price = _toDouble(data['productPrice']);

    return GestureDetector(
      onTap: () {
        if (productId.isEmpty) return;
        _firestore.collection('products').doc(productId).get().then((doc) {
          if (!mounted || !doc.exists) return;
          final product = doc.data();
          if (product != null) _openProductDetails(productId, product);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF9DDCCB), width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 58,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF197C68), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text('FEATURED LISTING', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .35)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, height: 1.08, fontWeight: FontWeight.w900, color: Color(0xFF145D50)),
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.8,
                          height: 1.32,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: productId.isEmpty
                                ? null
                                : () async {
                                    final productDoc = await _firestore.collection('products').doc(productId).get();
                                    if (!mounted || !productDoc.exists) return;
                                    final product = productDoc.data();
                                    if (product != null) await _addToCart(productId, product);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF117D68),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 17),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                            child: const Text('Buy Now', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('₹${_formatPrice(price)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF292329))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 42,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFDDF1EA), child: const Icon(Icons.handyman_outlined, color: Color(0xFF197C68), size: 40)),
                          )
                        : Container(color: const Color(0xFFDDF1EA), child: const Icon(Icons.handyman_outlined, color: Color(0xFF197C68), size: 40)),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.9), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF167965), size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CAMPAIGN BANNER
  // =========================================================
  //
  // With one campaign, the card stays still.
  // With multiple active campaigns, PageView rotates them
  // automatically every five seconds inside this exact area.

  Widget _buildCampaignBanner(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> campaignDocs, {
    bool embedded = false,
  }) {
    final activeCampaigns = campaignDocs.where((doc) {
      final data = doc.data();
      return data['enabled'] == true &&
          (data['status'] ?? '').toString() == 'Active';
    }).toList();

    if (activeCampaigns.isEmpty) return const SizedBox.shrink();

    _startCampaignCarousel(activeCampaigns.length);

    return SizedBox(
      height: 202,
      child: PageView.builder(
        controller: _campaignPageController,
        itemCount: activeCampaigns.length,
        physics: activeCampaigns.length == 1
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        onPageChanged: (index) => _campaignIndex = index,
        itemBuilder: (context, index) {
          final data = activeCampaigns[index].data();

          return Padding(
            padding: EdgeInsets.fromLTRB(
              embedded ? 0 : 14,
              8,
              embedded ? 0 : 14,
              8,
            ),
            child: _buildCampaignCard(data),
          );
        },
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> data) {
    final productId = (data['productId'] ?? '').toString();
    final name = (data['name'] ?? 'Special Offer').toString();
    final message = (data['message'] ?? '').toString();
    final offer = (data['offer'] ?? '').toString();
    final imageUrl = (data['productImageUrl'] ?? '').toString();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: productId.isEmpty
          ? null
          : _firestore.collection('products').doc(productId).get(),
      builder: (context, snapshot) {
        final product = snapshot.data?.data();

        return GestureDetector(
          onTap: () {
            if (productId.isEmpty || product == null) return;
            _openProductDetails(productId, product);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF6EA),
                  Color(0xFFFFE8CF),
                ],
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFFF0C994),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 11,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // -----------------------------------------------------
                // CAMPAIGN TEXT
                // -----------------------------------------------------
                Expanded(
                  flex: 58,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 7, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryOrange,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'SPECIAL OFFER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .25,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF292329),
                          ),
                        ),

                        const SizedBox(height: 5),

                        Expanded(
                          child: Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.28,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Offer tag + Know More.
                        Row(
                          children: [
                            if (offer.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFDDBB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  offer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: darkOrange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            SizedBox(
                              height: 34,
                              // child: ElevatedButton(
                              //   onPressed: product == null
                              //       ? null
                              //       : () {
                              //           _openProductDetails(
                              //             productId,
                              //             product,
                              //           );
                              //         },
                              //   style: ElevatedButton.styleFrom(
                              //     backgroundColor: primaryOrange,
                              //     foregroundColor: Colors.white,
                              //     elevation: 0,
                              //     padding: const EdgeInsets.symmetric(
                              //       horizontal: 12,
                              //     ),
                              //     shape: RoundedRectangleBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //     ),
                              //   ),
                              //   // child: const Text(
                              //   //   'Know more',
                              //   //   style: TextStyle(
                              //   //     fontSize: 11,
                              //   //     fontWeight: FontWeight.w800,
                              //   //   ),
                              //   // ),
                              // ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // -----------------------------------------------------
                // CAMPAIGN IMAGE
                // -----------------------------------------------------
                Expanded(
                  flex: 42,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  _,
                                  __,
                                  ___,
                                ) {
                                  return Container(
                                    color: const Color(0xFFFFE8CF),
                                    child: const Icon(
                                      Icons.local_offer_outlined,
                                      color: darkOrange,
                                      size: 38,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFFFFE8CF),
                                child: const Icon(
                                  Icons.local_offer_outlined,
                                  color: darkOrange,
                                  size: 38,
                                ),
                              ),
                      ),

                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 33,
                          height: 33,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.08),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: darkOrange,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
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
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final cart = _cartReference;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryOrange,
        elevation: 0,
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23)),
            SizedBox(height: 2),
            Text('Made by hand. Chosen with heart.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 11.5)),
          ],
        ),
        actions: [
          if (cart != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: cart.snapshots(),
              builder: (context, snapshot) {
                int totalQuantity = 0;
                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) totalQuantity += _toInt(doc.data()['quantity']);
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(icon: const Icon(Icons.shopping_bag_outlined, size: 29), color: Colors.white, tooltip: 'Cart', onPressed: _openCart),
                    if (totalQuantity > 0)
                      Positioned(
                        right: 2,
                        top: 1,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: const Color(0xFF145D50), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                          child: Text(totalQuantity > 99 ? '99+' : totalQuantity.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            IconButton(icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 29), onPressed: _openCart),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 27), tooltip: 'Log Out', onPressed: _logout),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Search handmade items...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                prefixIcon: const Icon(Icons.search_rounded, size: 30, color: Color(0xFF454044)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : const Icon(Icons.tune_rounded, size: 27, color: Color(0xFF454044)),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: primaryOrange, width: 1.6)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activeCampaignsStream(),
              builder: (context, campaignSnapshot) {
                if (campaignSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryOrange));
                final campaignDocs = campaignSnapshot.hasData ? campaignSnapshot.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _activeListingsStream(),
                  builder: (context, listingSnapshot) {
                    if (listingSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryOrange));
                    final listingDocs = listingSnapshot.hasData ? listingSnapshot.data!.docs : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore.collection('products').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryOrange));
                        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error fetching products.\n\n${snapshot.error}', textAlign: TextAlign.center)));
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No products available.'));

                        final products = snapshot.data!.docs.where((doc) {
                          final data = doc.data();
                          if (_searchQuery.isEmpty) return true;
                          final title = (data['title'] ?? '').toString().toLowerCase();
                          final description = (data['description'] ?? '').toString().toLowerCase();
                          final category = (data['category'] ?? '').toString().toLowerCase();
                          final subcategory = (data['subcategory'] ?? '').toString().toLowerCase();
                          final tags = _stringListToSearchableText(data['tags']);
                          final keywords = _stringListToSearchableText(data['keywords']);
                          final searchTerms = _stringListToSearchableText(data['searchTerms']);
                          return '''
$title
$description
$category
$subcategory
$tags
$keywords
$searchTerms
'''.contains(_searchQuery);
                        }).toList();

                        if (products.isEmpty) {
                          return CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _buildFeaturedListingSection(listingDocs),
                              ),
                              SliverToBoxAdapter(
                                child: _buildHandmadeCategoryStrip(),
                              ),
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 50,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No products match your search.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return CustomScrollView(
                          slivers: [
                            // FEATURED LISTING — ALWAYS FIRST.
                            SliverToBoxAdapter(
                              child: _buildFeaturedListingSection(listingDocs),
                            ),

                            // HANDMADE CATEGORIES — VISUAL ONLY.
                            SliverToBoxAdapter(
                              child: _buildHandmadeCategoryStrip(),
                            ),

                            // PRODUCT CATALOG.
                            //
                            // If a campaign exists:
                            //   Row 1 -> 3 products
                            //   Row 2 -> campaign (2 slots) + 1 product
                            //   Row 3+ -> 3 products
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                0,
                                14,
                                120,
                              ),
                              sliver: _buildCatalogSliver(
                                products,
                                campaignDocs,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAIAssistant,
        backgroundColor: primaryOrange,
        elevation: 7,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // =========================================================
  // HANDMADE CATEGORY STRIP
  // =========================================================
  // Visual navigation only for now. These buttons intentionally
  // have no functionality yet.

  Widget _buildHandmadeCategoryStrip() {
    final categories = <Map<String, dynamic>>[
      {'name': 'Jewelry', 'icon': Icons.diamond_outlined},
      {'name': 'Home Decor', 'icon': Icons.home_work_outlined},
      {'name': 'Textiles', 'icon': Icons.grid_on_rounded},
      {'name': 'Pottery', 'icon': Icons.local_fire_department_outlined},
      {'name': 'Accessories', 'icon': Icons.watch_outlined},
      {'name': 'More', 'icon': Icons.more_horiz_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 0, 10),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: 14),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 17),
          itemBuilder: (context, index) {
            final category = categories[index];

            return SizedBox(
              width: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF4D4B5),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      color: primaryOrange,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    category['name'] as String,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF393336),
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // MIXED CATALOG LAYOUT
  // =========================================================
  //
  // Layout when a campaign is active:
  //
  //   ROW 1:  Product | Product | Product
  //   ROW 2:  Campaign (2 slots) | Product
  //   ROW 3+: Product | Product | Product
  //
  // The campaign is exactly two product-card widths wide.
  // If there is no campaign, the catalog becomes a normal
  // three-column product layout.
  // =========================================================

  Widget _buildCatalogSliver(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> campaignDocs,
  ) {
    final activeCampaigns = campaignDocs.where((doc) {
      final data = doc.data();
      return data['enabled'] == true &&
          (data['status'] ?? '').toString() == 'Active';
    }).toList();

    final hasCampaign = activeCampaigns.isNotEmpty;

    // The first three products always form the first row.
    // The fourth product is placed beside the campaign in row two.
    final firstRowProducts = products.take(3).toList();

    final remainingAfterFirstRow = products.skip(3).toList();

    final secondRowProduct =
        remainingAfterFirstRow.isNotEmpty ? remainingAfterFirstRow.first : null;

    final remainingAfterSecondRow = secondRowProduct == null
        ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : remainingAfterFirstRow.skip(1).toList();

    final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> normalRows =
        [];

    if (hasCampaign) {
      for (int i = 0; i < remainingAfterSecondRow.length; i += 3) {
        normalRows.add(
          remainingAfterSecondRow
              .skip(i)
              .take(3)
              .toList(),
        );
      }
    } else {
      for (int i = 0; i < products.length; i += 3) {
        normalRows.add(
          products.skip(i).take(3).toList(),
        );
      }
    }

    // When a campaign exists but fewer than four products match the
    // current search, the campaign still appears after the first row.
    final totalRows = hasCampaign
        ? 1 + 1 + normalRows.length
        : normalRows.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rowIndex) {
          const gap = 9.0;
          const rowHeight = 202.0;

          // ---------------------------------------------------------
          // FIRST ROW — ALWAYS THREE COMPACT PRODUCTS
          // ---------------------------------------------------------
          if (rowIndex == 0 && hasCampaign) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(firstRowProducts.length, (index) {
                    final doc = firstRowProducts[index];
                    final product = doc.data();
                    final campaign = _campaignForProduct(
                      doc.id,
                      campaignDocs,
                    );

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == firstRowProducts.length - 1
                              ? 0
                              : gap,
                        ),
                        child: _buildProductCard(
                          doc.id,
                          product,
                          campaign: campaign,
                          listing: null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          }

          // ---------------------------------------------------------
          // SECOND ROW — CAMPAIGN + ONE PRODUCT
          // ---------------------------------------------------------
          if (hasCampaign && rowIndex == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildCampaignBanner(
                        campaignDocs,
                        embedded: true,
                      ),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      child: secondRowProduct == null
                          ? const SizedBox.shrink()
                          : _buildProductCard(
                              secondRowProduct.id,
                              secondRowProduct.data(),
                              campaign: _campaignForProduct(
                                secondRowProduct.id,
                                campaignDocs,
                              ),
                              listing: null,
                            ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ---------------------------------------------------------
          // NORMAL THREE-COLUMN ROWS AFTER THE CAMPAIGN
          // ---------------------------------------------------------
          final normalRowIndex = hasCampaign
              ? rowIndex - 2
              : rowIndex;

          if (normalRowIndex < 0 ||
              normalRowIndex >= normalRows.length) {
            return const SizedBox.shrink();
          }

          final rowProducts = normalRows[normalRowIndex];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(rowProducts.length, (index) {
                  final doc = rowProducts[index];
                  final product = doc.data();
                  final campaign = _campaignForProduct(
                    doc.id,
                    campaignDocs,
                  );

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == rowProducts.length - 1 ? 0 : gap,
                      ),
                      child: _buildProductCard(
                        doc.id,
                        product,
                        campaign: campaign,
                        listing: null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
        childCount: totalRows,
      ),
    );
  }

  Map<String, dynamic>? _listingForProduct(
    String productId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> listingDocs,
  ) {
    for (final doc in listingDocs) {
      final data = doc.data();
      final listingProductId = (data['productId'] ?? '').toString();
      final enabled = data['enabled'] == true;
      if (enabled && listingProductId == productId) return {...data, 'listingId': doc.id};
    }
    return null;
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    String productId,
    Map<String, dynamic> product, {
    Map<String, dynamic>? campaign,
    Map<String, dynamic>? listing,
  }) {
    final productTitle = (product['title'] ?? '').toString();
    final originalPrice = _toDouble(product['price']);
    final productImage = (product['imageUrl'] ?? '').toString();

    final hasCampaign = campaign != null;
    final discountPercentage = hasCampaign ? _getDiscountPercentage(campaign!) : 0.0;
    final hasValidDiscount = hasCampaign && discountPercentage > 0 && discountPercentage <= 100 && originalPrice > 0;
    final campaignPrice = hasValidDiscount ? _getCampaignPrice(originalPrice, discountPercentage) : originalPrice;

    return GestureDetector(
      onTap: () => _openProductDetails(productId, product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9E2DD)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 62,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: productImage.isNotEmpty
                        ? Image.network(productImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF4EEE9), child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey))))
                        : Container(color: const Color(0xFFF4EEE9), child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey))),
                  ),
                  // Wishlist UI only — intentionally not functional yet.
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.92), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 5)]),
                      child: const Icon(Icons.favorite_border_rounded, size: 19, color: Color(0xFF3D393B)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 38,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, height: 1.18, fontWeight: FontWeight.w800, color: Color(0xFF2A2729))),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${_formatPrice(hasValidDiscount ? campaignPrice : originalPrice)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: hasValidDiscount ? darkOrange : primaryOrange),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Material(
                          color: primaryOrange,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async => _addToCart(productId, product),
                            child: const SizedBox(width: 34, height: 34, child: Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 17)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CONVERT LIST TO SEARCHABLE TEXT
  // =========================================================

  String _stringListToSearchableText(dynamic value) {
    if (value is! List) {
      return '';
    }

    return value.map((item) => item.toString().toLowerCase()).join(' ');
  }
}
