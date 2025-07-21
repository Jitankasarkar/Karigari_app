import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:proto_app/size_config.dart';
import 'package:proto_app/admin_login.dart';
import 'package:proto_app/user_type_page.dart';

class Body extends StatefulWidget {
  const Body({super.key});
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return SafeArea(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255), // Orange
              Color.fromARGB(255, 255, 255, 255), // Light Cream/White
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: getProportionateScreenWidth(20)),
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
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),

              // Middle content (Lottie animation)
              SizedBox(
                height: getProportionateScreenHeight(320),
                width: getProportionateScreenWidth(320),
                child: Lottie.asset(
                  "assets/lottie/Colors (fork).json",
                  fit: BoxFit.contain,
                ),
              ),

              // Bottom content
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
                            MaterialPageRoute(builder: (context) => const UserTypeSelectionPage()),
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
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                        );
                      },
                      child: Text(
                        "Admin Login",
                        style: TextStyle(
                          color: Colors.grey[800],
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
