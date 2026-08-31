import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/buy_page.dart';
import 'package:proto_app/add_to_cart_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, String> product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  // =========================================================
  // OPEN PRODUCT DETAIL PAGE
  // =========================================================

  static Future<void> open(
    BuildContext context,
    Map<String, String> product,
  ) async {
    final imageUrl =
        (product["imageUrl"] ??
                product["image"] ??
                "")
            .replaceAll('"', '')
            .trim();

    // ---------------------------------------------------------
    // PRELOAD IMAGE
    // ---------------------------------------------------------

    if (imageUrl.isNotEmpty) {
      try {
        await precacheImage(
          NetworkImage(imageUrl),
          context,
        );
      } catch (_) {
        // Still open the page if image preload fails.
      }
    }

    if (!context.mounted) return;

    // ---------------------------------------------------------
    // FADE TRANSITION
    // ---------------------------------------------------------

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 180),

        reverseTransitionDuration:
            const Duration(milliseconds: 150),

        pageBuilder:
            (
          context,
          animation,
          secondaryAnimation,
        ) {
          return ProductDetailPage(
            product: product,
          );
        },

        transitionsBuilder:
            (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  // =========================================================
  // PRODUCT IMAGE
  // =========================================================

  Widget _buildImage(
    BuildContext context,
    String imageUrl,
  ) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 260,
        width: double.infinity,
        color: const Color(0xFFF5F5F5),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 50,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 260,
        fit: BoxFit.cover,

        frameBuilder:
            (
          context,
          child,
          frame,
          wasSynchronouslyLoaded,
        ) {
          if (wasSynchronouslyLoaded) {
            return child;
          }

          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: child,
          );
        },

        loadingBuilder:
            (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            color: const Color(0xFFF5F5F5),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFD66A16),
                ),
              ),
            ),
          );
        },

        errorBuilder:
            (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            color: const Color(0xFFF5F5F5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Image failed to load",
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // CART REFERENCE
  // =========================================================

  DocumentReference<Map<String, dynamic>> _cartReference(
    String userId,
    String productId,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(productId);
  }

  // =========================================================
  // ADD PRODUCT TO CART
  // =========================================================

  Future<void> _addToCart(
    BuildContext context,
    String productId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please log in to add products to your cart.",
          ),
        ),
      );

      return;
    }

    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Unable to identify this product.",
          ),
        ),
      );

      return;
    }

    final cartRef =
        _cartReference(
      user.uid,
      productId,
    );

    try {
      await cartRef.set(
        {
          // ---------------------------------------------------
          // PRODUCT INFORMATION
          // ---------------------------------------------------

          'productId': productId,

          'title':
              product["title"] ?? "",

          'description':
              product["description"] ?? "",

          'price':
              product["price"] ?? "0",

          'imageUrl':
              product["imageUrl"] ??
                  product["image"] ??
                  "",

          // ---------------------------------------------------
          // SELLER INFORMATION
          // ---------------------------------------------------

          'sellerName':
              product["sellerName"] ??
                  "Local Artisan",

          'sellerId':
              product["sellerId"] ?? "",

          // ---------------------------------------------------
          // CART INFORMATION
          // ---------------------------------------------------

          'quantity': 1,

          'addedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // No generic "added to cart" dialog.
      // The button itself changes into the quantity controller.
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not add to cart: $e",
          ),
        ),
      );
    }
  }

  // =========================================================
  // CHANGE QUANTITY
  // =========================================================

  Future<void> _changeQuantity(
    String productId,
    int currentQuantity,
    int change,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null || productId.isEmpty) {
      return;
    }

    final newQuantity =
        currentQuantity + change;

    final cartRef =
        _cartReference(
      user.uid,
      productId,
    );

    try {
      // -------------------------------------------------------
      // REMOVE ITEM IF QUANTITY BECOMES ZERO
      // -------------------------------------------------------

      if (newQuantity <= 0) {
        await cartRef.delete();
        return;
      }

      // -------------------------------------------------------
      // UPDATE QUANTITY
      // -------------------------------------------------------

      await cartRef.update({
        'quantity': newQuantity,
      });
    } catch (e) {
      debugPrint(
        "Cart quantity update failed: $e",
      );
    }
  }

  // =========================================================
  // CART ICON
  // =========================================================

  Widget _buildCartIcon(
    BuildContext context,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return IconButton(
        icon: const Icon(
          Icons.shopping_cart_outlined,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AddToCartPage(),
            ),
          );
        },
      );
    }

    final cartStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .snapshots();

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: cartStream,

      builder: (
        context,
        snapshot,
      ) {
        int totalQuantity = 0;

        if (snapshot.hasData) {
          for (final doc
              in snapshot.data!.docs) {
            final data = doc.data();

            final quantity =
                data['quantity'];

            if (quantity is int) {
              totalQuantity += quantity;
            } else if (quantity is num) {
              totalQuantity +=
                  quantity.toInt();
            }
          }
        }

        return IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AddToCartPage(),
              ),
            );
          },

          icon: Stack(
            clipBehavior:
                Clip.none,

            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 27,
              ),

              // ------------------------------------------------
              // CART BADGE
              // ------------------------------------------------

              if (totalQuantity > 0)
                Positioned(
                  right: -7,
                  top: -8,

                  child: Container(
                    constraints:
                        const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),

                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 4,
                    ),

                    decoration:
                        const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),

                    child: Center(
                      child: Text(
                        totalQuantity > 99
                            ? "99+"
                            : totalQuantity
                                .toString(),

                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // QUANTITY BUTTON
  // =========================================================

  Widget _buildQuantityButton(
    BuildContext context,
    String productId,
    int quantity,
  ) {
    return Container(
      height: 48,

      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF8D5314),
          width: 1.3,
        ),

        borderRadius:
            BorderRadius.circular(12),

        color: Colors.white,
      ),

      child: Row(
        children: [
          // ===================================================
          // MINUS
          // ===================================================

          Expanded(
            child: Material(
              color: Colors.transparent,

              child: InkWell(
                borderRadius:
                    const BorderRadius
                        .horizontal(
                  left: Radius.circular(12),
                ),

                onTap: () {
                  _changeQuantity(
                    productId,
                    quantity,
                    -1,
                  );
                },

                child: const Center(
                  child: Icon(
                    Icons.remove,
                    color:
                        Color(0xFF8D5314),
                  ),
                ),
              ),
            ),
          ),

          // ===================================================
          // QUANTITY
          // ===================================================

          Container(
            width: 55,

            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(
                  color:
                      Color(0xFFE4CDB9),
                ),
              ),
            ),

            child: Center(
              child: Text(
                quantity.toString(),

                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF8D5314),
                ),
              ),
            ),
          ),

          // ===================================================
          // PLUS
          // ===================================================

          Expanded(
            child: Material(
              color: Colors.transparent,

              child: InkWell(
                borderRadius:
                    const BorderRadius
                        .horizontal(
                  right: Radius.circular(12),
                ),

                onTap: () {
                  _changeQuantity(
                    productId,
                    quantity,
                    1,
                  );
                },

                child: const Center(
                  child: Icon(
                    Icons.add,
                    color:
                        Color(0xFF8D5314),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ADD / QUANTITY SECTION
  // =========================================================

  Widget _buildCartAction(
    BuildContext context,
    String productId,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

    // ---------------------------------------------------------
    // NOT LOGGED IN
    // ---------------------------------------------------------

    if (user == null) {
      return SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            _addToCart(
              context,
              productId,
            );
          },

          style:
              OutlinedButton.styleFrom(
            foregroundColor:
                const Color(0xFF8D5314),

            side:
                const BorderSide(
              color: Color(0xFF8D5314),
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),
          ),

          child:
              const Text(
            "Add to Cart",
            style: TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // ---------------------------------------------------------
    // LISTEN TO THIS PRODUCT'S CART ITEM
    // ---------------------------------------------------------

    final cartRef =
        _cartReference(
      user.uid,
      productId,
    );

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: cartRef.snapshots(),

      builder: (
        context,
        snapshot,
      ) {
        // -----------------------------------------------------
        // LOADING
        // -----------------------------------------------------

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: null,
              style:
                  OutlinedButton.styleFrom(
                side:
                    const BorderSide(
                  color:
                      Color(0xFFE4CDB9),
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child:
                  const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Color(0xFFD66A16),
                ),
              ),
            ),
          );
        }

        // -----------------------------------------------------
        // GET QUANTITY
        // -----------------------------------------------------

        int quantity = 0;

        if (snapshot.hasData &&
            snapshot.data!.exists) {
          final data =
              snapshot.data!.data();

          final rawQuantity =
              data?['quantity'];

          if (rawQuantity is int) {
            quantity = rawQuantity;
          } else if (rawQuantity is num) {
            quantity =
                rawQuantity.toInt();
          }
        }

        // -----------------------------------------------------
        // PRODUCT NOT IN CART
        // -----------------------------------------------------

        if (quantity <= 0) {
          return SizedBox(
            height: 48,

            child: OutlinedButton(
              onPressed: () {
                _addToCart(
                  context,
                  productId,
                );
              },

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF8D5314,
                ),

                side:
                    const BorderSide(
                  color:
                      Color(0xFF8D5314),
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),

              child:
                  const Text(
                "Add to Cart",
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          );
        }

        // -----------------------------------------------------
        // PRODUCT ALREADY IN CART
        // -----------------------------------------------------

        return _buildQuantityButton(
          context,
          productId,
          quantity,
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    // =========================================================
    // PRODUCT DATA
    // =========================================================

    final productId =
        product["productId"] ?? "";

    final productTitle =
        product["title"] ?? "";

    final productDescription =
        product["description"] ?? "";

    final productPrice =
        product["price"] ?? "0";

    final imagePath =
        product["imageUrl"] ??
            product["image"] ??
            "";

    final cleanImage =
        imagePath
            .replaceAll('"', '')
            .trim();

    // =========================================================
    // SELLER
    // =========================================================

    final rawSellerName =
        product["sellerName"] ?? "";

    final sellerName =
        rawSellerName
                .trim()
                .isNotEmpty
            ? rawSellerName.trim()
            : "Local Artisan";

    final sellerId =
        product["sellerId"] ?? "";

    return Scaffold(
      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        elevation: 0,

        title: Text(
          productTitle,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        backgroundColor:
            const Color(0xFFD66A16),

        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),

        actions: [
          // ===================================================
          // CART
          // ===================================================

          _buildCartIcon(
            context,
          ),

          const SizedBox(
            width: 6,
          ),
        ],
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: Column(
        children: [
          // =====================================================
          // PRODUCT IMAGE
          // =====================================================

          _buildImage(
            context,
            cleanImage,
          ),

          // =====================================================
          // PRODUCT INFORMATION
          // =====================================================

          Expanded(
            child:
                SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                20,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  // =============================================
                  // PRODUCT NAME
                  // =============================================

                  Text(
                    productTitle,

                    style:
                        const TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF222222),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // =============================================
                  // PRICE
                  // =============================================

                  Text(
                    '₹$productPrice',

                    style:
                        const TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFFD66A16),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // =============================================
                  // DESCRIPTION
                  // =============================================

                  const Text(
                    "About this product",

                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    productDescription,

                    style:
                        const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color:
                          Color(0xFF555555),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // =============================================
                  // SELLER
                  // =============================================

                  Container(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFFFF7F0,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),

                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFF1D8C5,
                        ),
                      ),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,

                          decoration:
                              const BoxDecoration(
                            color:
                                Color(
                              0xFFFFE8D5,
                            ),
                            shape:
                                BoxShape.circle,
                          ),

                          child:
                              const Icon(
                            Icons
                                .storefront_outlined,
                            color:
                                Color(
                              0xFFD66A16,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              const Text(
                                "Sold by",

                                style:
                                    TextStyle(
                                  fontSize:
                                      12,
                                  color:
                                      Colors.grey,
                                ),
                              ),

                              const SizedBox(
                                height: 2,
                              ),

                              Text(
                                sellerName,

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    const TextStyle(
                                  fontSize:
                                      15,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =============================================
                  // ITEM DETAILS
                  // =============================================

                  const Text(
                    "Item Details",

                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _detailRow(
                    Icons.handyman_outlined,
                    "Handmade product",
                  ),

                  _detailRow(
                    Icons.eco_outlined,
                    "Eco-friendly",
                  ),

                  _detailRow(
                    Icons.location_on_outlined,
                    "Locally crafted",
                  ),

                  _detailRow(
                    Icons.auto_awesome_outlined,
                    "Customization may be available",
                  ),

                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          ),

          // =====================================================
          // BOTTOM ACTIONS
          // =====================================================

          Container(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16,
            ),

            decoration:
                BoxDecoration(
              color: Colors.white,

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black
                          .withOpacity(0.08),
                  blurRadius: 15,
                  offset:
                      const Offset(
                    0,
                    -4,
                  ),
                ),
              ],
            ),

            child: Row(
              children: [
                // =================================================
                // ADD TO CART / QUANTITY
                // =================================================

                Expanded(
                  child:
                      _buildCartAction(
                    context,
                    productId,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // =================================================
                // BUY NOW
                // =================================================

                Expanded(
                  child:
                      SizedBox(
                    height: 48,

                    child:
                        ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    BuyPage(
                              productName:
                                  productTitle,

                              productPrice:
                                  productPrice,

                              productImage:
                                  cleanImage,

                              sellerName:
                                  sellerName,

                              sellerId:
                                  sellerId,
                            ),
                          ),
                        );
                      },

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF8D5314,
                        ),

                        foregroundColor:
                            Colors.white,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                      ),

                      child:
                          const Text(
                        "Buy Now",

                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _detailRow(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),

      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                const Color(0xFFD66A16),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              text,

              style:
                  const TextStyle(
                fontSize: 14,
                color:
                    Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }
}