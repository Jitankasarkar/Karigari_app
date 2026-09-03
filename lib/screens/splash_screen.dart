import 'package:flutter/material.dart';
import 'package:proto_app/screens/splash/components/body.dart';
import 'package:proto_app/size_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return const Scaffold(
      body: Body(),
    );
  }
}