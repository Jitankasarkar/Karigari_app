import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerAnalyticsPage extends StatefulWidget {
  /// Latest analytics snapshot produced from the seller's Firestore data.
  ///
  /// SellerInsights reads this shared snapshot because both pages are
  /// mounted by SellerDashboard inside the same IndexedStack.
  static final ValueNotifier<SellerAnalytics?> latestAnalytics =
      ValueNotifier<SellerAnalytics?>(null);

  const SellerAnalyticsPage({super.key});

  @override
  State<SellerAnalyticsPage> createState() => _SellerAnalyticsPageState();
}

class _SellerAnalyticsPageState extends State<SellerAnalyticsPage> {
  // =========================================================
  // DESIGN SYSTEM
  // =========================================================

  static const Color background = Color(0xFFF6F7F9);

  static const Color surface = Colors.white;

  static const Color primary = Color(0xFF172033);

  static const Color secondary = Color(0xFF667085);

  static const Color accent = Color(0xFF14B8A6);

  static const Color accentDark = Color(0xFF0F766E);

  static const Color purple = Color(0xFF6366F1);

  static const Color warning = Color(0xFFF59E0B);

  static const Color danger = Color(0xFFEF4444);

  static const Color border = Color(0xFFE7E9EE);

  // =========================================================
  // FIREBASE
  // =========================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================
  // STATE
  // =========================================================

  String _sellerId = '';
  String _sellerName = 'Your Shop';

  bool _loadingSeller = true;

