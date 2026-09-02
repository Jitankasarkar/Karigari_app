import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:proto_app/screens/seller_analytics_page.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SellerInsights extends StatefulWidget {
  const SellerInsights({super.key});

  @override
  State<SellerInsights> createState() => _SellerInsightsState();
}

class _SellerInsightsState extends State<SellerInsights>
    with SingleTickerProviderStateMixin {
  // =========================================================
  // DESIGN SYSTEM
  // =========================================================

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFF172033);
  static const Color secondary = Color(0xFF667085);
  static const Color muted = Color(0xFF98A2B3);
  static const Color border = Color(0xFFE7E9EE);

  static const Color aiPurple = Color(0xFF6657E8);
  static const Color aiPurpleDark = Color(0xFF5044C7);
  static const Color aiLight = Color(0xFFF2F0FF);

  static const Color green = Color(0xFF0F8A73);
  static const Color greenLight = Color(0xFFE9F8F4);

  static const Color orange = Color(0xFFE28A1B);
  static const Color orangeLight = Color(0xFFFFF5E6);

  // =========================================================
  // ANIMATION
  // =========================================================

  late final AnimationController _animationController;

  // =========================================================
  // SCROLL
  // =========================================================

  late final ScrollController _scrollController;

  // =========================================================
  // GEMINI / AI STATE
  // =========================================================

  String _geminiGrowthInsight = '';

  bool _isGeneratingInsight = false;
  bool _isGeneratingActionPlan = false;

  // Becomes true only after the seller explicitly
  // asks Gemini to generate the growth insight.
  bool _hasGeneratedInsight = false;

  // Used to determine whether the analytics data
  // actually changed.
  String _lastAnalyticsSignature = '';

  // =========================================================
  // REVENUE OPPORTUNITY STATE
  // =========================================================

  bool _scaleProductsExpanded = false;
  bool _quietProductsExpanded = false;
  bool _aovExpanded = false;

  bool _isGeneratingScaleAdvice = false;
  bool _isGeneratingQuietAdvice = false;
  bool _isGeneratingAovAdvice = false;

  String _scaleAdvice = '';
  String _quietAdvice = '';
  String _aovAdvice = '';

  String _scaleCacheSignature = '';
  String _quietCacheSignature = '';
  String _aovCacheSignature = '';

  // =========================================================
  // RECOMMENDED ACTIONS STATE
  // =========================================================

  // Currently selected action card.
  // This will be useful for the floating action window.
  String? _selectedAction;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    // ---------------------------------------------------------
    // Animation
    // ---------------------------------------------------------

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _animationController.forward();

    // ---------------------------------------------------------
    // Scroll controller
    // ---------------------------------------------------------

    _scrollController = ScrollController();

    // ---------------------------------------------------------
    // Listen for seller analytics changes
    // ---------------------------------------------------------

    SellerAnalyticsPage.latestAnalytics.addListener(_onAnalyticsChanged);

    // ---------------------------------------------------------
    // Handle analytics already available when page opens
    // ---------------------------------------------------------

    final SellerAnalytics? analytics =
        SellerAnalyticsPage.latestAnalytics.value;

    if (analytics != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _handleAnalytics(analytics);
      });
    }
  }
  // =========================================================
  // ANALYTICS LISTENER
  // =========================================================

  void _onAnalyticsChanged() {
    final analytics = SellerAnalyticsPage.latestAnalytics.value;

    if (analytics == null) {
      return;
    }

    _handleAnalytics(analytics);
  }

  // =========================================================
  // HANDLE ANALYTICS
  // =========================================================
  //
  // IMPORTANT:
  // This method DOES NOT call Gemini.
  //
  // Gemini is only called when the seller taps
  // "Generate growth insight".
  // =========================================================

  void _handleAnalytics(SellerAnalytics analytics) {
    if (!mounted) {
      return;
    }

    if (analytics.topProducts.isEmpty) {
      setState(() {
        _lastAnalyticsSignature = '';
        _geminiGrowthInsight = '';
        _hasGeneratedInsight = false;
        _isGeneratingInsight = false;
      });

      return;
    }

    final top = analytics.topProducts.first;

    final signature =
        '${top.name}|'
        '${top.orders}|'
        '${top.revenue}|'
        '${top.share}';

    // Analytics have not changed.
    // Do NOT clear the generated insight.
    if (signature == _lastAnalyticsSignature) {
      return;
    }

    _lastAnalyticsSignature = signature;

    // The underlying sales data changed.
    // The old AI insight is no longer considered current.
    setState(() {
      _geminiGrowthInsight = '';
      _hasGeneratedInsight = false;
      _isGeneratingInsight = false;
    });
  }

  // =========================================================
  // GEMINI - GROWTH INSIGHT
  // =========================================================

  Future<void> _generateGrowthInsight(SellerAnalytics analytics) async {
    if (analytics.topProducts.isEmpty) {
      return;
    }

    final top = analytics.topProducts.first;

    if (!mounted) {
      return;
    }

    // ---------------------------------------------------------
    // START REASONING STATE
    // ---------------------------------------------------------

    setState(() {
      _isGeneratingInsight = true;
      _hasGeneratedInsight = false;
      _geminiGrowthInsight = '';
    });

    debugPrint('GROWTH INSIGHT: started');
    debugPrint('GROWTH INSIGHT: product = ${top.name}');

    try {
      // -------------------------------------------------------
      // FIREBASE AI WITH APP CHECK
      // -------------------------------------------------------

      final model = FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(model: 'gemini-3.6-flash');

      // -------------------------------------------------------
      // PROMPT
      // -------------------------------------------------------

      final prompt =
          '''
You are the AI growth agent for a small artisan marketplace seller.

Analyze ONLY the provided business data.

The strongest product is:

Product name: ${top.name}
Completed orders: ${top.orders}
Revenue: ₹${top.revenue.toStringAsFixed(0)}
Revenue share: ${top.share.toStringAsFixed(1)}%

Overall shop data:

Completed orders: ${analytics.completedOrders}
Pending orders: ${analytics.pendingOrders}
Total revenue in selected period: ₹${analytics.periodRevenue.toStringAsFixed(0)}
Average order value: ₹${analytics.averageOrderValue.toStringAsFixed(0)}
Active products: ${analytics.activeProducts}
Products without completed sales: ${analytics.unusedProducts}

Write ONE short merchant-facing growth insight.

Rules:
- Maximum 45 words.
- Sound like an intelligent growth agent, not a generic chatbot.
- Explain WHY this product is the strongest signal.
- Do not invent customer behaviour.
- Do not invent percentages or statistics.
- Do not mention that you are Gemini.
- Do not use bullet points.
- Focus on what the merchant should understand from this signal.
''';

      debugPrint('GROWTH INSIGHT: sending request to Gemini');

      // -------------------------------------------------------
      // GEMINI REQUEST
      // -------------------------------------------------------

      final response = await model.generateContent([Content.text(prompt)]);

      debugPrint('GROWTH INSIGHT: Gemini responded');

      final text = response.text?.trim() ?? '';

      debugPrint('GROWTH INSIGHT RESPONSE: $text');

      if (!mounted) {
        return;
      }

      // -------------------------------------------------------
      // SHOW RESULT
      // -------------------------------------------------------

      setState(() {
        _geminiGrowthInsight = text.isNotEmpty
            ? text
            : _fallbackGrowthInsight(top);

        _isGeneratingInsight = false;
        _hasGeneratedInsight = true;
      });
    } catch (e, stackTrace) {
      debugPrint('GROWTH INSIGHT ERROR: $e');

      debugPrint('GROWTH INSIGHT STACKTRACE: $stackTrace');

      if (!mounted) {
        return;
      }

      // Even if Gemini fails, show the local fallback
      // so the card does not remain stuck.
      setState(() {
        _geminiGrowthInsight = _fallbackGrowthInsight(top);

        _isGeneratingInsight = false;
        _hasGeneratedInsight = true;
      });
    }
  }

  // =========================================================
  // GEMINI - ACTION PLAN
  // =========================================================

  Future<void> _generateActionPlan(SellerAnalytics analytics) async {
    // Action plan cannot be opened until the growth
    // insight has actually been generated.
    if (!_hasGeneratedInsight) {
      return;
    }

    if (_isGeneratingActionPlan) {
      return;
    }

    if (analytics.topProducts.isEmpty) {
      return;
    }

    final top = analytics.topProducts.first;

    if (!mounted) {
      return;
    }

    setState(() {
      _isGeneratingActionPlan = true;
    });

    debugPrint('ACTION PLAN: started');
    debugPrint('ACTION PLAN: product = ${top.name}');

    try {
      // -------------------------------------------------------
      // FIREBASE AI WITH APP CHECK
      // -------------------------------------------------------

      final model = FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(model: 'gemini-3.6-flash');

      // -------------------------------------------------------
      // PROMPT
      // -------------------------------------------------------

      final prompt =
          '''
You are an AI growth agent helping an artisan seller.

The seller's strongest product signal is:

Product: ${top.name}
Completed orders: ${top.orders}
Revenue: ₹${top.revenue.toStringAsFixed(0)}
Revenue share: ${top.share.toStringAsFixed(1)}%

Shop context:

Completed orders: ${analytics.completedOrders}
Total revenue: ₹${analytics.periodRevenue.toStringAsFixed(0)}
Average order value: ₹${analytics.averageOrderValue.toStringAsFixed(0)}
Active products: ${analytics.activeProducts}
Products without completed sales: ${analytics.unusedProducts}
Pending orders: ${analytics.pendingOrders}

Create a practical action plan for the merchant.

Return exactly 3 actions.

For each action use this format:

1. ACTION TITLE
What to do: one concise sentence.
Why: one concise sentence.

Rules:
- Use only the supplied data.
- Never invent customer preferences.
- Never invent statistics.
- Never claim that customers prefer something unless the data proves it.
- Do not guarantee revenue growth.
- Keep the advice realistic for a small artisan seller.
- Prioritize increasing visibility of the strongest product.
- Keep the response concise.
''';

      debugPrint('ACTION PLAN: sending request to Gemini');

      // -------------------------------------------------------
      // GEMINI REQUEST
      // -------------------------------------------------------

      final response = await model.generateContent([Content.text(prompt)]);

      debugPrint('ACTION PLAN: Gemini responded');

      final text = response.text?.trim() ?? '';

      debugPrint('ACTION PLAN RESPONSE: $text');

      if (!mounted) {
        return;
      }

      setState(() {
        _isGeneratingActionPlan = false;
      });

      _showActionPlan(
        title: top.name,
        response: text.isNotEmpty
            ? text
            : 'Gemini did not return an action plan.',
      );
    } catch (e, stackTrace) {
      debugPrint('ACTION PLAN ERROR: $e');

      debugPrint('ACTION PLAN STACKTRACE: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isGeneratingActionPlan = false;
      });

      _showActionPlan(
        title: top.name,
        response:
            'I could not generate the action plan right now. '
            'Please try again.',
      );
    }
  }

  // =========================================================
  // FALLBACK
  // =========================================================

  String _fallbackGrowthInsight(ProductPerformance top) {
    return '${top.name} is currently your strongest sales signal, '
        'with ${top.orders} completed orders contributing '
        '${top.share.toStringAsFixed(0)}% of observed revenue.';
  }

  // =========================================================
  // ACTION PLAN SHEET
  // =========================================================

  void _showActionPlan({required String title, required String response}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: const BoxDecoration(
            color: background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // HANDLE
                  // ------------------------------------------------

                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // HEADER
                  // ------------------------------------------------
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: aiLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: aiPurple,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI action plan',
                              style: TextStyle(
                                color: primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Generated from your shop signals',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // FOCUS PRODUCT
                  // ------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FOCUS PRODUCT',
                          style: TextStyle(
                            color: aiPurple,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          title,
                          style: const TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ------------------------------------------------
                  // AI RESPONSE
                  // ------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      response,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'AI recommendations are based on the sales signals currently available.',
                    style: TextStyle(color: muted, fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SellerAnalytics?>(
      valueListenable: SellerAnalyticsPage.latestAnalytics,
      builder: (context, analytics, child) {
        if (analytics == null) {
          return _buildWaitingState();
        }

        return Container(
          color: background,
          child: SafeArea(
            top: false,
            child: RefreshIndicator(
              color: aiPurple,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =====================================================
                    // HEADER
                    // =====================================================

                    _animated(0.0, 0.25, _buildHeader()),

                    const SizedBox(height: 20),

                    // =====================================================
                    // GROWTH SIGNAL
                    // =====================================================
                    _animated(0.08, 0.42, _buildGrowthSignal(analytics)),

                    const SizedBox(height: 28),

                    // =====================================================
                    // GROWTH OPPORTUNITIES
                    // =====================================================
                    _buildSectionHeader(
                      'Growth opportunities',
                      'Where the agent sees room to grow',
                    ),

                    const SizedBox(height: 14),

                    _buildGrowthOpportunities(analytics),

                    const SizedBox(height: 28),

                    // =====================================================
                    // RECOMMENDED ACTIONS
                    // =====================================================
                    _buildSectionHeader(
                      'Recommended actions',
                      'Your highest-impact next moves',
                    ),

                    const SizedBox(height: 14),

                    _buildActionItems(analytics),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // WAITING STATE
  // =========================================================

  Widget _buildWaitingState() {
    return Container(
      color: background,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: aiPurple,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Reading your shop signals...',
              style: TextStyle(
                color: secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ANIMATION
  // =========================================================

  Widget _animated(double begin, double end, Widget child) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: aiPurple,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Text(
                    'AI Growth',
                    style: TextStyle(
                      color: primary,
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                'Your AI copilot for growing the shop.',
                style: TextStyle(
                  color: secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: aiLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: aiPurple, size: 14),
              SizedBox(width: 5),
              Text(
                'AI',
                style: TextStyle(
                  color: aiPurpleDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // GROWTH SIGNAL
  // =========================================================

  Widget _buildGrowthSignal(SellerAnalytics analytics) {
    if (analytics.topProducts.isEmpty) {
      return _buildNoSignalCard();
    }

    final top = analytics.topProducts.first;

    final bool showReasoning = _isGeneratingInsight;

    final bool showResult = _hasGeneratedInsight && !_isGeneratingInsight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF222B42), Color(0xFF151C2D)],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // SIGNAL HEADER
          // =====================================================

          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFD0CBFF),
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROWTH SIGNAL DETECTED',
                      style: TextStyle(
                        color: Color(0xFFBDB8FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      'I found something worth acting on.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // =====================================================
          // INITIAL STATE
          // =====================================================
          if (!showReasoning && !showResult)
            _buildGenerateInsightButton(analytics),

          // =====================================================
          // REASONING STATE
          // =====================================================
          if (showReasoning) _buildReasoningState(),

          // =====================================================
          // GENERATED RESULT
          // =====================================================
          if (showResult) ...[
            // ---------------------------------------------------
            // PRODUCT TITLE
            // ---------------------------------------------------

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                'Double down on\n${top.name}.',
                key: ValueKey('product-${top.name}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),

            const SizedBox(height: 13),

            // ---------------------------------------------------
            // AI INSIGHT
            // ---------------------------------------------------
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _geminiGrowthInsight,
                key: const ValueKey('insight-result'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ---------------------------------------------------
            // METRICS
            // ---------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: _heroMetric(
                    top.orders.toString(),
                    top.orders == 1 ? 'order' : 'orders',
                  ),
                ),

                _heroDivider(),

                Expanded(
                  child: _heroMetric(_formatCurrency(top.revenue), 'revenue'),
                ),

                _heroDivider(),

                Expanded(
                  child: _heroMetric(
                    '${top.share.toStringAsFixed(0)}%',
                    'sales share',
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 21),

          // =====================================================
          // ACT ON THIS INSIGHT
          // =====================================================
          //
          // This button is ALWAYS visible.
          //
          // Before the AI insight is generated:
          //     disabled
          //
          // After the AI insight is generated:
          //     enabled
          //
          // While action plan is being generated:
          //     disabled
          //
          // =====================================================
          _buildActOnInsightButton(analytics),
        ],
      ),
    );
  }

  // =========================================================
  // GENERATE INSIGHT BUTTON
  // =========================================================

  Widget _buildGenerateInsightButton(SellerAnalytics analytics) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: _isGeneratingInsight
            ? null
            : () {
                _generateGrowthInsight(analytics);
              },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          decoration: BoxDecoration(
            color: aiPurple.withOpacity(0.18),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFF7E73F0).withOpacity(0.45),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFBDB8FF),
                size: 20,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Generate growth insight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFBDB8FF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // REASONING STATE
  // =========================================================

  Widget _buildReasoningState() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Row(
        key: const ValueKey('growth-reasoning'),
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFBDB8FF),
            ),
          ),

          const SizedBox(width: 9),

          const Expanded(
            child: Text(
              'The growth agent is reasoning...',
              style: TextStyle(
                color: Color(0xFFB9BDCA),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACT ON INSIGHT BUTTON
  // =========================================================

  Widget _buildActOnInsightButton(SellerAnalytics analytics) {
    final bool enabled =
        _hasGeneratedInsight &&
        !_isGeneratingInsight &&
        !_isGeneratingActionPlan;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: enabled
              ? () {
                  _generateActionPlan(analytics);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  _isGeneratingActionPlan
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_upward_rounded,
                  color: const Color(0xFFBDB8FF),
                  size: 20,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    _isGeneratingActionPlan
                        ? 'Building your action plan...'
                        : 'Act on this insight',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFFBDB8FF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HERO METRIC
  // =========================================================

  Widget _heroMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // HERO DIVIDER
  // =========================================================

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: Colors.white.withOpacity(0.10),
    );
  }

  // =========================================================
  // NO SIGNAL
  // =========================================================

  Widget _buildNoSignalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: aiPurple, size: 25),

          SizedBox(height: 12),

          Text(
            'Building your first growth signal',
            style: TextStyle(
              color: primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Complete more orders and the AI agent will be able to identify your strongest product signals.',
            style: TextStyle(color: secondary, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION HEADER
  // =========================================================

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: primary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,
          style: const TextStyle(
            color: secondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // REVENUE GROWTH OPPORTUNITIES
  // =========================================================

  Widget _buildGrowthOpportunities(SellerAnalytics analytics) {
    final List<Widget> cards = [];

    if (analytics.topProducts.isNotEmpty) {
      cards.add(
        _buildOpportunityWithDetails(
          icon: Icons.trending_up_rounded,
          color: green,
          background: greenLight,
          tag: 'STRONG SIGNAL',
          title: 'Scale best products',
          description:
              'Put more visibility behind the products already generating the strongest completed-order signals.',
          evidence:
              '${analytics.topProducts.length.clamp(1, 3)} strongest products available',
          expanded: _scaleProductsExpanded,
          loading: _isGeneratingScaleAdvice,
          onShow: () => _toggleScaleProducts(analytics),
          panel: _buildScaleProductsPanel(analytics),
        ),
      );
    }

    if (analytics.unusedProducts > 0) {
      cards.add(
        _buildOpportunityWithDetails(
          icon: Icons.visibility_outlined,
          color: orange,
          background: orangeLight,
          tag: 'CATALOGUE',
          title: 'Wake up quiet products',
          description:
              '${analytics.unusedProducts} active products have not generated a completed order yet.',
          evidence: '${analytics.unusedProducts} products need attention',
          expanded: _quietProductsExpanded,
          loading: _isGeneratingQuietAdvice,
          onShow: () => _toggleQuietProducts(analytics),
          panel: _buildQuietProductsPanel(analytics),
        ),
      );
    }

    if (analytics.averageOrderValue > 0) {
      cards.add(
        _buildOpportunityWithDetails(
          icon: Icons.shopping_bag_outlined,
          color: aiPurple,
          background: aiLight,
          tag: 'REVENUE',
          title: 'Increase order values',
          description:
              'Use your existing product signals to test simple bundles and add-ons that can make each order larger.',
          evidence:
              'Current AOV ${_formatCurrency(analytics.averageOrderValue)}',
          expanded: _aovExpanded,
          loading: _isGeneratingAovAdvice,
          onShow: () => _toggleAov(analytics),
          panel: _buildAovPanel(analytics),
        ),
      );
    }

    if (cards.isEmpty) {
      return _buildOpportunityCard(
        icon: Icons.auto_awesome_rounded,
        color: aiPurple,
        background: aiLight,
        tag: 'LEARNING',
        title: 'Give the agent more signals',
        description:
            'More completed sales will unlock stronger growth recommendations.',
        evidence:
            '${analytics.orderCount} orders • ${analytics.productCount} products',
      );
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  // =========================================================
  // OPPORTUNITY CARD + EXPANDABLE GEMINI PANEL
  // =========================================================

  Widget _buildOpportunityWithDetails({
    required IconData icon,
    required Color color,
    required Color background,
    required String tag,
    required String title,
    required String description,
    required String evidence,
    required bool expanded,
    required bool loading,
    required VoidCallback onShow,
    required Widget panel,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      style: const TextStyle(
                        color: secondary,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            evidence,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: loading ? null : onShow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: expanded
                                    ? color.withOpacity(0.10)
                                    : background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (loading)
                                    SizedBox(
                                      width: 11,
                                      height: 11,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                        color: color,
                                      ),
                                    )
                                  else
                                    Icon(
                                      expanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: color,
                                      size: 15,
                                    ),
                                  const SizedBox(width: 3),
                                  Text(
                                    loading
                                        ? 'Thinking'
                                        : expanded
                                        ? 'Hide'
                                        : 'Show',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: expanded ? panel : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // =========================================================
  // SCALE BEST PRODUCTS
  // =========================================================

  Future<void> _toggleScaleProducts(SellerAnalytics analytics) async {
    if (_scaleProductsExpanded) {
      setState(() => _scaleProductsExpanded = false);
      return;
    }

    if (_scaleAdvice.isNotEmpty &&
        _scaleCacheSignature == _analyticsSignature(analytics)) {
      setState(() => _scaleProductsExpanded = true);
      return;
    }

    if (_isGeneratingScaleAdvice || analytics.topProducts.isEmpty) {
      return;
    }

    setState(() {
      _scaleProductsExpanded = true;
      _isGeneratingScaleAdvice = true;
      _scaleAdvice = '';
    });

    try {
      final products = analytics.topProducts.take(3).toList();
      final productData = products
          .asMap()
          .entries
          .map(
            (entry) =>
                '${entry.key + 1}. ${entry.value.name} | orders: ${entry.value.orders} | revenue: ₹${entry.value.revenue.toStringAsFixed(0)}',
          )
          .join('\n');

      final model = _geminiModel();
      final prompt =
          '''
You are an AI growth agent for a small artisan marketplace seller.

Use ONLY these observed product sales signals:
$productData

Generate practical ways to scale these products.
Return one concise section for each product. For each product give:
- Product name
- One concrete scaling action
- One short reason based only on its observed sales signal

Do not invent customer preferences, demand, statistics, product features, or results.
Do not guarantee revenue growth.
Keep the whole answer under 180 words.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        _scaleAdvice = text.isNotEmpty
            ? text
            : 'Gemini did not return scaling advice.';
        _scaleCacheSignature = _analyticsSignature(analytics);
        _isGeneratingScaleAdvice = false;
      });
    } catch (e, stackTrace) {
      debugPrint('SCALE PRODUCTS ERROR: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _scaleAdvice =
            'I could not generate scaling advice right now. Please try again.';
        _scaleCacheSignature = _analyticsSignature(analytics);
        _isGeneratingScaleAdvice = false;
      });
    }
  }

  Widget _buildScaleProductsPanel(SellerAnalytics analytics) {
    final products = analytics.topProducts.take(3).toList();

    return _buildOpportunityPanel(
      color: green,
      title: 'Top selling products',
      subtitle: 'Your strongest observed sales signals',
      loading: _isGeneratingScaleAdvice,
      advice: _scaleAdvice,
      child: Column(
        children: [
          for (int i = 0; i < products.length; i++) ...[
            _buildProductSignalCard(
              product: products[i],
              rank: i + 1,
              color: green,
              background: greenLight,
            ),
            if (i != products.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // QUIET PRODUCTS
  // =========================================================

  Future<void> _toggleQuietProducts(SellerAnalytics analytics) async {
    if (_quietProductsExpanded) {
      setState(() => _quietProductsExpanded = false);
      return;
    }

    if (_quietAdvice.isNotEmpty &&
        _quietCacheSignature == _analyticsSignature(analytics)) {
      setState(() => _quietProductsExpanded = true);
      return;
    }

    if (_isGeneratingQuietAdvice) return;

    final quietProducts = analytics.quietProducts;
    if (quietProducts.isEmpty) {
      setState(() {
        _quietProductsExpanded = true;
        _quietAdvice =
            'There are no quiet products to analyse in the current data.';
        _quietCacheSignature = _analyticsSignature(analytics);
      });
      return;
    }

    setState(() {
      _quietProductsExpanded = true;
      _isGeneratingQuietAdvice = true;
      _quietAdvice = '';
    });

    try {
      final productData = quietProducts
          .take(8)
          .map((product) => '- ${product.name}')
          .join('\n');

      final model = _geminiModel();
      final prompt =
          '''
You are an AI growth agent helping a small artisan seller.

These active products have zero completed sales in the selected period:
$productData

Give practical ways to wake up these quiet products.
Start with a short principle, then give concise advice for the listed products.
Focus on improving visibility, listing presentation, positioning, and testing.

Rules:
- Use only the supplied product names and the fact that they have zero completed sales.
- Never invent why customers ignored a product.
- Never invent customer preferences, statistics, product features, or demand.
- Do not guarantee sales.
- Keep the whole answer under 180 words.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        _quietAdvice = text.isNotEmpty
            ? text
            : 'Gemini did not return advice for the quiet products.';
        _quietCacheSignature = _analyticsSignature(analytics);
        _isGeneratingQuietAdvice = false;
      });
    } catch (e, stackTrace) {
      debugPrint('QUIET PRODUCTS ERROR: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _quietAdvice =
            'I could not generate advice for the quiet products right now. Please try again.';
        _quietCacheSignature = _analyticsSignature(analytics);
        _isGeneratingQuietAdvice = false;
      });
    }
  }

  Widget _buildQuietProductsPanel(SellerAnalytics analytics) {
    final products = analytics.quietProducts.take(8).toList();

    return _buildOpportunityPanel(
      color: orange,
      title: 'Quiet products',
      subtitle: 'Active listings with no completed sales',
      loading: _isGeneratingQuietAdvice,
      advice: _quietAdvice,
      child: products.isEmpty
          ? const Text(
              'No quiet product names are available in the current analytics data.',
              style: TextStyle(color: secondary, fontSize: 11, height: 1.45),
            )
          : Column(
              children: [
                for (int i = 0; i < products.length; i++) ...[
                  _buildQuietProductCard(products[i]),
                  if (i != products.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _buildQuietProductCard(ProductPerformance product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: orangeLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: orange,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '0 sales',
            style: TextStyle(
              color: orange,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // INCREASE ORDER VALUES
  // =========================================================

  Future<void> _toggleAov(SellerAnalytics analytics) async {
    if (_aovExpanded) {
      setState(() => _aovExpanded = false);
      return;
    }

    if (_aovAdvice.isNotEmpty &&
        _aovCacheSignature == _analyticsSignature(analytics)) {
      setState(() => _aovExpanded = true);
      return;
    }

    if (_isGeneratingAovAdvice) return;

    setState(() {
      _aovExpanded = true;
      _isGeneratingAovAdvice = true;
      _aovAdvice = '';
    });

    try {
      final productData = analytics.topProducts
          .take(5)
          .map(
            (product) =>
                '- ${product.name}: ${product.orders} orders, ₹${product.revenue.toStringAsFixed(0)} revenue',
          )
          .join('\n');

      final model = _geminiModel();
      final prompt =
          '''
You are an AI growth agent for a small artisan seller.

Current average order value: ₹${analytics.averageOrderValue.toStringAsFixed(0)}
Observed product sales:
$productData

Suggest practical ways to increase average order value using only these observed shop signals.
Use the listed products as real examples from this shop, but DO NOT claim that any two products were bought together because that data is not supplied.

Give 3 concise ideas. Each idea should include:
1. What to try.
2. Which listed products could be used as an example.
3. Why the idea is reasonable from the available sales data.

Do not invent customer preferences, basket combinations, statistics, or product features.
Do not guarantee revenue growth.
Keep the whole answer under 180 words.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        _aovAdvice = text.isNotEmpty
            ? text
            : 'Gemini did not return AOV recommendations.';
        _aovCacheSignature = _analyticsSignature(analytics);
        _isGeneratingAovAdvice = false;
      });
    } catch (e, stackTrace) {
      debugPrint('AOV ADVICE ERROR: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _aovAdvice =
            'I could not generate AOV recommendations right now. Please try again.';
        _aovCacheSignature = _analyticsSignature(analytics);
        _isGeneratingAovAdvice = false;
      });
    }
  }

  Widget _buildAovPanel(SellerAnalytics analytics) {
    final products = analytics.topProducts.take(5).toList();

    return _buildOpportunityPanel(
      color: aiPurple,
      title: 'AOV growth ideas',
      subtitle: 'Examples based on products already selling',
      loading: _isGeneratingAovAdvice,
      advice: _aovAdvice,
      child: products.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: products
                  .map(
                    (product) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: aiLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '${product.name} • ${product.orders} orders',
                        style: const TextStyle(
                          color: aiPurpleDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  // =========================================================
  // COMMON AI PANEL
  // =========================================================

  Widget _buildOpportunityPanel({
    required Color color,
    required String title,
    required String subtitle,
    required bool loading,
    required String advice,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: secondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (title == 'Top selling products') {
                      setState(() => _scaleProductsExpanded = false);
                    } else if (title == 'Quiet products') {
                      setState(() => _quietProductsExpanded = false);
                    } else {
                      setState(() => _aovExpanded = false);
                    }
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: secondary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 13),
          if (loading)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'The growth agent is reasoning...',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else if (advice.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                advice,
                style: const TextStyle(
                  color: primary,
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductSignalCard({
    required ProductPerformance product,
    required int rank,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product.orders} ${product.orders == 1 ? 'order' : 'orders'}',
                  style: const TextStyle(
                    color: secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCurrency(product.revenue),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _analyticsSignature(SellerAnalytics analytics) {
    final top = analytics.topProducts
        .take(5)
        .map((p) => '${p.name}|${p.orders}|${p.revenue}|${p.share}')
        .join(';;');

    final quiet = analytics.quietProducts.map((p) => p.name).join('|');

    return '$top::$quiet::${analytics.averageOrderValue}';
  }

  GenerativeModel _geminiModel() {
    return FirebaseAI.googleAI(
      appCheck: FirebaseAppCheck.instance,
    ).generativeModel(model: 'gemini-3.6-flash');
  }

  // =========================================================
  // OPPORTUNITY CARD FALLBACK
  // =========================================================

  Widget _buildOpportunityCard({
    required IconData icon,
    required Color color,
    required Color background,
    required String tag,
    required String title,
    required String description,
    required String evidence,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: secondary,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  evidence,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // RECOMMENDED ACTIONS
  // =========================================================
  // =========================================================
  // RECOMMENDED ACTIONS
  // =========================================================

  // =========================================================
  // RECOMMENDED ACTIONS
  // =========================================================

  Widget _buildActionItems(SellerAnalytics analytics) {
    final actions = <_ActionData>[
      _ActionData(
        title: 'Campaigns',
        description: 'Bring your products forward with focused campaigns.',
        icon: Icons.campaign_outlined,

        // Deep seller-side purple
        color: const Color(0xFF40358F),
        background: const Color(0xFF40358F),

        // Kept only for compatibility with _ActionData.
        // It is NOT displayed on the card.
        badge: '',

        onTap: () => _openActionWorkspace(
          type: _ActionType.campaigns,
          analytics: analytics,
        ),
      ),

      _ActionData(
        title: 'Listings',
        description: 'Make your products easier to discover and understand.',
        icon: Icons.inventory_2_outlined,

        // Deep teal / green
        color: const Color(0xFF176B61),
        background: const Color(0xFF176B61),
        badge: '',

        onTap: () => _openActionWorkspace(
          type: _ActionType.listings,
          analytics: analytics,
        ),
      ),

      _ActionData(
        title: 'Bundles',
        description: 'Pair complementary products to encourage larger orders.',
        icon: Icons.add_link_rounded,

        // Deep warm brown / bronze
        color: const Color(0xFF76502B),
        background: const Color(0xFF76502B),
        badge: '',

        onTap: () => _openActionWorkspace(
          type: _ActionType.bundles,
          analytics: analytics,
        ),
      ),

      _ActionData(
        title: 'Offers',
        description: 'Give selected products another reason to be noticed.',
        icon: Icons.local_offer_outlined,

        // Deep blue
        color: const Color(0xFF28518A),
        background: const Color(0xFF28518A),
        badge: '',

        onTap: () => _openActionWorkspace(
          type: _ActionType.offers,
          analytics: analytics,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 620;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,

            // Slightly taller cards.
            childAspectRatio: compact ? 0.82 : 0.88,
          ),
          itemBuilder: (context, index) {
            return _animated(
              index * 0.05,
              (index * 0.05) + 0.25,
              _buildRecommendedActionCard(actions[index]),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // RECOMMENDED ACTION CARD
  // =========================================================

  Widget _buildRecommendedActionCard(_ActionData action) {
    return _RecommendedActionAnimatedCard(action: action);
  }
  // =========================================================
  // ACTION WORKSPACE
  // =========================================================

  // =========================================================
  // ACTION WORKSPACE
  // LEFT-SIDE FLOATING WORKSPACE
  // =========================================================

  void _openActionWorkspace({
    required _ActionType type,
    required SellerAnalytics analytics,
  }) {
    // Campaigns comes from the LEFT.
    // Listings comes from the RIGHT.
    final bool openFromRight = type == _ActionType.listings;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Action workspace',
      barrierColor: Colors.black.withOpacity(0.42),
      transitionDuration: const Duration(milliseconds: 320),

      pageBuilder: (context, animation, secondaryAnimation) {
        return _ActionWorkspaceSheet(type: type, analytics: analytics);
      },

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final Offset begin = openFromRight
            ? const Offset(1.0, 0.0) // RIGHT
            : const Offset(-1.0, 0.0); // LEFT

        final slideAnimation = Tween<Offset>(begin: begin, end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );

        return SlideTransition(position: slideAnimation, child: child);
      },
    );
  }
  // =========================================================
  // REFRESH
  // =========================================================
  //
  // IMPORTANT:
  //
  // Refresh DOES NOT:
  // - call Gemini
  // - clear the generated insight
  // - regenerate the growth insight
  //
  // It only:
  // - restarts the UI animation
  // - moves the page to the top
  //
  // =========================================================

  Future<void> _refresh() async {
    debugPrint('AI GROWTH: refresh requested');

    // ---------------------------------------------------------
    // Move page back to top
    // ---------------------------------------------------------

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    // ---------------------------------------------------------
    // Restart only the visual entrance animation
    // ---------------------------------------------------------

    if (mounted) {
      _animationController
        ..reset()
        ..forward();
    }

    await Future.delayed(const Duration(milliseconds: 250));

    debugPrint('AI GROWTH: refresh completed without Gemini request');
  }

  // =========================================================
  // FORMATTING
  // =========================================================

  String _formatCurrency(double value) {
    final rounded = value.round();

    final formatted = rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );

    return '₹$formatted';
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    SellerAnalyticsPage.latestAnalytics.removeListener(_onAnalyticsChanged);

    _scrollController.dispose();
    _animationController.dispose();

    super.dispose();
  }
}

// =============================================================
// RECOMMENDED ACTION MODELS
// =============================================================

enum _ActionType { campaigns, listings, bundles, offers }

class _ActionData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color background;
  final String badge;
  final VoidCallback onTap;

  const _ActionData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.background,
    required this.badge,
    required this.onTap,
  });
}
// =============================================================
// SLEEK RECOMMENDED ACTION CARD
// =============================================================

class _RecommendedActionAnimatedCard extends StatefulWidget {
  final _ActionData action;

  const _RecommendedActionAnimatedCard({required this.action});

  @override
  State<_RecommendedActionAnimatedCard> createState() =>
      _RecommendedActionAnimatedCardState();
}

class _RecommendedActionAnimatedCardState
    extends State<_RecommendedActionAnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _translateAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 180),
      value: 0.0,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _translateAnimation = Tween<double>(
      begin: 0.0,
      end: -2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  // =========================================================
  // TAP
  // =========================================================

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;

    setState(() {
      _isPressed = true;
    });

    _controller.forward();
  }

  void _handleTapCancel() {
    if (!mounted) return;

    setState(() {
      _isPressed = false;
    });

    _controller.reverse();
  }

  void _handleTap() {
    if (!mounted) return;

    setState(() {
      _isPressed = false;
    });

    _controller.reverse();

    // IMPORTANT:
    // This calls the callback from _ActionData.
    widget.action.onTap();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateAnimation.value),
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),

          // THIS is the important part.
          onTap: _handleTap,

          onTapDown: _handleTapDown,
          onTapCancel: _handleTapCancel,

          splashColor: Colors.white.withOpacity(0.08),
          highlightColor: Colors.white.withOpacity(0.04),

          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  action.color,
                  Color.lerp(action.color, Colors.black, 0.30) ?? action.color,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: action.color.withOpacity(_isPressed ? 0.15 : 0.22),
                  blurRadius: _isPressed ? 10 : 18,
                  offset: Offset(0, _isPressed ? 4 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // =================================================
                  // LARGE BACKGROUND ICON
                  // =================================================

                  Positioned(
                    right: -18,
                    bottom: -18,
                    child: Icon(
                      action.icon,
                      size: 105,
                      color: Colors.white.withOpacity(0.075),
                    ),
                  ),

                  // =================================================
                  // SMALL BACKGROUND ICON
                  // =================================================
                  Positioned(
                    right: 22,
                    top: -22,
                    child: Icon(
                      action.icon,
                      size: 55,
                      color: Colors.white.withOpacity(0.035),
                    ),
                  ),

                  // =================================================
                  // CONTENT
                  // =================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          _shortDescription(action.title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.16),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Explore',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            Icon(
                              action.icon,
                              color: Colors.white.withOpacity(0.88),
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SHORT DESCRIPTIONS
  // =========================================================

  String _shortDescription(String title) {
    switch (title) {
      case 'Campaigns':
        return 'Create focused campaigns to bring more attention to your products.';

      case 'Listings':
        return 'Improve how your products appear and get discovered.';

      case 'Bundles':
        return 'Combine complementary products to encourage larger orders.';

      case 'Offers':
        return 'Create simple offers that can help turn interest into sales.';

      default:
        return 'Take a smart action to improve your store performance.';
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ListingCandidate {
  final ProductPerformance product;
  final int completedOrders;
  final double revenue;

  const _ListingCandidate({
    required this.product,
    required this.completedOrders,
    required this.revenue,
  });
}

class _SavedListing {
  String firestoreId;

  final String productId;
  final String productName;
  final String productImageUrl;
  final String productPrice;

  final String title;
  final String description;

  final String sellerId;
  final String sellerName;

  String status;
  bool enabled;

  _SavedListing({
    required this.firestoreId,
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.productPrice,
    required this.title,
    required this.description,
    required this.sellerId,
    required this.sellerName,
    required this.status,
    required this.enabled,
  });

  factory _SavedListing.fromFirestore(String id, Map<String, dynamic> data) {
    return _SavedListing(
      firestoreId: id,
      productId: (data['productId'] ?? '').toString(),
      productName: (data['productName'] ?? '').toString(),
      productImageUrl: (data['productImageUrl'] ?? '').toString(),
      productPrice: (data['productPrice'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      status: (data['status'] ?? 'Approved').toString(),
      enabled: data['enabled'] == true,
    );
  }
}
// =============================================================
// ACTION WORKSPACE SHEET
// =============================================================

// =============================================================
// ACTION WORKSPACE - LEFT SIDE PANEL
// =============================================================

class _ActionWorkspaceSheet extends StatefulWidget {
  final _ActionType type;
  final SellerAnalytics analytics;

  const _ActionWorkspaceSheet({required this.type, required this.analytics});

  @override
  State<_ActionWorkspaceSheet> createState() => _ActionWorkspaceSheetState();
}

class _ActionWorkspaceSheetState extends State<_ActionWorkspaceSheet> {
  int _campaignTab = 0;

  // =============================================================
  // LISTING WORKSPACE STATE
  // =============================================================

  int _listingTab = 0;

  // Whether the seller is currently running the shop analysis.
  bool _isAnalyzingShop = false;

  // Current step shown in the agent-style analysis animation.
  int _listingAnalysisStep = 0;

  bool _isGeneratingListing = false;
  int _listingGenerationStep = 0;

  String _generatedListingTitle = '';
  String _generatedListingDescription = '';

  List<_SavedListing> _savedListings = [];
  bool _isLoadingSavedListings = false;

  bool _isSavingListing = false;

  // Products discovered after analysing the seller's
  // all-time completed sales.
  List<_ListingCandidate> _listingCandidates = [];

  // Product selected by the seller for the next stage.
  ProductPerformance? _selectedListingProduct;

  // Product selected in the Create Campaign tab.
  ProductPerformance? _selectedCreateProduct;

  // Product selected in the Generate with AI tab.
  ProductPerformance? _selectedGenerateProduct;

  final TextEditingController _campaignNameController = TextEditingController();

  final TextEditingController _campaignTextController = TextEditingController();

  final TextEditingController _campaignDiscountController =
      TextEditingController();

  String _campaignOfferType = 'percentage';

  bool _isGenerating = false;
  String _generatedCampaignReason = '';
  Timer? _aiLoadingTimer;

  int _aiLoadingStep = 0;

  final List<_DraftCampaign> _campaigns = [];

  // AI-generated campaign draft.
  // This is NOT saved until the seller approves it.
  _DraftCampaign? _generatedCampaignPreview;

  // Manual campaign draft.
  _DraftCampaign? _campaignPreview;

  // =============================================================
  // INIT STATE
  // =============================================================

  @override
  void initState() {
    super.initState();

    if (widget.type == _ActionType.campaigns) {
      _loadSavedCampaigns();
    }
    if (widget.type == _ActionType.listings) {
      _loadSavedListings();
    }
  }

  //bool _showCampaignSaved = false;
  void _resetCampaignForm() {
    setState(() {
      _selectedCreateProduct = null;

      _campaignNameController.clear();
      _campaignTextController.clear();
      _campaignDiscountController.clear();

      _campaignPreview = null;
      _generatedCampaignPreview = null;
      _generatedCampaignReason = '';
    });
  }

  Future<void> _loadSavedCampaigns() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('campaigns')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      final campaigns = snapshot.docs.map((doc) {
        final data = doc.data();

        return _DraftCampaign(
          // Firestore document ID
          firestoreId: doc.id,

          name: data['name']?.toString() ?? '',
          message: data['message']?.toString() ?? '',

          // Product
          productId: data['productId']?.toString() ?? '',
          productName: data['productName']?.toString() ?? '',
          productImageUrl: data['productImageUrl']?.toString() ?? '',

          // Offer
          offer: data['offer']?.toString() ?? '',

          // Seller
          sellerId: data['sellerId']?.toString() ?? '',
          sellerName: data['sellerName']?.toString() ?? '',

          // Campaign state
          status: data['status']?.toString() ?? 'Approved',
          enabled: data['enabled'] == true,

          // AI/manual
          generated: data['generated'] == true,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _campaigns
          ..clear()
          ..addAll(campaigns);
      });
    } catch (e) {
      debugPrint('Error loading saved campaigns: $e');
    }
  }
  // -------------------------------------------------------------
  // COLORS
  // -------------------------------------------------------------

  static const Color _purple = Color(0xFF6657E8);
  static const Color _purpleDark = Color(0xFF5144C9);
  static const Color _purpleSoft = Color(0xFFF3F1FF);
  static const Color _purpleVerySoft = Color(0xFFF8F7FF);

  static const Color _textDark = Color(0xFF171A2A);
  static const Color _textMedium = Color(0xFF667085);
  static const Color _textLight = Color(0xFF98A2B3);

  static const Color _border = Color(0xFFE8E8EF);

  // -------------------------------------------------------------
  // DISPOSE
  // -------------------------------------------------------------

  @override
  void dispose() {
    _campaignNameController.dispose();
    _campaignTextController.dispose();
    _campaignDiscountController.dispose();

    super.dispose();
  }

  // -------------------------------------------------------------
  // TITLE
  // -------------------------------------------------------------

  String get _title {
    switch (widget.type) {
      case _ActionType.campaigns:
        return 'Campaigns';

      case _ActionType.listings:
        return 'Listings';

      case _ActionType.bundles:
        return 'Bundles';

      case _ActionType.offers:
        return 'Offers';
    }
  }

  // -------------------------------------------------------------
  // ICON
  // -------------------------------------------------------------

  IconData get _icon {
    switch (widget.type) {
      case _ActionType.campaigns:
        return Icons.campaign_rounded;

      case _ActionType.listings:
        return Icons.inventory_2_rounded;

      case _ActionType.bundles:
        return Icons.add_link_rounded;

      case _ActionType.offers:
        return Icons.local_offer_rounded;
    }
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Keep the phone status bar white and visible.
        statusBarColor: Colors.white,

        // Dark icons/text for time, battery, notifications, etc.
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,

        // Navigation bar at the bottom.
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          //margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F8FF),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 35,
                offset: Offset(8, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: SafeArea(
              top: true,
              bottom: true,
              child: Column(
                children: [
                  // =================================================
                  // HEADER
                  // =================================================

                  _buildHeader(),

                  // =================================================
                  // BODY
                  // =================================================
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: _buildBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // =============================================================
  // HEADER
  // =============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          // -------------------------------------------------------
          // ICON
          // -------------------------------------------------------

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.type == _ActionType.listings
                  ? const Color(0xFFE9F8F4)
                  : _purpleSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              widget.type == _ActionType.listings
                  ? Icons.inventory_2_outlined
                  : Icons.campaign_rounded,
              color: widget.type == _ActionType.listings
                  ? const Color(0xFF0F8A73)
                  : _purple,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          // -------------------------------------------------------
          // TITLE
          // -------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _headerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textMedium,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------
          // CLOSE
          // -------------------------------------------------------
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF667085),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _headerSubtitle {
    switch (widget.type) {
      case _ActionType.campaigns:
        return 'Turn your growth signals into action';

      case _ActionType.listings:
        return 'Improve product visibility';

      case _ActionType.bundles:
        return 'Create smarter product combinations';

      case _ActionType.offers:
        return 'Turn interest into sales';
    }
  }

  // =============================================================
  // BODY
  // =============================================================

  Widget _buildBody() {
    switch (widget.type) {
      case _ActionType.campaigns:
        return _buildCampaignWorkspace();

      case _ActionType.listings:
        return _buildListingWorkspace();

      case _ActionType.bundles:
        return _buildComingNext(
          icon: Icons.add_link_rounded,
          title: 'Bundle workspace',
          description:
              'Get AI suggestions for product combinations that could increase your average order value.',
        );

      case _ActionType.offers:
        return _buildComingNext(
          icon: Icons.local_offer_outlined,
          title: 'Offer workspace',
          description:
              'Create seller-approved offers with products, discounts, validity periods and buyer-facing messages.',
        );
    }
  }

  // =============================================================
  // LEAST-SOLD PRODUCTS
  // =============================================================

  // =============================================================
  // LISTING WORKSPACE
  // =============================================================

  Widget _buildListingWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildListingTabs(),

        const SizedBox(height: 22),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          child: _listingTab == 0
              ? _buildFeaturedListings()
              : _buildSavedListings(),
        ),
      ],
    );
  }

  // =============================================================
  // LISTING TABS
  // =============================================================

  Widget _buildListingTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _listingTabButton(0, 'Featured', Icons.star_outline_rounded),
          _listingTabButton(1, 'Saved', Icons.bookmark_border_rounded),
        ],
      ),
    );
  }

  Widget _listingTabButton(int index, String label, IconData icon) {
    final bool selected = _listingTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _listingTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? const Color(0xFF0F8A73)
                    : const Color(0xFF667085),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF0F8A73)
                      : const Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // FEATURED LISTINGS
  // =============================================================

  Widget _buildFeaturedListings() {
    // -------------------------------------------------------------
    // ANALYSIS IN PROGRESS
    // -------------------------------------------------------------

    if (_isAnalyzingShop) {
      return _buildListingAnalysisLoader();
    }

    // -------------------------------------------------------------
    // LISTING GENERATION IN PROGRESS
    // -------------------------------------------------------------

    if (_isGeneratingListing) {
      return _buildListingGenerationLoader();
    }

    // -------------------------------------------------------------
    // GENERATED LISTING PREVIEW
    // -------------------------------------------------------------

    if (_generatedListingTitle.isNotEmpty &&
        _generatedListingDescription.isNotEmpty) {
      return _buildGeneratedListingPreview();
    }

    // -------------------------------------------------------------
    // NO ANALYSIS YET
    // -------------------------------------------------------------

    if (_listingCandidates.isEmpty) {
      return _buildListingStart();
    }

    // -------------------------------------------------------------
    // ANALYSIS COMPLETE
    // -------------------------------------------------------------

    return _buildListingRecommendations();
  }
  // =============================================================
  // INITIAL LISTING SCREEN
  // =============================================================

  Widget _buildListingStart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F8F4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD4EEE7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF0F8A73),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Improve product visibility',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Analyze your shop to discover products that could benefit from a stronger featured presence.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Ready to analyze your shop?',
          style: TextStyle(
            color: Color(0xFF172033),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'I’ll review your completed sales and find five products with the lowest sales activity.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _analyzeShopForListings,
            icon: const Icon(Icons.analytics_outlined, size: 19),
            label: const Text(
              'Analyze your shop',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F8A73),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // SHOP ANALYSIS
  // =============================================================

  Future<void> _analyzeShopForListings() async {
    if (_isAnalyzingShop) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please log in again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() {
      _isAnalyzingShop = true;
      _listingAnalysisStep = 0;
      _listingCandidates = [];
      _selectedListingProduct = null;
    });

    try {
      // Start the REAL Firestore calculation immediately.
      final Future<List<_ListingCandidate>> analysisFuture =
          _calculateLeastSoldProducts(user.uid);

      const List<String> steps = [
        'Connecting to your shop data...',
        'Reviewing completed orders...',
        'Comparing product performance...',
        'Finding lower-sales products...',
        'Preparing listing opportunities...',
      ];

      // -----------------------------------------------------------
      // 5-SECOND ANALYSIS EXPERIENCE
      // -----------------------------------------------------------

      for (int i = 0; i < steps.length; i++) {
        if (!mounted) {
          return;
        }

        setState(() {
          _listingAnalysisStep = i;
        });

        await Future.delayed(const Duration(seconds: 1));
      }

      // -----------------------------------------------------------
      // GET REAL RESULT
      // -----------------------------------------------------------

      final candidates = await analysisFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _listingCandidates = candidates;
        _isAnalyzingShop = false;
        _listingAnalysisStep = steps.length;
      });
    } catch (e) {
      debugPrint('LISTING SHOP ANALYSIS ERROR: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzingShop = false;
        _listingAnalysisStep = 0;
        _listingCandidates = [];
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not analyze your shop: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // =============================================================
  // ALL-TIME LEAST-SOLD PRODUCT CALCULATION
  // =============================================================

  Future<List<_ListingCandidate>> _calculateLeastSoldProducts(
    String sellerId,
  ) async {
    // -------------------------------------------------------------
    // SELLER CATALOGUE
    // -------------------------------------------------------------

    final List<ProductPerformance> products = List<ProductPerformance>.from(
      widget.analytics.allProducts,
    );

    if (products.isEmpty) {
      return [];
    }

    // -------------------------------------------------------------
    // GET ALL SELLER ORDERS
    // -------------------------------------------------------------

    final QuerySnapshot<Map<String, dynamic>> ordersSnapshot =
        await FirebaseFirestore.instance
            .collection('orders')
            .where('sellerId', isEqualTo: sellerId)
            .get();

    // productId -> completed order count
    final Map<String, int> orderCounts = {};

    // productId -> completed revenue
    final Map<String, double> revenues = {};

    // -------------------------------------------------------------
    // PROCESS COMPLETED ORDERS
    // -------------------------------------------------------------

    for (final doc in ordersSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();

      final String paymentStatus = (data['paymentStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (paymentStatus != 'done' && paymentStatus != 'completed') {
        continue;
      }

      final String productId = (data['productId'] ?? '').toString().trim();

      if (productId.isEmpty) {
        continue;
      }

      orderCounts[productId] = (orderCounts[productId] ?? 0) + 1;

      final dynamic rawPrice = data['productPrice'];

      double price = 0;

      if (rawPrice is num) {
        price = rawPrice.toDouble();
      } else {
        price =
            double.tryParse(
              rawPrice?.toString().replaceAll(',', '').trim() ?? '',
            ) ??
            0;
      }

      revenues[productId] = (revenues[productId] ?? 0) + price;
    }

    // -------------------------------------------------------------
    // BUILD LISTING CANDIDATES
    // -------------------------------------------------------------

    final List<_ListingCandidate> candidates = products.map((product) {
      return _ListingCandidate(
        product: product,
        completedOrders: orderCounts[product.id] ?? 0,
        revenue: revenues[product.id] ?? 0,
      );
    }).toList();

    // -------------------------------------------------------------
    // SORT
    //
    // 1. Fewest completed orders
    // 2. Lowest revenue if tied
    // -------------------------------------------------------------

    candidates.sort((a, b) {
      final int orderComparison = a.completedOrders.compareTo(
        b.completedOrders,
      );

      if (orderComparison != 0) {
        return orderComparison;
      }

      return a.revenue.compareTo(b.revenue);
    });

    // -------------------------------------------------------------
    // TOP 5 LEAST-SOLD
    // -------------------------------------------------------------

    return candidates.take(5).toList();
  }

  // =============================================================
  // AGENT-STYLE ANALYSIS LOADER
  // =============================================================

  Widget _buildListingAnalysisLoader() {
    const List<Map<String, String>> steps = [
      {
        'title': 'Connecting to your shop data',
        'subtitle': 'Accessing your catalogue and sales records',
      },
      {
        'title': 'Reviewing completed orders',
        'subtitle': 'Looking at your all-time completed sales',
      },
      {
        'title': 'Comparing product performance',
        'subtitle': 'Measuring sales activity across products',
      },
      {
        'title': 'Finding lower-sales products',
        'subtitle': 'Identifying products that could use more visibility',
      },
      {
        'title': 'Preparing listing opportunities',
        'subtitle': 'Organizing the best candidates for you',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEDE8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F8A73).withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F8F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF0F8A73),
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analyzing your shop',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Working through your sales signals',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F8A73)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          ...List.generate(steps.length, (index) {
            final bool completed = index < _listingAnalysisStep;

            final bool current = index == _listingAnalysisStep;

            final bool upcoming = index > _listingAnalysisStep;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: upcoming ? 0.3 : 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: completed
                          ? Container(
                              key: const ValueKey('completed'),
                              width: 25,
                              height: 25,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F8A73),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            )
                          : current
                          ? const SizedBox(
                              key: ValueKey('current'),
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0F8A73),
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('upcoming'),
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD7E6E2),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[index]['title']!,
                            style: TextStyle(
                              color: upcoming
                                  ? const Color(0xFF667085)
                                  : const Color(0xFF172033),
                              fontSize: 12,
                              fontWeight: current || completed
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            steps[index]['subtitle']!,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // =============================================================
  // LISTING RECOMMENDATIONS
  // =============================================================

  Widget _buildListingRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Listing opportunities found',
          style: TextStyle(
            color: Color(0xFF172033),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Based on completed sales across your catalogue, I found these products you can consider for listing.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),

        _buildListingCarousel(),

        const SizedBox(height: 20),

        _buildGenerateListingButton(),
      ],
    );
  }

  // =============================================================
  // HORIZONTAL PRODUCT CAROUSEL
  // =============================================================

  Widget _buildListingCarousel() {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 18),
        itemCount: _listingCandidates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final candidate = _listingCandidates[index];

          final bool selected =
              _selectedListingProduct?.id == candidate.product.id;

          return _buildListingProductCard(candidate, selected);
        },
      ),
    );
  }

  // =============================================================
  // PRODUCT CARD
  // =============================================================

  Widget _buildListingProductCard(_ListingCandidate candidate, bool selected) {
    final ProductPerformance product = candidate.product;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedListingProduct = product;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 166,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF0F8A73) : const Color(0xFFE1E7E5),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFF0F8A73).withOpacity(0.12)
                  : Colors.black.withOpacity(0.035),
              blurRadius: selected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------
            // IMAGE
            // -------------------------------------------------------

            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 105,
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const ColoredBox(
                              color: Color(0xFFE9F8F4),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Color(0xFF0F8A73),
                                size: 28,
                              ),
                            );
                          },
                        )
                      : const ColoredBox(
                          color: Color(0xFFE9F8F4),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF0F8A73),
                            size: 28,
                          ),
                        ),
                ),

                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F8A73),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
              ],
            ),

            // -------------------------------------------------------
            // DETAILS
            // -------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        '₹${product.price.round()}',
                        style: const TextStyle(
                          color: Color(0xFF0F8A73),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(width: 7),

                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F5F4),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${candidate.completedOrders} orders',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
  }

  // =============================================================
  // GENERATE LISTING BUTTON
  // =============================================================

  Widget _buildGenerateListingButton() {
    final bool enabled = _selectedListingProduct != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? _onGenerateListingPressed : null,
        icon: const Icon(Icons.auto_awesome_rounded, size: 19),
        label: const Text(
          'Generate listing',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F8A73),
          disabledBackgroundColor: const Color(0xFFDDECE8),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF8AA9A1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // TEMPORARY GENERATE ACTION
  // =============================================================

  Future<void> _onGenerateListingPressed() async {
    final product = _selectedListingProduct;

    if (product == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Select a product first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() {
      _isGeneratingListing = true;
      _listingGenerationStep = 0;
      _generatedListingTitle = '';
      _generatedListingDescription = '';
    });

    Timer? generationTimer;

    generationTimer = Timer.periodic(const Duration(milliseconds: 900), (
      timer,
    ) {
      if (!mounted || !_isGeneratingListing) {
        timer.cancel();
        return;
      }

      if (_listingGenerationStep < 3) {
        setState(() {
          _listingGenerationStep++;
        });
      }
    });

    try {
      final model = FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(model: 'gemini-3.5-flash-lite');

      final prompt =
          '''
You are creating a buyer-facing featured listing for an artisan marketplace.

The seller has already selected this exact product.

PRODUCT:
Name: ${product.name}
Price: ₹${product.price.round()}
Product ID: ${product.id}
Seller: ${product.sellerName}

IMPORTANT RULES:
- You MUST write the listing for this exact product.
- Do NOT choose another product.
- Do NOT change the product name into a different product.
- Do NOT invent materials, features, craftsmanship details, origin, certifications, guarantees, or specifications.
- Do NOT invent discounts or prices.
- The existing product image and price will be used by the app.
- Create attractive buyer-facing copy.
- Keep the title short and appealing.
- Description should be 2-3 sentences.
- Do not mention AI, analytics, sales, orders, or that the product has low sales.
- Do not mention any discount.

Return ONLY this format:

TITLE: <short buyer-facing title>
DESCRIPTION: <2-3 sentence buyer-facing description>
''';

      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 30));

      generationTimer?.cancel();

      final text = response.text?.trim() ?? '';

      String title = '';
      String description = '';

      for (final line in text.split('\n')) {
        final trimmed = line.trim();

        if (trimmed.toUpperCase().startsWith('TITLE:')) {
          title = trimmed.substring(6).trim();
        } else if (trimmed.toUpperCase().startsWith('DESCRIPTION:')) {
          description = trimmed.substring(12).trim();
        }
      }

      if (title.isEmpty || description.isEmpty) {
        throw Exception('Invalid AI response');
      }

      if (!mounted) return;

      setState(() {
        _generatedListingTitle = title;
        _generatedListingDescription = description;
        _isGeneratingListing = false;
        _listingGenerationStep = 3;
      });
    } on TimeoutException {
      generationTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _isGeneratingListing = false;
        _listingGenerationStep = 0;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('AI generation timed out. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      generationTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _isGeneratingListing = false;
        _listingGenerationStep = 0;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not generate listing: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  //GENERATE ANIMATION////////

  Widget _buildListingGenerationLoader() {
    const steps = [
      'Connecting to your product data...',
      'Understanding the product...',
      'Crafting the buyer-facing message...',
      'Polishing the listing...',
    ];

    final int step = _listingGenerationStep.clamp(0, steps.length - 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFE8DE)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0F8A73),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Creating your listing',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17352F),
            ),
          ),

          const SizedBox(height: 8),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              steps[step],
              key: ValueKey(step),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF66827B)),
            ),
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: Color(0xFFD5EEE8),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F8A73)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedListingPreview() {
    final product = _selectedListingProduct;

    if (product == null ||
        _generatedListingTitle.isEmpty ||
        _generatedListingDescription.isEmpty) {
      return const SizedBox.shrink();
    }

    const green = Color(0xFF0F8A73);
    const greenLight = Color(0xFFE9F8F4);
    const textDark = Color(0xFF17201E);
    const textMedium = Color(0xFF61736E);
    const border = Color(0xFFDCE9E5);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================
          // HEADER
          // =========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              color: greenLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 18, color: green),
                const SizedBox(width: 8),
                const Text(
                  'BUYER PREVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: green,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Featured',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: green,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // PRODUCT CONTENT
          // =========================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------------------------------------------
                // PRODUCT IMAGE
                // ---------------------------------------------------
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: AspectRatio(
                    // Wider ratio = shorter card
                    aspectRatio: 1.55,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        product.imageUrl.isNotEmpty
                            ? Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: const Color(0xFFF2F5F4),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      size: 38,
                                      color: Color(0xFF9BAFA9),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFFF2F5F4),
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 38,
                                  color: Color(0xFF9BAFA9),
                                ),
                              ),

                        // Featured badge on image
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 13),

                // ---------------------------------------------------
                // TITLE
                // ---------------------------------------------------
                Text(
                  _generatedListingTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 6),

                // ---------------------------------------------------
                // DESCRIPTION
                // ---------------------------------------------------
                Text(
                  _generatedListingDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 11),

                // ---------------------------------------------------
                // PRICE
                // ---------------------------------------------------
                Text(
                  '₹${product.price.round()}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: green,
                  ),
                ),

                const SizedBox(height: 15),

                // ---------------------------------------------------
                // ACTION BUTTONS
                // ---------------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSavingListing
                            ? null
                            : () {
                                setState(() {
                                  _generatedListingTitle = '';
                                  _generatedListingDescription = '';
                                  _listingGenerationStep = 0;
                                  _selectedListingProduct = null;
                                });
                              },
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF53635F),
                          side: const BorderSide(color: Color(0xFFD5DFDC)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingListing
                            ? null
                            : _approveAndSaveListing,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: Text(
                          _isSavingListing ? 'Saving...' : 'Approve & save',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9BCDC2),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SAVED LISTINGS
  // =============================================================

  Widget _buildSavedListings() {
    if (_isLoadingSavedListings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: CircularProgressIndicator(color: Color(0xFF0F8A73)),
        ),
      );
    }

    if (_savedListings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E9E6)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 42,
              color: Color(0xFF8DA29C),
            ),
            SizedBox(height: 14),
            Text(
              'No saved listings yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF263A35),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create a featured listing from the Featured tab.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF71827D)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _savedListings.map((listing) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSavedListingCard(listing),
        );
      }).toList(),
    );
  }

  Widget _buildSavedListingCard(_SavedListing listing) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: listing.enabled
              ? const Color(0xFF9AD9CC)
              : const Color(0xFFE0E9E6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 78,
              height: 78,
              child: listing.productImageUrl.isNotEmpty
                  ? Image.network(
                      listing.productImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: const Color(0xFFF2F5F4),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF9BAFA9),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFFF2F5F4),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF9BAFA9),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D2B28),
                        ),
                      ),
                    ),

                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: Color(0xFF72827D),
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteListing(listing);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 9),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  listing.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF778681),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      '₹${listing.productPrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F8A73),
                      ),
                    ),

                    const Spacer(),

                    Switch.adaptive(
                      value: listing.enabled,
                      activeColor: const Color(0xFF0F8A73),
                      onChanged: (value) {
                        _toggleListing(listing, value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListing(_SavedListing listing, bool enable) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      if (enable) {
        final activeSnapshot = await firestore
            .collection('listing')
            .where('sellerId', isEqualTo: user.uid)
            .where('enabled', isEqualTo: true)
            .get();

        final batch = firestore.batch();

        for (final doc in activeSnapshot.docs) {
          if (doc.id != listing.firestoreId) {
            batch.update(doc.reference, {
              'enabled': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        batch.update(firestore.collection('listing').doc(listing.firestoreId), {
          'enabled': true,
          'status': 'Approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        if (!mounted) return;

        setState(() {
          for (final item in _savedListings) {
            item.enabled = item.firestoreId == listing.firestoreId;
          }
        });
      } else {
        await firestore.collection('listing').doc(listing.firestoreId).update({
          'enabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          listing.enabled = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not update listing: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _deleteListing(_SavedListing listing) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete listing?'),
          content: const Text(
            'This featured listing will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFC0392B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('listing')
          .doc(listing.firestoreId)
          .delete();

      if (!mounted) return;

      setState(() {
        _savedListings.removeWhere(
          (item) => item.firestoreId == listing.firestoreId,
        );
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Listing deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not delete listing: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _loadSavedListings() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _isLoadingSavedListings = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('listing')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      final listings = snapshot.docs
          .map((doc) => _SavedListing.fromFirestore(doc.id, doc.data()))
          .toList();

      listings.sort((a, b) {
        if (a.enabled != b.enabled) {
          return a.enabled ? -1 : 1;
        }

        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        _savedListings = listings;
        _isLoadingSavedListings = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingSavedListings = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not load saved listings: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  //==========================================================
  //APPROVE AND SAVE LISTING
  //==========================================================
  Future<void> _approveAndSaveListing() async {
    final product = _selectedListingProduct;

    if (product == null ||
        _generatedListingTitle.trim().isEmpty ||
        _generatedListingDescription.trim().isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please log in first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (_isSavingListing) {
      return;
    }

    setState(() {
      _isSavingListing = true;
    });

    try {
      final sellerName = product.sellerName.isNotEmpty
          ? product.sellerName
          : (user.displayName ?? '');

      final title = _generatedListingTitle.trim();
      final description = _generatedListingDescription.trim();
      final price = product.price.round().toString();

      final listingRef = await FirebaseFirestore.instance
          .collection('listing')
          .add({
            'productId': product.id,
            'productName': product.name,
            'productImageUrl': product.imageUrl,
            'productPrice': price,

            'title': title,
            'description': description,

            'sellerId': user.uid,
            'sellerName': sellerName,

            'status': 'Approved',
            'enabled': false,
            'generated': true,

            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final savedListing = _SavedListing(
        firestoreId: listingRef.id,
        productId: product.id,
        productName: product.name,
        productImageUrl: product.imageUrl,
        productPrice: price,
        title: title,
        description: description,
        sellerId: user.uid,
        sellerName: sellerName,
        status: 'Approved',
        enabled: false,
      );

      if (!mounted) return;

      setState(() {
        _savedListings.insert(0, savedListing);

        _generatedListingTitle = '';
        _generatedListingDescription = '';

        _selectedListingProduct = null;
        _listingCandidates = [];

        _isSavingListing = false;

        // Move to Saved tab.
        _listingTab = 1;
      });

      await _showListingSavedDialog();

      if (!mounted) return;

      setState(() {
        _listingTab = 1;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingListing = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save listing: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _showListingSavedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const _ListingSavedDialog();
      },
    );
  }
  // =============================================================
  // CAMPAIGN WORKSPACE
  // =============================================================

  Widget _buildCampaignWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------
        // INTRO CARD
        // ---------------------------------------------------------

        // Container(
        //   width: double.infinity,
        //   padding: const EdgeInsets.all(17),
        //   decoration: BoxDecoration(
        //     color: _purpleVerySoft,
        //     borderRadius: BorderRadius.circular(18),
        //     border: Border.all(color: const Color(0xFFE8E4FF)),
        //   ),
        //   child: Row(
        //     crossAxisAlignment: CrossAxisAlignment.start,

        //   ),
        // ),

        // const SizedBox(height: 20),

        // ---------------------------------------------------------
        // TABS
        // ---------------------------------------------------------
        _buildCampaignTabs(),

        const SizedBox(height: 24),

        // ---------------------------------------------------------
        // CONTENT
        // ---------------------------------------------------------
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: _campaignTab == 0
              ? _buildGenerateCampaign()
              : _campaignTab == 1
              ? _buildCreateCampaign()
              : _buildActiveCampaigns(),
        ),
      ],
    );
  }

  // =============================================================
  // CAMPAIGN TABS
  // =============================================================

  Widget _buildCampaignTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDF3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tabButton(0, 'AI Generate', Icons.auto_awesome_rounded),

          _tabButton(1, 'Create', Icons.edit_rounded),

          _tabButton(2, 'Saved', Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final selected = _campaignTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _campaignTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? _purple : const Color(0xFF8B92A3),
              ),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _purple : _textMedium,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // =============================================================
  // campaign PRODUCT SELECTOR
  // =============================================================

  // =============================================================
  // CAMPAIGN PRODUCT SELECTOR
  // =============================================================

  // =============================================================
  // CAMPAIGN PRODUCT SELECTOR
  // =============================================================

  Widget _buildProductSelector({required bool isGenerate}) {
    final List<ProductPerformance> products = widget.analytics.allProducts;

    // Which product belongs to this workflow?
    final ProductPerformance? selectedProduct = isGenerate
        ? _selectedGenerateProduct
        : _selectedCreateProduct;

    // -------------------------------------------------------------
    // NO PRODUCTS
    // -------------------------------------------------------------

    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _purpleSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: _purple,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No products available',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Add a product to your catalogue first.',
                    style: TextStyle(
                      color: _textMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------
    // PRODUCT SELECTOR
    // -------------------------------------------------------------

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a product',
          style: TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          isGenerate
              ? 'Select the product you want AI to create a campaign for.'
              : 'Select the product you want to use for this campaign.',
          style: const TextStyle(
            color: _textMedium,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 11),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selectedProduct != null
                  ? _purple.withOpacity(0.55)
                  : _border,
              width: selectedProduct != null ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ProductPerformance>(
              value: selectedProduct,
              isExpanded: true,

              icon: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _purple,
                  size: 25,
                ),
              ),

              borderRadius: BorderRadius.circular(15),
              dropdownColor: Colors.white,

              // -----------------------------------------------------
              // HINT
              // -----------------------------------------------------
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: _textLight,
                      size: 20,
                    ),
                    SizedBox(width: 11),
                    Text(
                      'Select a product',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // -----------------------------------------------------
              // PRODUCTS
              // -----------------------------------------------------
              items: products.map((product) {
                return DropdownMenuItem<ProductPerformance>(
                  value: product,

                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _purpleSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,

                          child: product.imageUrl.isNotEmpty
                              ? Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.inventory_2_outlined,
                                      color: _purple,
                                      size: 19,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  color: _purple,
                                  size: 19,
                                ),
                        ),

                        const SizedBox(width: 11),

                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              // -----------------------------------------------------
              // SELECTION
              // -----------------------------------------------------
              onChanged: (ProductPerformance? value) {
                setState(() {
                  if (isGenerate) {
                    _selectedGenerateProduct = value;
                  } else {
                    _selectedCreateProduct = value;
                  }
                });
              },
            ),
          ),
        ),

        // -----------------------------------------------------------
        // SELECTED PRODUCT PREVIEW
        // -----------------------------------------------------------
        if (selectedProduct != null) ...[
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _purpleVerySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: _purple,
                  size: 17,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Selected: ${selectedProduct.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _purpleDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  // =============================================================
  // GENERATE CAMPAIGN
  // =============================================================

  Widget _buildGenerateCampaign() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate with AI',
          style: TextStyle(
            color: _textDark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Let AI turn your selected product into a campaign idea.',
          style: TextStyle(
            color: _textMedium,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------
        // PRODUCT SELECTOR
        // ---------------------------------------------------------
        _buildProductSelector(isGenerate: true),

        const SizedBox(height: 18),

        // ---------------------------------------------------------
        // GENERATING STATE / GENERATE BUTTON
        // ---------------------------------------------------------
        if (_isGenerating)
          _buildAiGeneratingLoader()
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedGenerateProduct == null
                  ? null
                  : _generateCampaignDraft,
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: const Text(
                'Generate campaign idea',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                disabledBackgroundColor: const Color(0xFFE4E1F7),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF9A94C7),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------
        // GENERATED CAMPAIGN DRAFT
        // ---------------------------------------------------------
        //
        // IMPORTANT:
        // Only show the AI-generated preview here.
        // Never use _campaigns.last because _campaigns
        // contains saved campaigns from both Create and AI.
        // ---------------------------------------------------------
        if (_generatedCampaignPreview != null)
          _buildGeneratedDraft(_generatedCampaignPreview!),
      ],
    );
  }

  // =============================================================
  // GENERATE CAMPAIGN DRAFT
  // =============================================================

  Future<void> _generateCampaignDraft() async {
    if (_isGenerating) return;

    final ProductPerformance? selectedProduct = _selectedGenerateProduct;

    if (selectedProduct == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select a product first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    // -----------------------------------------------------------
    // START GENERATING
    // -----------------------------------------------------------

    setState(() {
      _isGenerating = true;
      _generatedCampaignPreview = null;
      _generatedCampaignReason = '';

      // Start loading animation from:
      // Thinking...
      _aiLoadingStep = 0;
    });

    // -----------------------------------------------------------
    // START AI LOADING ANIMATION
    // -----------------------------------------------------------

    _aiLoadingTimer?.cancel();

    _aiLoadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_aiLoadingStep < 3) {
          _aiLoadingStep++;
        }
      });
    });

    try {
      // ---------------------------------------------------------
      // PRODUCT DATA
      // ---------------------------------------------------------

      final productData =
          '''
SELECTED PRODUCT
Name: ${selectedProduct.name}
Product ID: ${selectedProduct.id}
Current catalogue price: ₹${selectedProduct.price.toStringAsFixed(0)}

Observed completed orders: ${selectedProduct.orders}
Observed revenue: ₹${selectedProduct.revenue.toStringAsFixed(0)}
Revenue share of seller shop: ${selectedProduct.share.toStringAsFixed(1)}%

Seller: ${selectedProduct.sellerName}
''';

      // ---------------------------------------------------------
      // SHOP CONTEXT
      // ---------------------------------------------------------

      final shopData =
          '''
SELLER SHOP ANALYTICS

Total completed orders: ${widget.analytics.completedOrders}
Total revenue: ₹${widget.analytics.periodRevenue.toStringAsFixed(0)}
Average order value: ₹${widget.analytics.averageOrderValue.toStringAsFixed(0)}
Active products: ${widget.analytics.activeProducts}
Products without completed sales: ${widget.analytics.unusedProducts}
Pending orders: ${widget.analytics.pendingOrders}
''';

      // ---------------------------------------------------------
      // GEMINI MODEL
      // ---------------------------------------------------------

      final model = FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(model: 'gemini-3.6-flash');

      // ---------------------------------------------------------
      // PROMPT
      // ---------------------------------------------------------

      final prompt =
          '''
You are a campaign strategist for a small artisan marketplace seller.

The seller has ALREADY selected the product.

You MUST create a campaign ONLY for the selected product.

Do not select, recommend, replace, or switch to another product.

SELECTED PRODUCT:
$productData

SHOP CONTEXT:
$shopData

Your task is to create ONE practical promotional campaign.

Return EXACTLY this format:

CAMPAIGN NAME:
<short campaign name>

DISCOUNT:
<whole number between 5 and 25>

MESSAGE:
<short buyer-facing promotional message>

REASON:
<short explanation based ONLY on the supplied analytics>

IMPORTANT RULES:

1. The selected product is fixed.
2. Never choose another product.
3. Never invent product features.
4. Never invent customer preferences.
5. Never invent statistics.
6. Never claim that customers prefer something unless the supplied data proves it.
7. The discount MUST be a whole number from 5 to 25.
8. Use the selected product's actual sales signals when choosing the discount.
9. Stronger existing sales signals should generally result in a smaller/moderate discount.
10. Weak or zero sales signals may justify a stronger discount.
11. Do not guarantee increased sales or revenue.
12. The MESSAGE must NOT contain any percentage or discount number.
13. The REASON must NOT contain any percentage or discount number.
14. The MESSAGE must not mention a specific price.
15. The REASON must use only the supplied analytics.
16. Do not mention Gemini or AI.
17. Campaign name: maximum 6 words.
18. Buyer message: maximum 30 words.
19. Reason: maximum 35 words.

VERY IMPORTANT:

The app will display the discount separately.

Therefore, NEVER write things such as:
"Enjoy 20% off"
"Save 15%"
"20% discount"
"10% off"

inside MESSAGE or REASON.

Only put the numerical discount in the DISCOUNT field.

The selected product's name may be used in the message.

Do not fabricate any additional information.
''';

      debugPrint('CAMPAIGN AI: sending request');

      // ---------------------------------------------------------
      // GENERATE CONTENT
      // ---------------------------------------------------------

      final response = await model.generateContent([Content.text(prompt)]);

      final text = response.text?.trim() ?? '';

      debugPrint('CAMPAIGN AI RESPONSE: $text');

      if (!mounted) return;

      // ---------------------------------------------------------
      // STOP LOADING TIMER
      // ---------------------------------------------------------

      _aiLoadingTimer?.cancel();
      _aiLoadingTimer = null;

      // Show "Almost done..." briefly.
      setState(() {
        _aiLoadingStep = 3;
      });

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      // ---------------------------------------------------------
      // PARSE AI RESPONSE
      // ---------------------------------------------------------

      String campaignName = '';
      String message = '';

      // We intentionally do NOT trust AI's reason.
      //
      // The reason will be generated below from the actual
      // analytics values so it can never contain false statistics.
      int discount = 0;

      final lines = text.split('\n');

      String currentSection = '';

      for (final rawLine in lines) {
        final line = rawLine.trim();

        if (line.isEmpty) {
          continue;
        }

        final lower = line.toLowerCase();

        // -------------------------------------------------------
        // CAMPAIGN NAME
        // -------------------------------------------------------

        if (lower.startsWith('campaign name:')) {
          currentSection = 'name';

          campaignName = line.substring('campaign name:'.length).trim();

          continue;
        }

        // -------------------------------------------------------
        // DISCOUNT
        // -------------------------------------------------------

        if (lower.startsWith('discount:')) {
          currentSection = 'discount';

          final valueText = line.substring('discount:'.length).trim();

          discount =
              int.tryParse(
                valueText.replaceAll('%', '').replaceAll('off', '').trim(),
              ) ??
              0;

          continue;
        }

        // -------------------------------------------------------
        // MESSAGE
        // -------------------------------------------------------

        if (lower.startsWith('message:')) {
          currentSection = 'message';

          message = line.substring('message:'.length).trim();

          continue;
        }

        // -------------------------------------------------------
        // REASON
        // -------------------------------------------------------

        if (lower.startsWith('reason:')) {
          // We intentionally ignore AI's reason.
          //
          // We still change the section so any continuation
          // lines belonging to REASON are ignored.
          currentSection = 'reason';

          continue;
        }

        // -------------------------------------------------------
        // CONTINUATION LINES
        // -------------------------------------------------------

        if (currentSection == 'message') {
          message = '$message $line'.trim();
        }

        // Do NOT append anything from the AI reason.
      }

      // ---------------------------------------------------------
      // VALIDATE DISCOUNT
      // ---------------------------------------------------------

      if (discount < 5 || discount > 25) {
        discount = 10;
      }

      // ---------------------------------------------------------
      // FALLBACK CAMPAIGN NAME
      // ---------------------------------------------------------

      if (campaignName.isEmpty) {
        campaignName = '${selectedProduct.name} Special';
      }

      // ---------------------------------------------------------
      // FALLBACK MESSAGE
      // ---------------------------------------------------------

      if (message.isEmpty) {
        message =
            'Discover ${selectedProduct.name} with a special offer for a limited time.';
      }

      // ---------------------------------------------------------
      // CLEAN AI MESSAGE
      //
      // Even though the prompt tells Gemini not to include
      // percentages, remove them here as a final safety check.
      //
      // This guarantees that the message can never say
      // "Enjoy 20%" while the actual offer is 10%.
      // ---------------------------------------------------------

      message = message
          .replaceAll(
            RegExp(r'\b\d{1,3}\s*%\s*(off|discount)?\b', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'\b\d{1,3}\s*percent\b', caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      // If removing the percentage made the message empty,
      // use a safe fallback.
      if (message.isEmpty) {
        message =
            'Discover ${selectedProduct.name} with a special offer for a limited time.';
      }

      // ---------------------------------------------------------
      // CREATE TRUSTWORTHY REASON
      // ---------------------------------------------------------
      //
      // IMPORTANT:
      // Do NOT use the AI-generated reason here.
      //
      // This reason is generated by the app from the real
      // ProductPerformance analytics.
      //
      // Therefore:
      // - orders are real
      // - revenue share is real
      // - discount matches the actual offer
      // - no contradictory 20% / 10% situation
      // ---------------------------------------------------------

      final productOrders = selectedProduct.orders;
      final revenueShare = selectedProduct.share;

      String reason;

      if (productOrders == 0 && revenueShare <= 0) {
        reason =
            'This product has no completed orders yet, so the suggested offer is intended as a stronger test to attract initial buyer interest.';
      } else if (productOrders <= 2 && revenueShare < 5) {
        reason =
            'This product has limited sales activity and a small revenue contribution, so the suggested offer is a moderate way to encourage more buyer interest.';
      } else if (productOrders <= 2 && revenueShare >= 5) {
        reason =
            'This product has some completed sales and contributes meaningfully to shop revenue, so a moderate offer can encourage further purchases without relying on a heavy discount.';
      } else if (revenueShare >= 15) {
        reason =
            'This product already contributes strongly to shop revenue, so a moderate offer can support further purchases without relying on a large discount.';
      } else {
        reason =
            'This product has established sales activity, so the suggested offer provides a balanced promotional incentive based on its observed performance.';
      }

      // ---------------------------------------------------------
      // CREATE AI DRAFT
      // ---------------------------------------------------------

      final campaign = _DraftCampaign(
        name: campaignName,
        message: message,

        // -------------------------------------------------------
        // PRODUCT
        // -------------------------------------------------------
        productId: selectedProduct.id,
        productName: selectedProduct.name,
        productImageUrl: selectedProduct.imageUrl,

        // -------------------------------------------------------
        // OFFER
        //
        // This is the ONLY source of truth for the discount.
        // -------------------------------------------------------
        offer: '$discount% off',

        // -------------------------------------------------------
        // SELLER
        // -------------------------------------------------------
        sellerId: selectedProduct.sellerId,
        sellerName: selectedProduct.sellerName,

        // -------------------------------------------------------
        // STATE
        // -------------------------------------------------------
        status: 'Needs approval',
        enabled: false,

        // -------------------------------------------------------
        // AI GENERATED
        // -------------------------------------------------------
        generated: true,
      );

      // ---------------------------------------------------------
      // SHOW PREVIEW
      // ---------------------------------------------------------

      setState(() {
        _isGenerating = false;
        _generatedCampaignPreview = campaign;
        _generatedCampaignReason = reason;
        _aiLoadingStep = 3;
      });

      debugPrint(
        'CAMPAIGN READY: '
        '${selectedProduct.name} | '
        '$discount% off | '
        'orders=$productOrders | '
        'share=${revenueShare.toStringAsFixed(1)}%',
      );
    } catch (e, stackTrace) {
      debugPrint('CAMPAIGN AI ERROR: $e');
      debugPrint('CAMPAIGN AI STACKTRACE: $stackTrace');

      // ---------------------------------------------------------
      // STOP LOADING TIMER
      // ---------------------------------------------------------

      _aiLoadingTimer?.cancel();
      _aiLoadingTimer = null;

      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _generatedCampaignPreview = null;
        _generatedCampaignReason = '';
        _aiLoadingStep = 0;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not generate campaign: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // =============================================================
  // REJECT AI GENERATED CAMPAIGN
  // =============================================================

  void _rejectGeneratedCampaign() {
    setState(() {
      _generatedCampaignPreview = null;
      _generatedCampaignReason = '';
      _aiLoadingStep = 0;
    });
  }

  Widget _buildAiGeneratingLoader() {
    const steps = [
      (title: 'Thinking...', subtitle: 'Understanding your selected product'),
      (title: 'Reasoning...', subtitle: 'Reviewing your sales signals'),
      (title: 'Generating...', subtitle: 'Creating your campaign'),
      (title: 'Almost done...', subtitle: 'Finalizing your campaign'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: _purpleSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI is working',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ...List.generate(steps.length, (index) {
            final isCompleted = index < _aiLoadingStep;
            final isCurrent = index == _aiLoadingStep;
            final isUpcoming = index > _aiLoadingStep;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: isUpcoming ? 0.35 : 1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isCompleted
                          ? Container(
                              key: const ValueKey('completed'),
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: _purple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            )
                          : isCurrent
                          ? SizedBox(
                              key: const ValueKey('current'),
                              width: 24,
                              height: 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _purple,
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('upcoming'),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD8D4E5),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent || isCompleted
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isUpcoming ? _textMedium : _textDark,
                            ),
                            child: Text(steps[index].title),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            steps[index].subtitle,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _textMedium,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // =============================================================
  // GENERATED CAMPAIGN PREVIEW
  // =============================================================

  Widget _buildGeneratedDraft(_DraftCampaign campaign) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review campaign',
          style: TextStyle(
            color: _textDark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Preview how your AI-generated campaign will appear to buyers before saving it.',
          style: TextStyle(
            color: _textMedium,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),

        _buildCampaignPreview(campaign, isGenerated: true),
      ],
    );
  }
  // =============================================================
  // CREATE CAMPAIGN
  // =============================================================

  Widget _buildCreateCampaign() {
    // If a campaign has been created but not approved,
    // show the buyer-side preview instead of the form.
    if (_campaignPreview != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review campaign',
            style: TextStyle(
              color: _textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Preview how your campaign will appear to buyers before saving it.',
            style: TextStyle(
              color: _textMedium,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          _buildCampaignPreview(_campaignPreview!),
        ],
      );
    }

    // -------------------------------------------------------------
    // NORMAL CREATE FORM
    // -------------------------------------------------------------

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create your own',
          style: TextStyle(
            color: _textDark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Build a campaign yourself while keeping complete control over what buyers see.',
          style: TextStyle(
            color: _textMedium,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------
        // PRODUCT SELECTOR
        // ---------------------------------------------------------
        _buildProductSelector(isGenerate: false),

        const SizedBox(height: 20),

        // ---------------------------------------------------------
        // CAMPAIGN NAME
        // ---------------------------------------------------------
        _field(
          controller: _campaignNameController,
          label: 'Campaign name',
          hint: 'e.g. Festive Artisan Picks',
          icon: Icons.campaign_outlined,
        ),

        const SizedBox(height: 15),

        // ---------------------------------------------------------
        // BUYER MESSAGE
        // ---------------------------------------------------------
        _field(
          controller: _campaignTextController,
          label: 'Buyer-facing message',
          hint: 'Write a short message buyers will see',
          maxLines: 3,
          icon: Icons.chat_bubble_outline_rounded,
        ),

        const SizedBox(height: 15),

        // ---------------------------------------------------------
        // OFFER / DISCOUNT
        // ---------------------------------------------------------
        _field(
          controller: _campaignDiscountController,
          label: 'Offer / discount',
          hint: 'Optional — e.g. 10% off',
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          icon: Icons.sell_outlined,
        ),

        const SizedBox(height: 20),

        // ---------------------------------------------------------
        // CREATE BUTTON
        // ---------------------------------------------------------
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedCreateProduct == null ? null : _createCampaign,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Create campaign',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              disabledBackgroundColor: const Color(0xFFE4E1F7),
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xFF9A94C7),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // CAMPAIGN PRICE HELPERS
  // =============================================================

  double _campaignDiscountPercentage(String offer) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(offer);

    if (match == null) {
      return 0;
    }

    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  double _campaignDiscountedPrice(double originalPrice, String offer) {
    final discount = _campaignDiscountPercentage(offer);

    if (originalPrice <= 0 || discount <= 0) {
      return originalPrice;
    }

    final discounted = originalPrice * (1 - discount / 100);

    // Your app uses rounded rupee pricing.
    return discounted.roundToDouble();
  }
  // =============================================================
  // CAMPAIGN PREVIEW
  // =============================================================

  Widget _buildCampaignPreview(
    _DraftCampaign campaign, {
    bool isGenerated = false,
  }) {
    final ProductPerformance? product = widget.analytics.allProducts
        .cast<ProductPerformance?>()
        .firstWhere(
          (item) => item?.id == campaign.productId,
          orElse: () => null,
        );

    final double originalPrice = product?.price ?? 0;

    final double discountedPrice = _campaignDiscountedPrice(
      originalPrice,
      campaign.offer,
    );

    final bool hasDiscount =
        originalPrice > 0 &&
        discountedPrice > 0 &&
        discountedPrice < originalPrice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE1DEFF)),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------
          // PREVIEW HEADER
          // -------------------------------------------------------

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _purpleSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_outlined, color: _purple, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'BUYER PREVIEW',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              const Text(
                'Review before saving',
                style: TextStyle(
                  color: _textLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // -------------------------------------------------------
          // PREVIEW CARD
          // -------------------------------------------------------
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E4F5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------
                // PRODUCT IMAGE
                // -------------------------------------------------

                if (campaign.productImageUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: Image.network(
                      campaign.productImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: _purpleSoft,
                          child: const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: _purple,
                              size: 42,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 190,
                    color: _purpleSoft,
                    child: const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: _purple,
                        size: 42,
                      ),
                    ),
                  ),

                // -------------------------------------------------
                // BUYER CONTENT
                // -------------------------------------------------
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name
                      Text(
                        campaign.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMedium,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 7),

                      // Campaign name
                      Text(
                        campaign.name,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Buyer message
                      Text(
                        campaign.message,
                        style: const TextStyle(
                          color: _textMedium,
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // ------------------------------------------------
                      // OFFER + PRICE
                      // ------------------------------------------------
                      if (campaign.offer.isNotEmpty) ...[
                        const SizedBox(height: 13),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Discount badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _purpleSoft,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_offer_outlined,
                                    color: _purple,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    campaign.offer,
                                    style: const TextStyle(
                                      color: _purple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (hasDiscount) ...[
                              const SizedBox(width: 12),

                              // Original price
                              Text(
                                '₹${originalPrice.round()}',
                                style: const TextStyle(
                                  color: _textLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),

                              const SizedBox(width: 7),

                              // Discounted price
                              Text(
                                '₹${discountedPrice.round()}',
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 17),

          // -------------------------------------------------------
          // APPROVAL NOTE
          // -------------------------------------------------------
          const SizedBox(height: 16),

          // -------------------------------------------------------
          // ACTION BUTTONS
          // -------------------------------------------------------
          // -------------------------------------------------------
          // ACTION BUTTONS
          // -------------------------------------------------------
          // -------------------------------------------------------
          // ACTION BUTTONS
          // -------------------------------------------------------
          Row(
            children: [
              // -----------------------------------------------------
              // EDIT / REJECT
              // -----------------------------------------------------
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (isGenerated) {
                        // AI campaign → reject generated draft
                        _generatedCampaignPreview = null;
                        _generatedCampaignReason = '';
                        _aiLoadingStep = 0;
                      } else {
                        // Manual campaign → return to editing
                        _campaignPreview = null;
                      }
                    });
                  },
                  icon: Icon(
                    isGenerated ? Icons.close_rounded : Icons.edit_outlined,
                    size: 17,
                  ),
                  label: Text(
                    isGenerated ? 'Reject' : 'Edit',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMedium,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // -----------------------------------------------------
              // APPROVE & SAVE
              // -----------------------------------------------------
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _approveCampaign,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Approve & save',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// =============================================================
  // APPROVE & SAVE CAMPAIGN
  // =============================================================

  Future<void> _approveCampaign() async {
    final preview = _campaignPreview ?? _generatedCampaignPreview;

    if (preview == null) {
      return;
    }

    // -------------------------------------------------------------
    // GET CURRENT SELLER
    // -------------------------------------------------------------

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please log in again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    // -------------------------------------------------------------
    // SAVE CAMPAIGN
    // -------------------------------------------------------------

    try {
      final campaignRef = await FirebaseFirestore.instance
          .collection('campaigns')
          .add({
            // Campaign information
            'name': preview.name,
            'message': preview.message,
            'offer': preview.offer,

            // Product information
            'productId': preview.productId,
            'productName': preview.productName,
            'productImageUrl': preview.productImageUrl,

            // Seller information
            'sellerId': preview.sellerId.isNotEmpty
                ? preview.sellerId
                : user.uid,
            'sellerName': preview.sellerName,

            // Campaign state
            'status': 'Approved',
            'enabled': false,

            // AI / manual
            'generated': preview.generated,

            // Timestamps
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // -------------------------------------------------------------
      // SAVE FIRESTORE DOCUMENT ID
      // -------------------------------------------------------------

      preview.firestoreId = campaignRef.id;

      // -------------------------------------------------------------
      // UPDATE LOCAL STATE
      // -------------------------------------------------------------

      if (!mounted) return;

      setState(() {
        preview.status = 'Approved';
        preview.enabled = false;

        _campaigns.add(preview);

        _campaignPreview = null;
        _generatedCampaignPreview = null;

        // Reset form
        _selectedCreateProduct = null;
        _selectedGenerateProduct = null;

        _campaignNameController.clear();
        _campaignTextController.clear();
        _campaignDiscountController.clear();
      });

      // -------------------------------------------------------------
      // SHOW SUCCESS DIALOG
      // -------------------------------------------------------------

      await _showCampaignApprovedDialog();

      // -------------------------------------------------------------
      // AFTER DIALOG CLOSES → GO TO SAVED TAB
      // -------------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _campaignTab = 2;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not save campaign: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  //APPROVE DIALOG BOX

  Future<void> _showCampaignApprovedDialog() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Campaign approved',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: animation,
              child: const _CampaignApprovedDialogContent(),
            ),
          ),
        );
      },
    );
  }
  //=========================================
  // INPUT FIELD
  // =============================================================

  Widget _field({
    List<TextInputFormatter>? inputFormatters,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,

            hintStyle: const TextStyle(
              color: _textLight,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),

            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 15, right: 10, top: 2),
              child: Icon(icon, color: _purple, size: 21),
            ),

            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),

            filled: true,
            fillColor: Colors.white,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 16,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _border),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _border),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // CREATE CAMPAIGN
  // =============================================================

  // =============================================================
  // CREATE CAMPAIGN
  // =============================================================

  void _createCampaign() {
    // ---------------------------------------------------------
    // GET FORM VALUES
    // ---------------------------------------------------------

    final name = _campaignNameController.text.trim();
    final message = _campaignTextController.text.trim();
    final offerValue = _campaignDiscountController.text.trim();

    final ProductPerformance? selectedProduct = _selectedCreateProduct;

    // ---------------------------------------------------------
    // VALIDATE PRODUCT
    // ---------------------------------------------------------

    if (selectedProduct == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select a product first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    // ---------------------------------------------------------
    // VALIDATE NAME AND MESSAGE
    // ---------------------------------------------------------

    if (name.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please enter the campaign name and message.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    // ---------------------------------------------------------
    // VALIDATE OFFER / DISCOUNT
    // ---------------------------------------------------------

    String offer = '';

    if (offerValue.isNotEmpty) {
      final value = int.tryParse(offerValue);

      if (value == null || value <= 0 || value > 100) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Enter a discount between 1% and 100%.'),
              behavior: SnackBarBehavior.floating,
            ),
          );

        return;
      }

      // Convert "10" into "10% off"
      offer = '$value% off';
    }

    // ---------------------------------------------------------
    // CREATE CAMPAIGN PREVIEW
    // ---------------------------------------------------------

    final preview = _DraftCampaign(
      name: name,
      message: message,

      // Product
      productId: selectedProduct.id,
      productName: selectedProduct.name,
      productImageUrl: selectedProduct.imageUrl,

      // Offer
      offer: offer,

      // Seller
      sellerId: selectedProduct.sellerId,
      sellerName: selectedProduct.sellerName,

      // Campaign state
      status: 'Needs approval',
      enabled: false,

      // This is a manual campaign
      generated: false,
    );

    // ---------------------------------------------------------
    // SHOW PREVIEW
    // ---------------------------------------------------------

    setState(() {
      _campaignPreview = preview;
    });
  }

  // =============================================================
  // ACTIVE CAMPAIGNS
  // =============================================================

  Widget _buildActiveCampaigns() {
    if (_campaigns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _purpleSoft,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: _purple,
                size: 27,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'No campaigns yet',
              style: TextStyle(
                color: _textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Generate a campaign with AI or create one yourself. Your saved campaigns will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMedium, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _purpleVerySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E3FF)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 19, color: _purple),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Only one campaign can be active at a time. Enabling another campaign will disable the current one.',
                  style: TextStyle(
                    color: _textMedium,
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        for (int i = 0; i < _campaigns.length; i++) ...[
          _buildCampaignRow(_campaigns[i]),

          if (i != _campaigns.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // =============================================================
  // CAMPAIGN ROW
  // =============================================================

  Widget _buildCampaignRow(_DraftCampaign campaign) {
    // A campaign can only be enabled/disabled after approval.
    final approved =
        campaign.status == 'Approved' || campaign.status == 'Active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: campaign.enabled ? _purple.withOpacity(0.35) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================
          // CAMPAIGN NAME + STATUS
          // =========================================================

          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: campaign.enabled
                      ? const Color(0xFFE9F8F4)
                      : const Color(0xFFF2F3F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  campaign.enabled ? 'ACTIVE' : campaign.status.toUpperCase(),
                  style: TextStyle(
                    color: campaign.enabled
                        ? const Color(0xFF0F8A73)
                        : _textMedium,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // =========================================================
          // CAMPAIGN MESSAGE
          // =========================================================
          Text(
            campaign.message,
            style: const TextStyle(
              color: _textMedium,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          // =========================================================
          // ACTION BUTTONS
          // =========================================================
          Row(
            children: [
              // =====================================================
              // DELETE
              // =====================================================

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteCampaign(campaign),

                  icon: const Icon(Icons.delete_outline_rounded, size: 17),

                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC23B42),
                    side: const BorderSide(color: Color(0xFFE8BFC2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              // =====================================================
              // ENABLE / DISABLE
              // =====================================================
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: approved ? () => _toggleCampaign(campaign) : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: campaign.enabled
                        ? const Color(0xFFFCEBEC)
                        : _purple,

                    disabledBackgroundColor: const Color(0xFFEDEBF8),

                    foregroundColor: campaign.enabled
                        ? const Color(0xFFC23B42)
                        : Colors.white,

                    disabledForegroundColor: const Color(0xFF9A94C7),

                    elevation: 0,

                    padding: const EdgeInsets.symmetric(vertical: 12),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: Text(
                    campaign.enabled ? 'Disable' : 'Enable',

                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // =============================================================
  // TOGGLE CAMPAIGN
  // =============================================================

  Future<void> _toggleCampaign(_DraftCampaign campaign) async {
    if (campaign.firestoreId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Campaign is not linked to Firestore.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // -------------------------------------------------------------
    // DISABLE CURRENT CAMPAIGN
    // -------------------------------------------------------------

    if (campaign.enabled) {
      try {
        await FirebaseFirestore.instance
            .collection('campaigns')
            .doc(campaign.firestoreId)
            .update({
              'enabled': false,
              'status': 'Approved',
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;

        setState(() {
          campaign.enabled = false;
          campaign.status = 'Approved';
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Campaign disabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not disable campaign: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }

      return;
    }

    // -------------------------------------------------------------
    // ENABLE CAMPAIGN
    // -------------------------------------------------------------

    try {
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('campaigns')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      final batch = firestore.batch();

      // -----------------------------------------------------------
      // Disable all other campaigns belonging to this seller
      // -----------------------------------------------------------

      for (final doc in snapshot.docs) {
        if (doc.id == campaign.firestoreId) {
          continue;
        }

        final data = doc.data();

        if (data['enabled'] == true) {
          batch.update(doc.reference, {
            'enabled': false,
            'status': 'Approved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // -----------------------------------------------------------
      // Enable selected campaign
      // -----------------------------------------------------------

      batch
          .update(firestore.collection('campaigns').doc(campaign.firestoreId), {
            'enabled': true,
            'status': 'Active',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // -----------------------------------------------------------
      // Commit everything together
      // -----------------------------------------------------------

      await batch.commit();

      // -----------------------------------------------------------
      // Update local state
      // -----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        for (final other in _campaigns) {
          if (other.firestoreId != campaign.firestoreId) {
            other.enabled = false;

            if (other.status == 'Active') {
              other.status = 'Approved';
            }
          }
        }

        campaign.enabled = true;
        campaign.status = 'Active';
      });

      // -----------------------------------------------------------
      // SUCCESS MESSAGE
      // -----------------------------------------------------------

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Campaign is now active.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not activate campaign: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  //delete campaign

  Future<void> _deleteCampaign(_DraftCampaign campaign) async {
    if (campaign.firestoreId.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Campaign is not linked to Firestore.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    try {
      // -----------------------------------------------------------
      // DELETE FROM FIRESTORE
      // -----------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(campaign.firestoreId)
          .delete();

      // -----------------------------------------------------------
      // DELETE FROM LOCAL STATE
      // -----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _campaigns.removeWhere(
          (item) => item.firestoreId == campaign.firestoreId,
        );
      });

      // -----------------------------------------------------------
      // SUCCESS MESSAGE
      // -----------------------------------------------------------

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Campaign deleted.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not delete campaign: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // =============================================================
  // COMING NEXT
  // =============================================================

  Widget _buildComingNext({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _purpleSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: _purple, size: 28),
          ),

          const SizedBox(height: 17),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textMedium,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCampaign {
  // Firestore document ID
  String firestoreId;

  final String name;
  final String message;

  // Product attached to this campaign.
  final String productId;
  final String productName;
  final String productImageUrl;

  // Optional offer entered by seller.
  final String offer;

  // Seller information.
  final String sellerId;
  final String sellerName;

  final bool generated;

  String status;
  bool enabled;

  _DraftCampaign({
    this.firestoreId = '',

    required this.name,
    required this.message,

    required this.productId,
    required this.productName,
    required this.productImageUrl,

    required this.offer,

    required this.sellerId,
    required this.sellerName,

    required this.status,
    required this.enabled,

    required this.generated,
  });
}

class _CampaignApprovedDialogContent extends StatefulWidget {
  const _CampaignApprovedDialogContent();

  @override
  State<_CampaignApprovedDialogContent> createState() =>
      _CampaignApprovedDialogContentState();
}

class _CampaignApprovedDialogContentState
    extends State<_CampaignApprovedDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _circleAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _circleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.70, curve: Curves.easeOut),
    );

    _textAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    // Automatically close the dialog after 2.5 seconds.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 330,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 35,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // =====================================================
            // ANIMATED CHECK CIRCLE
            // =====================================================

            ScaleTransition(
              scale: _circleAnimation,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6657E8), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6657E8).withOpacity(0.28),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CheckPainter(progress: _checkAnimation.value),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =====================================================
            // SUCCESS TEXT
            // =====================================================
            FadeTransition(
              opacity: _textAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(_textAnimation),
                child: Column(
                  children: [
                    const Text(
                      'Campaign Approved!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171A2A),
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Your campaign has been saved successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =================================================
                    // SAVED BADGE
                    // =================================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F1FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF6657E8),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Saved',
                            style: TextStyle(
                              color: Color(0xFF6657E8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
}

// ===============================================================
// ANIMATED CHECK MARK
// ===============================================================

class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final start = Offset(size.width * 0.28, size.height * 0.52);

    final middle = Offset(size.width * 0.44, size.height * 0.67);

    final end = Offset(size.width * 0.73, size.height * 0.36);

    final path = Path();

    if (progress <= 0.5) {
      final firstProgress = progress / 0.5;

      final current = Offset(
        start.dx + (middle.dx - start.dx) * firstProgress,
        start.dy + (middle.dy - start.dy) * firstProgress,
      );

      path.moveTo(start.dx, start.dy);

      path.lineTo(current.dx, current.dy);
    } else {
      path.moveTo(start.dx, start.dy);

      path.lineTo(middle.dx, middle.dy);

      final secondProgress = (progress - 0.5) / 0.5;

      final current = Offset(
        middle.dx + (end.dx - middle.dx) * secondProgress,
        middle.dy + (end.dy - middle.dy) * secondProgress,
      );

      path.lineTo(current.dx, current.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ListingSavedDialog extends StatefulWidget {
  const _ListingSavedDialog();

  @override
  State<_ListingSavedDialog> createState() => _ListingSavedDialogState();
}

class _ListingSavedDialogState extends State<_ListingSavedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F8F4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF0F8A73),
                  size: 42,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Listing saved',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17201E),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Your listing has been added to Saved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF687873),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
