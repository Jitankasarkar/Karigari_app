import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:proto_app/screens/seller_products_page.dart';
import 'package:proto_app/screens/seller_orders_page.dart';

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key});

  @override
  State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  // =========================================================
  // SELLER THEME
  // =========================================================

  static const Color primaryOrange = Color(0xFFE4862D);
  static const Color deepOrange = Color(0xFFD66A16);

  static const Color navy = Color(0xFF172033);
  static const Color navyLight = Color(0xFF24364D);

  static const Color background = Color(0xFFF8F5F0);
  static const Color cardBackground = Color(0xFFFFFEFC);

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color accent = Color(0xFF14B8A6);
  static const Color accentLight = Color(0xFFE5F8F4);

  static const Color pendingColor = Color(0xFFF59E0B);
  static const Color completedColor = Color(0xFF10B981);

  // =========================================================
  // FIREBASE
  // =========================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // =========================================================
  // SELLER DATA
  // =========================================================

  String sellerName = "Seller";
  String sellerId = "";

  bool isLoadingSeller = true;

  // =========================================================
  // INITIALIZE
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadSeller();
  }

  // =========================================================
  // LOAD SELLER
  // =========================================================

  Future<void> _loadSeller() async {
    try {
      final User? currentUser =
          _auth.currentUser;

      if (currentUser == null) {
        if (mounted) {
          setState(() {
            isLoadingSeller = false;
          });
        }

        return;
      }

      final String currentSellerId =
          currentUser.uid;

      final sellerDoc =
          await _firestore
              .collection('sellers')
              .doc(currentSellerId)
              .get();

      if (!mounted) return;

      setState(() {
        sellerId = currentSellerId;

        if (sellerDoc.exists) {
          final data =
              sellerDoc.data();

          sellerName =
              data?['shopName']
                          ?.toString()
                          .trim()
                      .isNotEmpty ==
                  true
              ? data!['shopName']
                  .toString()
                  .trim()
              : "Seller";
        }

        isLoadingSeller = false;
      });
    } catch (e) {
      debugPrint(
        "Error loading seller: $e",
      );

      if (!mounted) return;

      setState(() {
        isLoadingSeller = false;
      });
    }
  }

  // =========================================================
  // PRICE CONVERSION
  // =========================================================

  double _getPrice(dynamic price) {
    if (price == null) {
      return 0;
    }

    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(
          price.toString(),
        ) ??
        0;
  }

  // =========================================================
  // OPEN PRODUCTS
  // =========================================================

  void _openProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductsPage(
          sellerId: sellerId,
          sellerName: sellerName,
        ),
      ),
    );
  }

  // =========================================================
  // OPEN ORDERS
  // =========================================================
