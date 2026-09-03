import 'dart:async';

import 'package:flutter/material.dart';
import 'package:proto_app/admin_login.dart';
import 'package:proto_app/screens/auth/buyer_login_screen.dart';
import 'package:proto_app/screens/auth/seller_login_screen.dart';

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body>
    with SingleTickerProviderStateMixin {
  // =========================================================
  // MAIN ENTRANCE ANIMATION
  // =========================================================

  late final AnimationController _animationController;

  // =========================================================
  // SUBTITLE TYPING ANIMATION
  // =========================================================

  Timer? _subtitleTypingTimer;
  Timer? _subtitleCursorTimer;

  static const String _subtitleText =
      'A platform which connects people through handmade treasures';

  int _subtitleTypedCharacters = 0;
  bool _subtitleCursorVisible = true;

  // =========================================================
  // ADMIN
  // =========================================================

  bool _showAdmin = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _animationController.forward();

    _startSubtitleTyping();
  }

  // =========================================================
  // SUBTITLE TYPING
  // =========================================================

  void _startSubtitleTyping() {
    _subtitleTypingTimer?.cancel();
    _subtitleCursorTimer?.cancel();

    _subtitleTypedCharacters = 0;
    _subtitleCursorVisible = true;

    if (mounted) {
      setState(() {});
    }

    // -------------------------------------------------------
    // BLINKING CURSOR
    // -------------------------------------------------------

    _subtitleCursorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (!mounted) return;

        setState(() {
          _subtitleCursorVisible =
              !_subtitleCursorVisible;
        });
      },
    );

    // -------------------------------------------------------
    // LETTER-BY-LETTER TYPING
    // -------------------------------------------------------

    _subtitleTypingTimer = Timer.periodic(
      const Duration(milliseconds: 55),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_subtitleTypedCharacters <
            _subtitleText.length) {
          setState(() {
            _subtitleTypedCharacters++;
          });
        } else {
          timer.cancel();

          // Keep the completed sentence visible
          // before restarting the typing animation.
          Future.delayed(
            const Duration(milliseconds: 2200),
            () {
              if (!mounted) return;

              _startSubtitleTyping();
            },
          );
        }
      },
    );
  }

  // =========================================================
  // BUYER LOGIN
  // =========================================================

  void _openBuyerLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerLoginScreen(),
      ),
    );
  }

  // =========================================================
  // SELLER LOGIN
  // =========================================================

  void _openSellerLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SellerLoginPage(),
      ),
    );
  }

  // =========================================================
  // ADMIN
  // =========================================================

  void _toggleAdmin() {
    setState(() {
      _showAdmin = !_showAdmin;
    });
  }

  void _openAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminLoginPage(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF3E7),
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [
          // ===================================================
          // BACKGROUND
          // ===================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/karigari_onboarding_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // ===================================================
          // SUBTLE OVERLAY
          // ===================================================

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                      const Color(0xFFFFF5E8)
                          .withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===================================================
          // MAIN CONTENT
          // ===================================================

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                28,
                16,
                28,
                0,
              ),
              child: Column(
                children: [
                  // =================================================
                  // ADMIN ICON
                  // =================================================

                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _toggleAdmin,
                          child: AnimatedContainer(
                            duration: const Duration(
                              milliseconds: 220,
                            ),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(
                                0.88,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.08),
                                  blurRadius: 10,
                                  offset:
                                      const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons
                                  .admin_panel_settings_outlined,
                              color: Color(0xFF8D5314),
                              size: 21,
                            ),
                          ),
                        ),

                        // =========================================
                        // HIDDEN ADMIN LOGIN
                        // =========================================

                        AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: 220,
                          ),
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
                          child: _showAdmin
                              ? Padding(
                                  key: const ValueKey(
                                    'admin_visible',
                                  ),
                                  padding:
                                      const EdgeInsets.only(
                                    top: 8,
                                  ),
                                  child: GestureDetector(
                                    onTap:
                                        _openAdminLogin,
                                    child: Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 14,
                                        vertical: 9,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors.white
                                            .withOpacity(
                                          0.94,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors
                                                .black
                                                .withOpacity(
                                              0.08,
                                            ),
                                            blurRadius: 10,
                                            offset:
                                                const Offset(
                                              0,
                                              4,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Admin Login',
                                        style: TextStyle(
                                          color:
                                              Color(
                                            0xFF8D5314,
                                          ),
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey(
                                    'admin_hidden',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // CENTER CONTENT
                  // =================================================

                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // ===========================================
                        // KARIGARI BRAND
                        // ===========================================

                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent:
                                _animationController,
                            curve: const Interval(
                              0.15,
                              0.55,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                              begin:
                                  const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent:
                                    _animationController,
                                curve: const Interval(
                                  0.15,
                                  0.55,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KARIGARI',
                                  style: TextStyle(
                                    color:
                                        Color(0xFFD96B2B),
                                    fontSize: 38,
                                    fontWeight:
                                        FontWeight.w800,
                                    letterSpacing: -1.2,
                                  ),
                                ),

                                const SizedBox(
                                  height: 10,
                                ),

                                // =================================
                                // TYPING SUBTITLE
                                // =================================

                                SizedBox(
                                  width: 285,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              _subtitleText
                                                  .substring(
                                            0,
                                            _subtitleTypedCharacters,
                                          ),
                                          style:
                                              const TextStyle(
                                            color:
                                                Color(
                                              0xFF4F4741,
                                            ),
                                            fontSize: 17,
                                            height: 1.45,
                                            fontWeight:
                                                FontWeight
                                                    .w500,
                                          ),
                                        ),

                                        // -----------------------------
                                        // MOVING BLINKING CURSOR
                                        // -----------------------------

                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment
                                                  .middle,
                                          child:
                                              AnimatedOpacity(
                                            duration:
                                                const Duration(
                                              milliseconds:
                                                  120,
                                            ),
                                            opacity:
                                                _subtitleCursorVisible
                                                    ? 1.0
                                                    : 0.0,
                                            child:
                                                Container(
                                              width: 2.2,
                                              height: 21,
                                              margin:
                                                  const EdgeInsets
                                                      .only(
                                                left: 3,
                                              ),
                                              decoration:
                                                  BoxDecoration(
                                                color:
                                                    const Color(
                                                  0xFFD96B2B,
                                                ),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  2,
                                                ),
                                              ),
                                            ),
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
                      ],
                    ),
                  ),

                  // =================================================
                  // BUYER + SELLER BUTTONS
                  // =================================================

                  Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomInset + 12,
                    ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent:
                            _animationController,
                        curve: const Interval(
                          0.45,
                          1.0,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                          begin:
                              const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent:
                                _animationController,
                            curve: const Interval(
                              0.45,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // =======================================
                            // BUYER
                            // =======================================

                            Expanded(
                              child:
                                  _buildRoleButton(
                                label: 'Buyer',
                                icon: Icons
                                    .shopping_bag_outlined,
                                backgroundColor:
                                    const Color(
                                  0xFFE86F2D,
                                ),
                                onTap:
                                    _openBuyerLogin,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            // =======================================
                            // SELLER
                            // =======================================

                            Expanded(
                              child:
                                  _buildRoleButton(
                                label: 'Seller',
                                icon: Icons
                                    .storefront_outlined,
                                backgroundColor:
                                    const Color(
                                  0xFF8D5314,
                                ),
                                onTap:
                                    _openSellerLogin,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SLEEK ROLE BUTTON
  // =========================================================

  Widget _buildRoleButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        splashColor:
            backgroundColor.withOpacity(0.08),
        highlightColor:
            backgroundColor.withOpacity(0.04),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(0.94),
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color:
                  backgroundColor.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    backgroundColor.withOpacity(0.12),
                blurRadius: 14,
                offset:
                    const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Row(
              children: [
                // =============================================
                // ICON
                // =============================================

                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color:
                        backgroundColor
                            .withOpacity(0.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color:
                        backgroundColor,
                    size: 20,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // =============================================
                // LABEL
                // =============================================

                Expanded(
                  child: Text(
                    label,
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF342C27),
                      fontSize: 14.5,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),

                // =============================================
                // ARROW
                // =============================================

                Container(
                  width: 35,
                  height: 35,
                  decoration:
                      BoxDecoration(
                    color:
                        backgroundColor,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _subtitleTypingTimer?.cancel();
    _subtitleCursorTimer?.cancel();

    _animationController.dispose();

    super.dispose();
  }
}