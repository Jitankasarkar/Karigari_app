import 'package:flutter/material.dart';
import 'package:proto_app/screens/splash/components/body.dart';
import 'package:proto_app/size_config.dart';

class SplashScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      body: Body(),
    );
  }
}