import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proto_app/screens/auth/buyer_signup_screen.dart';
import 'package:proto_app/product_page.dart';

class BuyerLoginScreen extends StatefulWidget {
  @override
  _BuyerLoginScreenState createState() => _BuyerLoginScreenState();
}

class _BuyerLoginScreenState extends State<BuyerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;

  // =========================================================
  // LOGIN FUNCTIONALITY
  // =========================================================

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showModernErrorDialog(
        'Please enter both email and password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showModernErrorDialog(
        'Invalid email or password.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // ERROR DIALOG
  // =========================================================

  void _showModernErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFFFFFCF8),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              22,
              22,
              18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE7D3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFD66A16),
                    size: 26,
                  ),
                ),

                const SizedBox(height: 13),

                const Text(
                  'Oops!',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF292929),
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF707070),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF8D5314),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // NAVIGATE TO SIGN UP
  // =========================================================

  void _openSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerSignUpScreen(),
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0ECE7),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF292929),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9A9A9A),
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF8D5314),
            size: 21,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 6,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SOCIAL BUTTON
  // =========================================================

  Widget _buildSocialButton({
    required Widget icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEFEAE5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 17),

          SizedBox(
            width: 27,
            height: 27,
            child: Center(
              child: icon,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF353535),
              ),
            ),
          ),

          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: Color(0xFF555555),
          ),

          const SizedBox(width: 17),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final double topInset =
        MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        // Same orange as the top of the header.
        statusBarColor: Color(0xFFE89428),

        // Keep status-bar icons dark.
        statusBarIconBrightness: Brightness.dark,

        // Bottom navigation area remains cream.
        systemNavigationBarColor: Color(0xFFFFE8C4),
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFE8C4),
        resizeToAvoidBottomInset: true,

        // =====================================================
        // IMPORTANT:
        // No SafeArea around the whole body.
        // This allows the orange header to visually reach
        // the top of the screen.
        // =====================================================

        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // =================================================
              // ORANGE HEADER
              // =================================================

              Container(
                width: double.infinity,

                // The top inset creates space for the status
                // bar while the orange background itself goes
                // behind it.
                padding: EdgeInsets.fromLTRB(
                  24,
                  topInset + 20,
                  24,
                  30,
                ),

                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE89428),
                      Color(0xFFD66A16),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(38),
                    bottomRight: Radius.circular(38),
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =========================================
                    // TOP NAVIGATION
                    // =========================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(
                                0.14,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                        ),

                        GestureDetector(
                          onTap: _openSignUp,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Text(
                              "Register",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // =========================================
                    // TITLE
                    // =========================================

                    const Text(
                      "Sign In",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Welcome back! Please sign in\n"
                      "to continue shopping",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // =================================================
              // WHITE FORM CARD
              // =================================================

              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    24,
                    18,
                    22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // =========================================
                      // EMAIL
                      // =========================================

                      _buildInputField(
                        controller: _emailController,
                        hint: "Email",
                        icon: Icons.email_outlined,
                        keyboardType:
                            TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 13),

                      // =========================================
                      // PASSWORD
                      // =========================================

                      _buildInputField(
                        controller:
                            _passwordController,
                        hint: "Password",
                        icon:
                            Icons.lock_outline_rounded,
                        obscureText:
                            _obscurePassword,
                        suffixIcon: IconButton(
                          splashRadius: 20,
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                            color:
                                const Color(0xFF999999),
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // =========================================
                      // SIGN IN BUTTON
                      // =========================================

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _login,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF8D5314),
                            disabledBackgroundColor:
                                const Color(0xFFC5A57E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Sign In",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // =========================================
                      // OR DIVIDER
                      // =========================================

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                                  const Color(0xFFE8E5E2),
                            ),
                          ),

                          const Padding(
                            padding:
                                EdgeInsets.symmetric(
                              horizontal: 13,
                            ),
                            child: Text(
                              "OR",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Color(0xFF999999),
                              ),
                            ),
                          ),

                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                                  const Color(0xFFE8E5E2),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // =========================================
                      // GOOGLE
                      // =========================================

                      _buildSocialButton(
                        icon: const GoogleLogo(
                          size: 25,
                        ),
                        text:
                            "Continue with Google",
                      ),

                      const SizedBox(height: 12),

                      // =========================================
                      // FACEBOOK
                      // =========================================

                      _buildSocialButton(
                        icon: Container(
                          width: 24,
                          height: 24,
                          decoration:
                              const BoxDecoration(
                            color: Color(0xFF1877F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "f",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        text:
                            "Continue with Facebook",
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // BOTTOM SIGN UP
              // =================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  5,
                  16,
                  25,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF292929),
                      ),
                    ),

                    const SizedBox(width: 5),

                    GestureDetector(
                      onTap: _openSignUp,
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8D5314),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// =============================================================
// GOOGLE LOGO
// =============================================================

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final double w = size.width;
    final double h = size.height;

    final double strokeWidth = w * 0.18;

    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    // =========================================================
    // BLUE
    // =========================================================

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // =========================================================
    // RED
    // =========================================================

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // =========================================================
    // YELLOW
    // =========================================================

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // =========================================================
    // GREEN
    // =========================================================

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // =========================================================
    // GOOGLE G
    // =========================================================

    canvas.drawArc(
      rect,
      -3.05,
      1.35,
      false,
      redPaint,
    );

    canvas.drawArc(
      rect,
      -1.70,
      1.10,
      false,
      yellowPaint,
    );

    canvas.drawArc(
      rect,
      -0.60,
      1.65,
      false,
      greenPaint,
    );

    canvas.drawArc(
      rect,
      1.05,
      2.25,
      false,
      bluePaint,
    );

    // =========================================================
    // BLUE HORIZONTAL BAR
    // =========================================================

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barTop = h * 0.42;
    final double barLeft = w * 0.50;

    canvas.drawRect(
      Rect.fromLTRB(
        barLeft,
        barTop,
        w,
        barTop + strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}