import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proto_app/screens/auth/buyer_login_screen.dart';

class BuyerSignUpScreen extends StatefulWidget {
  @override
  _BuyerSignUpScreenState createState() => _BuyerSignUpScreenState();
}

class _BuyerSignUpScreenState extends State<BuyerSignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;

  // =========================================================
  // SIGN UP FUNCTIONALITY
  // =========================================================

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    final emailRegex =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(email)) {
      _showDialog(
        "Invalid email format. Please enter a valid email.",
      );
      return;
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showDialog(
        "Please fill in all the fields.",
      );
      return;
    }

    if (password.length < 6) {
      _showDialog(
        "Password must be at least 6 characters long.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // =======================================================
      // 1. CREATE USER IN FIREBASE AUTH
      // =======================================================

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // =======================================================
      // 2. SAVE USER DATA TO FIRESTORE
      // =======================================================

      final user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        await userDoc.set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'createdAt': Timestamp.now(),
        });

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        _showDialog(
          "Signup successful. Please login now.",
          isSuccess: true,
        );
      } else {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        _showDialog(
          "Unexpected error: user is null.",
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already in use.';
          break;

        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;

        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;

        default:
          errorMessage = 'Signup failed: ${e.message}';
      }

      _showDialog(errorMessage);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showDialog(
        "Unexpected error occurred during signup.\n"
        "${e.runtimeType}: ${e.toString()}",
      );
    }
  }

  // =========================================================
  // DIALOG
  // =========================================================

  void _showDialog(
    String message, {
    bool isSuccess = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                // =================================================
                // ICON
                // =================================================

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? const Color(0xFFE7F3E8)
                        : const Color(0xFFFFE7D3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess
                        ? Icons.check_rounded
                        : Icons.error_outline_rounded,
                    color: isSuccess
                        ? const Color(0xFF5A9B63)
                        : const Color(0xFFD66A16),
                    size: 27,
                  ),
                ),

                const SizedBox(height: 13),

                // =================================================
                // TITLE
                // =================================================

                Text(
                  isSuccess ? "Success" : "Oops!",
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF292929),
                  ),
                ),

                const SizedBox(height: 7),

                // =================================================
                // MESSAGE
                // =================================================

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

                // =================================================
                // OK BUTTON
                // =================================================

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();

                      if (isSuccess) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BuyerLoginScreen(),
                          ),
                        );
                      }
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
  // INPUT FIELD
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
  // NAVIGATE TO LOGIN
  // =========================================================

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerLoginScreen(),
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
    _nameController.dispose();

    super.dispose();
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
        // Orange status bar
        statusBarColor: Color(0xFFE89528),

        // Dark status bar icons
        statusBarIconBrightness: Brightness.dark,

        // Cream bottom navigation area
        systemNavigationBarColor:
            Color(0xFFFFE8C4),
        systemNavigationBarIconBrightness:
            Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFE8C4),
        resizeToAvoidBottomInset: true,

        // =======================================================
        // NO SAFE AREA HERE
        //
        // This allows the orange header to extend behind
        // the Android status bar.
        // =======================================================

        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // =================================================
              // ORANGE HEADER
              // =================================================

              Container(
                width: double.infinity,

                padding: EdgeInsets.fromLTRB(
                  24,
                  topInset + 20,
                  24,
                  32,
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
                          MainAxisAlignment.start,
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
                      ],
                    ),

                    const SizedBox(height: 30),

                    // =========================================
                    // TITLE
                    // =========================================

                    const Text(
                      "Create Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Sign up to get started",
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
                      // FULL NAME
                      // =========================================

                      _buildInputField(
                        controller: _nameController,
                        hint: "Full Name",
                        icon:
                            Icons.person_outline_rounded,
                        keyboardType:
                            TextInputType.name,
                      ),

                      const SizedBox(height: 13),

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

                      const SizedBox(height: 20),

                      // =========================================
                      // SIGN UP BUTTON
                      // =========================================

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _signup,
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
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // LOGIN LINK
              // =================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  28,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF292929),
                      ),
                    ),

                    const SizedBox(width: 5),

                    GestureDetector(
                      onTap: _openLogin,
                      child: const Text(
                        "Login",
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
}