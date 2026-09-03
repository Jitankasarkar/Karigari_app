import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerOrderDetailsPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const SellerOrderDetailsPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<SellerOrderDetailsPage> createState() =>
      _SellerOrderDetailsPageState();
}

class _SellerOrderDetailsPageState
    extends State<SellerOrderDetailsPage> {

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

  static const Color completedColor =
      Color(0xFF10B981);

  static const Color pendingColor =
      Color(0xFFF59E0B);

  static const Color cancelledColor =
      Color(0xFFEF4444);

  static const Color processingColor =
      Color(0xFF6366F1);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool isUpdatingPayment = false;

  // =========================================================
  // STRING
  // =========================================================

  String _string(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value =
          data[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  // =========================================================
  // PRICE
  // =========================================================

  double _price(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // TIMESTAMP
  // =========================================================

  DateTime? _timestamp(
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

  // =========================================================
  // STATUS
  // =========================================================

  String _status(
    Map<String, dynamic> data,
  ) {
    final raw =
        _string(
          data,
          [
            'paymentStatus',
            'orderStatus',
          ],
        ).toLowerCase();

    if (raw == 'done' ||
        raw == 'completed' ||
        raw == 'paid') {
      return 'Completed';
    }

    if (raw == 'pending') {
      return 'Pending';
    }

    if (raw == 'cancelled' ||
        raw == 'canceled') {
      return 'Cancelled';
    }

    if (raw == 'processing') {
      return 'Processing';
    }

    if (raw.isEmpty) {
      return 'Unknown';
    }

    return raw[0].toUpperCase() +
        raw.substring(1);
  }

  // =========================================================
  // PAYMENT STATUS
  // =========================================================

  String _paymentStatus(
    Map<String, dynamic> data,
  ) {
    final raw =
        _string(
          data,
          [
            'paymentStatus',
          ],
        ).toLowerCase();

    if (raw == 'done' ||
        raw == 'completed' ||
        raw == 'paid') {
      return 'Paid';
    }

    if (raw == 'pending') {
      return 'Pending';
    }

    if (raw == 'cancelled' ||
        raw == 'canceled') {
      return 'Cancelled';
    }

    if (raw.isEmpty) {
      return 'Unavailable';
    }

    return raw[0].toUpperCase() +
        raw.substring(1);
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'Completed':
      case 'Paid':
        return completedColor;

      case 'Pending':
        return pendingColor;

      case 'Cancelled':
        return cancelledColor;

      case 'Processing':
        return processingColor;

      default:
        return textSecondary;
    }
  }

  // =========================================================
  // DATE
  // =========================================================

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
  // MARK PAYMENT COMPLETED / PENDING
  // =========================================================

  Future<void> _togglePaymentStatus(
    Map<String, dynamic> data,
  ) async {
    if (isUpdatingPayment) {
      return;
    }

    final current =
        _string(
          data,
          [
            'paymentStatus',
          ],
        ).toLowerCase();

    final bool isCurrentlyCompleted =
        current == 'done' ||
        current == 'completed' ||
        current == 'paid';

    final String newStatus =
        isCurrentlyCompleted
            ? 'pending'
            : 'completed';

    setState(() {
      isUpdatingPayment = true;
    });

    try {
      await _firestore
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'paymentStatus':
            newStatus,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              newStatus ==
                      'completed'
                  ? completedColor
                  : pendingColor,
          content:
              Text(
            newStatus ==
                    'completed'
                ? 'Payment marked as completed'
                : 'Payment marked as pending',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              cancelledColor,
          content:
              Text(
            'Unable to update payment status: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingPayment =
              false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,
      body:
          StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
        stream:
            _firestore
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
        builder:
            (
          context,
          snapshot,
        ) {
          // =================================================
          // DATA
          // =================================================

          Map<String, dynamic>
              data =
              Map<String, dynamic>.from(
            widget.orderData,
          );

          if (snapshot.hasData &&
              snapshot.data!.exists) {
            final firestoreData =
                snapshot.data!.data();

            if (firestoreData !=
                null) {
              data.addAll(
                firestoreData,
              );
            }
          }

          // =================================================
          // FIELDS
          // =================================================

          final status =
              _status(data);

          final paymentStatus =
              _paymentStatus(data);

          final statusColor =
              _statusColor(status);

          final paymentColor =
              _statusColor(
            paymentStatus,
          );

          final productName =
              _string(
            data,
            [
              'productName',
            ],
          );

          final buyerName =
              _string(
            data,
            [
              'fullName',
              'customerName',
              'name',
            ],
          );

          final email =
              _string(
            data,
            [
              'email',
              'customerEmail',
            ],
          );

          final phone =
              _string(
            data,
            [
              'phone',
              'phoneNumber',
              'mobile',
            ],
          );

          final paymentMethod =
              _string(
            data,
            [
              'paymentMethod',
            ],
          );

          final transactionId =
              _string(
            data,
            [
              'transactionId',
              'razorpayPaymentId',
              'paymentId',
            ],
          );

          final imageUrl =
              _string(
            data,
            [
              'productImage',
              'productImageUrl',
              'imageUrl',
              'image',
            ],
          );

          final address =
              _string(
            data,
            [
              'address',
              'deliveryAddress',
              'shippingAddress',
            ],
          );

          final price =
              _price(
            data['productPrice'],
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
                  status,
                  statusColor,
                ),
              ),

              // =================================================
              // META
              // =================================================

              SliverToBoxAdapter(
                child:
                    _buildOrderMeta(
                  data,
                  status,
                  statusColor,
                  paymentStatus,
                  paymentColor,
                ),
              ),

              // =================================================
              // CONTENT
              // =================================================

              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  30,
                ),
                sliver:
                    SliverList(
                  delegate:
                      SliverChildListDelegate(
                    [

                      _buildCustomerCard(
                        buyerName,
                        email,
                        phone,
                        address,
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildItemCard(
                        productName,
                        imageUrl,
                        price,
                        data,
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildPaymentCard(
                        paymentMethod,
                        transactionId,
                        paymentStatus,
                        paymentColor,
                      ),

                      if (address
                          .isNotEmpty) ...[
                        const SizedBox(
                          height:
                              12,
                        ),
                        _buildShippingCard(
                          address,
                        ),
                      ],

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildSummary(
                        price,
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      // =======================================
                      // PAYMENT TOGGLE
                      // =======================================

                      _buildPaymentToggle(
                        data,
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _buildActions(),
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
  // HEADER
  // =========================================================

  Widget _buildHeader(
    BuildContext context,
    String status,
    Color statusColor,
  ) {
    return Container(
      padding:
          EdgeInsets.only(
        top:
            MediaQuery.of(context)
                    .padding
                    .top +
                15,
        left:
            20,
        right:
            20,
        bottom:
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
            36,
          ),
          bottomRight:
              Radius.circular(
            36,
          ),
        ),
      ),
      child:
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
            width:
                14,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [

                Text(
                  'Order Details',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height:
                      3,
                ),

                Text(
                  'View complete information about this order',
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize:
                        11.5,
                    fontWeight:
                        FontWeight.w500,
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
                  11,
              vertical:
                  8,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withOpacity(
                0.13,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child:
                Text(
              '#${widget.orderId.length > 12 ? widget.orderId.substring(0, 12) : widget.orderId}',
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize:
                    10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color:
          Colors.white.withOpacity(
        0.14,
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
          width:
              48,
          height:
              48,
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
  // ORDER META
  // =========================================================

  Widget _buildOrderMeta(
    Map<String, dynamic> data,
    String status,
    Color statusColor,
    String paymentStatus,
    Color paymentColor,
  ) {
    return Transform.translate(
      offset:
          const Offset(
        0,
        -10,
      ),
      child:
          Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal:
              18,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical:
              17,
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
                  _meta(
                Icons.calendar_today_outlined,
                'Order Date',
                _formatDate(
                  _timestamp(
                    data,
                  ),
                ),
                primaryOrange,
              ),
            ),

            _verticalDivider(),

            Expanded(
              child:
                  _meta(
                Icons.schedule_outlined,
                'Order Status',
                status,
                statusColor,
              ),
            ),

            _verticalDivider(),

            Expanded(
              child:
                  _meta(
                Icons.credit_card_outlined,
                'Payment',
                paymentStatus,
                paymentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width:
          1,
      height:
          64,
      color:
          const Color(
        0xFFE9E2DA,
      ),
    );
  }

  Widget _meta(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            7,
      ),
      child:
          Column(
        children: [

          Icon(
            icon,
            size:
                17,
            color:
                color,
          ),

          const SizedBox(
            height:
                6,
          ),

          Text(
            label,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  textSecondary,
              fontSize:
                  9.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal:
                  8,
              vertical:
                  5,
            ),
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.08,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                Text(
              value,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color:
                    color,
                fontSize:
                    9.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION CARD
  // =========================================================

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        15,
        16,
        15,
        16,
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
                11,
            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Container(
                width:
                    34,
                height:
                    34,
                decoration:
                    BoxDecoration(
                  color:
                      iconColor
                          .withOpacity(
                    0.09,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      iconColor,
                  size:
                      19,
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Text(
                title,
                style:
                    const TextStyle(
                  color:
                      textPrimary,
                  fontSize:
                      16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          child,
        ],
      ),
    );
  }

  // =========================================================
  // CUSTOMER
  // =========================================================

  Widget _buildCustomerCard(
    String buyerName,
    String email,
    String phone,
    String address,
  ) {
    return _sectionCard(
      icon:
          Icons.person_outline_rounded,
      iconColor:
          deepOrange,
      title:
          'Customer Information',
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                if (buyerName
                    .isNotEmpty)
                  Text(
                    buyerName,
                    style:
                        const TextStyle(
                      color:
                          textPrimary,
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                if (email
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        9,
                  ),
                  _infoLine(
                    Icons
                        .mail_outline_rounded,
                    email,
                  ),
                ],

                if (phone
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        7,
                  ),
                  _infoLine(
                    Icons
                        .phone_outlined,
                    phone,
                  ),
                ],

                if (address
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        7,
                  ),
                  _infoLine(
                    Icons
                        .location_on_outlined,
                    address,
                  ),
                ],

                if (buyerName
                        .isEmpty &&
                    email
                        .isEmpty &&
                    phone
                        .isEmpty &&
                    address
                        .isEmpty)
                  const Text(
                    'Customer information unavailable',
                    style:
                        TextStyle(
                      color:
                          textSecondary,
                      fontSize:
                          12,
                    ),
                  ),
              ],
            ),
          ),

          if (buyerName
              .isNotEmpty)
            Container(
              width:
                  58,
              height:
                  58,
              margin:
                  const EdgeInsets.only(
                left:
                    10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFFF1E4,
                ),
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child:
                  Center(
                child:
                    Text(
                  _initials(
                    buyerName,
                  ),
                  style:
                      const TextStyle(
                    color:
                        deepOrange,
                    fontSize:
                        19,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(
    String name,
  ) {
    final parts =
        name
            .trim()
            .split(
              RegExp(
                r'\s+',
              ),
            );

    if (parts.isEmpty) {
      return '';
    }

    if (parts.length ==
        1) {
      return parts.first
          .substring(
            0,
            1,
          )
          .toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
        '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _infoLine(
    IconData icon,
    String text,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        Icon(
          icon,
          size:
              17,
          color:
              textSecondary,
        ),

        const SizedBox(
          width:
              8,
        ),

        Expanded(
          child:
              Text(
            text,
            style:
                const TextStyle(
              color:
                  textSecondary,
              fontSize:
                  11.5,
              height:
                  1.35,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ITEM
  // =========================================================

  Widget _buildItemCard(
    String productName,
    String imageUrl,
    double price,
    Map<String, dynamic> data,
  ) {
    final quantity =
        _string(
          data,
          [
            'quantity',
            'qty',
          ],
        );

    return _sectionCard(
      icon:
          Icons.shopping_bag_outlined,
      iconColor:
          primaryOrange,
      title:
          'Order Items',
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          _itemImage(
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
                  CrossAxisAlignment.start,
              children: [

                Text(
                  productName.isEmpty
                      ? 'Product name unavailable'
                      : productName,
                  maxLines:
                      2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        textPrimary,
                    fontSize:
                        14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      7,
                ),

                Text(
                  'Qty: ${quantity.isEmpty ? '1' : quantity}',
                  style:
                      const TextStyle(
                    color:
                        textSecondary,
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
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
              color:
                  deepOrange,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemImage(
    String url,
  ) {
    if (url.isEmpty) {
      return Container(
        width:
            88,
        height:
            88,
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFFFFF1E4,
          ),
          borderRadius:
              BorderRadius.circular(
            16,
          ),
        ),
        child:
            const Icon(
          Icons
              .shopping_bag_outlined,
          color:
              deepOrange,
          size:
              28,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child:
          Image.network(
        url,
        width:
            88,
        height:
            88,
        fit:
            BoxFit.cover,
        errorBuilder:
            (
          _,
          __,
          ___,
        ) =>
            Container(
          width:
              88,
          height:
              88,
          color:
              const Color(
            0xFFFFF1E4,
          ),
          child:
              const Icon(
            Icons
                .broken_image_outlined,
            color:
                deepOrange,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // PAYMENT
  // =========================================================

  Widget _buildPaymentCard(
    String method,
    String transactionId,
    String status,
    Color statusColor,
  ) {
    return _sectionCard(
      icon:
          Icons.credit_card_outlined,
      iconColor:
          completedColor,
      title:
          'Payment Information',
      child:
          Row(
        children: [

          Expanded(
            child:
                _paymentColumn(
              'Payment Method',
              method.isEmpty
                  ? 'Unavailable'
                  : method
                      .toUpperCase(),
            ),
          ),

          _verticalDivider(),

          Expanded(
            child:
                _paymentColumn(
              'Transaction ID',
              transactionId.isEmpty
                  ? 'Unavailable'
                  : transactionId,
            ),
          ),

          _verticalDivider(),

          Expanded(
            child:
                _paymentColumn(
              'Payment Status',
              status,
              color:
                  statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentColumn(
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            5,
      ),
      child:
          Column(
        children: [

          Text(
            label,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  textSecondary,
              fontSize:
                  9.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
                7,
          ),

          Text(
            value,
            maxLines:
                2,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  color ??
                      textPrimary,
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SHIPPING
  // =========================================================

  Widget _buildShippingCard(
    String address,
  ) {
    return _sectionCard(
      icon:
          Icons.local_shipping_outlined,
      iconColor:
          processingColor,
      title:
          'Shipping Information',
      child:
          _infoLine(
        Icons.location_on_outlined,
        address,
      ),
    );
  }

  // =========================================================
  // SUMMARY
  // =========================================================

  Widget _buildSummary(
    double price,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        17,
        16,
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFBF5,
        ),
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFF0E1CF,
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

              Container(
                width:
                    34,
                height:
                    34,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFEEDC,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .receipt_long_outlined,
                  color:
                      deepOrange,
                  size:
                      19,
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              const Text(
                'Order Summary',
                style:
                    TextStyle(
                  color:
                      textPrimary,
                  fontSize:
                      16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          _summaryRow(
            'Item Total',
            '₹${price.toStringAsFixed(0)}',
          ),

          const SizedBox(
            height:
                7,
          ),

          const Divider(
            height:
                16,
            color:
                Color(
              0xFFEBDCCB,
            ),
          ),

          Row(
            children: [

              const Text(
                'Total Amount',
                style:
                    TextStyle(
                  color:
                      textPrimary,
                  fontSize:
                      14,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const Spacer(),

              Text(
                '₹${price.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  color:
                      deepOrange,
                  fontSize:
                      20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
  ) {
    return Row(
      children: [

        Text(
          label,
          style:
              const TextStyle(
            color:
                textSecondary,
            fontSize:
                11.5,
            fontWeight:
                FontWeight.w500,
          ),
        ),

        const Spacer(),

        Text(
          value,
          style:
              const TextStyle(
            color:
                textPrimary,
            fontSize:
                11.5,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PAYMENT TOGGLE
  // =========================================================

  Widget _buildPaymentToggle(
    Map<String, dynamic> data,
  ) {
    final raw =
        _string(
          data,
          [
            'paymentStatus',
          ],
        ).toLowerCase();

    final bool completed =
        raw == 'done' ||
        raw == 'completed' ||
        raw == 'paid';

    final Color color =
        completed
            ? pendingColor
            : completedColor;

    final IconData icon =
        completed
            ? Icons.undo_rounded
            : Icons.check_circle_outline_rounded;

    final String label =
        completed
            ? 'Mark Payment Pending'
            : 'Mark Payment Completed';

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds:
            220,
      ),
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.07,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            0.18,
          ),
        ),
      ),
      child:
          Row(
        children: [

          Container(
            width:
                40,
            height:
                40,
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              completed
                  ? Icons
                      .check_circle_outline_rounded
                  : Icons
                      .schedule_outlined,
              color:
                  color,
              size:
                  21,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
                  completed
                      ? 'Payment completed'
                      : 'Payment pending',
                  style:
                      TextStyle(
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        color,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  completed
                      ? 'You can move this order back to pending.'
                      : 'Confirm that you have received the payment.',
                  style:
                      const TextStyle(
                    fontSize:
                        10,
                    color:
                        textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width:
                8,
          ),

          SizedBox(
            height:
                40,
            child:
                ElevatedButton.icon(
              onPressed:
                  isUpdatingPayment
                      ? null
                      : () =>
                          _togglePaymentStatus(
                        data,
                      ),
              icon:
                  isUpdatingPayment
                      ? const SizedBox(
                          width:
                              15,
                          height:
                              15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Icon(
                          icon,
                          size:
                              16,
                        ),
              label:
                  Text(
                label,
                style:
                    const TextStyle(
                  fontSize:
                      9.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    color,
                foregroundColor:
                    Colors.white,
                elevation:
                    0,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      10,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
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
  // ACTION BUTTONS
  // =========================================================

  Widget _buildActions() {
    return Row(
      children: [

        Expanded(
          child:
              _actionButton(
            icon:
                Icons.print_outlined,
            label:
                'Print Invoice',
            filled:
                false,
          ),
        ),

        const SizedBox(
          width:
              8,
        ),

        Expanded(
          child:
              _actionButton(
            icon:
                Icons.chat_bubble_outline_rounded,
            label:
                'Contact Customer',
            filled:
                false,
          ),
        ),

        const SizedBox(
          width:
              8,
        ),

        Expanded(
          child:
              _actionButton(
            icon:
                Icons.local_shipping_outlined,
            label:
                'Mark as Shipped',
            filled:
                true,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool filled,
  }) {
    return SizedBox(
      height:
          50,
      child:
          ElevatedButton.icon(
        onPressed:
            () {},
        icon:
            Icon(
          icon,
          size:
              17,
        ),
        label:
            Text(
          label,
          maxLines:
              2,
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            fontSize:
                9.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              filled
                  ? primaryOrange
                  : cardBackground,
          foregroundColor:
              filled
                  ? Colors.white
                  : textPrimary,
          elevation:
              0,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal:
                5,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            side:
                BorderSide(
              color:
                  filled
                      ? primaryOrange
                      : const Color(
                          0xFFE3DDD5,
                        ),
            ),
          ),
        ),
      ),
    );
  }
}