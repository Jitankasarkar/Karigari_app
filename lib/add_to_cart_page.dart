import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/buy_page.dart';

class AddToCartPage extends StatelessWidget {
  const AddToCartPage({super.key});

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryOrange = Color.fromARGB(255, 214, 112, 22);
  static const Color darkOrange = Color.fromARGB(255, 141, 83, 20);

  static const Color pageBackground = Color(0xFFFFFCF9);
  static const Color cardBorder = Color(0xFFF0E3D8);
  static const Color softGreen = Color(0xFFF1F9F4);
  static const Color softGreenBorder = Color(0xFFDCEFE3);

  // =========================================================
  // CART REFERENCE
  //
  // Firestore:
  // users/{userId}/cart/{productId}
  // =========================================================

  CollectionReference<Map<String, dynamic>> _cartReference(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart');
  }

  // =========================================================
  // SAFE INTEGER
  // =========================================================

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        )?.round() ??
        fallback;
  }

  // =========================================================
  // UPDATE QUANTITY
  // =========================================================

  Future<void> _updateQuantity(String cartId, int quantity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _cartReference(user.uid).doc(cartId);

    try {
      if (quantity <= 0) {
        await ref.delete();
      } else {
        await ref.update({
          'quantity': quantity,
        });
      }
    } catch (e) {
      debugPrint('Cart quantity update failed: $e');
    }
  }

  // =========================================================
  // REMOVE ITEM
  // =========================================================

  Future<void> _removeItem(String cartId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _cartReference(user.uid).doc(cartId).delete();
    } catch (e) {
      debugPrint('Cart item removal failed: $e');
    }
  }

  // =========================================================
  // CHECKOUT CART
  // =========================================================

  void _checkoutCart(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) {
    if (items.isEmpty) return;

    final cartItems = items.map((doc) {
      final data = doc.data();

      return {
        'cartId': doc.id,
        'productId': (data['productId'] ?? doc.id).toString(),
        'title': (data['title'] ?? '').toString(),
        'description': (data['description'] ?? '').toString(),
        'price': (data['price'] ?? '0').toString(),
        'originalPrice':
            (data['originalPrice'] ?? data['price'] ?? '0').toString(),
        'imageUrl': (data['imageUrl'] ?? '').toString(),
        'campaignId': (data['campaignId'] ?? '').toString(),
        'campaignOffer': (data['campaignOffer'] ?? '').toString(),
        'sellerName':
            (data['sellerName'] ?? 'Local Artisan').toString(),
        'sellerId': (data['sellerId'] ?? '').toString(),
        'quantity': _toInt(
          data['quantity'],
          fallback: 1,
        ),
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyPage.fromCart(
          cartItems: cartItems,
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: pageBackground,
        appBar: _buildAppBar(context),
        body: const Center(
          child: Text(
            'Please log in to view your cart.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF555555),
            ),
          ),
        ),
      );
    }

    final cartStream = _cartReference(user.uid)
        .orderBy(
          'addedAt',
          descending: true,
        )
        .snapshots();

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartStream,
        builder: (context, snapshot) {
          // -------------------------------------------------
          // LOADING
          // -------------------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryOrange,
              ),
            );
          }

          // -------------------------------------------------
          // ERROR
          // -------------------------------------------------

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final items = snapshot.data?.docs ?? [];

          // -------------------------------------------------
          // EMPTY CART
          // -------------------------------------------------

          if (items.isEmpty) {
            return _buildEmptyCart();
          }

          // -------------------------------------------------
          // CALCULATE SUBTOTAL
          // -------------------------------------------------

          int subtotal = 0;

          for (final doc in items) {
            final data = doc.data();

            final price = _toInt(data['price']);

            final quantity = _toInt(
              data['quantity'],
              fallback: 1,
            );

            subtotal += price * quantity;
          }

          // -------------------------------------------------
          // EXTRA CHARGES
          // -------------------------------------------------

          const int deliveryCharge = 20;
          const int platformFee = 1;

          final total = subtotal + deliveryCharge + platformFee;

          // =================================================
          // PAGE
          // =================================================

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    13,
                    12,
                    13,
                    14,
                  ),
                  children: [
                    _buildHandmadeBanner(),

                    const SizedBox(height: 16),

                    Text(
                      'Your Items (${items.length})',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF242424),
                        letterSpacing: -0.2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...items.map(
                      (doc) => _buildCartItem(
                        doc: doc,
                      ),
                    ),

                    const SizedBox(height: 2),

                    _buildSustainableBanner(),

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              _buildOrderSummary(
                context: context,
                subtotal: subtotal,
                deliveryCharge: deliveryCharge,
                platformFee: platformFee,
                total: total,
                items: items,
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // APP BAR
  // =========================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      toolbarHeight: 78,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD96F16),
              Color(0xFFE87500),
            ],
          ),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.maybePop(context);
            },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 26,
            ),
            padding: const EdgeInsets.only(
              left: 10,
              right: 5,
            ),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 3,
                right: 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review your items and place your order',
                    style: TextStyle(
                      color: Color(0xFFFFE8D3),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HANDMADE BANNER
  // =========================================================

  Widget _buildHandmadeBanner() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 88,
      ),
      padding: const EdgeInsets.fromLTRB(
        11,
        9,
        9,
        9,
      ),
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: softGreenBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF2E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 22,
              color: Color(0xFF55A975),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're supporting handmade.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF252525),
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Every purchase empowers artisans and preserves tradition.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Color(0xFF626262),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 43,
            height: 50,
            child: CustomPaint(
              painter: _HandmadePainter(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CART ITEM
  //
  // IMPORTANT:
  // No fixed-height Column is used here.
  // This prevents the "BOTTOM OVERFLOWED BY ... PIXELS" error
  // when the title/seller/price/quantity need more room.
  // =========================================================

  Widget _buildCartItem({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();

    final title = (data['title'] ?? '').toString();

    final imageUrl = (data['imageUrl'] ?? '').toString();

    final sellerName =
        (data['sellerName'] ?? 'Local Artisan').toString();

    final price = _toInt(data['price']);

    final originalPrice = _toInt(
      data['originalPrice'] ?? data['price'],
    );

    final campaignOffer =
        (data['campaignOffer'] ?? '').toString().trim();

    final hasCampaign =
        campaignOffer.isNotEmpty && originalPrice > price;

    final quantity = _toInt(
      data['quantity'],
      fallback: 1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorder,
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================================
          // IMAGE
          // =================================

          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 86,
              height: 86,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return _imagePlaceholder();
                      },
                    )
                  : _imagePlaceholder(),
            ),
          ),

          const SizedBox(width: 9),

          // =================================
          // DETAILS
          // =================================

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE + DELETE
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: Color(0xFF242424),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildDeleteButton(
                      docId: doc.id,
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // SELLER
                Text(
                  'Sold by: $sellerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF777777),
                  ),
                ),

                const SizedBox(height: 4),

                // PRICE
                if (hasCampaign)
                  Row(
                    children: [
                      Text(
                        '₹$originalPrice',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: darkOrange,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: darkOrange,
                    ),
                  ),

                const SizedBox(height: 4),

                // QUANTITY
                _buildQuantityControl(
                  docId: doc.id,
                  quantity: quantity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // QUANTITY CONTROL
  // =========================================================

  Widget _buildQuantityControl({
    required String docId,
    required int quantity,
  }) {
    return Container(
      height: 31,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        border: Border.all(
          color: const Color(0xFFF1D8C4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(11),
            ),
            onTap: () {
              _updateQuantity(
                docId,
                quantity - 1,
              );
            },
            child: const SizedBox(
              width: 31,
              height: 31,
              child: Icon(
                Icons.remove_rounded,
                size: 17,
                color: primaryOrange,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 30,
            ),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF282828),
              ),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(11),
            ),
            onTap: () {
              _updateQuantity(
                docId,
                quantity + 1,
              );
            },
            child: const SizedBox(
              width: 31,
              height: 31,
              child: Icon(
                Icons.add_rounded,
                size: 17,
                color: primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DELETE BUTTON
  // =========================================================

  Widget _buildDeleteButton({
    required String docId,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _removeItem(docId);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFD6D0),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: Color(0xFFD94236),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SUSTAINABLE CHOICE
  // =========================================================

  Widget _buildSustainableBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        11,
        9,
        9,
        9,
      ),
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: softGreenBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF2E5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_outlined,
              size: 23,
              color: Color(0xFF4B9A5D),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sustainable Choice',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF242424),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Eco-friendly packaging • Support local artisans • Preserve heritage',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Color(0xFF626262),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.spa_outlined,
            size: 40,
            color: Color(0x284B9A5D),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER SUMMARY
  // =========================================================

  Widget _buildOrderSummary({
    required BuildContext context,
    required int subtotal,
    required int deliveryCharge,
    required int platformFee,
    required int total,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        11,
        9,
        11,
        5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                10,
                6,
                10,
                4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFF0E9E3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _summaryRow(
                    'Subtotal (${items.length} ${items.length == 1 ? 'item' : 'items'})',
                    subtotal,
                  ),
                  _summaryRow(
                    'Delivery Fee',
                    deliveryCharge,
                  ),
                  _summaryRow(
                    'Platform Fee',
                    platformFee,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Divider(
                      height: 1,
                      color: Color(0xFFEDE8E3),
                    ),
                  ),
                  _summaryRow(
                    'Total',
                    total,
                    bold: true,
                    totalRow: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            SizedBox(
              width: double.infinity,
              height: 49,
              child: ElevatedButton(
                onPressed: () {
                  _checkoutCart(
                    context,
                    items,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shadowColor: primaryOrange.withOpacity(0.2),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Proceed to Checkout • ₹$total',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 17,
                  color: Color(0xFF4D8D56),
                ),
                const SizedBox(width: 6),
                Text(
                  'Secure payments. 100% safe.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SUMMARY ROW
  // =========================================================

  Widget _summaryRow(
    String label,
    int amount, {
    bool bold = false,
    bool totalRow = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: totalRow ? 4 : 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!totalRow) ...[
                _summaryIcon(label),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: totalRow ? 17 : 13,
                  fontWeight: bold
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: totalRow
                      ? const Color(0xFF242424)
                      : const Color(0xFF404040),
                ),
              ),
            ],
          ),
          Text(
            '₹$amount',
            style: TextStyle(
              fontSize: totalRow ? 18 : 13,
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: totalRow
                  ? primaryOrange
                  : const Color(0xFF252525),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY ICON
  // =========================================================

  Widget _summaryIcon(String label) {
    IconData icon;

    if (label.startsWith('Subtotal')) {
      icon = Icons.shopping_bag_outlined;
    } else if (label == 'Delivery Fee') {
      icon = Icons.local_shipping_outlined;
    } else {
      icon = Icons.shield_outlined;
    }

    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF2E7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 13,
        color: darkOrange,
      ),
    );
  }

  // =========================================================
  // EMPTY CART
  // =========================================================

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1E4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 45,
                color: primaryOrange,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF242424),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add some handmade products!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load cart',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE PLACEHOLDER
  // =========================================================

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.image_outlined,
        size: 34,
        color: Colors.grey.shade400,
      ),
    );
  }
}

// ===========================================================
// HANDMADE BANNER DECORATION
// ===========================================================

class _HandmadePainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0xFF76B98C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final center = Offset(
      size.width / 2,
      size.height * 0.47,
    );

    // Heart
    final heart = Path();

    heart.moveTo(
      center.dx,
      center.dy + 11,
    );

    heart.cubicTo(
      center.dx - 19,
      center.dy - 1,
      center.dx - 18,
      center.dy - 16,
      center.dx - 8,
      center.dy - 16,
    );

    heart.cubicTo(
      center.dx - 2,
      center.dy - 16,
      center.dx + 2,
      center.dy - 11,
      center.dx,
      center.dy - 6,
    );

    heart.cubicTo(
      center.dx + 2,
      center.dy - 11,
      center.dx + 6,
      center.dy - 16,
      center.dx + 12,
      center.dy - 14,
    );

    heart.cubicTo(
      center.dx + 21,
      center.dy - 11,
      center.dx + 19,
      center.dy + 1,
      center.dx,
      center.dy + 11,
    );

    canvas.drawPath(heart, paint);

    // Left hand
    final leftHand = Path();

    leftHand.moveTo(
      center.dx - 26,
      center.dy + 27,
    );

    leftHand.cubicTo(
      center.dx - 31,
      center.dy + 15,
      center.dx - 31,
      center.dy + 5,
      center.dx - 25,
      center.dy - 1,
    );

    leftHand.cubicTo(
      center.dx - 20,
      center.dy - 5,
      center.dx - 15,
      center.dy + 2,
      center.dx - 13,
      center.dy + 7,
    );

    canvas.drawPath(leftHand, paint);

    // Right hand
    final rightHand = Path();

    rightHand.moveTo(
      center.dx + 26,
      center.dy + 27,
    );

    rightHand.cubicTo(
      center.dx + 31,
      center.dy + 15,
      center.dx + 31,
      center.dy + 5,
      center.dx + 25,
      center.dy - 1,
    );

    rightHand.cubicTo(
      center.dx + 20,
      center.dy - 5,
      center.dx + 15,
      center.dy + 2,
      center.dx + 13,
      center.dy + 7,
    );

    canvas.drawPath(rightHand, paint);

    // Rays
    canvas.drawLine(
      Offset(center.dx, center.dy - 27),
      Offset(center.dx, center.dy - 34),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx - 16, center.dy - 24),
      Offset(center.dx - 20, center.dy - 31),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx + 16, center.dy - 24),
      Offset(center.dx + 20, center.dy - 31),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
