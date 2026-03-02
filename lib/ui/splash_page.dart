import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_page.dart';
import 'type_selctor_page.dart';

class SplashScreen extends StatefulWidget {
  final String? savedID;
  final String? userType;
  const SplashScreen({super.key, this.savedID, this.userType});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  void _startApp() async {
    // طلب الصلاحيات الشاملة مرة أخرى لضمان عمل الرادار
    await [
      Permission.location, 
      Permission.notification,
      Permission.phone,
      Permission.sensors,
      Permission.systemAlertWindow
    ].request();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (widget.savedID != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminPage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppTypeSelector()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // خلفية داكنة لتناسب شعار هصبة
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings, size: 100, color: Colors.blue.shade900),
            const SizedBox(height: 20),
            const Text("HASBA ADMIN", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.blue),
          ],
        ),
      ),
    );
  }
}