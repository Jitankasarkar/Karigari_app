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

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  // =========================================================
  // COLORS
  // =========================================================

  static const Color primaryOrange =
      Color.fromARGB(255, 214, 112, 22);

  static const Color darkOrange =
      Color.fromARGB(255, 141, 83, 20);

  static const Color cardBackground =
      Color.fromARGB(255, 249, 243, 251);

  // =========================================================
  // FIRESTORE
  // =========================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
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

  CollectionReference<Map<String, dynamic>>?
      get _cartReference {
    final uid = _userId;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cart');
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
      MaterialPageRoute(
        builder: (_) => const AddToCartPage(),
      ),
    );
  }

  // =========================================================
  // ADD PRODUCT TO CART
  // =========================================================

  Future<void> _addToCart(
    String productId,
    Map<String, dynamic> product,
  ) async {
    final cart = _cartReference;

    if (cart == null) {
      _showMessage(
        "Please log in to add items to cart.",
      );
      return;
    }

    final cartItem = cart.doc(productId);

    try {
      final existing = await cartItem.get();

      if (existing.exists) {
        final currentQuantity =
            _toInt(existing.data()?['quantity']);

        await cartItem.update({
          'quantity': currentQuantity + 1,
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        final sellerName =
            (product['sellerName'] ?? '')
                .toString()
                .trim();

        await cartItem.set({
          'productId': productId,

          'title':
              (product['title'] ?? '').toString(),

          'description':
              (product['description'] ?? '')
                  .toString(),

          'price':
              (product['price'] ?? '0').toString(),

          'imageUrl':
              (product['imageUrl'] ?? '')
                  .toString(),

          'sellerId':
              (product['sellerId'] ?? '')
                  .toString(),

          'sellerName':
              sellerName.isNotEmpty
                  ? sellerName
                  : 'Local Artisan',

          'quantity': 1,

          'addedAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      }

      _showMessage("Added to cart");
    } catch (e) {
      _showMessage(
        "Could not add to cart: $e",
      );
    }
  }

  // =========================================================
  // CHANGE CART QUANTITY
  // =========================================================

  Future<void> _changeQuantity(
    String productId,
    int change,
  ) async {
    final cart = _cartReference;

    if (cart == null) return;

    final cartItem = cart.doc(productId);

    try {
      final snapshot = await cartItem.get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data() ?? {};

      final currentQuantity =
          _toInt(data['quantity']);

      final newQuantity =
          currentQuantity + change;

      if (newQuantity <= 0) {
        await cartItem.delete();
        return;
      }

      await cartItem.update({
        'quantity': newQuantity,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage(
        "Could not update cart: $e",
      );
    }
  }

  // =========================================================
  // PRODUCT QUANTITY STREAM
  // =========================================================

  Stream<int> _productQuantityStream(
    String productId,
  ) {
    final cart = _cartReference;

    if (cart == null) {
      return Stream.value(0);
    }

    return cart
        .doc(productId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return 0;
      }

      final data = snapshot.data();

      return _toInt(
        data?['quantity'],
      );
    });
  }

  // =========================================================
  // SAFE INTEGER CONVERSION
  // =========================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
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
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 2),
        ),
      );
  }

  // =========================================================
  // OPEN PRODUCT DETAILS
  // =========================================================

  void _openProductDetails(
    String productId,
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product["title"] ?? "").toString();

    final productDescription =
        (product["description"] ?? "")
            .toString();

    final productPrice =
        (product["price"] ?? "0").toString();

    final productImage =
        (product["imageUrl"] ?? "").toString();

    final sellerName =
        (product["sellerName"] ?? "")
            .toString()
            .trim();

    final sellerId =
        (product["sellerId"] ?? "").toString();

    ProductDetailPage.open(
      context,
      {
        "productId": productId,
        "title": productTitle,
        "description": productDescription,
        "price": productPrice,
        "imageUrl": productImage,
        "sellerName":
            sellerName.isNotEmpty
                ? sellerName
                : "Local Artisan",
        "sellerId": sellerId,
      },
    );
  }

  // =========================================================
  // OPEN BUY PAGE
  // =========================================================

  void _openBuyPage(
    String productId,
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product["title"] ?? "").toString();

    final productPrice =
        (product["price"] ?? "0").toString();

    final productImage =
        (product["imageUrl"] ?? "").toString();

    final sellerName =
        (product["sellerName"] ?? "")
            .toString()
            .trim();

    final sellerId =
        (product["sellerId"] ?? "").toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyPage(
          productId: productId,
          productName: productTitle,
          productPrice: productPrice,
          productImage: productImage,
          sellerName:
              sellerName.isNotEmpty
                  ? sellerName
                  : "Local Artisan",
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

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/splash',
      (route) => false,
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final cart = _cartReference;

    return Scaffold(
      backgroundColor: Colors.white,

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: const Text(
          "Products",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),

        backgroundColor:
            primaryOrange,

        elevation: 0,

        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),

        actions: [
          // ---------------------------------------------------
          // CART
          // ---------------------------------------------------

          if (cart != null)
            StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: cart.snapshots(),

              builder:
                  (context, snapshot) {
                int totalQuantity = 0;

                if (snapshot.hasData) {
                  for (final doc
                      in snapshot.data!.docs) {
                    totalQuantity += _toInt(
                      doc.data()['quantity'],
                    );
                  }
                }

                return Stack(
                  clipBehavior:
                      Clip.none,

                  children: [
                    IconButton(
                      icon:
                          const Icon(
                        Icons
                            .shopping_cart_outlined,
                        color:
                            Colors.white,
                        size: 29,
                      ),

                      tooltip: 'Cart',

                      onPressed:
                          _openCart,
                    ),

                    if (totalQuantity > 0)
                      Positioned(
                        right: 2,
                        top: 2,

                        child:
                            Container(
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
                              BoxDecoration(
                            color:
                                Colors.red,

                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),

                            border:
                                Border.all(
                              color:
                                  primaryOrange,
                              width: 1.5,
                            ),
                          ),

                          child:
                              Text(
                            totalQuantity >
                                    99
                                ? '99+'
                                : totalQuantity
                                    .toString(),

                            textAlign:
                                TextAlign
                                    .center,

                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            IconButton(
              icon:
                  const Icon(
                Icons
                    .shopping_cart_outlined,
                color: Colors.white,
                size: 29,
              ),
              onPressed: _openCart,
            ),

          // ---------------------------------------------------
          // LOGOUT
          // ---------------------------------------------------

          IconButton(
            icon:
                const Icon(
              Icons.logout,
              color: Colors.white,
              size: 27,
            ),

            tooltip: 'Log Out',

            onPressed: _logout,
          ),

          const SizedBox(
            width: 4,
          ),
        ],
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: Column(
        children: [
          // ===================================================
          // SEARCH BAR
          // ===================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              10,
            ),

            child: TextField(
              controller:
                  _searchController,

              onChanged: (value) {
                setState(() {
                  _searchQuery =
                      value
                          .toLowerCase()
                          .trim();
                });
              },

              decoration:
                  InputDecoration(
                hintText:
                    'Search products...',

                hintStyle:
                    TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 17,
                ),

                prefixIcon:
                    const Icon(
                  Icons.search,
                  size: 30,
                ),

                suffixIcon:
                    _searchQuery
                            .isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(
                              Icons.clear,
                            ),

                            onPressed:
                                () {
                              _searchController
                                  .clear();

                              setState(() {
                                _searchQuery =
                                    '';
                              });
                            },
                          )
                        : null,

                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 17,
                  horizontal: 10,
                ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),

                  borderSide:
                      BorderSide(
                    color:
                        Colors.grey.shade700,
                    width: 1.3,
                  ),
                ),

                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),

                  borderSide:
                      BorderSide(
                    color:
                        Colors.grey.shade700,
                    width: 1.3,
                  ),
                ),

                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),

                  borderSide:
                      const BorderSide(
                    color:
                        primaryOrange,
                    width: 2,
                  ),
                ),

                filled: true,

                fillColor:
                    Colors.grey.shade50,
              ),
            ),
          ),

          // ===================================================
          // PRODUCTS
          // ===================================================

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: _firestore
                  .collection(
                    'products',
                  )
                  .snapshots(),

              builder:
                  (context, snapshot) {
                // ---------------------------------------------
                // LOADING
                // ---------------------------------------------

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          primaryOrange,
                    ),
                  );
                }

                // ---------------------------------------------
                // ERROR
                // ---------------------------------------------

                if (snapshot.hasError) {
                  return Center(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .all(20),

                      child:
                          Text(
                        "Error fetching products.\n\n"
                        "${snapshot.error}",
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                // ---------------------------------------------
                // NO PRODUCTS
                // ---------------------------------------------

                if (!snapshot.hasData ||
                    snapshot
                        .data!
                        .docs
                        .isEmpty) {
                  return const Center(
                    child:
                        Text(
                      "No products available.",
                      style:
                          TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                // ---------------------------------------------
                // FILTER PRODUCTS
                // ---------------------------------------------

                final products =
                    snapshot
                        .data!
                        .docs
                        .where(
                  (doc) {
                    final data =
                        doc.data();

                    final title =
                        (data["title"] ??
                                "")
                            .toString()
                            .toLowerCase();

                    final description =
                        (data["description"] ??
                                "")
                            .toString()
                            .toLowerCase();

                    final category =
                        (data["category"] ??
                                "")
                            .toString()
                            .toLowerCase();

                    final subcategory =
                        (data[
                                    "subcategory"] ??
                                "")
                            .toString()
                            .toLowerCase();

                    final tags =
                        _stringListToSearchableText(
                      data["tags"],
                    );

                    final keywords =
                        _stringListToSearchableText(
                      data["keywords"],
                    );

                    final searchTerms =
                        _stringListToSearchableText(
                      data["searchTerms"],
                    );

                    if (_searchQuery
                        .isEmpty) {
                      return true;
                    }

                    final searchableText =
                        '''
$title
$description
$category
$subcategory
$tags
$keywords
$searchTerms
'''
                            .toLowerCase();

                    return searchableText
                        .contains(
                      _searchQuery,
                    );
                  },
                ).toList();

                // ---------------------------------------------
                // NO SEARCH RESULTS
                // ---------------------------------------------

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                      children: [
                        Icon(
                          Icons.search_off,
                          size: 52,
                          color:
                              Colors.grey
                                  .shade400,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        const Text(
                          "No products match your search.",
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w600,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Text(
                          "Try another search term.",
                          style:
                              TextStyle(
                            color:
                                Colors.grey
                                    .shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // =================================================
                // PRODUCT GRID
                // =================================================

                return GridView.builder(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    14,
                    6,
                    14,
                    120,
                  ),

                  itemCount:
                      products.length,

                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,

                    // Horizontal gap
                    crossAxisSpacing: 12,

                    // More vertical gap
                    mainAxisSpacing: 18,

                    // Taller cards
                    childAspectRatio: 0.64,
                  ),

                  itemBuilder:
                      (context, index) {
                    final doc =
                        products[index];

                    final product =
                        doc.data();

                    return _buildProductCard(
                      doc.id,
                      product,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // =======================================================
      // AI ASSISTANT
      // =======================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAIAssistant,

        backgroundColor:
            primaryOrange,

        elevation: 7,

        icon:
            const Icon(
          Icons.auto_awesome,
          color: Colors.white,
        ),

        label:
            const Text(
          "Assistant",
          style:
              TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation
              .endFloat,
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    String productId,
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product["title"] ?? "")
            .toString();

    final productPrice =
        (product["price"] ?? "0")
            .toString();

    final productImage =
        (product["imageUrl"] ?? "")
            .toString();

    return GestureDetector(
      onTap: () {
        _openProductDetails(
          productId,
          product,
        );
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 1,
        ),

        decoration:
            BoxDecoration(
          color:
              cardBackground,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          // Downward card shadow
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.18,
              ),

              blurRadius: 7,

              spreadRadius: 0,

              offset:
                  const Offset(
                0,
                4,
              ),
            ),
          ],
        ),

        clipBehavior:
            Clip.antiAlias,

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [
            // =================================================
            // PRODUCT IMAGE
            // =================================================

            AspectRatio(
              aspectRatio: 1.0,

              child: Image.network(
                productImage,

                width:
                    double.infinity,

                fit:
                    BoxFit.cover,

                loadingBuilder:
                    (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress ==
                      null) {
                    return child;
                  }

                  return Container(
                    color:
                        Colors.grey.shade100,

                    child:
                        const Center(
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            primaryOrange,
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
                    color:
                        Colors.grey.shade100,

                    child:
                        Center(
                      child: Icon(
                        Icons
                            .broken_image_outlined,
                        size: 38,
                        color:
                            Colors.grey
                                .shade500,
                      ),
                    ),
                  );
                },
              ),
            ),

            // =================================================
            // PRODUCT INFORMATION
            // =================================================

            Expanded(
              child:
                  Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  10,
                  10,
                  10,
                  9,
                ),

                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    // =========================================
                    // TITLE
                    // =========================================

                    Text(
                      productTitle,

                      maxLines: 2,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .w700,

                        fontSize: 15,

                        height: 1.2,

                        color:
                            Color(
                          0xFF242124,
                        ),
                      ),
                    ),

                    // =========================================
                    // SPACE BETWEEN TITLE AND BOTTOM ROW
                    // =========================================

                    const Spacer(),

                    // =========================================
                    // BUY + PRICE
                    // =========================================

                    StreamBuilder<int>(
                      stream:
                          _productQuantityStream(
                        productId,
                      ),

                      builder:
                          (
                        context,
                        snapshot,
                      ) {
                        final quantity =
                            snapshot
                                    .data ??
                                0;

                        return SizedBox(
                          height: 42,

                          child:
                              Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .center,

                            children: [
                              // =================================
                              // BUY / CART CONTROL
                              // =================================

                              if (quantity ==
                                  0)
                                SizedBox(
                                  height:
                                      42,

                                  child:
                                      ElevatedButton(
                                    onPressed:
                                        () {
                                      // Add to cart
                                      // remains functional.
                                      _addToCart(
                                        productId,
                                        product,
                                      );
                                    },

                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          darkOrange,

                                      foregroundColor:
                                          Colors.white,

                                      elevation:
                                          1,

                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal:
                                            23,
                                      ),

                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          22,
                                        ),
                                      ),

                                      tapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,
                                    ),

                                    child:
                                        const Text(
                                      "Buy",

                                      style:
                                          TextStyle(
                                        fontSize:
                                            14,

                                        fontWeight:
                                            FontWeight
                                                .w500,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height:
                                      42,

                                  decoration:
                                      BoxDecoration(
                                    color:
                                        darkOrange,

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      22,
                                    ),
                                  ),

                                  child:
                                      Row(
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,

                                    children: [
                                      // MINUS
                                      SizedBox(
                                        width:
                                            38,

                                        height:
                                            42,

                                        child:
                                            IconButton(
                                          padding:
                                              EdgeInsets.zero,

                                          icon:
                                              const Icon(
                                            Icons
                                                .remove,
                                            color:
                                                Colors.white,
                                            size:
                                                17,
                                          ),

                                          onPressed:
                                              () {
                                            _changeQuantity(
                                              productId,
                                              -1,
                                            );
                                          },
                                        ),
                                      ),

                                      // QUANTITY
                                      Text(
                                        quantity
                                            .toString(),

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,

                                          fontWeight:
                                              FontWeight
                                                  .bold,

                                          fontSize:
                                              14,
                                        ),
                                      ),

                                      // PLUS
                                      SizedBox(
                                        width:
                                            38,

                                        height:
                                            42,

                                        child:
                                            IconButton(
                                          padding:
                                              EdgeInsets.zero,

                                          icon:
                                              const Icon(
                                            Icons
                                                .add,
                                            color:
                                                Colors.white,
                                            size:
                                                17,
                                          ),

                                          onPressed:
                                              () {
                                            _changeQuantity(
                                              productId,
                                              1,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // =================================
                              // SPACE
                              // =================================

                              const Spacer(),

                              // =================================
                              // PRICE - BOTTOM RIGHT
                              // =================================

                              Flexible(
                                child:
                                    Align(
                                  alignment:
                                      Alignment
                                          .centerRight,

                                  child:
                                      Text(
                                    '₹$productPrice',

                                    maxLines:
                                        1,

                                    overflow:
                                        TextOverflow
                                            .ellipsis,

                                    textAlign:
                                        TextAlign
                                            .right,

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w700,

                                      fontSize:
                                          15,

                                      color:
                                          Color(
                                        0xFF242124,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  String _stringListToSearchableText(
    dynamic value,
  ) {
    if (value is! List) {
      return '';
    }

    return value
        .map(
          (item) => item
              .toString()
              .toLowerCase(),
        )
        .join(' ');
  }
}