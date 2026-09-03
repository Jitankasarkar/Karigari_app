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
        (product["imageUrl"] ?? product["image"] ?? "")
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
            (context, animation, secondaryAnimation) {
          return ProductDetailPage(
            product: product,
          );
        },
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
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
        frameBuilder: (
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
            (context, child, loadingProgress) {
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
            (context, error, stackTrace) {
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
  // SAFE DOUBLE
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
              '',
        ) ??
        0.0;
  }

  // =========================================================
  // GET DISCOUNT PERCENTAGE
  // =========================================================

  double _getDiscountPercentage(
    Map<String, dynamic> campaign,
  ) {
    final offer =
        (campaign['offer'] ?? '').toString().trim();

    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*%',
    ).firstMatch(offer);

    return double.tryParse(
          match?.group(1) ?? '',
        ) ??
        0.0;
  }

  // =========================================================
  // CALCULATE CAMPAIGN PRICE
  // =========================================================

  double _getCampaignPrice(
    double originalPrice,
    double discountPercentage,
  ) {
    if (originalPrice <= 0 ||
        discountPercentage <= 0) {
      return originalPrice;
    }

    final calculatedPrice =
        originalPrice *
        (1.0 - discountPercentage / 100.0);

    // Keep campaign pricing consistent with BuyPage.
    return calculatedPrice.roundToDouble();
  }

  // =========================================================
  // FORMAT PRICE
  // =========================================================

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // =========================================================
  // ADD PRODUCT TO CART
  // =========================================================

 Future<void> _addToCart(
  BuildContext context,
  String productId, {
  double? campaignPrice,
  Map<String, dynamic>? campaign,
}) async {
  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            16,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7D3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFD66A16),
                  size: 21,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Login required",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF292929),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Please log in to add products to your cart.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD66A16),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return;
  }

  if (productId.isEmpty) {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            16,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7D3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD66A16),
                  size: 21,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Something went wrong",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF292929),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Unable to identify this product.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD66A16),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return;
  }

  // =========================================================
  // ORIGINAL PRICE
  // =========================================================

  final double originalPrice =
      _toDouble(product["price"]);

  // =========================================================
  // EFFECTIVE PRICE
  // =========================================================

  final double effectivePrice =
      campaignPrice ?? originalPrice;

  // =========================================================
  // CART DOCUMENT
  // =========================================================

  final cartRef = _cartReference(
    user.uid,
    productId,
  );

  try {
    await cartRef.set(
      {
        // PRODUCT INFORMATION
        'productId': productId,

        'title': product["title"] ?? "",

        'description':
            product["description"] ?? "",

        'imageUrl':
            product["imageUrl"] ??
            product["image"] ??
            "",

        // PRICE INFORMATION
        'price': _formatPrice(effectivePrice),

        'originalPrice':
            _formatPrice(originalPrice),

        // CAMPAIGN INFORMATION
        'campaignId': campaign != null
            ? (campaign['campaignId'] ?? '')
                .toString()
            : '',

        'campaignOffer': campaign != null
            ? (campaign['offer'] ?? '')
                .toString()
            : '',

        // SELLER INFORMATION
        'sellerName':
            product["sellerName"] ??
            "Local Artisan",

        'sellerId':
            product["sellerId"] ?? "",

        // CART INFORMATION
        'quantity': 1,

        'addedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!context.mounted) return;

    // =======================================================
    // ADDED TO CART DIALOG
    // =======================================================

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            16,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F3E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF5A9B63),
                  size: 27,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Added to cart",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF292929),
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                "Your product is ready for checkout.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF777777),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 40,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFD66A16),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue shopping",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFCF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            16,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7D3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD66A16),
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Couldn't add to cart",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF292929),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFD66A16),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

    final cartRef = _cartReference(
      user.uid,
      productId,
    );

    try {
      if (newQuantity <= 0) {
        await cartRef.delete();
        return;
      }

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
      builder: (context, snapshot) {
        int totalQuantity = 0;

        if (snapshot.hasData) {
          for (final doc
              in snapshot.data!.docs) {
            final data = doc.data();

            final rawQuantity =
                data['quantity'];

            if (rawQuantity is int) {
              totalQuantity += rawQuantity;
            } else if (rawQuantity is num) {
              totalQuantity +=
                  rawQuantity.toInt();
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
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 27,
              ),
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
                        const EdgeInsets.symmetric(
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
          // ---------------------------------------------------
          // MINUS
          // ---------------------------------------------------

          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    const BorderRadius.horizontal(
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

          // ---------------------------------------------------
          // QUANTITY
          // ---------------------------------------------------

          Container(
            width: 55,
            decoration:
                const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(
                  color: Color(0xFFE4CDB9),
                ),
              ),
            ),
            child: Center(
              child: Text(
                quantity.toString(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF8D5314),
                ),
              ),
            ),
          ),

          // ---------------------------------------------------
          // PLUS
          // ---------------------------------------------------

          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    const BorderRadius.horizontal(
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
  // ADD TO CART / QUANTITY SECTION
  // =========================================================

  Widget _buildCartAction(
    BuildContext context,
    String productId,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

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
            side: const BorderSide(
              color: Color(0xFF8D5314),
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Add to Cart",
            style: TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final cartRef = _cartReference(
      user.uid,
      productId,
    );

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: cartRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: null,
              child: const SizedBox(
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
        // NOT IN CART
        // -----------------------------------------------------

        if (quantity <= 0) {
          return SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () async {
                try {
                  // ===========================================
                  // CHECK ACTIVE CAMPAIGN
                  // ===========================================

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

                  Map<String, dynamic>?
                      activeCampaign;

                  // ===========================================
                  // FIND CAMPAIGN FOR PRODUCT
                  // ===========================================

                  for (final doc
                      in campaignSnapshot
                          .docs) {
                    final data =
                        doc.data();

                    final status =
                        (data['status'] ??
                                '')
                            .toString();

                    final campaignProductId =
                        (data['productId'] ??
                                '')
                            .toString();

                    if (status ==
                            'Active' &&
                        campaignProductId ==
                            productId) {
                      activeCampaign = {
                        ...data,
                        'campaignId':
                            doc.id,
                      };

                      break;
                    }
                  }

                  // ===========================================
                  // ORIGINAL PRICE
                  // ===========================================

                  final double
                      originalPrice =
                      _toDouble(
                    product["price"],
                  );

                  // ===========================================
                  // EFFECTIVE PRICE
                  // ===========================================

                  double effectivePrice =
                      originalPrice;

                  if (activeCampaign !=
                      null) {
                    final double
                        discountPercentage =
                        _getDiscountPercentage(
                      activeCampaign,
                    );

                    if (discountPercentage >
                        0.0) {
                      effectivePrice =
                          _getCampaignPrice(
                        originalPrice,
                        discountPercentage,
                      );
                    }
                  }

                  // ===========================================
                  // SAVE TO CART
                  // ===========================================

                  await _addToCart(
                    context,
                    productId,
                    campaignPrice:
                        effectivePrice,
                    campaign:
                        activeCampaign,
                  );
                } catch (e) {
                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Could not check offer: $e",
                      ),
                    ),
                  );
                }
              },
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                        0xFF8D5314),
                side: const BorderSide(
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
              child: const Text(
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
        // ALREADY IN CART
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
  // PRODUCT ID
  // =========================================================

  final String productId = product["productId"] ?? "";

  // =========================================================
  // LIVE PRODUCT CATALOG STREAM
  // =========================================================

  final productStream = productId.trim().isNotEmpty
      ? FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .snapshots()
      : null;

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: productStream,
    builder: (context, productSnapshot) {
      // =======================================================
      // MERGE PRODUCT DATA
      // =======================================================

      final Map<String, dynamic> catalogProduct = {
        ...product,
      };

      if (productSnapshot.hasData &&
          productSnapshot.data!.exists) {
        final firestoreData = productSnapshot.data!.data();

        if (firestoreData != null) {
          catalogProduct.addAll(firestoreData);
        }
      }

      // =======================================================
      // PRODUCT DATA
      // =======================================================

      final String productTitle =
          (catalogProduct["title"] ?? "").toString();

      final String productDescription =
          (catalogProduct["description"] ?? "").toString();

      final String shortDescription =
          (catalogProduct["shortDescription"] ?? "").toString();

      final double originalPrice =
          _toDouble(catalogProduct["price"]);

      final String imagePath =
          (catalogProduct["imageUrl"] ??
                  catalogProduct["image"] ??
                  "")
              .toString();

      final String cleanImage =
          imagePath.replaceAll('"', '').trim();

      // =======================================================
      // SELLER
      // =======================================================

      final String rawSellerName =
          (catalogProduct["sellerName"] ?? "").toString();

      final String sellerName =
          rawSellerName.trim().isNotEmpty
              ? rawSellerName.trim()
              : "Local Artisan";

      final String sellerId =
          (catalogProduct["sellerId"] ?? "").toString();

      // =======================================================
      // CAMPAIGN STREAM
      // =======================================================

      final campaignStream = FirebaseFirestore.instance
          .collection('campaigns')
          .where(
            'enabled',
            isEqualTo: true,
          )
          .snapshots();

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: campaignStream,
        builder: (context, campaignSnapshot) {
          // =====================================================
          // FIND ACTIVE CAMPAIGN
          // =====================================================

          Map<String, dynamic>? activeCampaign;

          if (campaignSnapshot.hasData) {
            for (final doc in campaignSnapshot.data!.docs) {
              final data = doc.data();

              final String status =
                  (data['status'] ?? '').toString();

              final String campaignProductId =
                  (data['productId'] ?? '').toString();

              if (status == 'Active' &&
                  campaignProductId == productId) {
                activeCampaign = {
                  ...data,
                  'campaignId': doc.id,
                };
                break;
              }
            }
          }

          // =====================================================
          // CAMPAIGN / PRICE
          // =====================================================

          final double discountPercentage =
              activeCampaign != null
                  ? _getDiscountPercentage(activeCampaign)
                  : 0.0;

          final bool hasCampaign =
              activeCampaign != null &&
              discountPercentage > 0.0;

          final double campaignPrice =
              hasCampaign
                  ? _getCampaignPrice(
                      originalPrice,
                      discountPercentage,
                    )
                  : originalPrice;

          final String displayPrice =
              _formatPrice(campaignPrice);

          final String originalPriceText =
              _formatPrice(originalPrice);

          final String campaignName =
              activeCampaign?['name']?.toString().trim() ?? '';

          final String campaignOffer =
              activeCampaign?['offer']?.toString().trim() ?? '';

          // =====================================================
          // SCREEN
          // =====================================================

          return Scaffold(
            backgroundColor: const Color(0xFFFFFCF8),

            // ===================================================
            // APP BAR
            // ===================================================

            appBar: AppBar(
              toolbarHeight: 68,
              elevation: 0,
              backgroundColor: const Color(0xFFD66A16),
              foregroundColor: Colors.white,

              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 27,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),

              title: Text(
                productTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),

              actions: [
                _buildCartIcon(context),
                const SizedBox(width: 4),
              ],
            ),

            // ===================================================
            // BOTTOM ACTION BAR
            // ===================================================

            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(
                      color: Color(0xFFEDE2D8),
                      width: 0.8,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ADD TO CART
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: _buildCartAction(
                          context,
                          productId,
                        ),
                      ),
                    ),

                    const SizedBox(width: 9),

                    // BUY NOW
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BuyPage(
                                  productId: productId,
                                  productName: productTitle,
                                  productPrice: displayPrice,
                                  productImage: cleanImage,
                                  sellerName: sellerName,
                                  sellerId: sellerId,
                                  originalProductPrice:
                                      originalPriceText,
                                  campaignId: hasCampaign
                                      ? (activeCampaign![
                                                  'campaignId'] ??
                                              '')
                                          .toString()
                                      : '',
                                  campaignOffer: hasCampaign
                                      ? (activeCampaign!['offer'] ??
                                              '')
                                          .toString()
                                      : '',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF8D5314),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 19,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Buy Now",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===================================================
            // BODY
            // ===================================================

            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // =================================================
                // PRODUCT IMAGE
                // =================================================

                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: _buildImage(
                          context,
                          cleanImage,
                        ),
                      ),

                      // CAMPAIGN BADGE
                      if (hasCampaign)
                        Positioned(
                          right: 14,
                          top: 14,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD66A16),
                              borderRadius:
                                  BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(
                                    0.12,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_offer_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_formatPrice(discountPercentage)}% OFF',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // =================================================
                // PRODUCT CONTENT
                // =================================================

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    24,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        // =========================================
                        // TITLE
                        // =========================================

                        Text(
                          productTitle,
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202020),
                            letterSpacing: -0.35,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // =========================================
                        // PRICE
                        // =========================================

                        if (hasCampaign)
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.center,
                            children: [
                              Text(
                                '₹$originalPriceText',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF888888),
                                  decoration:
                                      TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                '₹$displayPrice',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD66A16),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            '₹$displayPrice',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD66A16),
                            ),
                          ),

                        // =========================================
                        // CAMPAIGN INFORMATION
                        // =========================================

                        if (hasCampaign &&
                            (campaignName.isNotEmpty ||
                                campaignOffer.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 11,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF4E9),
                                    Color(0xFFFFEBDD),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF4D1B5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration:
                                        const BoxDecoration(
                                      color: Color(0xFFFFDCC0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.local_offer_rounded,
                                      size: 18,
                                      color: Color(0xFFD66A16),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (campaignName.isNotEmpty)
                                          Text(
                                            campaignName,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color:
                                                  Color(0xFF4D2D17),
                                            ),
                                          ),
                                        if (campaignOffer.isNotEmpty)
                                          ...[
                                            if (campaignName
                                                .isNotEmpty)
                                              const SizedBox(
                                                height: 2,
                                              ),
                                            Text(
                                              campaignOffer,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Color(0xFF765D4D),
                                              ),
                                            ),
                                          ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 22),

                        // =========================================
                        // ABOUT THIS PRODUCT
                        // =========================================

                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD66A16),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              "About this product",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF252525),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 9),

                        // =========================================
                        // DESCRIPTION
                        // =========================================

                        if (shortDescription.trim().isNotEmpty)
                          Text(
                            shortDescription.trim(),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xFF666666),
                            ),
                          )
                        else if (productDescription
                            .trim()
                            .isNotEmpty)
                          Text(
                            productDescription.trim(),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xFF666666),
                            ),
                          )
                        else
                          const Text(
                            "Product details provided by the seller.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF777777),
                            ),
                          ),

                        // =========================================
                        // FULL DESCRIPTION
                        // =========================================

                        if (productDescription.trim().isNotEmpty &&
                            shortDescription.trim().isNotEmpty &&
                            productDescription.trim() !=
                                shortDescription.trim())
                          ...[
                            const SizedBox(height: 12),
                            Text(
                              productDescription.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.55,
                                color: Color(0xFF747474),
                              ),
                            ),
                          ],

                        const SizedBox(height: 20),

                        // =========================================
                        // SELLER CARD
                        // =========================================

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7F0),
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF0D8C5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration:
                                    const BoxDecoration(
                                  color: Color(0xFFFFE7D3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: Color(0xFFD66A16),
                                  size: 21,
                                ),
                              ),

                              const SizedBox(width: 11),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Sold by",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8A8A8A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      sellerName,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: Color(0xFF2B2B2B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (sellerId.trim().isNotEmpty)
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          const Color(0xFFF0D8C5),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified_outlined,
                                    size: 17,
                                    color: Color(0xFF5A9B63),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // =========================================
                        // PRODUCT CATALOG INFORMATION
                        // =========================================

                        _buildCatalogInformation(
                          catalogProduct,
                        ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  // =========================================================
  // PRODUCT CATALOG INFORMATION
  // =========================================================
  //
  // This section is data-driven. It reads customer-facing
  // catalogue fields from the Firestore products document and
  // renders only fields that actually contain values.
  // =========================================================

  Widget _buildCatalogInformation(
    Map<String, dynamic> catalogProduct,
  ) {
    final String category =
        _catalogString(catalogProduct['category']);

    final String subcategory =
        _catalogString(catalogProduct['subcategory']);

    final String sellerCategory =
        _catalogString(catalogProduct['sellerCategory']);

    final List<String> tags =
        _catalogStringList(catalogProduct['tags']);

    final bool hasCategory =
        category.isNotEmpty;

    final bool hasSubcategory =
        subcategory.isNotEmpty;

    final bool hasSellerCategory =
        sellerCategory.isNotEmpty;

    final bool hasTags =
        tags.isNotEmpty;

    if (!hasCategory &&
        !hasSubcategory &&
        !hasSellerCategory &&
        !hasTags) {
      return const SizedBox.shrink();
    }

    final List<Widget> informationRows = [];

    if (hasCategory) {
      informationRows.add(
        _buildCatalogRow(
          icon: Icons.category_outlined,
          label: "Category",
          value: category,
        ),
      );
    }

    if (hasSubcategory) {
      if (informationRows.isNotEmpty) {
        informationRows.add(
          const SizedBox(height: 10),
        );
      }

      informationRows.add(
        _buildCatalogRow(
          icon: Icons.grid_view_rounded,
          label: "Subcategory",
          value: subcategory,
        ),
      );
    }

    if (hasSellerCategory) {
      if (informationRows.isNotEmpty) {
        informationRows.add(
          const SizedBox(height: 10),
        );
      }

      informationRows.add(
        _buildCatalogRow(
          icon: Icons.storefront_outlined,
          label: "Seller category",
          value: sellerCategory,
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 21,
              decoration: BoxDecoration(
                color: const Color(0xFFD66A16),
                borderRadius:
                    BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              "Product information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF252525),
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (informationRows.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              13,
              13,
              13,
              13,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color: const Color(0xFFE9E2DD),
              ),
            ),
            child: Column(
              children: informationRows,
            ),
          ),

        if (hasTags) ...[
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 4,
                height: 21,
                decoration: BoxDecoration(
                  color: const Color(0xFFD66A16),
                  borderRadius:
                      BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                "Tags",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF252525),
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final tag in tags)
                _buildTagChip(tag),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCatalogRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        _buildInfoIcon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A8A8A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF303030),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0D1B8),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7B4A25),
        ),
      ),
    );
  }

  String _catalogString(dynamic value) {
    if (value == null) return '';

    return value
        .toString()
        .trim();
  }

  List<String> _catalogStringList(dynamic value) {
    if (value is! Iterable) {
      return const [];
    }

    final List<String> values = [];

    for (final item in value) {
      final String text =
          item?.toString().trim() ?? '';

      if (text.isNotEmpty &&
          !values.contains(text)) {
        values.add(text);
      }
    }

    return values;
  }

  // =========================================================
  // INFO ICON
  // =========================================================

  Widget _buildInfoIcon(
    IconData icon,
  ) {
    return Container(
      width: 36,
      height: 36,
      decoration:
          const BoxDecoration(
        color: Color(0xFFFFF0E4),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: Color(0xFFD66A16),
      ),
    );
  }

}