  int _selectedPeriod = 30;

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
      final user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _loadingSeller = false;
        });

        return;
      }

      final sellerId = user.uid;

      final sellerDoc = await _firestore
          .collection('sellers')
          .doc(sellerId)
          .get();

      if (!mounted) return;

      final data = sellerDoc.data();

      final shopName = data?['shopName']?.toString().trim() ?? '';

      setState(() {
        _sellerId = sellerId;

        _sellerName = shopName.isNotEmpty ? shopName : 'Your Shop';

        _loadingSeller = false;
      });
    } catch (e) {
      debugPrint('Analytics seller loading error: $e');

      if (!mounted) return;

      setState(() {
        _loadingSeller = false;
      });
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingSeller) {
      return const Center(child: CircularProgressIndicator(color: accent));
    }

    if (_sellerId.isEmpty) {
      return _buildErrorState('Unable to load seller information.');
    }

    return Container(
      color: background,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('orders')
            .where('sellerId', isEqualTo: _sellerId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (orderSnapshot.hasError) {
            return _buildErrorState(
              'Unable to load order analytics.\n\n'
              '${orderSnapshot.error}',
            );
          }

          final orders = orderSnapshot.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('products')
                .where('sellerId', isEqualTo: _sellerId)
                .snapshots(),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (productSnapshot.hasError) {
                return _buildErrorState(
                  'Unable to load product analytics.\n\n'
                  '${productSnapshot.error}',
                );
              }

              final products = productSnapshot.data?.docs ?? [];

              final analytics = _AnalyticsEngine.build(
                orders: orders,
                products: products,
                periodDays: _selectedPeriod,
              );

              // Publish the exact same analytics snapshot used to render
              // this page so SellerInsights can consume it without
              // duplicating Firestore queries or business calculations.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                SellerAnalyticsPage.latestAnalytics.value = analytics;
              });

              return _buildPage(analytics);
            },
          );
        },
      ),
    );
  }

  // =========================================================
  // MAIN PAGE
  // =========================================================

  Widget _buildPage(SellerAnalytics analytics) {
    return RefreshIndicator(
      color: accent,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(analytics),

            const SizedBox(height: 24),

            _buildPeriodSelector(),

            const SizedBox(height: 24),

            _buildExecutiveSummary(analytics),

            const SizedBox(height: 28),

            _buildSectionTitle(
              'Performance',
              'What is happening with your shop',
            ),

            const SizedBox(height: 14),

            _buildPerformanceGrid(analytics),

            const SizedBox(height: 30),

            _buildRevenueSection(analytics),

            const SizedBox(height: 30),

            _buildSectionTitle(
              'Product performance',
              'Which products are driving sales',
            ),

            const SizedBox(height: 14),

            _buildTopProducts(analytics),

            const SizedBox(height: 30),

            _buildSectionTitle(
              'Order intelligence',
              'A closer look at customer activity',
            ),

            const SizedBox(height: 14),

            _buildOrderIntelligence(analytics),

            const SizedBox(height: 30),

            _buildSectionTitle('Inventory', 'Your current product catalogue'),

            const SizedBox(height: 14),

            _buildInventorySection(analytics),

            const SizedBox(height: 30),

            _buildAiFoundation(analytics),

            const SizedBox(height: 20),

            _buildDataSourceFooter(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(SellerAnalytics analytics) {
    final firstName = _sellerName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: primary,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Your shop, understood.',
                    style: TextStyle(
                      fontSize: 15,
                      color: secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Welcome back, $firstName.',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            _buildLiveBadge(),
          ],
        ),

        const SizedBox(height: 18),

        _buildDataConfidenceRow(analytics),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBF7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: accent),
          SizedBox(width: 7),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataConfidenceRow(SellerAnalytics analytics) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 18, color: accentDark),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics are live',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${analytics.orderCount} orders • '
                  '${analytics.productCount} products '
                  'from Firestore',
                  style: const TextStyle(fontSize: 11, color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PERIOD SELECTOR
  // =========================================================

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodButton(label: '7D', days: 7),
        const SizedBox(width: 8),
        _buildPeriodButton(label: '30D', days: 30),
        const SizedBox(width: 8),
        _buildPeriodButton(label: '90D', days: 90),
        const SizedBox(width: 8),
        _buildPeriodButton(label: 'All', days: 0),
      ],
    );
  }

  Widget _buildPeriodButton({required String label, required int days}) {
    final selected = _selectedPeriod == days;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = days;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? primary : border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : secondary,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // EXECUTIVE SUMMARY
  // =========================================================

  Widget _buildExecutiveSummary(SellerAnalytics analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Business overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB8C1D1),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _periodLabel(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            '₹${_formatAmount(analytics.periodRevenue)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 3),

          const Text(
            'Revenue',
            style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B5)),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildDarkMetric(
                  'Orders',
                  analytics.periodOrders.toString(),
                ),
              ),
              Expanded(
                child: _buildDarkMetric(
                  'Avg. order',
                  '₹${_formatAmount(analytics.averageOrderValue)}',
                ),
              ),
              Expanded(
                child: _buildDarkMetric(
                  'Completion',
                  '${analytics.completionRate.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDarkMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF9AA5B5)),
        ),
      ],
    );
  }

  // =========================================================
  // PERFORMANCE
  // =========================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: primary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: secondary)),
      ],
    );
  }

  Widget _buildPerformanceGrid(SellerAnalytics analytics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Revenue',
                value: '₹${_formatAmount(analytics.periodRevenue)}',
                helper: '${analytics.periodOrders} orders',
                icon: Icons.currency_rupee_rounded,
                iconColor: accentDark,
                background: const Color(0xFFEAFBF7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Orders',
                value: analytics.periodOrders.toString(),
                helper: '${analytics.completedOrders} completed',
                icon: Icons.shopping_bag_outlined,
                iconColor: purple,
                background: const Color(0xFFF0EFFF),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Avg. order',
                value: '₹${_formatAmount(analytics.averageOrderValue)}',
                helper: 'per completed order',
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF2563EB),
                background: const Color(0xFFEEF4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Pending',
                value: analytics.pendingOrders.toString(),
                helper: 'needs attention',
                icon: Icons.schedule_outlined,
                iconColor: warning,
                background: const Color(0xFFFFF7E8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String helper,
    required IconData icon,
    required Color iconColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),

          const SizedBox(height: 17),

          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: primary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: secondary),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // REVENUE
  // =========================================================

  Widget _buildRevenueSection(SellerAnalytics analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Daily revenue from completed orders',
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),

              Text(
                '₹${_formatAmount(analytics.periodRevenue)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accentDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (analytics.dailyRevenue.isEmpty)
            _buildInlineEmpty('No completed sales in this period.')
          else
            ...analytics.dailyRevenue
                .take(7)
                .map((item) => _buildRevenueRow(item)),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(DailyRevenue item) {
    final maxRevenue = item.maxRevenue <= 0 ? 1 : item.maxRevenue;

    final percentage = (item.revenue / maxRevenue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 7,
                backgroundColor: const Color(0xFFF0F2F5),
                valueColor: const AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 60,
            child: Text(
              '₹${_formatAmount(item.revenue)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TOP PRODUCTS
  // =========================================================

  Widget _buildTopProducts(SellerAnalytics analytics) {
    if (analytics.topProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.inventory_2_outlined,
        title: 'No product sales yet',
        subtitle:
            'Once orders are completed, your strongest products will appear here.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < analytics.topProducts.length; i++)
            _buildProductPerformanceRow(
              analytics.topProducts[i],
              rank: i + 1,
              isLast: i == analytics.topProducts.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildProductPerformanceRow(
    ProductPerformance product, {
    required int rank,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFFFF5E5)
                  : const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: rank == 1 ? warning : secondary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${product.orders} '
                  '${product.orders == 1 ? 'order' : 'orders'}',
                  style: const TextStyle(fontSize: 11, color: secondary),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_formatAmount(product.revenue)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${product.share.toStringAsFixed(0)}% of sales',
                style: const TextStyle(fontSize: 9, color: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER INTELLIGENCE
  // =========================================================

  Widget _buildOrderIntelligence(SellerAnalytics analytics) {
    return Column(
      children: [
        _buildInsightTile(
          icon: Icons.people_outline_rounded,
          title: 'Customers',
          value: analytics.uniqueCustomers.toString(),
          description: 'unique customers represented in your orders',
          color: purple,
        ),

        const SizedBox(height: 10),

        _buildInsightTile(
          icon: Icons.credit_card_outlined,
          title: 'Online payments',
          value: analytics.onlinePayments.toString(),
          description: 'orders paid through Razorpay',
          color: accentDark,
        ),

        const SizedBox(height: 10),

        _buildInsightTile(
          icon: Icons.payments_outlined,
          title: 'Cash on delivery',
          value: analytics.codPayments.toString(),
          description: 'orders using cash on delivery',
          color: warning,
        ),

        const SizedBox(height: 10),

        _buildInsightTile(
          icon: Icons.pending_actions_outlined,
          title: 'Needs attention',
          value: analytics.pendingOrders.toString(),
          description: analytics.pendingOrders == 0
              ? 'No pending orders right now'
              : 'orders are still pending',
          color: analytics.pendingOrders == 0 ? accentDark : warning,
        ),
      ],
    );
  }

  Widget _buildInsightTile({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: color),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: secondary),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INVENTORY
  // =========================================================

  Widget _buildInventorySection(SellerAnalytics analytics) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInventoryMetric(
                  'Total products',
                  analytics.productCount.toString(),
                ),
              ),
              Expanded(
                child: _buildInventoryMetric(
                  'Active',
                  analytics.activeProducts.toString(),
                ),
              ),
              Expanded(
                child: _buildInventoryMetric(
                  'Sold',
                  analytics.soldProducts.toString(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(height: 1, color: border),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 17, color: purple),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  analytics.unusedProducts == 0
                      ? 'Every active product has generated an order.'
                      : '${analytics.unusedProducts} active products have not generated an order yet.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: secondary)),
      ],
    );
  }

  // =========================================================
  // AI FOUNDATION
  // =========================================================

  Widget _buildAiFoundation(SellerAnalytics analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: purple,
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI insight layer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ready for Gemini',
                      style: TextStyle(
                        fontSize: 10,
                        color: purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            _buildCurrentInsight(analytics),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _buildAiTag('Sales'),
              _buildAiTag('Products'),
              _buildCustomersTag(analytics),
              _buildAiTag('Payments'),
              _buildAiTag('Trends'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E0F8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: secondary,
        ),
      ),
    );
  }

  Widget _buildCustomersTag(SellerAnalytics analytics) {
    return _buildAiTag('${analytics.uniqueCustomers} customers');
  }

  String _buildCurrentInsight(SellerAnalytics analytics) {
    if (analytics.periodOrders == 0) {
      return 'There are not enough completed sales in this period to identify a reliable sales pattern yet.';
    }

    if (analytics.topProducts.isEmpty) {
      return 'Sales data is available, but there is not enough product-level activity to identify a leading product yet.';
    }

    final top = analytics.topProducts.first;

    if (analytics.completionRate >= 80) {
      return '${top.name} is currently your strongest product by completed orders. Your order completion rate is ${analytics.completionRate.toStringAsFixed(0)}%, giving Gemini a strong foundation for future growth recommendations.';
    }

    return '${top.name} is currently your strongest product by completed orders. There are ${analytics.pendingOrders} pending orders, so order completion is an important area for future AI recommendations.';
  }

  // =========================================================
  // FOOTER
  // =========================================================

  Widget _buildDataSourceFooter() {
    return Center(
      child: Text(
        'Live data • Firestore • Seller-scoped analytics',
        style: TextStyle(fontSize: 10, color: secondary.withOpacity(0.75)),
      ),
    );
  }

  // =========================================================
  // EMPTY / ERROR / LOADING
  // =========================================================

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: accent));
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 42, color: secondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: secondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, height: 1.4, color: secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEmpty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: const TextStyle(fontSize: 11, color: secondary)),
    );
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refresh() async {
    await _loadSeller();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _periodLabel() {
    if (_selectedPeriod == 0) {
      return 'ALL TIME';
    }

    return 'LAST $_selectedPeriod DAYS';
  }

  String _formatAmount(double value) {
    // Analytics should show exact revenue values.
    // Example: ₹1,995 instead of ₹2.0K.
    return value.toStringAsFixed(0);
  }
}

// =============================================================
// ANALYTICS ENGINE
// =============================================================
//
// This class contains the actual business calculations.
// Keeping calculations separate from the UI makes the data
// easy to send to Gemini later.
//
// =============================================================

class _AnalyticsEngine {
  static SellerAnalytics build({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    required int periodDays,
  }) {
    final now = DateTime.now();

    DateTime? startDate;

    if (periodDays > 0) {
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: periodDays - 1));
    }

    // ---------------------------------------------------------
    // NORMALISE ORDERS
    // ---------------------------------------------------------

    final allOrders = orders.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());

      data['_id'] = doc.id;

      return data;
    }).toList();

    // ---------------------------------------------------------
    // PERIOD ORDERS
    // ---------------------------------------------------------

    final periodOrders = allOrders.where((order) {
      final date = _timestampToDate(order['timestamp']);

      if (date == null) {
        return false;
      }

      if (startDate == null) {
        return true;
      }

      return !date.isBefore(startDate);
    }).toList();

    // ---------------------------------------------------------
    // STATUS
    // ---------------------------------------------------------

    final completed = periodOrders.where((order) {
      final status = _normaliseStatus(order['paymentStatus']);

      return status == 'done' || status == 'completed';
    }).toList();

    final pending = periodOrders.where((order) {
      return _normaliseStatus(order['paymentStatus']) == 'pending';
    }).toList();

    // ---------------------------------------------------------
    // REVENUE
    // ---------------------------------------------------------

    double revenue = 0;

    for (final order in completed) {
      revenue += _price(order['productPrice']);
    }

    final averageOrderValue = completed.isEmpty
        ? 0
        : revenue / completed.length;

    final completionRate = periodOrders.isEmpty
        ? 0
        : (completed.length / periodOrders.length) * 100;

    // ---------------------------------------------------------
    // CUSTOMERS
    // ---------------------------------------------------------

    final customerIds = <String>{};

    for (final order in periodOrders) {
      final id = order['userId']?.toString().trim() ?? '';

      if (id.isNotEmpty) {
        customerIds.add(id);
      }
    }

    // ---------------------------------------------------------
    // PAYMENT METHODS
    // ---------------------------------------------------------

    int onlinePayments = 0;
    int codPayments = 0;

    for (final order in periodOrders) {
      final method =
          order['paymentMethod']?.toString().toLowerCase().trim() ?? '';

      if (method == 'online') {
        onlinePayments++;
      } else if (method == 'cod') {
        codPayments++;
      }
    }

    // ---------------------------------------------------------
    // PRODUCTS
    // ---------------------------------------------------------

    final productMaps = products
        .map((doc) => Map<String, dynamic>.from(doc.data()))
        .toList();

    
    // =============================================================
    // ALL SELLER PRODUCTS
    // Used by Campaign / Bundle / Offer workspaces.
    // =============================================================

    final allProducts = productMaps.map((product) {
  final rawPrice = product['price'];

  double parsedPrice = 0;

  if (rawPrice is num) {
    parsedPrice = rawPrice.toDouble();
  } else if (rawPrice != null) {
    parsedPrice = double.tryParse(
          rawPrice.toString().replaceAll('₹', '').trim(),
        ) ??
        0;
  }

  return ProductPerformance(
  // Firestore document ID
  id: product['productId']?.toString() ?? '',

  // Product name from Firestore
  name: product['title']?.toString() ?? 'Untitled product',

  // Catalogue products don't need analytics values here.
  orders: 0,
  revenue: 0,
  share: 0,

  price: parsedPrice,

  imageUrl: product['imageUrl']?.toString() ?? '',

  // Seller information
  sellerId: product['sellerId']?.toString() ?? '',
  sellerName: product['sellerName']?.toString() ?? '',
);
}).toList();

    final activeProducts = productMaps.where((product) {
      return product['isAvailable'] == true;
    }).length;

    // ---------------------------------------------------------
    // PRODUCT SALES
    // ---------------------------------------------------------

    final productStats = <String, ProductPerformance>{};

    for (final order in completed) {
      final name = order['productName']?.toString().trim() ?? 'Unknown Product';

      final price = _price(order['productPrice']);

      final existing = productStats[name];

      if (existing == null) {
        productStats[name] = ProductPerformance(
          name: name,
          orders: 1,
          revenue: price,
          share: 0,
        );
      } else {
        productStats[name] = ProductPerformance(
          name: name,
          orders: existing.orders + 1,
          revenue: existing.revenue + price,
          share: 0,
        );
      }
    }

    var topProducts = productStats.values.toList();

    topProducts.sort((a, b) {
      final orderCompare = b.orders.compareTo(a.orders);

      if (orderCompare != 0) {
        return orderCompare;
      }

      return b.revenue.compareTo(a.revenue);
    });

    final productByTitle = <String, Map<String, dynamic>>{};

    for (final product in productMaps) {
      final title = product['title']?.toString().trim() ?? '';
      if (title.isNotEmpty) {
        productByTitle[title.toLowerCase()] = product;
      }
    }

    topProducts = topProducts.take(5).map((product) {
      final double share = revenue <= 0 ? 0 : (product.revenue / revenue) * 100;

      final catalogProduct = productByTitle[product.name.toLowerCase()];

      return ProductPerformance(
        name: product.name,
        orders: product.orders,
        revenue: product.revenue,
        share: share,
        price: catalogProduct == null ? 0 : _price(catalogProduct['price']),
        imageUrl: catalogProduct == null
            ? ''
            : catalogProduct['imageUrl']?.toString() ?? '',
      );
    }).toList();

    // ---------------------------------------------------------
    // SOLD PRODUCTS
    // ---------------------------------------------------------

    final soldProductNames = productStats.keys
        .map((name) => name.toLowerCase())
        .toSet();

    int soldProducts = 0;

    for (final product in productMaps) {
      final title = product['title']?.toString().toLowerCase().trim() ?? '';

      if (title.isNotEmpty && soldProductNames.contains(title)) {
        soldProducts++;
      }
    }

    final unusedProducts = math.max(0, activeProducts - soldProducts);

    // ---------------------------------------------------------
    // QUIET PRODUCTS
    // ---------------------------------------------------------

    final quietProducts = <ProductPerformance>[];

    for (final product in productMaps) {
      final title = product['title']?.toString().trim() ?? '';

      if (title.isEmpty || product['isAvailable'] != true) {
        continue;
      }

      final hasSales = soldProductNames.contains(title.toLowerCase());

      if (!hasSales) {
        quietProducts.add(
          ProductPerformance(
            name: title,
            orders: 0,
            revenue: 0,
            share: 0,
            price: _price(product['price']),
            imageUrl: product['imageUrl']?.toString() ?? '',
          ),
        );
      }
    }

    // ---------------------------------------------------------
    // DAILY REVENUE
    // ---------------------------------------------------------

    final dailyMap = <String, double>{};

    for (final order in completed) {
      final date = _timestampToDate(order['timestamp']);

      if (date == null) {
        continue;
      }

      final key =
          '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      dailyMap[key] = (dailyMap[key] ?? 0) + _price(order['productPrice']);
    }

    var dailyRevenue = dailyMap.entries.map((entry) {
      final parts = entry.key.split('-');

      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      return DailyRevenue(
        label: '${date.day}/${date.month}',
        revenue: entry.value,
        maxRevenue: 0,
      );
    }).toList();

    dailyRevenue.sort((a, b) {
      return b.label.compareTo(a.label);
    });

    final double maxDailyRevenue = dailyRevenue.isEmpty
        ? 0
        : dailyRevenue.map((item) => item.revenue).reduce(math.max);

    dailyRevenue = dailyRevenue.map((item) {
      return DailyRevenue(
        label: item.label,
        revenue: item.revenue,
        maxRevenue: maxDailyRevenue,
      );
    }).toList();

    return SellerAnalytics(
      orderCount: allOrders.length,
      productCount: productMaps.length,
      activeProducts: activeProducts,
      soldProducts: soldProducts,
      unusedProducts: unusedProducts,
      periodOrders: periodOrders.length,
      completedOrders: completed.length,
      pendingOrders: pending.length,
      periodRevenue: revenue,
      averageOrderValue: averageOrderValue.toDouble(),
      completionRate: completionRate.toDouble(),
      uniqueCustomers: customerIds.length,
      onlinePayments: onlinePayments,
      codPayments: codPayments,
      topProducts: topProducts,
      quietProducts: quietProducts,
      allProducts: allProducts,
      dailyRevenue: dailyRevenue,
    );
  }

  // =========================================================
  // VALUE HELPERS
  // =========================================================

  static double _price(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static String _normaliseStatus(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? '';
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}

// =============================================================
// ANALYTICS MODEL
// =============================================================

class SellerAnalytics {
  final int orderCount;
  final int productCount;

  final int activeProducts;
  final int soldProducts;
  final int unusedProducts;

  final int periodOrders;
  final int completedOrders;
  final int pendingOrders;

  final double periodRevenue;
  final double averageOrderValue;
  final double completionRate;

  final int uniqueCustomers;
  final int onlinePayments;
  final int codPayments;

  // =============================================================
  // PRODUCT DATA
  // =============================================================

  // Used for analytics / dashboard insights.
  final List<ProductPerformance> topProducts;

  // Products with little/no sales activity.
  final List<ProductPerformance> quietProducts;

  // ALL products belonging to the seller.
  // Used by Campaign / Bundle / Offer workspaces.
  final List<ProductPerformance> allProducts;

  final List<DailyRevenue> dailyRevenue;

  SellerAnalytics({
    required this.orderCount,
    required this.productCount,
    required this.activeProducts,
    required this.soldProducts,
    required this.unusedProducts,
    required this.periodOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.periodRevenue,
    required this.averageOrderValue,
    required this.completionRate,
    required this.uniqueCustomers,
    required this.onlinePayments,
    required this.codPayments,

    List<ProductPerformance>? topProducts,
    List<ProductPerformance>? quietProducts,
    List<ProductPerformance>? allProducts,
    List<DailyRevenue>? dailyRevenue,
  })  : topProducts =
            List<ProductPerformance>.unmodifiable(
          topProducts ?? const <ProductPerformance>[],
        ),
        quietProducts =
            List<ProductPerformance>.unmodifiable(
          quietProducts ?? const <ProductPerformance>[],
        ),
        allProducts =
            List<ProductPerformance>.unmodifiable(
          allProducts ?? const <ProductPerformance>[],
        ),
        dailyRevenue =
            List<DailyRevenue>.unmodifiable(
          dailyRevenue ?? const <DailyRevenue>[],
        );

  Map<String, dynamic> toGeminiPayload() {
    return {
      'overview': {
        'totalOrders': orderCount,
        'totalProducts': productCount,
        'activeProducts': activeProducts,
        'periodOrders': periodOrders,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'revenue': periodRevenue,
        'averageOrderValue': averageOrderValue,
        'completionRate': completionRate,
        'uniqueCustomers': uniqueCustomers,
      },

      'payments': {
        'online': onlinePayments,
        'cashOnDelivery': codPayments,
      },

      // Keep top products for analytics / AI insights.
      'products': topProducts.map((product) {
        return {
          'id': product.id,
          'name': product.name,
          'orders': product.orders,
          'revenue': product.revenue,
          'revenueShare': product.share,
          'price': product.price,
        };
      }).toList(),

      'quietProducts': quietProducts.map((product) {
        return {
          'id': product.id,
          'name': product.name,
          'price': product.price,
        };
      }).toList(),

      'revenueActivity': dailyRevenue.map((day) {
        return {
          'date': day.label,
          'revenue': day.revenue,
        };
      }).toList(),
    };
  }
}

// =============================================================
// PRODUCT PERFORMANCE
// =============================================================

class ProductPerformance {
  final String id;
  final String name;

  final int orders;
  final double revenue;
  final double share;

  // Catalogue data
  final double price;
  final String imageUrl;

  // Seller data
  final String sellerId;
  final String sellerName;

  ProductPerformance({
    this.id = '',
    required this.name,
    required this.orders,
    required this.revenue,
    required this.share,
    this.price = 0,
    this.imageUrl = '',

    // Seller data
    this.sellerId = '',
    this.sellerName = '',
  });
}

// =============================================================
// DAILY REVENUE
// =============================================================

class DailyRevenue {
  final String label;
  final double revenue;
  final double maxRevenue;

  DailyRevenue({
    required this.label,
    required this.revenue,
    required this.maxRevenue,
  });
}
