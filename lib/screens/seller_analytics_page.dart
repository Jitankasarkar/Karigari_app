import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Seller analytics dashboard.
///
/// IMPORTANT:
/// - All seller analytics are calculated from the seller's Firestore orders
///   and products.
/// - Existing SellerAnalytics fields and Gemini payload keys are preserved.
/// - New analytics fields are additive so SellerInsights can continue using
///   the same shared SellerAnalytics snapshot.
class SellerAnalyticsPage extends StatefulWidget {
  static final ValueNotifier<SellerAnalytics?> latestAnalytics =
      ValueNotifier<SellerAnalytics?>(null);

  const SellerAnalyticsPage({super.key});

  @override
  State<SellerAnalyticsPage> createState() => _SellerAnalyticsPageState();
}

class _SellerAnalyticsPageState extends State<SellerAnalyticsPage>
    with SingleTickerProviderStateMixin {
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
  static const Color blue = Color(0xFF2563EB);
  static const Color border = Color(0xFFE7E9EE);

  static const List<Color> chartColors = [
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _sellerId = '';
  String _sellerName = 'Your Shop';
  bool _loadingSeller = true;
  int _selectedPeriod = 30;

  late final AnimationController _headlineController;

  @override
  void initState() {
    super.initState();
    _headlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _loadSeller();
  }

  @override
  void dispose() {
    _headlineController.dispose();
    super.dispose();
  }

  Future<void> _loadSeller() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _loadingSeller = false);
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
      setState(() => _loadingSeller = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSeller) {
      return const Center(
        child: CircularProgressIndicator(color: accent),
      );
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
              'Unable to load order analytics.\n\n${orderSnapshot.error}',
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
                  'Unable to load product analytics.\n\n${productSnapshot.error}',
                );
              }

              final products = productSnapshot.data?.docs ?? [];

              final analytics = _AnalyticsEngine.build(
                orders: orders,
                products: products,
                periodDays: _selectedPeriod,
              );

              // Keep the exact same analytics snapshot available to the
              // SellerInsights / AI Growth tab. Existing consumers continue
              // receiving all original fields.
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
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(analytics),
            const SizedBox(height: 20),
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildExecutiveSummary(analytics),
            const SizedBox(height: 26),
            _buildSectionTitle(
              'Performance',
              'What is happening with your shop',
            ),
            const SizedBox(height: 13),
            _buildPerformanceGrid(analytics),
            const SizedBox(height: 28),
            _buildRevenueTrend(analytics),
            const SizedBox(height: 28),
            _buildOrderTrend(analytics),
            const SizedBox(height: 28),
            _buildSectionTitle(
              'Product performance',
              'Which products are driving completed sales',
            ),
            const SizedBox(height: 13),
            _buildProductAnalytics(analytics),
            const SizedBox(height: 28),
            _buildCategoryAnalytics(analytics),
            const SizedBox(height: 28),
            _buildPaymentAnalytics(analytics),
            const SizedBox(height: 28),
            _buildSectionTitle(
              'Order intelligence',
              'A closer look at customer activity',
            ),
            const SizedBox(height: 13),
            _buildOrderIntelligence(analytics),
            const SizedBox(height: 28),
            _buildCustomerAnalytics(analytics),
            const SizedBox(height: 28),
            _buildSectionTitle(
              'Inventory',
              'Your current product catalogue',
            ),
            const SizedBox(height: 13),
            _buildInventorySection(analytics),
            const SizedBox(height: 28),
            _buildOpportunitySection(analytics),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(SellerAnalytics analytics) {
    final shop = _sellerName.trim().isEmpty ? 'your shop' : _sellerName.trim();

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
                  _buildTypingTitle(),
                  const SizedBox(height: 6),
                  const Text(
                    'Your business, at a glance.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: secondary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Good to see you, $shop.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondary.withOpacity(0.82),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
           // _buildLiveBadge(),
          ],
        ),
        const SizedBox(height: 17),
       // _buildDataConfidenceRow(analytics),
      ],
    );
  }

  Widget _buildTypingTitle() {
    const words = <String>['See', "what's", 'selling'];

    return AnimatedBuilder(
      animation: _headlineController,
      builder: (context, _) {
        final t = _headlineController.value;

        return Wrap(
          spacing: 7,
          children: List.generate(words.length, (index) {
            const starts = <double>[0.04, 0.25, 0.46];
            const ends = <double>[0.20, 0.41, 0.62];
            final start = starts[index];
            final end = ends[index];

            final progress = t <= start
                ? 0.0
                : t >= end
                    ? 1.0
                    : Curves.easeOutCubic.transform(
                        (t - start) / (end - start),
                      );

            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 4 * (1 - progress)),
                child: Text(
                  words[index],
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: primary,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
              ),
            );
          }),
        );
      },
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
        onTap: () => setState(() => _selectedPeriod = days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? primary : surface,
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
    final growth = analytics.revenueGrowth;
    final growthAvailable = analytics.hasPreviousPeriod;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
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
          const SizedBox(height: 13),
          Text(
            '₹${_formatAmount(analytics.periodRevenue)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Revenue from completed orders',
            style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B5)),
          ),
          if (growthAvailable) ...[
            const SizedBox(height: 10),
            _buildGrowthPill(growth),
          ],
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

  Widget _buildGrowthPill(double growth) {
    final positive = growth >= 0;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: positive
              ? const Color(0x2234D399)
              : const Color(0x22FCA5A5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 14,
              color: positive
                  ? const Color(0xFF6EE7B7)
                  : const Color(0xFFFCA5A5),
            ),
            const SizedBox(width: 5),
            Text(
              '${growth.abs().toStringAsFixed(0)}% vs previous period',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: positive
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFFCA5A5),
              ),
            ),
          ],
        ),
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
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: secondary),
        ),
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
                helper: '${analytics.completedOrders} completed',
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
                iconColor: blue,
                background: const Color(0xFFEEF4FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Pending',
                value: analytics.pendingOrders.toString(),
                helper: analytics.pendingOrders == 0
                    ? 'nothing needs attention'
                    : 'needs attention',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
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
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
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
  // REVENUE TREND
  // =========================================================

  Widget _buildRevenueTrend(SellerAnalytics analytics) {
    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.show_chart_rounded,
            iconColor: accentDark,
            iconBackground: const Color(0xFFEAFBF7),
            title: 'Revenue trend',
            subtitle: 'Completed-order revenue over time',
            trailing: '₹${_formatAmount(analytics.periodRevenue)}',
            trailingColor: accentDark,
          ),
          const SizedBox(height: 18),
          if (analytics.revenueTrend.isEmpty)
            _buildChartEmpty('No completed sales in this period.')
          else
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(
                  points: analytics.revenueTrend,
                  lineColor: accent,
                  fillColor: const Color(0x2014B8A6),
                  valueFormatter: (v) => _compactAmount(v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER TREND
  // =========================================================

  Widget _buildOrderTrend(SellerAnalytics analytics) {
    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.bar_chart_rounded,
            iconColor: purple,
            iconBackground: const Color(0xFFF0EFFF),
            title: 'Order activity',
            subtitle: 'Orders received during this period',
            trailing: '${analytics.periodOrders}',
            trailingColor: primary,
          ),
          const SizedBox(height: 18),
          if (analytics.orderTrend.isEmpty)
            _buildChartEmpty('No orders in this period.')
          else
            SizedBox(
              height: 205,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarChartPainter(
                  points: analytics.orderTrend,
                  barColor: purple,
                  valueFormatter: (v) => v.toStringAsFixed(0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT ANALYTICS
  // =========================================================

  Widget _buildProductAnalytics(SellerAnalytics analytics) {
    if (analytics.topProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.inventory_2_outlined,
        title: 'No product sales yet',
        subtitle:
            'Once an order is completed, your strongest products will appear here.',
      );
    }

    final products = analytics.topProducts.take(5).toList();
    final maxOrders = products.fold<int>(
      0,
      (max, p) => math.max(max, p.orders),
    );

    return _analyticsCard(
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
                      'Top sellers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ranked by completed orders',
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
              _smallPill('${products.length} shown', purple),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < products.length; i++) ...[
            _buildProductBar(
              products[i],
              rank: i + 1,
              maxOrders: maxOrders,
            ),
            if (i != products.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildProductBar(
    ProductPerformance product, {
    required int rank,
    required int maxOrders,
  }) {
    final double fraction = maxOrders <= 0
        ? 0.0
        : (product.orders / maxOrders).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1
                    ? const Color(0xFFFFF5E5)
                    : const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? warning : secondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${_formatAmount(product.revenue)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Container(
                      height: 7,
                      color: const Color(0xFFF0F2F5),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: rank == 1 ? accent : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 62,
              child: Text(
                '${product.orders} ${product.orders == 1 ? 'order' : 'orders'}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, color: secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Text(
            '${product.share.toStringAsFixed(0)}% of period revenue',
            style: const TextStyle(fontSize: 9, color: secondary),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CATEGORY ANALYTICS
  // =========================================================

  Widget _buildCategoryAnalytics(SellerAnalytics analytics) {
    final categories = analytics.categoryPerformance;

    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.donut_large_rounded,
            iconColor: warning,
            iconBackground: const Color(0xFFFFF7E8),
            title: 'Category performance',
            subtitle: 'Where your completed-order revenue comes from',
            trailing: '${categories.length}',
            trailingColor: primary,
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            _buildChartEmpty('No category-level sales are available yet.')
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      values: categories.map((e) => e.revenue).toList(),
                      colors: List.generate(
                        categories.length,
                        (i) => chartColors[i % chartColors.length],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < categories.length; i++) ...[
                        _buildCategoryLegend(
                          categories[i],
                          chartColors[i % chartColors.length],
                        ),
                        if (i != categories.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryLegend(
    CategoryPerformance category,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${category.share.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: secondary,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // PAYMENT ANALYTICS
  // =========================================================

  Widget _buildPaymentAnalytics(SellerAnalytics analytics) {
    final online = analytics.onlinePayments;
    final cod = analytics.codPayments;
    final total = online + cod;
    final onlineShare = total == 0 ? 0.0 : online / total;

    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: accentDark,
            iconBackground: const Color(0xFFEAFBF7),
            title: 'Payment mix',
            subtitle: 'How customers are paying for orders',
            trailing: '$total',
            trailingColor: primary,
          ),
          const SizedBox(height: 18),
          if (total == 0)
            _buildChartEmpty('No recognized payment methods in this period.')
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildPaymentStat(
                    icon: Icons.credit_card_rounded,
                    title: 'Online',
                    value: online,
                    share: onlineShare,
                    color: accentDark,
                    background: const Color(0xFFEAFBF7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPaymentStat(
                    icon: Icons.payments_outlined,
                    title: 'COD',
                    value: cod,
                    share: total == 0 ? 0 : cod / total,
                    color: warning,
                    background: const Color(0xFFFFF7E8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  if (onlineShare > 0)
                    Expanded(
                      flex: online,
                      child: Container(height: 10, color: accent),
                    ),
                  if (cod > 0)
                    Expanded(
                      flex: cod,
                      child: Container(height: 10, color: warning),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStat({
    required IconData icon,
    required String title,
    required int value,
    required double share,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value orders',
                  style: const TextStyle(fontSize: 9, color: secondary),
                ),
              ],
            ),
          ),
          Text(
            '${(share * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
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
          description: 'unique customers represented in this period',
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
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
  // CUSTOMER ANALYTICS
  // =========================================================

  Widget _buildCustomerAnalytics(SellerAnalytics analytics) {
    final repeat = analytics.repeatCustomers;
    final unique = analytics.uniqueCustomers;
    final repeatShare = unique == 0 ? 0.0 : repeat / unique;

    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.groups_rounded,
            iconColor: purple,
            iconBackground: const Color(0xFFF0EFFF),
            title: 'Customer behaviour',
            subtitle: 'What the order history says about your buyers',
            trailing: '$unique',
            trailingColor: primary,
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _buildMiniInsight(
                  label: 'Unique customers',
                  value: '$unique',
                  helper: 'in selected period',
                  color: purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniInsight(
                  label: 'Repeat customers',
                  value: '$repeat',
                  helper: '2+ completed orders',
                  color: accentDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Repeat-customer share',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: secondary,
                ),
              ),
              const Spacer(),
              Text(
                '${(repeatShare * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: repeatShare,
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F2F5),
              valueColor: const AlwaysStoppedAnimation<Color>(purple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInsight({
    required String label,
    required String value,
    required String helper,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            helper,
            style: const TextStyle(fontSize: 9, color: secondary),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INVENTORY
  // =========================================================

  Widget _buildInventorySection(SellerAnalytics analytics) {
    final activeRatio = analytics.productCount == 0
        ? 0.0
        : analytics.activeProducts / analytics.productCount;
    final soldRatio = analytics.productCount == 0
        ? 0.0
        : analytics.soldProducts / analytics.productCount;

    return _analyticsCard(
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
          _buildInventoryProgress(
            label: 'Catalogue active',
            value: activeRatio,
            percentage: '${(activeRatio * 100).toStringAsFixed(0)}%',
            color: accent,
          ),
          const SizedBox(height: 11),
          _buildInventoryProgress(
            label: 'Products that generated a sale',
            value: soldRatio,
            percentage: '${(soldRatio * 100).toStringAsFixed(0)}%',
            color: purple,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 17,
                color: purple,
              ),
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

  Widget _buildInventoryProgress({
    required String label,
    required double value,
    required String percentage,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    percentage,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0).toDouble(),
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF0F2F5),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
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
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: secondary),
        ),
      ],
    );
  }

  // =========================================================
  // PRODUCT OPPORTUNITIES
  // =========================================================

  Widget _buildOpportunitySection(SellerAnalytics analytics) {
    final quiet = analytics.quietProducts.take(5).toList();

    return _analyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: warning,
            iconBackground: const Color(0xFFFFF7E8),
            title: 'Product opportunities',
            subtitle: 'Active catalogue products without completed sales',
            trailing: '${analytics.quietProducts.length}',
            trailingColor: warning,
          ),
          const SizedBox(height: 15),
          if (quiet.isEmpty)
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAFBF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: accentDark,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Every active product has generated a completed order.',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                for (int i = 0; i < quiet.length; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          quiet[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(quiet[i].price)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                  if (i != quiet.length - 1) const SizedBox(height: 10),
                ],
                if (analytics.quietProducts.length > 5) ...[
                  const SizedBox(height: 12),
                  Text(
                    '+ ${analytics.quietProducts.length - 5} more active products',
                    style: const TextStyle(
                      fontSize: 10,
                      color: secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // =========================================================
  // COMMON CARDS
  // =========================================================

  Widget _analyticsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required String trailing,
    required Color trailingColor,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: trailingColor,
          ),
        ),
      ],
    );
  }

  Widget _smallPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildChartEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_outlined, size: 27, color: secondary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: secondary),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FOOTER / STATES
  // =========================================================


  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: accent),
    );
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
        color: surface,
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
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadSeller();
  }

  String _periodLabel() {
    if (_selectedPeriod == 0) return 'ALL TIME';
    return 'LAST $_selectedPeriod DAYS';
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(0);
  }

  String _compactAmount(double value) {
    final abs = value.abs();
    if (abs >= 1000000) return '₹${(value / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }
}

// =============================================================
// ANALYTICS ENGINE
// =============================================================

class _AnalyticsEngine {
  static SellerAnalytics build({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    required int periodDays,
  }) {
    final now = DateTime.now();

    DateTime? currentStart;
    DateTime? previousStart;
    DateTime? previousEnd;

    if (periodDays > 0) {
      currentStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: periodDays - 1));
      previousEnd = currentStart.subtract(const Duration(microseconds: 1));
      previousStart = currentStart.subtract(Duration(days: periodDays));
    }

    final allOrders = orders.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['_id'] = doc.id;
      return data;
    }).toList();

    final periodOrders = allOrders.where((order) {
      final date = _timestampToDate(order['timestamp']);
      if (date == null) return false;
      if (currentStart == null) return true;
      return !date.isBefore(currentStart);
    }).toList();

    final previousOrders = periodDays > 0
        ? allOrders.where((order) {
            final date = _timestampToDate(order['timestamp']);
            if (date == null || previousStart == null || previousEnd == null) {
              return false;
            }
            return !date.isBefore(previousStart) && !date.isAfter(previousEnd);
          }).toList()
        : <Map<String, dynamic>>[];

    final completed = periodOrders.where((order) {
      final status = _normaliseStatus(order['paymentStatus']);
      return status == 'done' ||
          status == 'completed' ||
          status == 'paid';
    }).toList();

    final pending = periodOrders.where((order) {
      return _normaliseStatus(order['paymentStatus']) == 'pending';
    }).toList();

    final cancelled = periodOrders.where((order) {
      final status = _normaliseStatus(order['paymentStatus']);
      return status == 'cancelled' || status == 'canceled';
    }).toList();

    final processing = periodOrders.where((order) {
      return _normaliseStatus(order['paymentStatus']) == 'processing';
    }).toList();

    double revenue = 0;
    for (final order in completed) {
      revenue += _price(order['productPrice']);
    }

    double previousRevenue = 0;
    for (final order in previousOrders) {
      final status = _normaliseStatus(order['paymentStatus']);
      if (status == 'done' || status == 'completed' || status == 'paid') {
        previousRevenue += _price(order['productPrice']);
      }
    }

    final averageOrderValue = completed.isEmpty
        ? 0.0
        : revenue / completed.length;

    final completionRate = periodOrders.isEmpty
        ? 0.0
        : (completed.length / periodOrders.length) * 100;

    final customerCounts = <String, int>{};
    for (final order in periodOrders) {
      final id = _customerId(order);
      if (id.isNotEmpty) {
        customerCounts[id] = (customerCounts[id] ?? 0) + 1;
      }
    }

    final uniqueCustomers = customerCounts.length;
    final repeatCustomers = customerCounts.values.where((count) => count >= 2).length;

    int onlinePayments = 0;
    int codPayments = 0;
    for (final order in periodOrders) {
      final method = order['paymentMethod']?.toString().toLowerCase().trim() ?? '';
      if (method == 'online' || method == 'razorpay') {
        onlinePayments++;
      } else if (method == 'cod' || method == 'cash on delivery') {
        codPayments++;
      }
    }

    final productMaps = products
        .map((doc) => Map<String, dynamic>.from(doc.data()))
        .toList();

    final activeProducts = productMaps.where((product) {
      return product['isAvailable'] == true;
    }).length;

    // Catalogue lookup by ID first, title second.
    final productById = <String, Map<String, dynamic>>{};
    final productByTitle = <String, Map<String, dynamic>>{};

    for (final product in productMaps) {
      final id = product['productId']?.toString().trim() ?? '';
      final title = product['title']?.toString().trim() ?? '';
      if (id.isNotEmpty) productById[id] = product;
      if (title.isNotEmpty) productByTitle[_productKey(title)] = product;
    }

    // ---------------------------------------------------------
    // PRODUCT SALES
    // ---------------------------------------------------------

    final productStats = <String, ProductPerformance>{};

    for (final order in completed) {
      final productId = order['productId']?.toString().trim() ?? '';
      final rawProductName = order['productName']?.toString() ?? '';

      // Use the catalogue title when the order contains a valid productId.
      // This gives analytics one canonical display name even when older orders
      // contain slightly different productName values.
      final catalogProduct = productId.isNotEmpty
          ? productById[productId]
          : null;
      final catalogTitle = catalogProduct?['title']?.toString().trim() ?? '';
      final productName = catalogTitle.isNotEmpty
          ? catalogTitle
          : (rawProductName.trim().isEmpty
              ? 'Unknown Product'
              : rawProductName.trim());

      // IMPORTANT: aggregate by normalized product name, not productId.
      // A product can have multiple historical IDs/documents in orders, but
      // if the seller sees the same catalogue product name, it must appear as
      // one product in analytics. Example: Bamboo Lantern ₹1995 + ₹399 = ₹2394.
      final key = _productKey(productName);

      final price = _price(order['productPrice']);
      final existing = productStats[key];

      if (existing == null) {
        productStats[key] = ProductPerformance(
          id: productId,
          name: productName,
          orders: 1,
          revenue: price,
          share: 0,
        );
      } else {
        productStats[key] = ProductPerformance(
          // Keep a real productId when one is available, but do not use it
          // as the aggregation key because the same product may have
          // different historical IDs.
          id: existing.id.isNotEmpty ? existing.id : productId,
          name: existing.name,
          orders: existing.orders + 1,
          revenue: existing.revenue + price,
          share: 0,
          price: existing.price,
          imageUrl: existing.imageUrl,
          sellerId: existing.sellerId,
          sellerName: existing.sellerName,
        );
      }
    }

    var rankedProducts = productStats.values.toList();
    rankedProducts.sort((a, b) {
      final orderCompare = b.orders.compareTo(a.orders);
      if (orderCompare != 0) return orderCompare;
      return b.revenue.compareTo(a.revenue);
    });

    final topProducts = rankedProducts.take(5).map((product) {
      final catalog = _findCatalogProduct(
        product,
        productById,
        productByTitle,
      );
      final share = revenue <= 0 ? 0.0 : (product.revenue / revenue) * 100;

      return ProductPerformance(
        id: product.id,
        name: product.name,
        orders: product.orders,
        revenue: product.revenue,
        share: share,
        price: catalog == null ? 0 : _price(catalog['price']),
        imageUrl: catalog?['imageUrl']?.toString() ?? '',
        sellerId: catalog?['sellerId']?.toString() ?? '',
        sellerName: catalog?['sellerName']?.toString() ?? '',
      );
    }).toList();

    // ---------------------------------------------------------
    // ALL SELLER PRODUCTS WITH ACTUAL SALES VALUES
    // ---------------------------------------------------------

    final allProducts = productMaps.map((product) {
      final productId = product['productId']?.toString().trim() ?? '';
      final productName = product['title']?.toString().trim() ?? 'Untitled product';

      // Sales are aggregated by the canonical product name. Do NOT fall back
      // to productId here because historical orders can contain different
      // product IDs for the same catalogue product. The analytics UI should
      // show one combined sales record for that product.
      final stats = productStats[_productKey(productName)];

      final productRevenue = stats?.revenue ?? 0;
      final productOrders = stats?.orders ?? 0;
      final productShare = revenue <= 0 ? 0.0 : (productRevenue / revenue) * 100;

      return ProductPerformance(
        id: productId,
        name: productName,
        orders: productOrders,
        revenue: productRevenue,
        share: productShare,
        price: _price(product['price']),
        imageUrl: product['imageUrl']?.toString() ?? '',
        sellerId: product['sellerId']?.toString() ?? '',
        sellerName: product['sellerName']?.toString() ?? '',
      );
    }).toList();

    // A product is considered SOLD only when the seller has at least one
    // completed/paid order for that catalogue product in the selected period.
    // Use the same canonical product-name key as productStats so historical
    // orders with different product IDs still count as the same product.
    final soldProductKeys = <String>{};

    for (final order in completed) {
      final productId = order['productId']?.toString().trim() ?? '';
      final rawName = order['productName']?.toString() ?? '';

      // Prefer the current catalogue title when the order's productId maps to
      // a real seller product. Otherwise use the order's productName.
      final catalog = productId.isNotEmpty ? productById[productId] : null;
      final catalogTitle = catalog?['title']?.toString().trim() ?? '';
      final effectiveName = catalogTitle.isNotEmpty
          ? catalogTitle
          : rawName.trim();
      final key = _productKey(effectiveName);

      if (key.isNotEmpty) {
        soldProductKeys.add(key);
      }
    }

    // Count UNIQUE catalogue products with completed sales. This is deliberately
    // based on canonical titles rather than raw order IDs, so the value cannot
    // be inflated by duplicate/historical product IDs or duplicate order rows.
    final catalogueProductKeys = <String>{};
    for (final product in productMaps) {
      final title = product['title']?.toString().trim() ?? '';
      final key = _productKey(title);
      if (key.isNotEmpty) {
        catalogueProductKeys.add(key);
      }
    }

    final soldCatalogueKeys = catalogueProductKeys
        .intersection(soldProductKeys);
    final soldProducts = soldCatalogueKeys.length;

    final quietProducts = <ProductPerformance>[];
    final addedQuietKeys = <String>{};
    for (final product in productMaps) {
      if (product['isAvailable'] != true) continue;

      final id = product['productId']?.toString().trim() ?? '';
      final title = product['title']?.toString() ?? '';
      if (title.trim().isEmpty) continue;
      final titleKey = _productKey(title);

      // Use the exact same sold-product definition as soldProducts.
      // Also avoid showing the same canonical product twice if duplicate
      // catalogue documents exist.
      final sold = soldCatalogueKeys.contains(titleKey);

      if (!sold && addedQuietKeys.add(titleKey)) {
        quietProducts.add(
          ProductPerformance(
            id: id,
            name: title,
            orders: 0,
            revenue: 0,
            share: 0,
            price: _price(product['price']),
            imageUrl: product['imageUrl']?.toString() ?? '',
            sellerId: product['sellerId']?.toString() ?? '',
            sellerName: product['sellerName']?.toString() ?? '',
          ),
        );
      }
    }

    // ---------------------------------------------------------
    // DAILY REVENUE - PRESERVED FOR EXISTING AI PAYLOAD
    // ---------------------------------------------------------

    final dailyMap = <String, double>{};
    for (final order in completed) {
      final date = _timestampToDate(order['timestamp']);
      if (date == null) continue;
      final key = _dateKey(date);
      dailyMap[key] = (dailyMap[key] ?? 0) + _price(order['productPrice']);
    }

    var dailyRevenue = dailyMap.entries.map((entry) {
      final date = _parseDateKey(entry.key);
      return DailyRevenue(
        label: '${date.day}/${date.month}',
        revenue: entry.value,
        maxRevenue: 0,
        date: date,
      );
    }).toList();

    dailyRevenue.sort((a, b) => a.date.compareTo(b.date));

    final maxDailyRevenue = dailyRevenue.isEmpty
        ? 0.0
        : dailyRevenue.map((item) => item.revenue).reduce(math.max);

    dailyRevenue = dailyRevenue
        .map(
          (item) => DailyRevenue(
            label: item.label,
            revenue: item.revenue,
            maxRevenue: maxDailyRevenue,
            date: item.date,
          ),
        )
        .toList();

    // ---------------------------------------------------------
    // VISUAL TREND SERIES
    // ---------------------------------------------------------

    final revenueTrend = _buildTrend(
      orders: completed,
      periodDays: periodDays,
      valueBuilder: (order) => _price(order['productPrice']),
      mode: _TrendMode.revenue,
    );

    final orderTrend = _buildTrend(
      orders: periodOrders,
      periodDays: periodDays,
      valueBuilder: (_) => 1,
      mode: _TrendMode.orders,
    );

    // ---------------------------------------------------------
    // CATEGORY PERFORMANCE
    // ---------------------------------------------------------

    final categoryMap = <String, _CategoryAccumulator>{};

    for (final order in completed) {
      final catalog = _findCatalogForOrder(order, productById, productByTitle);
      final category = (order['category'] ?? catalog?['category'])
              ?.toString()
              .trim() ??
          '';
      final categoryName = category.isEmpty ? 'Uncategorised' : category;
      final key = categoryName.toLowerCase();
      final price = _price(order['productPrice']);

      final accumulator = categoryMap.putIfAbsent(
        key,
        () => _CategoryAccumulator(name: categoryName),
      );
      accumulator.orders++;
      accumulator.revenue += price;
    }

    final categoryPerformance = categoryMap.values.map((item) {
      final share = revenue <= 0 ? 0.0 : (item.revenue / revenue) * 100;
      return CategoryPerformance(
        name: item.name,
        orders: item.orders,
        revenue: item.revenue,
        share: share,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final statusBreakdown = <String, int>{
      'Completed': completed.length,
      'Pending': pending.length,
      'Processing': processing.length,
      'Cancelled': cancelled.length,
    };

    final previousRevenueGrowth = _percentageChange(
      previousRevenue,
      revenue,
    );
    final previousOrderGrowth = _percentageChange(
      previousOrders.length.toDouble(),
      periodOrders.length.toDouble(),
    );

    return SellerAnalytics(
      // Original fields — preserved.
      orderCount: allOrders.length,
      productCount: productMaps.length,
      activeProducts: activeProducts,
      soldProducts: soldProducts,
      unusedProducts: math.max(0, activeProducts - soldProducts),
      periodOrders: periodOrders.length,
      completedOrders: completed.length,
      pendingOrders: pending.length,
      periodRevenue: revenue,
      averageOrderValue: averageOrderValue,
      completionRate: completionRate,
      uniqueCustomers: uniqueCustomers,
      onlinePayments: onlinePayments,
      codPayments: codPayments,
      topProducts: topProducts,
      quietProducts: quietProducts,
      allProducts: allProducts,
      dailyRevenue: dailyRevenue,

      // New fields — additive only.
      revenueTrend: revenueTrend,
      orderTrend: orderTrend,
      categoryPerformance: categoryPerformance,
      statusBreakdown: statusBreakdown,
      repeatCustomers: repeatCustomers,
      previousPeriodRevenue: previousRevenue,
      previousPeriodOrders: previousOrders.length,
      revenueGrowth: previousRevenueGrowth,
      orderGrowth: previousOrderGrowth,
      hasPreviousPeriod: periodDays > 0,
    );
  }

  // Canonical product-name key used throughout analytics.
  // This prevents visually identical catalogue/order names from becoming
  // separate products because of capitalization, repeated spaces, NBSP,
  // or zero-width Unicode characters.
  static String _productKey(String value) {
    return value
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static Map<String, dynamic>? _findCatalogProduct(
    ProductPerformance product,
    Map<String, Map<String, dynamic>> productById,
    Map<String, Map<String, dynamic>> productByTitle,
  ) {
    if (product.id.isNotEmpty) {
      final byId = productById[product.id];
      if (byId != null) return byId;
    }
    return productByTitle[_productKey(product.name)];
  }

  static Map<String, dynamic>? _findCatalogForOrder(
    Map<String, dynamic> order,
    Map<String, Map<String, dynamic>> productById,
    Map<String, Map<String, dynamic>> productByTitle,
  ) {
    final id = order['productId']?.toString().trim() ?? '';
    if (id.isNotEmpty && productById.containsKey(id)) return productById[id];

    final name = order['productName']?.toString() ?? '';
    if (name.trim().isNotEmpty) return productByTitle[_productKey(name)];
    return null;
  }

  static String _customerId(Map<String, dynamic> order) {
    for (final key in const [
      'userId',
      'buyerId',
      'customerId',
      'uid',
    ]) {
      final value = order[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static List<TrendPoint> _buildTrend({
    required List<Map<String, dynamic>> orders,
    required int periodDays,
    required num Function(Map<String, dynamic>) valueBuilder,
    required _TrendMode mode,
  }) {
    final dated = <MapEntry<DateTime, num>>[];
    for (final order in orders) {
      final date = _timestampToDate(order['timestamp']);
      if (date == null) continue;
      dated.add(MapEntry(date, valueBuilder(order)));
    }

    if (dated.isEmpty) return [];

    dated.sort((a, b) => a.key.compareTo(b.key));

    // 7D / 30D: daily. 90D: weekly. All-time: monthly.
    final Map<String, _TrendAccumulator> grouped = {};

    for (final entry in dated) {
      final date = entry.key;
      late String key;
      late DateTime bucketDate;

      if (periodDays == 0) {
        bucketDate = DateTime(date.year, date.month, 1);
        key = '${bucketDate.year}-${bucketDate.month}';
      } else if (periodDays <= 30) {
        bucketDate = DateTime(date.year, date.month, date.day);
        key = _dateKey(bucketDate);
      } else {
        final normalized = DateTime(date.year, date.month, date.day);
        final daysFromEpoch = normalized.difference(DateTime(1970)).inDays;
        final weekStartDays = daysFromEpoch - (daysFromEpoch % 7);
        bucketDate = DateTime(1970).add(Duration(days: weekStartDays));
        key = _dateKey(bucketDate);
      }

      final item = grouped.putIfAbsent(
        key,
        () => _TrendAccumulator(date: bucketDate),
      );
      item.value += entry.value.toDouble();
    }

    final result = grouped.values
        .map(
          (item) => TrendPoint(
            date: item.date,
            label: _trendLabel(item.date, periodDays),
            value: item.value,
            mode: mode,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  static String _trendLabel(DateTime date, int periodDays) {
    if (periodDays == 0) {
      return '${_monthShort(date.month)}\n${date.year.toString().substring(2)}';
    }
    if (periodDays > 30) {
      return '${date.day}/${date.month}';
    }
    return '${date.day}/${date.month}';
  }

  static String _monthShort(int month) {
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
    return months[month - 1];
  }

  static double _percentageChange(double previous, double current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return 100;
    }
    return ((current - previous) / previous) * 100;
  }

  static double _price(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(
          value
              .toString()
              .replaceAll('₹', '')
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  static String _normaliseStatus(dynamic value) {
    return value?.toString().toLowerCase().trim() ?? '';
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

class _CategoryAccumulator {
  final String name;
  int orders = 0;
  double revenue = 0;

  _CategoryAccumulator({required this.name});
}

class _TrendAccumulator {
  final DateTime date;
  double value = 0;

  _TrendAccumulator({required this.date});
}

enum _TrendMode { revenue, orders }

// =============================================================
// ANALYTICS MODELS
// =============================================================

class SellerAnalytics {
  // Original fields.
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
  final List<ProductPerformance> topProducts;
  final List<ProductPerformance> quietProducts;
  final List<ProductPerformance> allProducts;
  final List<DailyRevenue> dailyRevenue;

  // New visual-analysis fields. Additive so existing consumers are safe.
  final List<TrendPoint> revenueTrend;
  final List<TrendPoint> orderTrend;
  final List<CategoryPerformance> categoryPerformance;
  final Map<String, int> statusBreakdown;
  final int repeatCustomers;
  final double previousPeriodRevenue;
  final int previousPeriodOrders;
  final double revenueGrowth;
  final double orderGrowth;
  final bool hasPreviousPeriod;

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
    List<TrendPoint>? revenueTrend,
    List<TrendPoint>? orderTrend,
    List<CategoryPerformance>? categoryPerformance,
    Map<String, int>? statusBreakdown,
    this.repeatCustomers = 0,
    this.previousPeriodRevenue = 0,
    this.previousPeriodOrders = 0,
    this.revenueGrowth = 0,
    this.orderGrowth = 0,
    this.hasPreviousPeriod = false,
  })  : topProducts = List<ProductPerformance>.unmodifiable(
          topProducts ?? const <ProductPerformance>[],
        ),
        quietProducts = List<ProductPerformance>.unmodifiable(
          quietProducts ?? const <ProductPerformance>[],
        ),
        allProducts = List<ProductPerformance>.unmodifiable(
          allProducts ?? const <ProductPerformance>[],
        ),
        dailyRevenue = List<DailyRevenue>.unmodifiable(
          dailyRevenue ?? const <DailyRevenue>[],
        ),
        revenueTrend = List<TrendPoint>.unmodifiable(
          revenueTrend ?? const <TrendPoint>[],
        ),
        orderTrend = List<TrendPoint>.unmodifiable(
          orderTrend ?? const <TrendPoint>[],
        ),
        categoryPerformance = List<CategoryPerformance>.unmodifiable(
          categoryPerformance ?? const <CategoryPerformance>[],
        ),
        statusBreakdown = Map<String, int>.unmodifiable(
          statusBreakdown ?? const <String, int>{},
        );

  // IMPORTANT: Original Gemini payload keys are preserved.
  // New fields are added without removing the existing AI context.
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
        'repeatCustomers': repeatCustomers,
        'soldProducts': soldProducts,
        'unusedProducts': unusedProducts,
      },
      'payments': {
        'online': onlinePayments,
        'cashOnDelivery': codPayments,
      },
      'growth': {
        'hasPreviousPeriod': hasPreviousPeriod,
        'previousPeriodRevenue': previousPeriodRevenue,
        'revenueGrowth': revenueGrowth,
        'previousPeriodOrders': previousPeriodOrders,
        'orderGrowth': orderGrowth,
      },
      'statusBreakdown': statusBreakdown,
      'categories': categoryPerformance.map((category) {
        return {
          'name': category.name,
          'orders': category.orders,
          'revenue': category.revenue,
          'revenueShare': category.share,
        };
      }).toList(),
      'customers': {
        'unique': uniqueCustomers,
        'repeat': repeatCustomers,
      },
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
      'visualTrends': {
        'revenue': revenueTrend.map((point) {
          return {
            'date': point.date.toIso8601String(),
            'label': point.label,
            'value': point.value,
          };
        }).toList(),
        'orders': orderTrend.map((point) {
          return {
            'date': point.date.toIso8601String(),
            'label': point.label,
            'value': point.value,
          };
        }).toList(),
      },
    };
  }
}

class ProductPerformance {
  final String id;
  final String name;
  final int orders;
  final double revenue;
  final double share;
  final double price;
  final String imageUrl;
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
    this.sellerId = '',
    this.sellerName = '',
  });
}

class DailyRevenue {
  final String label;
  final double revenue;
  final double maxRevenue;
  final DateTime date;

  DailyRevenue({
    required this.label,
    required this.revenue,
    required this.maxRevenue,
    DateTime? date,
  }) : date = date ?? DateTime(2000);
}

class TrendPoint {
  final DateTime date;
  final String label;
  final double value;
  final _TrendMode mode;

  TrendPoint({
    required this.date,
    required this.label,
    required this.value,
    required this.mode,
  });
}

class CategoryPerformance {
  final String name;
  final int orders;
  final double revenue;
  final double share;

  CategoryPerformance({
    required this.name,
    required this.orders,
    required this.revenue,
    required this.share,
  });
}

// =============================================================
// CHART PAINTERS
// =============================================================

class _LineChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color lineColor;
  final Color fillColor;
  final String Function(double) valueFormatter;

  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 42.0;
    const right = 8.0;
    const top = 18.0;
    const bottom = 30.0;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);

    final maxValue = points.map((p) => p.value).fold<double>(
          0,
          (max, value) => math.max(max, value),
        );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = const Color(0xFFEFF1F4)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 3; i++) {
      final y = top + (chartHeight * i / 2);
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final value = safeMax * (1 - i / 2);
      textPainter.text = TextSpan(
        text: valueFormatter(value),
        style: const TextStyle(
          fontSize: 8,
          color: Color(0xFF98A2B3),
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: left - 5);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (points.length - 1);
      final y = top + chartHeight * (1 - points[i].value / safeMax);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, top + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        final previousX = points.length == 1
            ? left + chartWidth / 2
            : left + chartWidth * (i - 1) / (points.length - 1);
        final previousY =
            top + chartHeight * (1 - points[i - 1].value / safeMax);
        final controlX = (previousX + x) / 2;
        path.cubicTo(
          controlX,
          previousY,
          controlX,
          y,
          x,
          y,
        );
        fillPath.lineTo(x, y);
      }
    }

    final lastX = points.length == 1
        ? left + chartWidth / 2
        : left + chartWidth;
    fillPath.lineTo(lastX, top + chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    final outerDotPaint = Paint()..color = Colors.white;

    for (int i = 0; i < points.length; i++) {
      // Keep the chart visually readable when there are many points.
      final shouldDrawDot = points.length <= 15 ||
          i == 0 ||
          i == points.length - 1 ||
          i % math.max(1, (points.length / 8).round()) == 0;
      if (!shouldDrawDot) continue;

      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (points.length - 1);
      final y = top + chartHeight * (1 - points[i].value / safeMax);
      canvas.drawCircle(Offset(x, y), 5, outerDotPaint);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    // X-axis labels: show a maximum of 6 labels to avoid clutter.
    final labelCount = math.min(6, points.length);
    for (int j = 0; j < labelCount; j++) {
      final index = points.length == 1
          ? 0
          : ((j * (points.length - 1)) / math.max(1, labelCount - 1)).round();
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);

      textPainter.text = TextSpan(
        text: points[index].label,
        style: const TextStyle(
          fontSize: 8,
          color: Color(0xFF98A2B3),
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: 45);
      final double labelX = (x - textPainter.width / 2).clamp(
        left,
        size.width - right - textPainter.width,
      ).toDouble();
      textPainter.paint(
        canvas,
        Offset(labelX, size.height - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _BarChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color barColor;
  final String Function(double) valueFormatter;

  _BarChartPainter({
    required this.points,
    required this.barColor,
    required this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 30.0;
    const right = 8.0;
    const top = 16.0;
    const bottom = 30.0;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final maxValue = points.map((p) => p.value).fold<double>(
          0,
          (max, value) => math.max(max, value),
        );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = const Color(0xFFEFF1F4)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 3; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final value = safeMax * (1 - i / 2);
      textPainter.text = TextSpan(
        text: valueFormatter(value),
        style: const TextStyle(
          fontSize: 8,
          color: Color(0xFF98A2B3),
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: left - 5);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    final visible = math.min(points.length, 18);
    final firstIndex = points.length - visible;
    final gap = chartWidth / math.max(1, visible);
    final barWidth = math.max(5.0, gap * 0.55);

    for (int i = 0; i < visible; i++) {
      final point = points[firstIndex + i];
      final x = left + gap * i + (gap - barWidth) / 2;
      final height = chartHeight * (point.value / safeMax);
      final y = top + chartHeight - height;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, math.max(2, height)),
        const Radius.circular(5),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, chartHeight),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFF1F3F6),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = barColor.withOpacity(0.9),
      );
    }

    final labelCount = math.min(6, visible);
    for (int j = 0; j < labelCount; j++) {
      final localIndex = visible == 1
          ? 0
          : ((j * (visible - 1)) / math.max(1, labelCount - 1)).round();
      final point = points[firstIndex + localIndex];
      final x = left + gap * localIndex + gap / 2;

      textPainter.text = TextSpan(
        text: point.label,
        style: const TextStyle(
          fontSize: 8,
          color: Color(0xFF98A2B3),
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: 45);
      final double labelX = (x - textPainter.width / 2).clamp(
        left,
        size.width - right - textPainter.width,
      ).toDouble();
      textPainter.paint(
        canvas,
        Offset(labelX, size.height - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.barColor != barColor;
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutChartPainter({
    required this.values,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 23.0;
    double startAngle = -math.pi / 2;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );

      startAngle += sweep;
    }

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - strokeWidth / 2 - 1, innerPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Revenue',
        style: TextStyle(
          fontSize: 9,
          color: Color(0xFF667085),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
