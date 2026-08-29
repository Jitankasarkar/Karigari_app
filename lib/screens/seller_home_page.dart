import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerHomePage extends StatefulWidget {
  const SellerHomePage({super.key});

  @override
  State<SellerHomePage> createState() => _SellerHomePageState();
}

class _SellerHomePageState extends State<SellerHomePage> {
  // =========================================================
  // SELLER THEME
  // =========================================================

  static const Color primary = Color(0xFF172033);
  static const Color secondary = Color(0xFF1F2937);
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentLight = Color(0xFFE6FFFB);

  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color pendingColor = Color(0xFFF59E0B);
  static const Color completedColor = Color(0xFF10B981);
  static const Color revenueColor = Color(0xFF0F766E);

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
  // LOAD SELLER PROFILE
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
          final data = sellerDoc.data();

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
  // CONVERT PRICE
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
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (isLoadingSeller) {
      return const Center(
        child: CircularProgressIndicator(
          color: accent,
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
                color: accent,
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
          // STATISTICS
          // ===================================================

          int totalOrders =
              orders.length;

          int pendingOrders = 0;

          int completedOrders = 0;

          double totalRevenue = 0;

          for (final doc in orders) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            final status =
                data['paymentStatus']
                        ?.toString()
                        .toLowerCase()
                        .trim() ??
                    "";

            final price =
                _getPrice(
              data['productPrice'],
            );

            if (status == "pending") {
              pendingOrders++;
            }

            if (status == "done" ||
                status == "completed") {
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
            color: accent,

            onRefresh: _loadSeller,

            child: SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                30,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =================================================
                  // WELCOME SECTION
                  // =================================================

                  Text(
                    "Welcome back!",
                    style: TextStyle(
                      fontSize: 15,
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
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          textPrimary,
                      letterSpacing: -0.7,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    "Here's what's happening with your shop.",
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Colors.grey[600],
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // =================================================
                  // OVERVIEW HEADER
                  // =================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [

                      const Text(
                        "Overview",
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              textPrimary,
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              accentLight,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: const Row(
                          children: [

                            Icon(
                              Icons
                                  .fiber_manual_record,
                              size: 8,
                              color:
                                  accent,
                            ),

                            SizedBox(
                              width: 6,
                            ),

                            Text(
                              "Live",
                              style:
                                  TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color:
                                    Color(
                                  0xFF0F766E,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // =================================================
                  // PRODUCT STATISTICS
                  // =================================================

                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('products')
                        .where(
                          'sellerId',
                          isEqualTo:
                              sellerId,
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
                          height: 260,
                          child: Center(
                            child:
                                CircularProgressIndicator(
                              color: accent,
                            ),
                          ),
                        );
                      }

                      final totalProducts =
                          productSnapshot
                                  .data
                                  ?.docs
                                  .length ??
                              0;

                      return Column(
                        children: [

                          // =========================================
                          // TOP STAT CARDS
                          // =========================================

                          Row(
                            children: [

                              Expanded(
                                child:
                                    _buildModernStatCard(
                                  title:
                                      "Products",
                                  value:
                                      totalProducts
                                          .toString(),
                                  icon:
                                      Icons
                                          .inventory_2_outlined,
                                  iconColor:
                                      accent,
                                  backgroundColor:
                                      Colors.white,
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    _buildModernStatCard(
                                  title:
                                      "Orders",
                                  value:
                                      totalOrders
                                          .toString(),
                                  icon:
                                      Icons
                                          .shopping_bag_outlined,
                                  iconColor:
                                      const Color(
                                    0xFF6366F1,
                                  ),
                                  backgroundColor:
                                      Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // =========================================
                          // PENDING + COMPLETED
                          // =========================================

                          Row(
                            children: [

                              Expanded(
                                child:
                                    _buildModernStatCard(
                                  title:
                                      "Pending",
                                  value:
                                      pendingOrders
                                          .toString(),
                                  icon:
                                      Icons
                                          .schedule_outlined,
                                  iconColor:
                                      pendingColor,
                                  backgroundColor:
                                      Colors.white,
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    _buildModernStatCard(
                                  title:
                                      "Completed",
                                  value:
                                      completedOrders
                                          .toString(),
                                  icon:
                                      Icons
                                          .check_circle_outline,
                                  iconColor:
                                      completedColor,
                                  backgroundColor:
                                      Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // =========================================
                          // REVENUE
                          // =========================================

                          _buildModernRevenueCard(
                            totalRevenue,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  // =================================================
                  // RECENT ORDERS HEADER
                  // =================================================

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [

                      const Text(
                        "Recent Orders",
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              textPrimary,
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),

                          border:
                              Border.all(
                            color:
                                Colors.grey
                                    .shade200,
                          ),
                        ),

                        child: Text(
                          "${displayedOrders.length} recent",
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // =================================================
                  // NO ORDERS
                  // =================================================

                  if (displayedOrders.isEmpty)
                    _buildEmptyOrders(),

                  // =================================================
                  // ORDER LIST
                  // =================================================

                  ...displayedOrders.map(
                    (doc) {
                      final data =
                          doc.data()
                              as Map<String, dynamic>;

                      return _buildModernOrderCard(
                        data,
                      );
                    },
                  ),

                  const SizedBox(
                    height: 10,
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
  // MODERN STAT CARD
  // =========================================================

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color: backgroundColor,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.035,
            ),

            blurRadius: 12,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // =====================================================
          // ICON
          // =====================================================

          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color:
                  iconColor.withOpacity(
                0.10,
              ),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // =====================================================
          // VALUE
          // =====================================================

          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.w800,
              color:
                  textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          // =====================================================
          // TITLE
          // =====================================================

          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
              color:
                  textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MODERN REVENUE CARD
  // =========================================================

  Widget _buildModernRevenueCard(
    double revenue,
  ) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,

          colors: [
            Color(0xFF172033),
            Color(0xFF24364D),
          ],
        ),

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.08,
            ),

            blurRadius: 18,

            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [

          // =====================================================
          // REVENUE ICON
          // =====================================================

          Container(
            width: 52,
            height: 52,

            decoration:
                BoxDecoration(
              color:
                  accent.withOpacity(
                0.16,
              ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child: const Icon(
              Icons
                  .account_balance_wallet_outlined,
              color:
                  Color(0xFF5EEAD4),
              size: 27,
            ),
          ),

          const SizedBox(
            width: 15,
          ),

          // =====================================================
          // REVENUE TEXT
          // =====================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "Total Revenue",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        Color(0xFFCBD5E1),
                  ),
                ),

                const SizedBox(
                  height: 4,
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
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                const Text(
                  "From completed orders",
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // REVENUE ICON
          // =====================================================

          Container(
            padding:
                const EdgeInsets.all(8),

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withOpacity(
                0.06,
              ),

              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            child: const Icon(
              Icons
                  .trending_up_rounded,
              color:
                  Color(0xFF5EEAD4),
              size: 21,
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
        vertical: 32,
        horizontal: 20,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Column(
        children: [

          Container(
            width: 60,
            height: 60,

            decoration:
                BoxDecoration(
              color:
                  accentLight,

              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            child: const Icon(
              Icons
                  .shopping_bag_outlined,
              size: 29,
              color: accent,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            "No orders yet",
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color:
                  textPrimary,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            "Orders from your customers will appear here.",
            textAlign:
                TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              color:
                  Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MODERN ORDER CARD
  // =========================================================

  Widget _buildModernOrderCard(
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
        status == "completed") {
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
        statusText == "Completed";

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
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(17),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),

            blurRadius: 10,

            offset:
                const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [

          // =====================================================
          // PRODUCT ICON
          // =====================================================

          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF0FDFA,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: const Icon(
              Icons
                  .shopping_bag_outlined,
              color: accent,
              size: 23,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          // =====================================================
          // ORDER INFORMATION
          // =====================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  productName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "Buyer: $buyerName",
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  "$paymentMethod  •  ₹${price.toStringAsFixed(0)}",
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          // =====================================================
          // STATUS
          // =====================================================

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 9,
              vertical: 6,
            ),

            decoration:
                BoxDecoration(
              color:
                  statusColor.withOpacity(
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
                  width: 6,
                  height: 6,

                  decoration:
                      BoxDecoration(
                    color:
                        statusColor,
                    shape:
                        BoxShape.circle,
                  ),
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  statusText,
                  style:
                      TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}