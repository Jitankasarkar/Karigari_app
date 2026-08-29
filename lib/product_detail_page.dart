import 'package:flutter/material.dart';
import 'package:proto_app/buy_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, String> product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  // =========================================================
  // OPEN PRODUCT DETAIL PAGE
  //
  // Use this method from the AI Assistant or ProductPage.
  // It preloads the product image before navigating.
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
        // If image preload fails, still open the page.
      }
    }

    if (!context.mounted) return;

    // ---------------------------------------------------------
    // LIGHTWEIGHT FADE TRANSITION
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

        // -----------------------------------------------------
        // IMAGE BUILDER
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // LOADING
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // ERROR
        // -----------------------------------------------------

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

  @override
  Widget build(BuildContext context) {
    // =========================================================
    // PRODUCT DATA
    // =========================================================

    final productTitle =
        product["title"] ?? "";

    final productDescription =
        product["description"] ?? "";

    final productPrice =
        product["price"] ?? "0";

    // ---------------------------------------------------------
    // IMAGE
    // ---------------------------------------------------------

    final imagePath =
        product["imageUrl"] ??
        product["image"] ??
        "";

    final cleanImage =
        imagePath.replaceAll('"', '').trim();

    // ---------------------------------------------------------
    // SELLER
    // ---------------------------------------------------------

    final rawSellerName =
        product["sellerName"] ?? "";

    final sellerName =
        rawSellerName.trim().isNotEmpty
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
          overflow: TextOverflow.ellipsis,

          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        backgroundColor:
            const Color(0xFFD66A16),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
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
            child: SingleChildScrollView(
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
                  // -------------------------------------------------
                  // PRODUCT NAME
                  // -------------------------------------------------

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

                  // -------------------------------------------------
                  // PRICE
                  // -------------------------------------------------

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

                  // -------------------------------------------------
                  // DESCRIPTION
                  // -------------------------------------------------

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

                  // -------------------------------------------------
                  // SELLER
                  // -------------------------------------------------

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

                  // -------------------------------------------------
                  // ITEM DETAILS
                  // -------------------------------------------------

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

          // =======================================================
          // BOTTOM ACTIONS
          // =======================================================

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
                      Colors.black.withOpacity(
                    0.08,
                  ),
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
                // ADD TO CART
                // =================================================

                Expanded(
                  child:
                      OutlinedButton(
                    onPressed: () {
                      // TODO:
                      // Add product to cart.
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
                            Color(
                          0xFF8D5314,
                        ),
                      ),

                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 14,
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

                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
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
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF8D5314,
                      ),

                      foregroundColor:
                          Colors.white,

                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 14,
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
                      "Buy Now",

                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w700,
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