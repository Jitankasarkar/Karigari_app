import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:proto_app/screens/seller_order_details_page.dart';

class SellerOrdersPage extends StatefulWidget {
  final String sellerId;
  final String initialFilter;

  const SellerOrdersPage({
    super.key,
    required this.sellerId,
    this.initialFilter = 'all',
  });

  @override
  State<SellerOrdersPage> createState() =>
      _SellerOrdersPageState();
}

class _SellerOrdersPageState
    extends State<SellerOrdersPage> {

  // =========================================================
  // THEME
  // =========================================================

  static const Color primaryOrange =
      Color(0xFFE4862D);

  static const Color deepOrange =
      Color(0xFFD66A16);

  static const Color background =
      Color(0xFFF8F5F0);

  static const Color cardBackground =
      Color(0xFFFFFEFC);

  static const Color textPrimary =
      Color(0xFF172033);

  static const Color textSecondary =
      Color(0xFF6B7280);

  static const Color pendingColor =
      Color(0xFFF59E0B);

  static const Color completedColor =
      Color(0xFF10B981);

  static const Color cancelledColor =
      Color(0xFFEF4444);

  static const Color processingColor =
      Color(0xFF6366F1);

  // =========================================================
  // FIRESTORE
  // =========================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // STATE
  // =========================================================

  late String selectedFilter;

  String searchQuery = '';

  @override
  void initState() {
    super.initState();

    selectedFilter =
        widget.initialFilter.toLowerCase();

    if (![
      'all',
      'pending',
      'completed',
      'cancelled',
    ].contains(selectedFilter)) {
      selectedFilter = 'all';
    }
  }

  // =========================================================
  // PRICE
  // =========================================================

  double _price(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _normalizedStatus(
    Map<String, dynamic> data,
  ) {
    final raw =
        data['paymentStatus']
                ?.toString()
                .toLowerCase()
                .trim() ??
            '';

    if (raw == 'done' ||
        raw == 'completed' ||
        raw == 'paid') {
      return 'completed';
    }

    if (raw == 'pending') {
      return 'pending';
    }

    if (raw == 'cancelled' ||
        raw == 'canceled') {
      return 'cancelled';
    }

    if (raw == 'processing') {
      return 'processing';
    }

    return raw;
  }

  String _statusText(
    Map<String, dynamic> data,
  ) {
    final status =
        _normalizedStatus(data);

    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'processing':
        return 'Processing';
      default:
        if (status.isEmpty) {
          return 'Unknown';
        }

        return status[0].toUpperCase() +
            status.substring(1);
    }
  }

  Color _statusColor(
    Map<String, dynamic> data,
  ) {
    switch (_normalizedStatus(data)) {
      case 'completed':
        return completedColor;
      case 'pending':
        return pendingColor;
      case 'cancelled':
        return cancelledColor;
      case 'processing':
        return processingColor;
      default:
        return textSecondary;
    }
  }

  // =========================================================
  // DATE
  // =========================================================

  DateTime? _date(
    Map<String, dynamic> data,
  ) {
    final value =
        data['timestamp'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Date unavailable';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour =
        date.hour % 12 == 0
            ? 12
            : date.hour % 12;

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final suffix =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year} • '
        '$hour:$minute $suffix';
  }

  // =========================================================
  // SEARCH MATCH
  // =========================================================

  bool _matchesSearch(
    String orderId,
    Map<String, dynamic> data,
  ) {
    if (searchQuery.trim().isEmpty) {
      return true;
    }

    final query =
        searchQuery
            .toLowerCase()
            .trim();

    final product =
        data['productName']
                ?.toString()
                .toLowerCase() ??
            '';

    final customer =
        data['fullName']
                ?.toString()
                .toLowerCase() ??
            '';

    final email =
        data['email']
                ?.toString()
                .toLowerCase() ??
            '';

    final phone =
        data['phone']
                ?.toString()
                .toLowerCase() ??
            '';

    final id =
        orderId.toLowerCase();

    return product.contains(query) ||
        customer.contains(query) ||
        email.contains(query) ||
        phone.contains(query) ||
        id.contains(query);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,
      body:
          StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where(
              'sellerId',
              isEqualTo:
                  widget.sellerId,
            )
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color:
                    primaryOrange,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'Unable to load orders.\n\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final allDocs =
              snapshot.data?.docs ?? [];

          // ===================================================
          // COUNTS
          // ===================================================

          int pendingCount = 0;
          int completedCount = 0;
          int cancelledCount = 0;

          for (final doc in allDocs) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            switch (
                _normalizedStatus(data)) {
              case 'pending':
                pendingCount++;
                break;

              case 'completed':
                completedCount++;
                break;

              case 'cancelled':
                cancelledCount++;
                break;
            }
          }

          // ===================================================
          // FILTER
          // ===================================================

          final filteredDocs =
              allDocs.where((doc) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            final status =
                _normalizedStatus(data);

            bool filterMatch = true;

            if (selectedFilter ==
                'pending') {
              filterMatch =
                  status == 'pending';
            } else if (selectedFilter ==
                'completed') {
              filterMatch =
                  status == 'completed';
            } else if (selectedFilter ==
                'cancelled') {
              filterMatch =
                  status == 'cancelled';
            }

            return filterMatch &&
                _matchesSearch(
                  doc.id,
                  data,
                );
          }).toList();

          // ===================================================
          // SORT NEWEST FIRST
          // ===================================================

          filteredDocs.sort(
            (a, b) {
              final aData =
                  a.data()
                      as Map<String, dynamic>;

              final bData =
                  b.data()
                      as Map<String, dynamic>;

              final aDate =
                  _date(aData);

              final bDate =
                  _date(bData);

              if (aDate == null &&
                  bDate == null) {
                return 0;
              }

              if (aDate == null) {
                return 1;
              }

              if (bDate == null) {
                return -1;
              }

              return bDate.compareTo(
                aDate,
              );
            },
          );

          return CustomScrollView(
            physics:
                const BouncingScrollPhysics(),
            slivers: [

              // =================================================
              // HEADER
              // =================================================

              SliverToBoxAdapter(
                child:
                    _buildHeader(
                  context,
                  allDocs.length,
                ),
              ),

              // =================================================
              // STATS
              // =================================================

              SliverToBoxAdapter(
                child:
                    _buildStats(
                  allDocs.length,
                  completedCount,
                  pendingCount,
                  cancelledCount,
                ),
              ),

              // =================================================
              // SEARCH
              // =================================================

              SliverToBoxAdapter(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    0,
                  ),
                  child:
                      _buildSearch(),
                ),
              ),

              // =================================================
              // FILTERS
              // =================================================

              SliverToBoxAdapter(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    0,
                  ),
                  child:
                      _buildFilters(),
                ),
              ),

              // =================================================
              // SECTION TITLE
              // =================================================

              SliverToBoxAdapter(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    22,
                    18,
                    12,
                  ),
                  child:
                      Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
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
                                  BorderRadius
                                      .circular(
                                5,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 9,
                          ),

                          Text(
                            _sectionTitle(),
                            style:
                                const TextStyle(
                              fontSize:
                                  20,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              color:
                                  textPrimary,
                            ),
                          ),
                        ],
                      ),

                      Text(
                        filteredDocs.length
                            .toString(),
                        style:
                            const TextStyle(
                          fontSize:
                              14,
                          fontWeight:
                              FontWeight
                                  .w700,
                          color:
                              textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // ORDERS
              // =================================================

              if (filteredDocs.isEmpty)
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    5,
                    18,
                    30,
                  ),
                  sliver:
                      SliverToBoxAdapter(
                    child:
                        _buildEmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    30,
                  ),
                  sliver:
                      SliverList(
                    delegate:
                        SliverChildBuilderDelegate(
                      (
                        context,
                        index,
                      ) {
                        final doc =
                            filteredDocs[
                                index];

                        final data =
                            doc.data()
                                as Map<
                                    String,
                                    dynamic>;

                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 12,
                          ),
                          child:
                              _buildOrderCard(
                            context,
                            doc.id,
                            data,
                          ),
                        );
                      },
                      childCount:
                          filteredDocs.length,
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
  // HEADER
  // =========================================================

  Widget _buildHeader(
    BuildContext context,
    int totalOrders,
  ) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context)
                .padding
                .top +
            12,
        18,
        24,
      ),
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFFF39A22),
            deepOrange,
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(
            34,
          ),
          bottomRight:
              Radius.circular(
            34,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              _headerButton(
                Icons.arrow_back_rounded,
                () =>
                    Navigator.pop(
                  context,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    Text(
                      'Orders',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            25,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    SizedBox(
                      height: 3,
                    ),

                    Text(
                      'Manage and track your orders',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            11.5,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                    ),
                  ],
                ),
              ),

              _headerButton(
                Icons.search_rounded,
                () {},
              ),
            ],
          ),

          const SizedBox(
            height: 22,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [

              Text(
                totalOrders.toString(),
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      44,
                  height: 0.9,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 3,
                ),
                child:
                    Text(
                  'total orders',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // HEADER BUTTON
  // =========================================================

  Widget _headerButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color:
          Colors.white.withOpacity(
        0.13,
      ),
      shape:
          const CircleBorder(),
      child:
          InkWell(
        customBorder:
            const CircleBorder(),
        onTap:
            onTap,
        child:
            SizedBox(
          width: 48,
          height: 48,
          child:
              Icon(
            icon,
            color:
                Colors.white,
            size:
                25,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATS
  // =========================================================

  Widget _buildStats(
    int total,
    int completed,
    int pending,
    int cancelled,
  ) {
    return Transform.translate(
      offset:
          const Offset(
        0,
        -8,
      ),
      child:
          Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 16,
        ),
        decoration:
            BoxDecoration(
          color:
              cardBackground,
          borderRadius:
              BorderRadius.circular(
            23,
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
                0.04,
              ),
              blurRadius:
                  16,
              offset:
                  const Offset(
                0,
                6,
              ),
            ),
          ],
        ),
        child:
            Row(
          children: [

            Expanded(
              child:
                  _statItem(
                Icons.shopping_bag_outlined,
                total,
                'All',
                deepOrange,
                const Color(
                  0xFFFFF1E4,
                ),
              ),
            ),

            _divider(),

            Expanded(
              child:
                  _statItem(
                Icons.check_circle_outline_rounded,
                completed,
                'Completed',
                completedColor,
                const Color(
                  0xFFEEF9F1,
                ),
              ),
            ),

            _divider(),

            Expanded(
              child:
                  _statItem(
                Icons.schedule_outlined,
                pending,
                'Pending',
                pendingColor,
                const Color(
                  0xFFFFF7E8,
                ),
              ),
            ),

            _divider(),

            Expanded(
              child:
                  _statItem(
                Icons.cancel_outlined,
                cancelled,
                'Cancelled',
                cancelledColor,
                const Color(
                  0xFFFFF0F0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    int value,
    String label,
    Color color,
    Color background,
  ) {
    return Column(
      children: [

        Container(
          width:
              42,
          height:
              42,
          decoration:
              BoxDecoration(
            color:
                background,
            shape:
                BoxShape.circle,
          ),
          child:
              Icon(
            icon,
            color:
                color,
            size:
                21,
          ),
        ),

        const SizedBox(
          height:
              7,
        ),

        Text(
          value.toString(),
          style:
              const TextStyle(
            fontSize:
                22,
            fontWeight:
                FontWeight.w800,
            color:
                textPrimary,
          ),
        ),

        const SizedBox(
          height:
              1,
        ),

        Text(
          label,
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            fontSize:
                9.5,
            fontWeight:
                FontWeight.w600,
            color:
                textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width:
          1,
      height:
          60,
      color:
          const Color(
        0xFFE9E2DA,
      ),
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearch() {
    return Container(
      height:
          54,
      decoration:
          BoxDecoration(
        color:
            cardBackground,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5DED6,
          ),
        ),
      ),
      child:
          TextField(
        onChanged:
            (value) {
          setState(() {
            searchQuery =
                value;
          });
        },
        decoration:
            const InputDecoration(
          border:
              InputBorder.none,
          prefixIcon:
              Icon(
            Icons.search_rounded,
            color:
                textSecondary,
          ),
          hintText:
              'Search by customer, product or order ID',
          hintStyle:
              TextStyle(
            color:
                Color(
              0xFF9CA3AF,
            ),
            fontSize:
                13,
          ),
          contentPadding:
              EdgeInsets.symmetric(
            vertical:
                17,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FILTERS
  // =========================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child:
          Row(
        children: [

          _filterChip(
            'All',
            'all',
          ),

          const SizedBox(
            width:
                8,
          ),

          _filterChip(
            'Pending',
            'pending',
          ),

          const SizedBox(
            width:
                8,
          ),

          _filterChip(
            'Completed',
            'completed',
          ),

          const SizedBox(
            width:
                8,
          ),

          _filterChip(
            'Cancelled',
            'cancelled',
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String value,
  ) {
    final selected =
        selectedFilter ==
            value;

    Color color =
        primaryOrange;

    if (value ==
        'pending') {
      color =
          pendingColor;
    }

    if (value ==
        'completed') {
      color =
          completedColor;
    }

    if (value ==
        'cancelled') {
      color =
          cancelledColor;
    }

    return GestureDetector(
      onTap:
          () {
        setState(() {
          selectedFilter =
              value;
        });
      },
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              220,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              20,
          vertical:
              11,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? color
                  : cardBackground,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          border:
              Border.all(
            color:
                selected
                    ? color
                    : const Color(
                        0xFFE5DED6,
                      ),
          ),
        ),
        child:
            Text(
          label,
          style:
              TextStyle(
            color:
                selected
                    ? Colors.white
                    : textSecondary,
            fontSize:
                12,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _sectionTitle() {
    switch (selectedFilter) {
      case 'pending':
        return 'Pending Orders';
      case 'completed':
        return 'Completed Orders';
      case 'cancelled':
        return 'Cancelled Orders';
      default:
        return 'All Orders';
    }
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final productName =
        data['productName']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? data['productName']
            .toString()
        : 'Product unavailable';

    final customerName =
        data['fullName']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? data['fullName']
            .toString()
        : 'Customer unavailable';

    final email =
        data['email']
                ?.toString() ??
            '';

    final price =
        _price(
      data['productPrice'],
    );

    final imageUrl =
        data['productImage']
                ?.toString() ??
            data['productImageUrl']
                ?.toString() ??
            data['imageUrl']
                ?.toString() ??
            '';

    final status =
        _statusText(data);

    final statusColor =
        _statusColor(data);

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        onTap:
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SellerOrderDetailsPage(
                orderId:
                    orderId,
                orderData:
                    data,
              ),
            ),
          );
        },
        child:
            Container(
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration:
              BoxDecoration(
            color:
                cardBackground,
            borderRadius:
                BorderRadius.circular(
              21,
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
                    12,
                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child:
              Column(
            children: [

              // =============================================
              // TOP
              // =============================================

              Row(
                children: [

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [

                        Text(
                          '#${orderId.length > 12 ? orderId.substring(0, 12) : orderId}',
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                textPrimary,
                          ),
                        ),

                        const SizedBox(
                          height:
                              4,
                        ),

                        Text(
                          _formatDate(
                            _date(
                              data,
                            ),
                          ),
                          style:
                              const TextStyle(
                            fontSize:
                                10.5,
                            color:
                                textSecondary,
                            
                                
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          9,
                      vertical:
                          6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          statusColor
                              .withOpacity(
                        0.09,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [

                        Container(
                          width:
                              6,
                          height:
                              6,
                          decoration:
                              BoxDecoration(
                            color:
                                statusColor,
                            shape:
                                BoxShape
                                    .circle,
                          ),
                        ),

                        const SizedBox(
                          width:
                              5,
                        ),

                        Text(
                          status,
                          style:
                              TextStyle(
                            fontSize:
                                9.5,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    14,
              ),

              // =============================================
              // PRODUCT + CUSTOMER
              // =============================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [

                  _productImage(
                    imageUrl,
                  ),

                  const SizedBox(
                    width:
                        12,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [

                        Text(
                          productName,
                          maxLines:
                              2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                textPrimary,
                          ),
                        ),

                        const SizedBox(
                          height:
                              7,
                        ),

                        Row(
                          children: [

                            const Icon(
                              Icons
                                  .person_outline_rounded,
                              size:
                                  15,
                              color:
                                  textSecondary,
                            ),

                            const SizedBox(
                              width:
                                  5,
                            ),

                            Expanded(
                              child:
                                  Text(
                                customerName,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      11,
                                  fontWeight:FontWeight(600),
                                      
                                  color:
                                      textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (email
                            .isNotEmpty) ...[
                          const SizedBox(
                            height:
                                4,
                          ),
                          Row(
                            children: [

                              const Icon(
                                Icons
                                    .mail_outline_rounded,
                                size:
                                    14,
                                color:
                                    textSecondary,
                              ),

                              const SizedBox(
                                width:
                                    5,
                              ),

                              Expanded(
                                child:
                                    Text(
                                  email,
                                  maxLines:
                                      1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        10,
                                    color:
                                        textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style:
                        const TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight
                              .w800,
                      color:
                          deepOrange,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    13,
              ),

              // =============================================
              // VIEW DETAILS
              // =============================================

              SizedBox(
                width:
                    double.infinity,
                height:
                    42,
                child:
                    OutlinedButton(
                  onPressed:
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerOrderDetailsPage(
                          orderId:
                              orderId,
                          orderData:
                              data,
                        ),
                      ),
                    );
                  },
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        deepOrange,
                    side:
                        const BorderSide(
                      color:
                          primaryOrange,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                  ),
                  child:
                      const Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [

                      Text(
                        'View Details',
                        style:
                            TextStyle(
                          fontSize:
                              12,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      SizedBox(
                        width:
                            5,
                      ),

                      Icon(
                        Icons
                            .arrow_forward_rounded,
                        size:
                            16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT IMAGE
  // =========================================================

  Widget _productImage(
    String url,
  ) {
    if (url.trim().isEmpty) {
      return Container(
        width:
            64,
        height:
            64,
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
          size:
              25,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        15,
      ),
      child:
          Image.network(
        url,
        width:
            64,
        height:
            64,
        fit:
            BoxFit.cover,
        errorBuilder:
            (
          _,
          __,
          ___,
        ) {
          return Container(
            width:
                64,
            height:
                64,
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
                  .broken_image_outlined,
              color:
                  deepOrange,
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            20,
        vertical:
            38,
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
      child:
          Column(
        children: [

          Container(
            width:
                58,
            height:
                58,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFFF1E4,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child:
                const Icon(
              Icons
                  .inventory_2_outlined,
              color:
                  deepOrange,
              size:
                  28,
            ),
          ),

          const SizedBox(
            height:
                13,
          ),

          const Text(
            'No orders found',
            style:
                TextStyle(
              fontSize:
                  16,
              fontWeight:
                  FontWeight
                      .w800,
              color:
                  textPrimary,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          const Text(
            'Orders matching this filter will appear here.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize:
                  11.5,
              color:
                  textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}