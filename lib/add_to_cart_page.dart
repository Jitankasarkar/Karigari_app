import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/buy_page.dart';

class AddToCartPage extends StatelessWidget {
  const AddToCartPage({super.key});

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryOrange =
      Color.fromARGB(255, 214, 112, 22);

  static const Color darkOrange =
      Color.fromARGB(255, 141, 83, 20);

  // =========================================================
  // UPDATE QUANTITY
  // =========================================================

  Future<void> _updateQuantity(
    String cartId,
    int quantity,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final ref = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(cartId);

    if (quantity <= 0) {
      await ref.delete();
    } else {
      await ref.update({
        "quantity": quantity,
      });
    }
  }

  // =========================================================
  // REMOVE ITEM
  // =========================================================

  Future<void> _removeItem(
    String cartId,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(cartId)
        .delete();
  }

  // =========================================================
  // CHECKOUT CART
  // =========================================================

  void _checkoutCart(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>
        items,
  ) {
    if (items.isEmpty) return;

    final cartItems =
        items.map((doc) {
      final data = doc.data();

      return {
        "cartId": doc.id,
        "productId":
            (data["productId"] ?? doc.id)
                .toString(),
        "title":
            (data["title"] ?? "")
                .toString(),
        "description":
            (data["description"] ?? "")
                .toString(),
        "price":
            (data["price"] ?? "0")
                .toString(),
        "imageUrl":
            (data["imageUrl"] ?? "")
                .toString(),
        "sellerName":
            (data["sellerName"] ??
                    "Local Artisan")
                .toString(),
        "sellerId":
            (data["sellerId"] ?? "")
                .toString(),
        "quantity":
            (data["quantity"] ?? 1) as int,
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
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "My Cart",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor:
              primaryOrange,
        ),
        body: const Center(
          child: Text(
            "Please log in to view your cart.",
          ),
        ),
      );
    }

    final cartStream =
        FirebaseFirestore
            .instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .orderBy(
              'addedAt',
              descending: true,
            )
            .snapshots();

    return Scaffold(

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        title: const Text(
          "My Cart",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        backgroundColor:
            primaryOrange,

        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: cartStream,

        builder:
            (context, snapshot) {

          // ---------------------------------------------------
          // LOADING
          // ---------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          // ---------------------------------------------------
          // ERROR
          // ---------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),

                child: Text(
                  "Unable to load cart.\n\n"
                  "${snapshot.error}",
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final items =
              snapshot.data?.docs ?? [];

          // ---------------------------------------------------
          // EMPTY CART
          // ---------------------------------------------------

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [

                  Icon(
                    Icons
                        .shopping_cart_outlined,
                    size: 80,
                    color:
                        Colors.grey.shade400,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    "Your cart is empty",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    "Add some handmade products!",
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // ---------------------------------------------------
          // TOTAL
          // ---------------------------------------------------

          int subtotal = 0;

          for (final doc in items) {
            final data = doc.data();

            final price =
                int.tryParse(
                      (data["price"] ?? "0")
                          .toString(),
                    ) ??
                    0;

            final quantity =
                (data["quantity"] ?? 1)
                    as int;

            subtotal +=
                price * quantity;
          }

          const int deliveryCharge = 20;
          const int platformFee = 1;

          final total =
              subtotal +
              deliveryCharge +
              platformFee;

          // ---------------------------------------------------
          // CART LIST
          // ---------------------------------------------------

          return Column(
            children: [

              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.all(12),

                  itemCount:
                      items.length,

                  itemBuilder:
                      (context, index) {

                    final doc =
                        items[index];

                    final data =
                        doc.data();

                    final title =
                        (data["title"] ?? "")
                            .toString();

                    final imageUrl =
                        (data["imageUrl"] ?? "")
                            .toString();

                    final sellerName =
                        (data["sellerName"] ??
                                "Local Artisan")
                            .toString();

                    final price =
                        int.tryParse(
                              (data["price"] ??
                                      "0")
                                  .toString(),
                            ) ??
                            0;

                    final quantity =
                        (data["quantity"] ??
                                1)
                            as int;

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),

                      elevation: 3,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

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
                            // IMAGE
                            // =================================

                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                10,
                              ),

                              child:
                                  Image.network(
                                imageUrl,

                                width: 95,
                                height: 95,

                                fit: BoxFit.cover,

                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    width: 95,
                                    height: 95,
                                    color:
                                        Colors
                                            .grey
                                            .shade100,
                                    child:
                                        const Icon(
                                      Icons
                                          .broken_image,
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            // =================================
                            // INFORMATION
                            // =================================

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

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
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    "Sold by: $sellerName",

                                    maxLines: 1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    style:
                                        TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors
                                              .grey
                                              .shade600,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 6,
                                  ),

                                  Text(
                                    "₹$price",

                                    style:
                                        const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color:
                                          darkOrange,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  Row(
                                    children: [

                                      // MINUS

                                      IconButton(
                                        onPressed: () {
                                          _updateQuantity(
                                            doc.id,
                                            quantity - 1,
                                          );
                                        },

                                        icon:
                                            const Icon(
                                          Icons
                                              .remove_circle_outline,
                                        ),

                                        color:
                                            darkOrange,

                                        padding:
                                            EdgeInsets
                                                .zero,

                                        constraints:
                                            const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),

                                      Text(
                                        "$quantity",

                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      // PLUS

                                      IconButton(
                                        onPressed: () {
                                          _updateQuantity(
                                            doc.id,
                                            quantity + 1,
                                          );
                                        },

                                        icon:
                                            const Icon(
                                          Icons
                                              .add_circle_outline,
                                        ),

                                        color:
                                            darkOrange,

                                        padding:
                                            EdgeInsets
                                                .zero,

                                        constraints:
                                            const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),

                                      const Spacer(),

                                      // REMOVE

                                      IconButton(
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
                                            Colors.red,
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
              // SUMMARY
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
                      color:
                          Colors.black
                              .withOpacity(
                        0.08,
                      ),
                      blurRadius: 15,
                      offset:
                          const Offset(0, -4),
                    ),
                  ],
                ),

                child: SafeArea(
                  top: false,

                  child: Column(
                    children: [

                      _summaryRow(
                        "Subtotal",
                        subtotal,
                      ),

                      _summaryRow(
                        "Delivery",
                        deliveryCharge,
                      ),

                      _summaryRow(
                        "Platform Fee",
                        platformFee,
                      ),

                      const Divider(),

                      _summaryRow(
                        "Total",
                        total,
                        bold: true,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      SizedBox(
                        width: double.infinity,

                        child:
                            ElevatedButton(
                          onPressed: () {
                            _checkoutCart(
                              context,
                              items,
                            );
                          },

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                darkOrange,

                            foregroundColor:
                                Colors.white,

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

                          child: Text(
                            "Checkout • ₹$total",

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
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),

          Text(
            "₹$amount",

            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}