void _openOrders() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SellerOrdersPage(
        sellerId: sellerId,
      ),
    ),
  );
}

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (isLoadingSeller) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryOrange,
        ),
      );
    }

    if (sellerId.isEmpty) {
      return const Center(
        child: Text(
          "Unable to load seller information.",
        ),
      );
    }

    return Container(
      color: background,

      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where(
              'sellerId',
              isEqualTo: sellerId,
            )
            .snapshots(),

        builder: (
          context,
          orderSnapshot,
        ) {
          // ===================================================
          // LOADING
          // ===================================================

          if (orderSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryOrange,
              ),
            );
          }

          // ===================================================
          // ERROR
          // ===================================================

          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),

                child: Text(
                  "Error loading orders:\n"
                  "${orderSnapshot.error}",
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          // ===================================================
          // ORDERS
          // ===================================================

          final orders =
              orderSnapshot.data?.docs ?? [];

          // ===================================================
          // STATIC DASHBOARD COUNTS
          //
          // The cards themselves are static.
          // Only these numbers are calculated from Firestore.
          // ===================================================

          final int totalOrders =
              orders.length;

          int pendingOrders = 0;
          int completedOrders = 0;
          double totalRevenue = 0;

          for (final doc in orders) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            final String status =
                data['paymentStatus']
                        ?.toString()
                        .toLowerCase()
                        .trim() ??
                    "";

            final double price =
                _getPrice(
              data['productPrice'],
            );

            // -----------------------------------------------
            // PENDING
            // -----------------------------------------------

            if (status == "pending") {
              pendingOrders++;
            }

            // -----------------------------------------------
            // COMPLETED / PAID
            // -----------------------------------------------

            if (status == "done" ||
                status == "completed" ||
                status == "paid") {
              completedOrders++;

              totalRevenue += price;
            }
          }

          // ===================================================
          // RECENT ORDERS
          // ===================================================

          final recentOrders =
              List<QueryDocumentSnapshot>.from(
            orders,
          );

          recentOrders.sort(
            (a, b) {
              final aData =
                  a.data()
                      as Map<String, dynamic>;

              final bData =
                  b.data()
                      as Map<String, dynamic>;

              final Timestamp? aTime =
                  aData['timestamp']
                          is Timestamp
                      ? aData['timestamp']
                          as Timestamp
                      : null;

              final Timestamp? bTime =
                  bData['timestamp']
                          is Timestamp
                      ? bData['timestamp']
                          as Timestamp
                      : null;

              if (aTime == null &&
                  bTime == null) {
                return 0;
              }

              if (aTime == null) {
                return 1;
              }

              if (bTime == null) {
                return -1;
              }

              return bTime.compareTo(
                aTime,
              );
            },
          );

          final displayedOrders =
              recentOrders
                  .take(5)
                  .toList();

          // ===================================================
          // MAIN CONTENT
          // ===================================================

          return RefreshIndicator(
            color: primaryOrange,

            onRefresh: _loadSeller,

            child: SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                35,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =================================================
                  // WELCOME / SHOP HERO
                  // =================================================

                  _buildShopHero(),

                  const SizedBox(
                    height: 24,
                  ),

                  // =================================================
                  // OVERVIEW HEADER
                  // =================================================

                  _buildSectionHeader(
                    title: "Overview",
                    trailing:
                        _buildLiveBadge(),
                  ),

                  const SizedBox(
                    height: 13,
                  ),

                  // =================================================
                  // PRODUCT + ORDER STAT CARDS
                  // =================================================

                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('products')
                        .where(
                          'sellerId',
                          isEqualTo: sellerId,
                        )
                        .snapshots(),

                    builder: (
                      context,
                      productSnapshot,
                    ) {
                      if (productSnapshot
                              .connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 300,

                          child: Center(
                            child:
                                CircularProgressIndicator(
                              color:
                                  primaryOrange,
                            ),
                          ),
                        );
                      }

                      final int totalProducts =
                          productSnapshot
                                  .data
                                  ?.docs
                                  .length ??
                              0;

                      return Column(
                        children: [

                          // =========================================
                          // TOP TWO CARDS
                          // =========================================

                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              // =====================================
                              // PRODUCTS
                              // =====================================

                              Expanded(
                                child:
                                    _buildOverviewCard(
                                  title:
                                      "Products",

                                  value:
                                      totalProducts
                                          .toString(),

                                  icon:
                                      Icons
                                          .inventory_2_outlined,

                                  color:
                                      accent,

                                  background:
                                      const Color(
                                    0xFFF0FBF8,
                                  ),

                                  onTap:
                                      _openProducts,
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              // =====================================
                              // ORDERS
                              // =====================================

                              Expanded(
                                child:
                                    _buildOverviewCard(
                                  title:
                                      "Orders",

                                  value:
                                      totalOrders
                                          .toString(),

                                  icon:
                                      Icons
                                          .shopping_bag_outlined,

                                  color:
                                      const Color(
                                    0xFF7167E8,
                                  ),

                                  background:
                                      const Color(
                                    0xFFF3F1FF,
                                  ),

                                  onTap:
                                      _openOrders,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // =========================================
                          // STATIC PENDING + COMPLETED CARDS
                          // =========================================

                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [

                              // =====================================
                              // PENDING
                              // =====================================

                              Expanded(
                                child:
                                    _buildOverviewCard(
                                  title:
                                      "Pending",

                                  // Only this number changes.
                                  value:
                                      pendingOrders
                                          .toString(),

                                  icon:
                                      Icons
                                          .schedule_outlined,

                                  color:
                                      pendingColor,

                                  background:
                                      const Color(
                                    0xFFFFF7E8,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              // =====================================
                              // COMPLETED
                              // =====================================

                              Expanded(
                                child:
                                    _buildOverviewCard(
                                  title:
                                      "Completed",

                                  // Only this number changes.
                                  value:
                                      completedOrders
                                          .toString(),

                                  icon:
                                      Icons
                                          .check_circle_outline_rounded,

                                  color:
                                      completedColor,

                                  background:
                                      const Color(
                                    0xFFEEF9F1,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          // =========================================
                          // REVENUE
                          // =========================================

                          _buildRevenueCard(
                            totalRevenue,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // =================================================
                  // RECENT ORDERS
                  // =================================================

                  _buildSectionHeader(
                    title:
                        "Recent Orders",

                    trailing:
                        _buildRecentBadge(
                      displayedOrders.length,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // =================================================
                  // EMPTY STATE
                  // =================================================

                  if (displayedOrders.isEmpty)
                    _buildEmptyOrders(),

                  // =================================================
                  // RECENT ORDER LIST
                  // =================================================

                  ...displayedOrders.map(
                    (doc) {
                      final data =
                          doc.data()
                              as Map<String, dynamic>;

                      return _buildOrderCard(
                        data,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 5,
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
  // SHOP HERO
  // =========================================================

  Widget _buildShopHero() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        18,
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            cardBackground,

        borderRadius:
            BorderRadius.circular(
          26,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFFEDE5DC,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.035,
            ),

            blurRadius:
                18,

            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),

      child: Row(
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "Welcome back!",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  sellerName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        textPrimary,
                    letterSpacing:
                        -0.7,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  "Here's what's happening\n"
                  "with your shop.",

                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color:
                        textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Container(
            width: 78,
            height: 78,

            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,

                colors: [
                  Color(0xFFFFE8C4),
                  Color(0xFFFFD49C),
                ],
              ),

              shape:
                  BoxShape.circle,

              border:
                  Border.all(
                color:
                    Colors.white,
                width: 4,
              ),
            ),

            child:
                const Icon(
              Icons.storefront_rounded,
              size: 38,
              color:
                  deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION HEADER
  // =========================================================

  Widget _buildSectionHeader({
    required String title,
    required Widget trailing,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Row(
          children: [

            Container(
              width: 4,
              height: 21,

              decoration:
                  BoxDecoration(
                color:
                    primaryOrange,

                borderRadius:
                    BorderRadius.circular(
                  5,
                ),
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Text(
              title,

              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color:
                    textPrimary,
                letterSpacing:
                    -0.3,
              ),
            ),
          ],
        ),

        trailing,
      ],
    );
  }

  // =========================================================
  // LIVE BADGE
  // =========================================================

  Widget _buildLiveBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),

      decoration:
          BoxDecoration(
        color:
            accentLight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: const Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(
            Icons.circle,
            size: 7,
            color: accent,
          ),

          SizedBox(
            width: 6,
          ),

          Text(
            "Live",

            style:
                TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(
                0xFF0F766E,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RECENT BADGE
  // =========================================================

  Widget _buildRecentBadge(
    int count,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFFE9E2DA,
          ),
        ),
      ),

      child: Text(
        "$count recent",

        style:
            const TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
          color:
              textSecondary,
        ),
      ),
    );
  }

  // =========================================================
  // OVERVIEW CARD
  // =========================================================

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color background,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,

      borderRadius:
          BorderRadius.circular(
        22,
      ),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        splashColor:
            color.withOpacity(
          0.08,
        ),

        highlightColor:
            color.withOpacity(
          0.04,
        ),

        child: Container(
          height: 158,

          padding:
              const EdgeInsets.fromLTRB(
            15,
            15,
            13,
            13,
          ),

          decoration:
              BoxDecoration(
            color:
                cardBackground,

            borderRadius:
                BorderRadius.circular(
              22,
            ),

            border:
                Border.all(
              color:
                  color.withOpacity(
                0.16,
              ),
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(
                  0.025,
                ),

                blurRadius:
                    13,

                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),

          child: Stack(
            children: [

              Positioned(
                right: 0,
                top: 4,

                child: SizedBox(
                  width: 52,
                  height: 48,

                  child:
                      GridView.builder(
                    physics:
                        const NeverScrollableScrollPhysics(),

                    padding:
                        EdgeInsets.zero,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          3,

                      crossAxisSpacing:
                          7,

                      mainAxisSpacing:
                          7,
                    ),

                    itemCount:
                        9,

                    itemBuilder:
                        (
                      _,
                      __,
                    ) {
                      return Container(
                        decoration:
                            BoxDecoration(
                          color:
                              color.withOpacity(
                            0.18,
                          ),

                          shape:
                              BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Container(
                    width: 48,
                    height: 48,

                    decoration:
                        BoxDecoration(
                      color:
                          background,

                      shape:
                          BoxShape.circle,
                    ),

                    child: Icon(
                      icon,

                      color:
                          color,

                      size: 24,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    value,

                    style:
                        TextStyle(
                      fontSize: 29,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          color,
                      letterSpacing:
                          -0.7,
                    ),
                  ),

                  const SizedBox(
                    height: 1,
                  ),

                  Text(
                    title,

                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          textSecondary,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  if (onTap != null)
                    GestureDetector(
                      onTap:
                          onTap,

                      behavior:
                          HitTestBehavior
                              .opaque,

                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          Text(
                            "View all",

                            style:
                                TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  color,
                            ),
                          ),

                          const SizedBox(
                            width: 3,
                          ),

                          Icon(
                            Icons
                                .arrow_forward_rounded,

                            size: 12,

                            color:
                                color,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // REVENUE CARD
  // =========================================================

  Widget _buildRevenueCard(
    double revenue,
  ) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        14,
        16,
      ),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,

          colors: [
            Color(0xFF151B26),
            Color(0xFF24364D),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.10,
            ),

            blurRadius:
                18,

            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 54,
            height: 54,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF0F766E,
              ).withOpacity(
                0.25,
              ),

              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),

            child:
                const Icon(
              Icons
                  .account_balance_wallet_outlined,

              color:
                  Color(
                0xFF5EEAD4,
              ),

              size: 27,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "Total Revenue",

                  style:
                      TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        Color(
                      0xFFCBD5E1,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  "₹${revenue.toStringAsFixed(0)}",

                  style:
                      const TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Colors.white,
                    letterSpacing:
                        -0.7,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                const Text(
                  "From completed orders",

                  style:
                      TextStyle(
                    fontSize: 10,
                    color:
                        Color(
                      0xFF94A3B8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withOpacity(
                0.06,
              ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child:
                const Icon(
              Icons
                  .trending_up_rounded,

              color:
                  Color(
                0xFF5EEAD4,
              ),

              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY ORDERS
  // =========================================================

  Widget _buildEmptyOrders() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),

      decoration:
          BoxDecoration(
        color:
            cardBackground,

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFFEDE5DC,
          ),
        ),
      ),

      child: Column(
        children: [

          Container(
            width: 56,
            height: 56,

            decoration:
                BoxDecoration(
              color:
                  accentLight,

              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            child:
                const Icon(
              Icons
                  .shopping_bag_outlined,

              size: 27,

              color:
                  accent,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            "No orders yet",

            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color:
                  textPrimary,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            "Orders from your customers will appear here.",

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _buildOrderCard(
    Map<String, dynamic> data,
  ) {
    final productName =
        data['productName']
                ?.toString() ??
            "Unknown Product";

    final buyerName =
        data['fullName']
                ?.toString() ??
            "Unknown Buyer";

    final price =
        _getPrice(
      data['productPrice'],
    );

    final status =
        data['paymentStatus']
                ?.toString()
                .toLowerCase()
                .trim() ??
            "unknown";

    final paymentMethod =
        data['paymentMethod']
                ?.toString()
                .toUpperCase() ??
            "";

    String statusText;

    if (status == "done" ||
        status == "completed" ||
        status == "paid") {
      statusText = "Completed";
    } else if (status == "pending") {
      statusText = "Pending";
    } else {
      statusText =
          status.isEmpty
              ? "Unknown"
              : status;
    }

    final bool isCompleted =
        statusText ==
            "Completed";

    final Color statusColor =
        isCompleted
            ? completedColor
            : pendingColor;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(
        13,
      ),

      decoration:
          BoxDecoration(
        color:
            cardBackground,

        borderRadius:
            BorderRadius.circular(
          19,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFFEDE5DC,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),

            blurRadius:
                10,

            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFFF1E4,
              ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child:
                const Icon(
              Icons
                  .shopping_bag_outlined,

              color:
                  deepOrange,

              size: 22,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  productName,

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  "Buyer: $buyerName",

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "$paymentMethod  •  ₹${price.toStringAsFixed(0)}",

                  style:
                      const TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(
                      0xFF9CA3AF,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      statusColor
                          .withOpacity(
                    0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [

                    Container(
                      width: 5,
                      height: 5,

                      decoration:
                          BoxDecoration(
                        color:
                            statusColor,

                        shape:
                            BoxShape.circle,
                      ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      statusText,

                      style:
                          TextStyle(
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              const Icon(
                Icons
                    .arrow_forward_rounded,

                size: 16,

                color:
                    Color(
                  0xFF9CA3AF,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}