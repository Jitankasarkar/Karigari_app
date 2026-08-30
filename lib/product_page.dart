import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:proto_app/buy_page.dart';
import 'package:proto_app/product_detail_page.dart';
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

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        return AIAssistant(
          
        );
      },
    );
  }

  // =========================================================
  // OPEN PRODUCT DETAILS
  // =========================================================

  void _openProductDetails(
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product["title"] ?? "").toString();

    final productDescription =
        (product["description"] ?? "").toString();

    final productPrice =
        (product["price"] ?? "0").toString();

    final productImage =
        (product["imageUrl"] ?? "").toString();

    final sellerName =
        (product["sellerName"] ?? "")
                .toString()
                .trim()
                .isNotEmpty
            ? product["sellerName"]
                .toString()
                .trim()
            : "Local Artisan";

    final sellerId =
        (product["sellerId"] ?? "").toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: {
            "title": productTitle,
            "description": productDescription,
            "price": productPrice,
            "imageUrl": productImage,
            "sellerName": sellerName,
            "sellerId": sellerId,
          },
        ),
      ),
    );
  }

  // =========================================================
  // OPEN BUY PAGE
  // =========================================================

  void _openBuyPage(
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
                .trim()
                .isNotEmpty
            ? product["sellerName"]
                .toString()
                .trim()
            : "Local Artisan";

    final sellerId =
        (product["sellerId"] ?? "").toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyPage(
          productName: productTitle,
          productPrice: productPrice,
          productImage: productImage,
          sellerName: sellerName,
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
    return Scaffold(
      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: const Text(
          "Products",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        backgroundColor: primaryOrange,

        elevation: 0,

        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),

            tooltip: 'Log Out',

            onPressed: _logout,
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: Padding(
        padding: const EdgeInsets.all(10),

        child: Column(
          children: [
            // =================================================
            // SEARCH BAR
            // =================================================

            TextField(
              controller: _searchController,

              onChanged: (value) {
                setState(() {
                  _searchQuery =
                      value.toLowerCase().trim();
                });
              },

              decoration: InputDecoration(
                hintText:
                    'Search products...',

                prefixIcon:
                    const Icon(Icons.search),

                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                            ),

                            onPressed: () {
                              _searchController.clear();

                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),

                filled: true,

                fillColor:
                    Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // PRODUCTS
            // =================================================

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore
                        .instance
                        .collection('products')
                        .snapshots(),

                builder:
                    (context, snapshot) {
                  // -------------------------------------------
                  // LOADING
                  // -------------------------------------------

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  // -------------------------------------------
                  // ERROR
                  // -------------------------------------------

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        "Error fetching products.",
                      ),
                    );
                  }

                  // -------------------------------------------
                  // NO DATA
                  // -------------------------------------------

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No products available.",
                      ),
                    );
                  }

                  // -------------------------------------------
                  // FILTER PRODUCTS
                  // -------------------------------------------

                  final products =
                      snapshot.data!.docs.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final title =
                        (data["title"] ?? "")
                            .toString()
                            .toLowerCase();

                    final description =
                        (data["description"] ?? "")
                            .toString()
                            .toLowerCase();

                    final category =
                        (data["category"] ?? "")
                            .toString()
                            .toLowerCase();

                    final subcategory =
                        (data["subcategory"] ?? "")
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

                    // ---------------------------------------
                    // CURRENT SEARCH
                    //
                    // We now search across the AI-generated
                    // catalog fields as well.
                    //
                    // This means a user can search things like:
                    // "wedding"
                    // "colourful"
                    // "traditional"
                    // "bangles"
                    // etc.
                    // ---------------------------------------

                    if (_searchQuery.isEmpty) {
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

                    return searchableText.contains(
                      _searchQuery,
                    );
                  }).toList();

                  // -------------------------------------------
                  // NO SEARCH RESULTS
                  // -------------------------------------------

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color:
                                Colors.grey.shade400,
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            "No products match your search.",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Try another search term.",
                            style: TextStyle(
                              color:
                                  Colors.grey.shade600,
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
                        const EdgeInsets.only(
                      bottom: 100,
                    ),

                    itemCount:
                        products.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,

                      crossAxisSpacing: 10,

                      mainAxisSpacing: 10,

                      childAspectRatio: 0.65,
                    ),

                    itemBuilder:
                        (context, index) {
                      final product =
                          products[index].data()
                              as Map<String, dynamic>;

                      return _buildProductCard(
                        product,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // =====================================================
      // AI ASSISTANT BUTTON
      // =====================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAIAssistant,

        backgroundColor:
            primaryOrange,

        elevation: 7,

        icon: const Icon(
          Icons.auto_awesome,
          color: Colors.white,
        ),

        label: const Text(
          "Assistant",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    Map<String, dynamic> product,
  ) {
    final productTitle =
        (product["title"] ?? "").toString();

    final productDescription =
        (product["description"] ?? "").toString();

    final productPrice =
        (product["price"] ?? "0").toString();

    final productImage =
        (product["imageUrl"] ?? "").toString();

    final sellerName =
        (product["sellerName"] ?? "")
                .toString()
                .trim()
                .isNotEmpty
            ? product["sellerName"]
                .toString()
                .trim()
            : "Local Artisan";

    final sellerId =
        (product["sellerId"] ?? "").toString();

    return GestureDetector(
      onTap: () {
        _openProductDetails(
          product,
        );
      },

      child: Card(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),

        elevation: 4,

        clipBehavior:
            Clip.antiAlias,

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ===============================================
            // PRODUCT IMAGE
            // ===============================================

            SizedBox(
              height: 180,
              width: double.infinity,

              child: Image.network(
                productImage,

                fit: BoxFit.cover,

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

                  return const Center(
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
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

                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 35,
                      ),
                    ),
                  );
                },
              ),
            ),

            // ===============================================
            // PRODUCT TITLE
            // ===============================================

            Padding(
              padding:
                  const EdgeInsets.all(8),

              child: Text(
                productTitle,

                maxLines: 2,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const Spacer(),

            // ===============================================
            // BUY BUTTON + PRICE
            // ===============================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),

              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                children: [
                  // -----------------------------------------
                  // BUY
                  // -----------------------------------------

                  ElevatedButton(
                    onPressed: () {
                      _openBuyPage(
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

                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      textStyle:
                          const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                    child:
                        const Text(
                      "Buy",
                    ),
                  ),

                  // -----------------------------------------
                  // PRICE
                  // -----------------------------------------

                  Flexible(
                    child: Text(
                      '₹$productPrice',

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Colors.black,

                        fontWeight:
                            FontWeight.bold,
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
          (item) =>
              item.toString().toLowerCase(),
        )
        .join(' ');
  }
}