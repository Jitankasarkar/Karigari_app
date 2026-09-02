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

  // =========================================================
  // CART REFERENCE
  //
  // Firestore structure:
  //
  // users
  //   └── userId
  //        └── cart
  //             └── productId
  //
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
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

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
        // -----------------------------------------------------
        // CART
        // -----------------------------------------------------

        'cartId': doc.id,

        // -----------------------------------------------------
        // PRODUCT
        // -----------------------------------------------------

        'productId': (data['productId'] ?? doc.id).toString(),

        'title': (data['title'] ?? '').toString(),

        'description': (data['description'] ?? '').toString(),

        // This is the CURRENT price stored in the cart.
        //
        // For a normal product:
        //     price = original price
        //
        // For a campaign product:
        //     price = discounted price
        //
        'price': (data['price'] ?? '0').toString(),

        // Original product price.
        //
        // For a normal product this will be the same
        // as "price".
        //
        'originalPrice':
            (data['originalPrice'] ?? data['price'] ?? '0').toString(),

        'imageUrl': (data['imageUrl'] ?? '').toString(),

        // -----------------------------------------------------
        // CAMPAIGN
        // -----------------------------------------------------

        'campaignId': (data['campaignId'] ?? '').toString(),

        'campaignOffer': (data['campaignOffer'] ?? '').toString(),

        // -----------------------------------------------------
        // SELLER
        // -----------------------------------------------------

        'sellerName':
            (data['sellerName'] ?? 'Local Artisan').toString(),

        'sellerId':
            (data['sellerId'] ?? '').toString(),

        // -----------------------------------------------------
        // QUANTITY
        // -----------------------------------------------------

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

    // =======================================================
    // NOT LOGGED IN
    // =======================================================

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Cart',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: primaryOrange,
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
        ),
        body: const Center(
          child: Text(
            'Please log in to view your cart.',
          ),
        ),
      );
    }

    // =======================================================
    // CART STREAM
    // =======================================================

    final cartStream = _cartReference(
      user.uid,
    ).orderBy(
      'addedAt',
      descending: true,
    ).snapshots();

    return Scaffold(
      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryOrange,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: cartStream,
        builder: (context, snapshot) {
          // -------------------------------------------------
          // LOADING
          // -------------------------------------------------

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // -------------------------------------------------
          // ERROR
          // -------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 50,
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

                    const SizedBox(height: 8),

                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // -------------------------------------------------
          // CART ITEMS
          // -------------------------------------------------

          final items =
              snapshot.data?.docs ?? [];

          // -------------------------------------------------
          // EMPTY CART
          // -------------------------------------------------

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Add some handmade products!',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // -------------------------------------------------
          // CALCULATE SUBTOTAL
          //
          // IMPORTANT:
          // "price" is always the effective price.
          //
          // Therefore:
          //
          // Normal product:
          // 399 × 1 = 399
          //
          // Discounted product:
          // 479 × 1 = 479
          //
          // -------------------------------------------------

          int subtotal = 0;

          for (final doc in items) {
            final data = doc.data();

            final price = _toInt(
              data['price'],
            );

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

          final total =
              subtotal +
              deliveryCharge +
              platformFee;

          // =================================================
          // CART CONTENT
          // =================================================

          return Column(
            children: [
              // =================================================
              // ITEMS
              // =================================================

              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    20,
                  ),
                  itemCount: items.length,
                  itemBuilder:
                      (context, index) {
                    final doc =
                        items[index];

                    final data =
                        doc.data();

                    // -----------------------------------------
                    // PRODUCT DATA
                    // -----------------------------------------

                    final title =
                        (data['title'] ?? '')
                            .toString();

                    final imageUrl =
                        (data['imageUrl'] ?? '')
                            .toString();

                    final sellerName =
                        (data['sellerName'] ??
                                'Local Artisan')
                            .toString();

                    // -----------------------------------------
                    // PRICE
                    // -----------------------------------------

                    final price =
                        _toInt(
                      data['price'],
                    );

                    final originalPrice =
                        _toInt(
                      data['originalPrice'] ??
                          data['price'],
                    );

                    // -----------------------------------------
                    // CAMPAIGN
                    // -----------------------------------------

                    final campaignOffer =
                        (data['campaignOffer'] ??
                                '')
                            .toString()
                            .trim();

                    final hasCampaign =
                        campaignOffer.isNotEmpty &&
                        originalPrice > price;

                    // -----------------------------------------
                    // QUANTITY
                    // -----------------------------------------

                    final quantity =
                        _toInt(
                      data['quantity'],
                      fallback: 1,
                    );

                    // =================================================
                    // ITEM CARD
                    // =================================================

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),

                      elevation: 2,

                      shadowColor:
                          Colors.black
                              .withOpacity(0.08),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),

                      clipBehavior:
                          Clip.antiAlias,

                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          10,
                        ),

                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            // =================================
                            // PRODUCT IMAGE
                            // =================================

                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),

                              child: SizedBox(
                                width: 100,
                                height: 100,

                                child:
                                    imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
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
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            // =================================
                            // PRODUCT INFORMATION
                            // =================================

                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,

                                children: [
                                  // --------------------------------
                                  // TITLE
                                  // --------------------------------

                                  Text(
                                    title,

                                    maxLines: 2,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 5,
                                  ),

                                  // --------------------------------
                                  // SELLER
                                  // --------------------------------

                                  Text(
                                    'Sold by: $sellerName',

                                    maxLines: 1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        TextStyle(
                                      fontSize: 12,
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 7,
                                  ),

                                  // =================================
                                  // CAMPAIGN OFFER
                                  // =================================

                                  if (hasCampaign)
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),

                                      decoration:
                                          BoxDecoration(
                                        color:
                                            const Color(
                                          0xFFFFE8D5,
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
                                            width: 4,
                                          ),

                                          Text(
                                            campaignOffer,

                                            style:
                                                const TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w800,
                                              color:
                                                  primaryOrange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (hasCampaign)
                                    const SizedBox(
                                      height: 6,
                                    ),

                                  // =================================
                                  // PRICE
                                  // =================================

                                  if (hasCampaign)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .center,

                                      children: [
                                        // ORIGINAL PRICE
                                        Text(
                                          '₹$originalPrice',

                                          style:
                                              TextStyle(
                                            fontSize: 13,
                                            color: Colors
                                                .grey
                                                .shade500,
                                            decoration:
                                                TextDecoration
                                                    .lineThrough,
                                            decorationThickness:
                                                2,
                                          ),
                                        ),

                                        const SizedBox(
                                          width: 8,
                                        ),

                                        // DISCOUNTED PRICE
                                        Text(
                                          '₹$price',

                                          style:
                                              const TextStyle(
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                darkOrange,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    // NORMAL PRICE
                                    Text(
                                      '₹$price',

                                      style:
                                          const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            darkOrange,
                                      ),
                                    ),

                                  const SizedBox(
                                    height: 9,
                                  ),

                                  // =================================
                                  // QUANTITY CONTROL
                                  // =================================

                                  Row(
                                    children: [
                                      Container(
                                        height: 38,

                                        decoration:
                                            BoxDecoration(
                                          border:
                                              Border.all(
                                            color: Colors
                                                .grey
                                                .shade300,
                                          ),

                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            10,
                                          ),
                                        ),

                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize
                                                  .min,

                                          children: [
                                            // -------------------------
                                            // MINUS
                                            // -------------------------

                                            InkWell(
                                              borderRadius:
                                                  const BorderRadius
                                                      .horizontal(
                                                left:
                                                    Radius.circular(
                                                  10,
                                                ),
                                              ),

                                              onTap: () {
                                                _updateQuantity(
                                                  doc.id,
                                                  quantity -
                                                      1,
                                                );
                                              },

                                              child:
                                                  const SizedBox(
                                                width: 38,
                                                height: 38,

                                                child:
                                                    Icon(
                                                  Icons
                                                      .remove,
                                                  size:
                                                      18,
                                                  color:
                                                      darkOrange,
                                                ),
                                              ),
                                            ),

                                            // -------------------------
                                            // QUANTITY
                                            // -------------------------

                                            Container(
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth:
                                                    35,
                                              ),

                                              alignment:
                                                  Alignment
                                                      .center,

                                              child:
                                                  Text(
                                                '$quantity',

                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                            ),

                                            // -------------------------
                                            // PLUS
                                            // -------------------------

                                            InkWell(
                                              borderRadius:
                                                  const BorderRadius
                                                      .horizontal(
                                                right:
                                                    Radius.circular(
                                                  10,
                                                ),
                                              ),

                                              onTap: () {
                                                _updateQuantity(
                                                  doc.id,
                                                  quantity +
                                                      1,
                                                );
                                              },

                                              child:
                                                  const SizedBox(
                                                width: 38,
                                                height: 38,

                                                child:
                                                    Icon(
                                                  Icons
                                                      .add,
                                                  size:
                                                      18,
                                                  color:
                                                      darkOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Spacer(),

                                      // -------------------------
                                      // DELETE
                                      // -------------------------

                                      IconButton(
                                        tooltip:
                                            'Remove',

                                        onPressed: () {
                                          _removeItem(
                                            doc.id,
                                          );
                                        },

                                        icon:
                                            const Icon(
                                          Icons
                                              .delete_outline,
                                        ),

                                        color:
                                            Colors.red
                                                .shade400,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // =================================================
              // ORDER SUMMARY
              // =================================================

              Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16,
                ),

                decoration:
                    BoxDecoration(
                  color: Colors.white,

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.08),
                      blurRadius: 18,
                      offset:
                          const Offset(
                        0,
                        -5,
                      ),
                    ),
                  ],
                ),

                child: SafeArea(
                  top: false,

                  child: Column(
                    children: [
                      // -----------------------------------------
                      // SUBTOTAL
                      // -----------------------------------------

                      _summaryRow(
                        'Subtotal',
                        subtotal,
                      ),

                      // -----------------------------------------
                      // DELIVERY
                      // -----------------------------------------

                      _summaryRow(
                        'Delivery',
                        deliveryCharge,
                      ),

                      // -----------------------------------------
                      // PLATFORM FEE
                      // -----------------------------------------

                      _summaryRow(
                        'Platform Fee',
                        platformFee,
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      const Divider(),

                      // -----------------------------------------
                      // TOTAL
                      // -----------------------------------------

                      _summaryRow(
                        'Total',
                        total,
                        bold: true,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // -----------------------------------------
                      // CHECKOUT BUTTON
                      // -----------------------------------------

                      SizedBox(
                        width:
                            double.infinity,

                        child:
                            ElevatedButton(
                          onPressed: () {
                            _checkoutCart(
                              context,
                              items,
                            );
                          },

                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                darkOrange,

                            foregroundColor:
                                Colors.white,

                            elevation: 0,

                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 15,
                            ),

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
                              Text(
                            'Checkout • ₹$total',

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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

  // =========================================================
  // SUMMARY ROW
  // =========================================================

  Widget _summaryRow(
    String label,
    int amount, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Text(
            label,

            style: TextStyle(
              fontSize: 15,
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),

          Text(
            '₹$amount',

            style: TextStyle(
              fontSize: 15,
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}