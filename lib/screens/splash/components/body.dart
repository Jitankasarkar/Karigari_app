import 'package:flutter/material.dart';
// import 'package:proto_app/screens/auth/buyer_login_screen.dart';
// import 'package:proto_app/constants.dart';
import 'package:proto_app/size_config.dart';
import 'package:proto_app/admin_login.dart';
import 'package:proto_app/user_type_page.dart'; // <-- Admin login screen

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context); // initialize SizeConfig

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: getProportionateScreenWidth(20)),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top content
              Column(
                children: [
                  SizedBox(height: getProportionateScreenHeight(20)),
                  Text(
                    "KARIGARI",
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(36),
                      color: const Color.fromARGB(255, 220, 124, 89),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: getProportionateScreenHeight(8)),
                  Text(
                    "A platform which connects people",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: getProportionateScreenWidth(14),
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              // Middle content (image)
              Image.asset(
                "assets/images/splash_1.jpg",
                height: getProportionateScreenHeight(320),
                width: getProportionateScreenWidth(320),
              ),

              // Bottom content (button + admin login link)
              Padding(
                padding: EdgeInsets.only(bottom: getProportionateScreenHeight(20)),
                child: Column(
                  children: [
                    SizedBox(
                      width: getProportionateScreenWidth(200),
                      height: getProportionateScreenHeight(45),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 224, 103, 59),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UserTypeSelectionPage()),
                          );
                        },
                        child: Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: getProportionateScreenWidth(16),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Admin Login Link
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AdminLoginPage()),
                        );
                      },
                      child: Text(
                        "Admin Login",
                        style: TextStyle(
                          color: Colors.grey[700],
                          decoration: TextDecoration.underline,
                          fontSize: getProportionateScreenWidth(14),
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
