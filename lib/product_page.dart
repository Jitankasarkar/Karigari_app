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
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

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
      builder: (context) {
        return const AIAssistant();
      },
    );
  }

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
          ),
        ),

        backgroundColor: const Color.fromARGB(
          255,
          214,
          112,
          22,
        ),

        actions: [
          // -------------------------------------------------
          // LOGOUT
          // -------------------------------------------------

          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            tooltip: 'Log Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/splash',
                (route) => false,
              );
            },
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
                hintText: 'Search products...',

                prefixIcon:
                    const Icon(Icons.search),

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =================================================
            // PRODUCTS
            // =================================================

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),

                builder: (context, snapshot) {
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

                  if (!snapshot.hasData) {
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
                    final data = doc.data()
                        as Map<String, dynamic>;

                    final title =
                        (data["title"] ?? "")
                            .toString()
                            .toLowerCase();

                    return title.contains(
                      _searchQuery,
                    );
                  }).toList();

                  // -------------------------------------------
                  // NO SEARCH RESULTS
                  // -------------------------------------------

                  if (products.isEmpty) {
                    return const Center(
                      child: Text(
                        "No products match your search.",
                      ),
                    );
                  }

                  // =================================================
                  // PRODUCT GRID
                  // =================================================

                  return GridView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 90,
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
                      // -------------------------------------------
                      // FIRESTORE PRODUCT
                      // -------------------------------------------

                      final product =
                          products[index].data()
                              as Map<String, dynamic>;

                      // -------------------------------------------
                      // PRODUCT DATA
                      // -------------------------------------------

                      final productTitle =
                          (product["title"] ?? "")
                              .toString();

                      final productDescription =
                          (product["description"] ?? "")
                              .toString();

                      final productPrice =
                          (product["price"] ?? "0")
                              .toString();

                      final productImage =
                          (product["imageUrl"] ?? "")
                              .toString();

                      // -------------------------------------------
                      // SELLER DATA
                      // -------------------------------------------

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
                          (product["sellerId"] ?? "")
                              .toString();

                      // =================================================
                      // PRODUCT CARD
                      // =================================================

                      return GestureDetector(
                        // -----------------------------------------------
                        // OPEN PRODUCT DETAIL
                        // -----------------------------------------------

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailPage(
                                product: {
                                  "title":
                                      productTitle,
                                  "description":
                                      productDescription,
                                  "price":
                                      productPrice,
                                  "imageUrl":
                                      productImage,
                                  "sellerName":
                                      sellerName,
                                  "sellerId":
                                      sellerId,
                                },
                              ),
                            ),
                          );
                        },

                        child: Card(
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),

                          elevation: 4,

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              // =====================================
                              // PRODUCT IMAGE
                              // =====================================

                              ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(
                                  top:
                                      Radius.circular(12),
                                ),

                                child: SizedBox(
                                  height: 180,
                                  width:
                                      double.infinity,

                                  child:
                                      Image.network(
                                    productImage,
                                    fit:
                                        BoxFit.cover,

                                    errorBuilder:
                                        (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return const Center(
                                        child: Icon(
                                          Icons
                                              .broken_image,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // =====================================
                              // PRODUCT TITLE
                              // =====================================

                              Padding(
                                padding:
                                    const EdgeInsets.all(
                                  8.0,
                                ),

                                child: Text(
                                  productTitle,

                                  maxLines: 2,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,

                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // =====================================
                              // BUY BUTTON + PRICE
                              // =====================================

                              Padding(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),

                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,

                                  children: [
                                    // ---------------------------------
                                    // BUY BUTTON
                                    // ---------------------------------

                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    BuyPage(
                                              productName:
                                                  productTitle,
                                              productPrice:
                                                  productPrice,
                                              productImage:
                                                  productImage,
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
                                            const Color
                                                .fromARGB(
                                          255,
                                          141,
                                          83,
                                          20,
                                        ),

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
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.white,
                                        ),
                                      ),
                                    ),

                                    // ---------------------------------
                                    // PRICE
                                    // ---------------------------------

                                    Text(
                                      '₹$productPrice',

                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.black,
                                        fontWeight:
                                            FontWeight.bold,
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
                },
              ),
            ),
          ],
        ),
      ),

      // =====================================================
      // AI ASSISTANT BUTTON
      // =====================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAIAssistant,

        backgroundColor:
            const Color.fromARGB(
          255,
          214,
          112,
          22,
        ),

        elevation: 6,

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
}