import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:proto_app/screens/seller_analytics_page.dart';

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

  late AnimationController _animationController;

  // =========================================================
  // SCROLL
  // =========================================================

  final ScrollController _scrollController =
      ScrollController();

  // =========================================================
  // GEMINI STATE
  // =========================================================

  String _geminiGrowthInsight = '';

  bool _isGeneratingInsight = false;
  bool _isGeneratingActionPlan = false;

  // True only after the seller explicitly asks Gemini
  // to generate the growth insight.
  bool _hasGeneratedInsight = false;

  // Used to detect when the underlying analytics actually
  // changed. Refreshing the screen does NOT count as a change.
  String _lastAnalyticsSignature = '';

  // =========================================================
  // INIT
  // =========================================================
  //revenue growth opportunitues states
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
  String _growthInsightSignature = '';
      
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    SellerAnalyticsPage.latestAnalytics.addListener(
      _onAnalyticsChanged,
    );

    final analytics =
        SellerAnalyticsPage.latestAnalytics.value;

    if (analytics != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAnalytics(analytics);
      });
    }
  }

  // =========================================================
  // ANALYTICS LISTENER
  // =========================================================

  void _onAnalyticsChanged() {
    final analytics =
        SellerAnalyticsPage.latestAnalytics.value;

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

  void _handleAnalytics(
    SellerAnalytics analytics,
  ) {
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
String _growthInsightDataSignature(
  SellerAnalytics analytics,
) {
  if (analytics.topProducts.isEmpty) {
    return 'empty';
  }

  final top = analytics.topProducts.first;

  return [
    top.name,
    top.orders,
    top.revenue,
    analytics.periodRevenue,
    analytics.completedOrders,
  ].join('|');
}
 Future<void> _generateGrowthInsight(
  SellerAnalytics analytics,
) async {
  // =========================================================
  // NO TOP PRODUCT = NOTHING TO ANALYSE
  // =========================================================

  if (analytics.topProducts.isEmpty) {
    return;
  }

  if (!mounted) {
    return;
  }

  final top = analytics.topProducts.first;

  // =========================================================
  // CHECK WHETHER THE UNDERLYING DATA HAS CHANGED
  // =========================================================

  final currentSignature =
      _growthInsightDataSignature(analytics);

  if (_growthInsightSignature != currentSignature) {
    setState(() {
      _geminiGrowthInsight = '';
      _hasGeneratedInsight = false;
    });

    _growthInsightSignature = currentSignature;
  }

  // =========================================================
  // CALCULATE CURRENT REVENUE SHARE LOCALLY
  //
  // Flutter is the source of truth.
  // Gemini does NOT calculate this.
  // =========================================================

  final double topRevenueShare =
      analytics.periodRevenue <= 0
          ? 0
          : (top.revenue /
                  analytics.periodRevenue) *
              100;

  final String exactRevenueShare =
      topRevenueShare.toStringAsFixed(1);

  // =========================================================
  // DYNAMIC SIGNAL LABEL
  //
  // This is determined locally from verified analytics.
  // It changes automatically for different sellers/products.
  // =========================================================

  final String signalLabel;

  if (topRevenueShare >= 70) {
    signalLabel = 'Dominant sales signal';
  } else if (topRevenueShare >= 40) {
    signalLabel = 'Strong sales signal';
  } else if (topRevenueShare >= 20) {
    signalLabel = 'Promising sales signal';
  } else {
    signalLabel = 'Emerging sales signal';
  }

  // =========================================================
  // VERIFIED VALUES
  // =========================================================

  final String productName =
      top.name;

  final int orderCount =
      top.orders;

  final String productRevenue =
      top.revenue.toStringAsFixed(0);

  final String totalRevenue =
      analytics.periodRevenue
          .toStringAsFixed(0);

  final String averageOrderValue =
      analytics.averageOrderValue
          .toStringAsFixed(0);

  final int completedOrders =
      analytics.completedOrders;

  final int pendingOrders =
      analytics.pendingOrders;

  final int activeProducts =
      analytics.activeProducts;

  final int unusedProducts =
      analytics.unusedProducts;

  // =========================================================
  // DEBUG
  // =========================================================

  debugPrint(
    '========================================',
  );

  debugPrint(
    'GROWTH INSIGHT',
  );

  debugPrint(
    '========================================',
  );

  debugPrint(
    'Product: $productName',
  );

  debugPrint(
    'Orders: $orderCount',
  );

  debugPrint(
    'Product revenue: ₹$productRevenue',
  );

  debugPrint(
    'Total revenue: ₹$totalRevenue',
  );

  debugPrint(
    'Revenue share: $exactRevenueShare%',
  );

  debugPrint(
    'Signal label: $signalLabel',
  );

  debugPrint(
    'Completed orders: $completedOrders',
  );

  debugPrint(
    'Pending orders: $pendingOrders',
  );

  debugPrint(
    'Average order value: ₹$averageOrderValue',
  );

  debugPrint(
    'Active products: $activeProducts',
  );

  debugPrint(
    'Unused products: $unusedProducts',
  );

  debugPrint(
    '========================================',
  );

  // =========================================================
  // START AI REASONING STATE
  // =========================================================

  setState(() {
    _isGeneratingInsight = true;
    _hasGeneratedInsight = false;
    _geminiGrowthInsight = '';
  });

  try {
    // =======================================================
    // FIREBASE AI
    // =======================================================

    final model =
        FirebaseAI.googleAI(
      appCheck:
          FirebaseAppCheck.instance,
    ).generativeModel(
      model:
          'gemini-3.6-flash',
    );

    // =======================================================
    // GEMINI PROMPT
    //
    // Gemini is ONLY responsible for qualitative reasoning.
    //
    // It does NOT generate:
    // - product name
    // - order count
    // - revenue
    // - percentages
    // - AOV
    // =======================================================

    final prompt = '''
You are the reasoning engine of an AI growth agent
for a small artisan marketplace seller.

The application has already analysed the seller's
business data and identified the strongest product.

Your task is ONLY to provide a short,
useful merchant-facing recommendation.

The application itself will display all verified
business metrics separately.

Therefore YOU MUST NOT mention any factual metrics.

DO NOT mention:
- product names
- number of orders
- revenue amounts
- percentages
- revenue share
- AOV
- sales statistics
- customer behaviour
- customer preferences
- demand
- conversion rates
- invented data
- invented results

Do not calculate anything.

The strongest product is the product that currently
has the strongest observed completed-sales signal.

Give ONE concise recommendation explaining what
the merchant should consider doing next.

The recommendation should feel like an intelligent
AI growth agent helping a merchant make a decision,
not like a generic chatbot.

Focus on an actionable direction such as:
- increasing visibility
- giving the product more prominence
- testing promotional placement
- improving inventory readiness
- experimenting with positioning
- making the product easier to discover

Do not guarantee revenue growth.

Maximum 25 words.

Do not use bullet points.

Do not mention Gemini.

Return ONLY the recommendation.
''';

    debugPrint(
      'GROWTH INSIGHT: sending reasoning request...',
    );

    // =======================================================
    // GEMINI REQUEST
    // =======================================================

    final response =
        await model.generateContent([
      Content.text(prompt),
    ]);

    final aiRecommendation =
        response.text?.trim() ?? '';

    debugPrint(
      'GROWTH INSIGHT AI RECOMMENDATION: '
      '$aiRecommendation',
    );

    if (!mounted) {
      return;
    }

    // =======================================================
    // BUILD VERIFIED FACTUAL PART LOCALLY
    //
    // Gemini has no control over this information.
    // =======================================================

    final String factualInsight =
        '$productName is your $signalLabel, '
        'with $orderCount '
        '${orderCount == 1 ? 'completed order' : 'completed orders'} '
        'contributing $exactRevenueShare% of observed revenue.';

    // =======================================================
    // COMBINE VERIFIED DATA + AI REASONING
    // =======================================================

    final String finalInsight;

    if (aiRecommendation.isNotEmpty) {
      finalInsight =
          '$factualInsight $aiRecommendation';
    } else {
      finalInsight =
          '$factualInsight '
          'Consider increasing its visibility and '
          'testing it more prominently in your shop.';
    }

    // =======================================================
    // SHOW RESULT
    // =======================================================

    setState(() {
      _geminiGrowthInsight =
          finalInsight;

      _isGeneratingInsight =
          false;

      _hasGeneratedInsight =
          true;
    });

    debugPrint(
      'GROWTH INSIGHT FINAL: '
      '$_geminiGrowthInsight',
    );
  } catch (e, stackTrace) {
    // =======================================================
    // GEMINI FAILED
    // =======================================================

    debugPrint(
      'GROWTH INSIGHT ERROR: $e',
    );

    debugPrint(
      'GROWTH INSIGHT STACKTRACE: $stackTrace',
    );

    if (!mounted) {
      return;
    }

    // =======================================================
    // LOCAL FALLBACK
    //
    // Everything here comes directly from analytics.
    // =======================================================

    final String fallbackInsight =
        '$productName is your $signalLabel, '
        'with $orderCount '
        '${orderCount == 1 ? 'completed order' : 'completed orders'} '
        'contributing $exactRevenueShare% of observed revenue. '
        'Consider increasing its visibility and testing '
        'it more prominently in your shop.';

    setState(() {
      _geminiGrowthInsight =
          fallbackInsight;

      _isGeneratingInsight =
          false;

      _hasGeneratedInsight =
          true;
    });

    debugPrint(
      'GROWTH INSIGHT FALLBACK: '
      '$fallbackInsight',
    );
  }
}
  // =========================================================
  // GEMINI - ACTION PLAN
  // =========================================================

  Future<void> _generateActionPlan(
    SellerAnalytics analytics,
  ) async {
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
    debugPrint(
      'ACTION PLAN: product = ${top.name}',
    );

    try {
      // -------------------------------------------------------
      // FIREBASE AI WITH APP CHECK
      // -------------------------------------------------------

      final model = FirebaseAI.googleAI(
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(
        model: 'gemini-3.6-flash',
      );

      // -------------------------------------------------------
      // PROMPT
      // -------------------------------------------------------

      final prompt = '''
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

      debugPrint(
        'ACTION PLAN: sending request to Gemini',
      );

      // -------------------------------------------------------
      // GEMINI REQUEST
      // -------------------------------------------------------

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      debugPrint(
        'ACTION PLAN: Gemini responded',
      );

     final text = response.text?.trim() ?? '';

      debugPrint(
        'ACTION PLAN RESPONSE: $text',
      );

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
      debugPrint(
        'ACTION PLAN ERROR: $e',
      );

      debugPrint(
        'ACTION PLAN STACKTRACE: $stackTrace',
      );

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

  String _fallbackGrowthInsight(
    ProductPerformance top,
  ) {
    return '${top.name} is currently your strongest sales signal, '
        'with ${top.orders} completed orders contributing '
        '${top.share.toStringAsFixed(0)}% of observed revenue.';
  }

  // =========================================================
  // ACTION PLAN SHEET
  // =========================================================

  void _showActionPlan({
    required String title,
    required String response,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(
            maxHeight: 620,
          ),
          decoration: const BoxDecoration(
            color: background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                        borderRadius:
                            BorderRadius.circular(10),
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
                          borderRadius:
                              BorderRadius.circular(14),
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI action plan',
                              style: TextStyle(
                                color: primary,
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Generated from your shop signals',
                              style: TextStyle(
                                color: secondary,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w500,
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
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FOCUS PRODUCT',
                          style: TextStyle(
                            color: aiPurple,
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          title,
                          style: const TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
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
                      borderRadius:
                          BorderRadius.circular(22),
                    ),
                    child: Text(
                      response,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.6,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'AI recommendations are based on the sales signals currently available.',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<
        SellerAnalytics?>(
      valueListenable:
          SellerAnalyticsPage.latestAnalytics,
      builder: (
        context,
        analytics,
        child,
      ) {
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
                physics:
                    const AlwaysScrollableScrollPhysics(
                  parent:
                      BouncingScrollPhysics(),
                ),
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  40,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _animated(
                      0.0,
                      0.25,
                      _buildHeader(),
                    ),

                    const SizedBox(height: 20),

                    _animated(
                      0.08,
                      0.42,
                      _buildGrowthSignal(
                        analytics,
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildSectionHeader(
                      'Revenue opportunities',
                      'Where the agent sees room to increase revenue',
                    ),

                    const SizedBox(height: 14),

                    _buildGrowthOpportunities(
                      analytics,
                    ),

                    const SizedBox(height: 28),

                    _buildSectionHeader(
                      'Recommended actions',
                      'Your highest-impact next moves',
                    ),

                    const SizedBox(height: 14),

                    _buildActionItems(
                      analytics,
                    ),

                    const SizedBox(height: 28),

                    _buildSectionHeader(
                      'Campaign ideas',
                      'Directions based on your current catalogue',
                    ),

                    const SizedBox(height: 14),

                    _buildCampaignIdeas(
                      analytics,
                    ),

                    const SizedBox(height: 28),

                    _buildSectionHeader(
                      'Smart bundles',
                      'Combinations worth testing',
                    ),

                    const SizedBox(height: 14),

                    _buildBundleIdeas(
                      analytics,
                    ),

                    const SizedBox(height: 28),

                    _buildGeminiReadyCard(
                      analytics,
                    ),

                    const SizedBox(height: 24),

                    _buildFooter(),
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

  Widget _animated(
    double begin,
    double end,
    Widget child,
  ) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (
        context,
        child,
      ) {
        final value = animation.value;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              12 * (1 - value),
            ),
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: aiPurple,
                      borderRadius:
                          BorderRadius.circular(11),
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
                      fontWeight:
                          FontWeight.w800,
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
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: aiLight,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: aiPurple,
                size: 14,
              ),
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

  Widget _buildGrowthSignal(
    SellerAnalytics analytics,
  ) {
    if (analytics.topProducts.isEmpty) {
      return _buildNoSignalCard();
    }

    final top =
        analytics.topProducts.first;

    final bool showReasoning =
        _isGeneratingInsight;

    final bool showResult =
        _hasGeneratedInsight &&
        !_isGeneratingInsight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF222B42),
            Color(0xFF151C2D),
          ],
        ),
        borderRadius:
            BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
                  color: Colors.white
                      .withOpacity(0.10),
                  borderRadius:
                      BorderRadius.circular(13),
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROWTH SIGNAL DETECTED',
                      style: TextStyle(
                        color: Color(0xFFBDB8FF),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      'I found something worth acting on.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
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
            _buildGenerateInsightButton(
              analytics,
            ),

          // =====================================================
          // REASONING STATE
          // =====================================================

          if (showReasoning)
            _buildReasoningState(),

          // =====================================================
          // GENERATED RESULT
          // =====================================================

          if (showResult) ...[
            // ---------------------------------------------------
            // PRODUCT TITLE
            // ---------------------------------------------------

            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 250),
              child: Text(
                'Double down on\n${top.name}.',
                key: ValueKey(
                  'product-${top.name}',
                ),
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
              duration:
                  const Duration(milliseconds: 250),
              child: Text(
                _geminiGrowthInsight,
                key: const ValueKey(
                  'insight-result',
                ),
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(0.68),
                  fontSize: 13,
                  height: 1.55,
                  fontWeight:
                      FontWeight.w500,
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
                    top.orders == 1
                        ? 'order'
                        : 'orders',
                  ),
                ),

                _heroDivider(),

                Expanded(
                  child: _heroMetric(
                    _formatCurrency(
                      top.revenue,
                    ),
                    'revenue',
                  ),
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

          _buildActOnInsightButton(
            analytics,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // GENERATE INSIGHT BUTTON
  // =========================================================

  Widget _buildGenerateInsightButton(
    SellerAnalytics analytics,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(17),
        onTap: _isGeneratingInsight
            ? null
            : () {
                _generateGrowthInsight(
                  analytics,
                );
              },
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: aiPurple.withOpacity(0.18),
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFF7E73F0)
                  .withOpacity(0.45),
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
                    fontWeight:
                        FontWeight.w800,
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
      duration:
          const Duration(milliseconds: 250),
      child: Row(
        key: const ValueKey(
          'growth-reasoning',
        ),
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
                fontWeight:
                    FontWeight.w500,
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

  Widget _buildActOnInsightButton(
    SellerAnalytics analytics,
  ) {
    final bool enabled =
        _hasGeneratedInsight &&
        !_isGeneratingInsight &&
        !_isGeneratingActionPlan;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(17),
          onTap: enabled
              ? () {
                  _generateActionPlan(
                    analytics,
                  );
                }
              : null,
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color: Colors.white
                    .withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isGeneratingActionPlan
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_upward_rounded,
                  color:
                      const Color(0xFFBDB8FF),
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
                      fontWeight:
                          FontWeight.w800,
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

  Widget _heroMetric(
    String value,
    String label,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
            color: Colors.white
                .withOpacity(0.52),
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
      margin:
          const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      color: Colors.white
          .withOpacity(0.10),
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
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: aiPurple,
            size: 25,
          ),

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
            style: TextStyle(
              color: secondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION HEADER
  // =========================================================

  Widget _buildSectionHeader(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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

// =============================================================
// AI GROWTH OPPORTUNITIES
// =============================================================

// =============================================================
// AI GROWTH — MODERN OPPORTUNITY AGENT
// =============================================================

Widget _buildGrowthOpportunities(
  SellerAnalytics analytics,
) {
  final List<Widget> opportunities = [];

  if (analytics.topProducts.isNotEmpty) {
    opportunities.add(
      _buildOpportunityWithDetails(
        index: 0,
        icon: Icons.trending_up_rounded,
        color: green,
        background: greenLight,
        title: 'Scale what is already working',
        description:
            'The agent found products with the strongest completed-order signals. These are the safest places to test more visibility.',
        evidence:
            '${analytics.topProducts.length.clamp(1, 3)} products are showing traction',
        expanded: _scaleProductsExpanded,
        loading: _isGeneratingScaleAdvice,
        onShow: () => _toggleScaleProducts(analytics),
        panel: _buildScaleProductsPanel(analytics),
      ),
    );
  }

  if (analytics.unusedProducts > 0) {
    opportunities.add(
      _buildOpportunityWithDetails(
        index: 1,
        icon: Icons.visibility_outlined,
        color: orange,
        background: orangeLight,
        title: 'Bring quiet products back',
        description:
            'Some active listings have not produced a completed order yet. The agent can suggest practical experiments to give them another chance.',
        evidence:
            '${analytics.unusedProducts} active listings need attention',
        expanded: _quietProductsExpanded,
        loading: _isGeneratingQuietAdvice,
        onShow: () => _toggleQuietProducts(analytics),
        panel: _buildQuietProductsPanel(analytics),
      ),
    );
  }

  if (analytics.averageOrderValue > 0) {
    opportunities.add(
      _buildOpportunityWithDetails(
        index: 2,
        icon: Icons.add_shopping_cart_rounded,
        color: aiPurple,
        background: aiLight,
        title: 'Find ways to grow each order',
        description:
            'The agent can use your existing sales signals to suggest bundles, add-ons and simple ways to make each completed order more valuable.',
        evidence:
            'Current average order ${_formatCurrency(analytics.averageOrderValue)}',
        expanded: _aovExpanded,
        loading: _isGeneratingAovAdvice,
        onShow: () => _toggleAov(analytics),
        panel: _buildAovPanel(analytics),
      ),
    );
  }

  if (opportunities.isEmpty) {
    return _buildAgentEmptyState(analytics);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      

      const SizedBox(height: 16),

      ...List.generate(
        opportunities.length,
        (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == opportunities.length - 1 ? 0 : 14,
            ),
            child: opportunities[index],
          );
        },
      ),
    ],
  );
}

// =============================================================
// AGENT INTRO
// =============================================================


// =============================================================
// ANIMATED AI ORB
// =============================================================

Widget _buildAnimatedAgentOrb() {
  return TweenAnimationBuilder<double>(
    tween: Tween(
      begin: 0.92,
      end: 1.0,
    ),
    duration: const Duration(milliseconds: 1300),
    curve: Curves.easeInOut,
    builder: (context, value, child) {
      return Transform.scale(
        scale: value,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                aiLight,
                Colors.white,
              ],
            ),
            border: Border.all(
              color: aiPurple.withOpacity(0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: aiPurple.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: aiPurple.withOpacity(0.08),
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: aiPurple,
                size: 17,
              ),
            ],
          ),
        ),
      );
    },
  );
}

// =============================================================
// MAIN OPPORTUNITY CARD
// =============================================================

Widget _buildOpportunityWithDetails({
  required int index,
  required IconData icon,
  required Color color,
  required Color background,
  required String title,
  required String description,
  required String evidence,
  required bool expanded,
  required bool loading,
  required VoidCallback onShow,
  required Widget panel,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween(
      begin: 0,
      end: 1,
    ),
    duration: Duration(
      milliseconds: 420 + (index * 110),
    ),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            0,
            18 * (1 - value),
          ),
          child: child,
        ),
      );
    },
    child: Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(
              expanded ? 23 : 21,
            ),
            border: Border.all(
              color: expanded
                  ? color.withOpacity(0.18)
                  : border,
              width: expanded ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: expanded
                    ? color.withOpacity(0.055)
                    : Colors.black.withOpacity(0.018),
                blurRadius: expanded ? 22 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              splashColor: color.withOpacity(0.04),
              highlightColor: color.withOpacity(0.025),
              onTap: loading ? null : onShow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOpportunityIcon(
                        icon: icon,
                        color: color,
                        background: background,
                        expanded: expanded,
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.15,
                              ),
                            ),

                            const SizedBox(height: 7),

                            Text(
                              description,
                              style: const TextStyle(
                                color: secondary,
                                fontSize: 11.5,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      _buildOpportunityArrow(
                        color: color,
                        expanded: expanded,
                        loading: loading,
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: background.withOpacity(0.48),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: color,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evidence,
                            style: TextStyle(
                              color: color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!expanded && !loading)
                          Text(
                            'Explore',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (loading) ...[
                    const SizedBox(height: 13),
                    _buildThinkingIndicator(color),
                  ],
                ],
              ),
            ),
          ),
        ),

        // -------------------------------------------------------
        // EXPANDABLE AGENT ANALYSIS
        // -------------------------------------------------------

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: expanded
              ? KeyedSubtree(
                  key: const ValueKey('expanded'),
                  child: panel,
                )
              : const SizedBox(
                  key: ValueKey('collapsed'),
                ),
        ),
      ],
    ),
  );
}

// =============================================================
// OPPORTUNITY ICON
// =============================================================

Widget _buildOpportunityIcon({
  required IconData icon,
  required Color color,
  required Color background,
  required bool expanded,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: expanded
          ? color.withOpacity(0.11)
          : background,
      borderRadius: BorderRadius.circular(15),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Icon(
        icon,
        key: ValueKey(expanded),
        color: color,
        size: 21,
      ),
    ),
  );
}

// =============================================================
// ARROW / EXPAND CONTROL
// =============================================================

Widget _buildOpportunityArrow({
  required Color color,
  required bool expanded,
  required bool loading,
}) {
  if (loading) {
    return SizedBox(
      width: 21,
      height: 21,
      child: CircularProgressIndicator(
        strokeWidth: 1.8,
        color: color,
      ),
    );
  }

  return AnimatedRotation(
    duration: const Duration(milliseconds: 240),
    turns: expanded ? 0.5 : 0,
    child: Icon(
      Icons.keyboard_arrow_down_rounded,
      color: color.withOpacity(0.8),
      size: 22,
    ),
  );
}

// =============================================================
// THINKING INDICATOR
// =============================================================

Widget _buildThinkingIndicator(Color color) {
  return Row(
    children: [
      _buildThinkingDot(color, 0),
      const SizedBox(width: 4),
      _buildThinkingDot(color, 1),
      const SizedBox(width: 4),
      _buildThinkingDot(color, 2),
      const SizedBox(width: 8),
      const Text(
        'The agent is looking at your shop...',
        style: TextStyle(
          color: secondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _buildThinkingDot(
  Color color,
  int index,
) {
  return TweenAnimationBuilder<double>(
    tween: Tween(
      begin: 0.55,
      end: 1.0,
    ),
    duration: Duration(
      milliseconds: 550 + (index * 120),
    ),
    curve: Curves.easeInOut,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    },
  );
}

// =============================================================
// EMPTY AGENT STATE
// =============================================================

Widget _buildAgentEmptyState(
  SellerAnalytics analytics,
) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        _buildAnimatedAgentOrb(),

        const SizedBox(height: 13),

        const Text(
          'I am still learning your shop',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'As more completed orders come in, I will have stronger signals to find useful growth opportunities.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondary,
            fontSize: 11,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: aiLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${analytics.orderCount} orders  •  ${analytics.productCount} products',
            style: const TextStyle(
              color: aiPurpleDark,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================
// SCALE BEST PRODUCTS
// =============================================================

Future<void> _toggleScaleProducts(
  SellerAnalytics analytics,
) async {
  if (_scaleProductsExpanded) {
    if (!mounted) return;

    setState(() {
      _scaleProductsExpanded = false;
    });

    return;
  }

  final signature = _analyticsSignature(analytics);

  if (_scaleAdvice.isNotEmpty &&
      _scaleCacheSignature == signature) {
    if (!mounted) return;

    setState(() {
      _scaleProductsExpanded = true;
    });

    return;
  }

  if (_isGeneratingScaleAdvice ||
      analytics.topProducts.isEmpty) {
    return;
  }

  if (!mounted) return;

  setState(() {
    _scaleProductsExpanded = true;
    _isGeneratingScaleAdvice = true;
    _scaleAdvice = '';
  });

  try {
    final products =
        analytics.topProducts.take(3).toList();

    final productData = products
        .asMap()
        .entries
        .map(
          (entry) =>
              '${entry.key + 1}. ${entry.value.name} | orders: ${entry.value.orders} | revenue: ₹${entry.value.revenue.toStringAsFixed(0)}',
        )
        .join('\n');

    final model = _geminiModel();

    final prompt = '''
You are an AI growth agent for a small artisan marketplace seller.

Use ONLY these observed product sales signals:
$productData

Generate practical ways to scale these products.

Return one concise section for each product.

For each product give:
- Product name
- One concrete scaling action
- One short reason based only on its observed sales signal

Do not invent customer preferences, demand, statistics, product features, or results.
Do not guarantee revenue growth.
Keep the whole answer under 180 words.
''';

    final response =
        await model.generateContent([
      Content.text(prompt),
    ]);

    final text =
        response.text?.trim() ?? '';

    if (!mounted) return;

    setState(() {
      _scaleAdvice = text.isNotEmpty
          ? text
          : 'The agent could not return scaling advice right now.';

      _scaleCacheSignature = signature;
      _isGeneratingScaleAdvice = false;
    });
  } catch (e, stackTrace) {
    debugPrint(
      'SCALE PRODUCTS ERROR: $e',
    );
    debugPrint('$stackTrace');

    if (!mounted) return;

    setState(() {
      _scaleAdvice =
          'I could not generate scaling advice right now. Please try again.';

      _scaleCacheSignature = signature;
      _isGeneratingScaleAdvice = false;
    });
  }
}

// =============================================================
// SCALE PRODUCTS PANEL
// =============================================================

Widget _buildScaleProductsPanel(
  SellerAnalytics analytics,
) {
  final products =
      analytics.topProducts.take(3).toList();

  return _buildOpportunityPanel(
    color: green,
    title: 'What the agent found',
    subtitle:
        'Products already showing the strongest sales signals',
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
            index: i,
          ),
          if (i != products.length - 1)
            const SizedBox(height: 9),
        ],
      ],
    ),
  );
}

// =============================================================
// QUIET PRODUCTS
// =============================================================

Future<void> _toggleQuietProducts(
  SellerAnalytics analytics,
) async {
  if (_quietProductsExpanded) {
    if (!mounted) return;

    setState(() {
      _quietProductsExpanded = false;
    });

    return;
  }

  final signature =
      _analyticsSignature(analytics);

  if (_quietAdvice.isNotEmpty &&
      _quietCacheSignature == signature) {
    if (!mounted) return;

    setState(() {
      _quietProductsExpanded = true;
    });

    return;
  }

  if (_isGeneratingQuietAdvice) {
    return;
  }

  final quietProducts =
      analytics.quietProducts;

  if (quietProducts.isEmpty) {
    if (!mounted) return;

    setState(() {
      _quietProductsExpanded = true;
      _quietAdvice =
          'There are no quiet products to analyse in the current data.';
      _quietCacheSignature = signature;
    });

    return;
  }

  if (!mounted) return;

  setState(() {
    _quietProductsExpanded = true;
    _isGeneratingQuietAdvice = true;
    _quietAdvice = '';
  });

  try {
    final productData = quietProducts
        .take(8)
        .map(
          (product) => '- ${product.name}',
        )
        .join('\n');

    final model = _geminiModel();

    final prompt = '''
You are an AI growth agent helping a small artisan seller.

These active products have zero completed sales in the selected period:
$productData

Give practical ways to wake up these quiet products.

Start with a short principle, then give concise advice for the listed products.

Focus on:
- improving visibility
- listing presentation
- positioning
- testing

Rules:
- Use only the supplied product names and the fact that they have zero completed sales.
- Never invent why customers ignored a product.
- Never invent customer preferences, statistics, product features, or demand.
- Do not guarantee sales.
- Keep the whole answer under 180 words.
''';

    final response =
        await model.generateContent([
      Content.text(prompt),
    ]);

    final text =
        response.text?.trim() ?? '';

    if (!mounted) return;

    setState(() {
      _quietAdvice = text.isNotEmpty
          ? text
          : 'The agent could not return advice for these products.';

      _quietCacheSignature = signature;
      _isGeneratingQuietAdvice = false;
    });
  } catch (e, stackTrace) {
    debugPrint(
      'QUIET PRODUCTS ERROR: $e',
    );
    debugPrint('$stackTrace');

    if (!mounted) return;

    setState(() {
      _quietAdvice =
          'I could not generate advice for the quiet products right now. Please try again.';

      _quietCacheSignature = signature;
      _isGeneratingQuietAdvice = false;
    });
  }
}

// =============================================================
// QUIET PRODUCTS PANEL
// =============================================================

Widget _buildQuietProductsPanel(
  SellerAnalytics analytics,
) {
  final products =
      analytics.quietProducts.take(8).toList();

  return _buildOpportunityPanel(
    color: orange,
    title: 'Products worth testing',
    subtitle:
        'Active listings with no completed sales yet',
    loading: _isGeneratingQuietAdvice,
    advice: _quietAdvice,
    child: products.isEmpty
        ? const Text(
            'No quiet products are available in the current analytics data.',
            style: TextStyle(
              color: secondary,
              fontSize: 11,
              height: 1.45,
            ),
          )
        : Column(
            children: [
              for (int i = 0;
                  i < products.length;
                  i++) ...[
                _buildQuietProductCard(
                  products[i],
                  index: i,
                ),
                if (i != products.length - 1)
                  const SizedBox(height: 9),
              ],
            ],
          ),
  );
}

// =============================================================
// QUIET PRODUCT CARD
// =============================================================

Widget _buildQuietProductCard(
  ProductPerformance product, {
  required int index,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween(
      begin: 0,
      end: 1,
    ),
    duration: Duration(
      milliseconds: 260 + (index * 45),
    ),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            10 * (1 - value),
            0,
          ),
          child: child,
        ),
      );
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: orangeLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: orange,
              size: 18,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: orangeLight.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '0 sales',
              style: TextStyle(
                color: orange,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// INCREASE ORDER VALUES
// =============================================================

Future<void> _toggleAov(
  SellerAnalytics analytics,
) async {
  if (_aovExpanded) {
    if (!mounted) return;

    setState(() {
      _aovExpanded = false;
    });

    return;
  }

  final signature =
      _analyticsSignature(analytics);

  if (_aovAdvice.isNotEmpty &&
      _aovCacheSignature == signature) {
    if (!mounted) return;

    setState(() {
      _aovExpanded = true;
    });

    return;
  }

  if (_isGeneratingAovAdvice) {
    return;
  }

  if (!mounted) return;

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

    final prompt = '''
You are an AI growth agent for a small artisan seller.

Current average order value:
₹${analytics.averageOrderValue.toStringAsFixed(0)}

Observed product sales:
$productData

Suggest practical ways to increase average order value using only these observed shop signals.

Use the listed products as real examples from this shop.

DO NOT claim that any two products were bought together because that data is not supplied.

Give 3 concise ideas.

Each idea should include:
1. What to try.
2. Which listed products could be used as an example.
3. Why the idea is reasonable from the available sales data.

Do not invent customer preferences, basket combinations, statistics, or product features.
Do not guarantee revenue growth.
Keep the whole answer under 180 words.
''';

    final response =
        await model.generateContent([
      Content.text(prompt),
    ]);

    final text =
        response.text?.trim() ?? '';

    if (!mounted) return;

    setState(() {
      _aovAdvice = text.isNotEmpty
          ? text
          : 'The agent could not return AOV recommendations.';

      _aovCacheSignature = signature;
      _isGeneratingAovAdvice = false;
    });
  } catch (e, stackTrace) {
    debugPrint(
      'AOV ADVICE ERROR: $e',
    );
    debugPrint('$stackTrace');

    if (!mounted) return;

    setState(() {
      _aovAdvice =
          'I could not generate AOV recommendations right now. Please try again.';

      _aovCacheSignature = signature;
      _isGeneratingAovAdvice = false;
    });
  }
}

// =============================================================
// AOV PANEL
// =============================================================

Widget _buildAovPanel(
  SellerAnalytics analytics,
) {
  final products =
      analytics.topProducts.take(5).toList();

  return _buildOpportunityPanel(
    color: aiPurple,
    title: 'Ideas the agent can test',
    subtitle:
        'Built from products already showing sales activity',
    loading: _isGeneratingAovAdvice,
    advice: _aovAdvice,
    child: products.isEmpty
        ? const SizedBox.shrink()
        : Wrap(
            spacing: 7,
            runSpacing: 7,
            children: products
                .map(
                  (product) => Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: aiLight,
                      borderRadius:
                          BorderRadius.circular(11),
                      border: Border.all(
                        color: aiPurple
                            .withOpacity(0.07),
                      ),
                    ),
                    child: Text(
                      '${product.name} · ${product.orders} ${product.orders == 1 ? 'order' : 'orders'}',
                      style: const TextStyle(
                        color: aiPurpleDark,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

// =============================================================
// COMMON AGENT PANEL
// =============================================================

Widget _buildOpportunityPanel({
  required Color color,
  required String title,
  required String subtitle,
  required bool loading,
  required String advice,
  required Widget child,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    width: double.infinity,
    margin: const EdgeInsets.only(
      top: 8,
    ),
    padding: const EdgeInsets.fromLTRB(
      15,
      16,
      15,
      16,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F9FA),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: color.withOpacity(0.10),
      ),
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // -------------------------------------------------------
        // AGENT HEADER
        // -------------------------------------------------------

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: color,
                size: 15,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: secondary,
                      fontSize: 9.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(18),
                onTap: () {
                  if (!mounted) return;

                  if (title ==
                      'What the agent found') {
                    setState(() {
                      _scaleProductsExpanded =
                          false;
                    });
                  } else if (title ==
                      'Products worth testing') {
                    setState(() {
                      _quietProductsExpanded =
                          false;
                    });
                  } else {
                    setState(() {
                      _aovExpanded = false;
                    });
                  }
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: secondary,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // -------------------------------------------------------
        // DATA
        // -------------------------------------------------------

        child,

        const SizedBox(height: 14),

        // -------------------------------------------------------
        // AI THINKING / RESULT
        // -------------------------------------------------------

        AnimatedSwitcher(
          duration:
              const Duration(milliseconds: 280),
          transitionBuilder:
              (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
            );
          },
          child: loading
              ? Row(
                  key: const ValueKey(
                    'thinking',
                  ),
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'The agent is reasoning from your shop data...',
                        style: TextStyle(
                          color: secondary,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : advice.isNotEmpty
                  ? _buildAgentAdvice(
                      color: color,
                      advice: advice,
                    )
                  : const SizedBox(
                      key: ValueKey(
                        'empty-advice',
                      ),
                    ),
        ),
      ],
    ),
  );
}

// =============================================================
// AI ADVICE RESULT
// =============================================================

Widget _buildAgentAdvice({
  required Color color,
  required String advice,
}) {
  return TweenAnimationBuilder<double>(
    key: ValueKey(advice),
    tween: Tween(
      begin: 0,
      end: 1,
    ),
    duration:
        const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            0,
            10 * (1 - value),
          ),
          child: child,
        ),
      );
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        14,
        13,
        14,
        14,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: color,
              size: 14,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              advice,
              style: const TextStyle(
                color: primary,
                fontSize: 10.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// PRODUCT SIGNAL CARD
// =============================================================

Widget _buildProductSignalCard({
  required ProductPerformance product,
  required int rank,
  required Color color,
  required Color background,
  required int index,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween(
      begin: 0,
      end: 1,
    ),
    duration: Duration(
      milliseconds: 280 + (index * 65),
    ),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            12 * (1 - value),
            0,
          ),
          child: child,
        ),
      );
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          // -----------------------------------------------------
          // RANK
          // -----------------------------------------------------

          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(width: 11),

          // -----------------------------------------------------
          // PRODUCT
          // -----------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: secondary
                          .withOpacity(0.7),
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${product.orders} ${product.orders == 1 ? 'order' : 'orders'}',
                      style:
                          const TextStyle(
                        color: secondary,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // -----------------------------------------------------
          // REVENUE
          // -----------------------------------------------------

          Text(
            _formatCurrency(
              product.revenue,
            ),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// ANALYTICS SIGNATURE
// =============================================================

String _analyticsSignature(
  SellerAnalytics analytics,
) {
  final top = analytics.topProducts
      .take(5)
      .map(
        (p) =>
            '${p.name}|${p.orders}|${p.revenue}|${p.share}',
      )
      .join(';;');

  final quiet = analytics.quietProducts
      .map(
        (p) => p.name,
      )
      .join('|');

  return '$top::$quiet::${analytics.averageOrderValue}';
}

  GenerativeModel _geminiModel() {
    return FirebaseAI.googleAI(
      appCheck: FirebaseAppCheck.instance,
    ).generativeModel(
      model: 'gemini-3.6-flash',
    );
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
  // ACTION ITEMS
  // =========================================================

  Widget _buildActionItems(
    SellerAnalytics analytics,
  ) {
    final List<_ActionData> actions = [];

    if (analytics.topProducts.isNotEmpty) {
      final top =
          analytics.topProducts.first;

      actions.add(
        _ActionData(
          title:
              'Feature ${top.name}',
          description:
              'Give the product with the strongest observed sales signal more visibility.',
          icon:
              Icons.star_outline_rounded,
        ),
      );
    }

    if (analytics.averageOrderValue > 0) {
      actions.add(
        _ActionData(
          title:
              'Test a product bundle',
          description:
              'Combine complementary products to encourage larger orders.',
          icon:
              Icons.add_link_rounded,
        ),
      );
    }

    if (analytics.unusedProducts > 0) {
      actions.add(
        _ActionData(
          title:
              'Improve quiet listings',
          description:
              'Review presentation and positioning for products without completed sales.',
          icon:
              Icons.edit_note_rounded,
        ),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        _ActionData(
          title:
              'Keep collecting sales signals',
          description:
              'More completed orders will unlock stronger recommendations.',
          icon:
              Icons.insights_outlined,
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0;
            i < actions.length;
            i++)
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child: _buildActionItem(
              actions[i],
              i + 1,
            ),
          ),
      ],
    );
  }

  // =========================================================
  // ACTION ITEM
  // =========================================================

  Widget _buildActionItem(
    _ActionData action,
    int number,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: aiLight,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Text(
              number
                  .toString()
                  .padLeft(2, '0'),
              style: const TextStyle(
                color: aiPurpleDark,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Icon(
            action.icon,
            color: secondary,
            size: 18,
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style:
                      const TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  action.description,
                  style:
                      const TextStyle(
                    color: secondary,
                    fontSize: 11,
                    height: 1.4,
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
  // CAMPAIGNS
  // =========================================================

  Widget _buildCampaignIdeas(
    SellerAnalytics analytics,
  ) {
    if (analytics.topProducts.isEmpty) {
      return _buildSimpleCard(
        icon:
            Icons.lightbulb_outline_rounded,
        title:
            'Build your first campaign signal',
        description:
            'More completed orders will allow the AI to suggest campaigns around products with proven demand.',
      );
    }

    final top =
        analytics.topProducts.first;

    return Column(
      children: [
        _buildSimpleCard(
          icon:
              Icons.star_rounded,
          title:
              '${top.name} spotlight',
          description:
              'Build a focused promotion around your strongest existing product signal.',
        ),

        const SizedBox(height: 10),

        if (analytics.unusedProducts > 0)
          _buildSimpleCard(
            icon:
                Icons.explore_outlined,
            title:
                'Rediscover your catalogue',
            description:
                'Bring quiet products together into a themed collection and test renewed visibility.',
          ),
      ],
    );
  }

  // =========================================================
  // BUNDLES
  // =========================================================

  Widget _buildBundleIdeas(
    SellerAnalytics analytics,
  ) {
    if (analytics.topProducts.length < 2) {
      return _buildSimpleCard(
        icon:
            Icons.add_link_rounded,
        title:
            'Bundle opportunity',
        description:
            'Once multiple products show sales signals, the AI can suggest stronger product combinations.',
      );
    }

    final first =
        analytics.topProducts[0];

    final second =
        analytics.topProducts[1];

    return _buildSimpleCard(
      icon:
          Icons.add_link_rounded,
      title:
          '${first.name} + ${second.name}',
      description:
          'These are your two strongest observed product signals. Test whether presenting them together increases basket size.',
    );
  }

  // =========================================================
  // SIMPLE CARD
  // =========================================================

  Widget _buildSimpleCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: aiLight,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: aiPurple,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  description,
                  style:
                      const TextStyle(
                    color: secondary,
                    fontSize: 11,
                    height: 1.45,
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
  // GEMINI FOUNDATION
  // =========================================================

  Widget _buildGeminiReadyCard(
    SellerAnalytics analytics,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: aiLight,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE1DDFB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: aiPurple,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI intelligence layer',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${analytics.periodOrders} orders analysed',
                  style: const TextStyle(
                    color: aiPurpleDark,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.check_circle_rounded,
            color: green,
            size: 20,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FOOTER
  // =========================================================

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'AI recommendations are based on your shop data.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
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
    debugPrint(
      'AI GROWTH: refresh requested',
    );

    // ---------------------------------------------------------
    // Move page back to top
    // ---------------------------------------------------------

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration:
            const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    // ---------------------------------------------------------
    // Restart only the visual entrance animation.
    //
    // This does NOT touch Gemini state.
    // ---------------------------------------------------------

    _animationController.reset();
    _animationController.forward();

    await Future.delayed(
      const Duration(milliseconds: 250),
    );

    debugPrint(
      'AI GROWTH: refresh completed without Gemini request',
    );
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
    SellerAnalyticsPage.latestAnalytics
        .removeListener(
      _onAnalyticsChanged,
    );

    _scrollController.dispose();

    _animationController.dispose();

    super.dispose();
  }
}

// =============================================================
// ACTION MODEL
// =============================================================

class _ActionData {
  final String title;
  final String description;
  final IconData icon;

  const _ActionData({
    required this.title,
    required this.description,
    required this.icon,
  });
}