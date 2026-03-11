import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // إضافة المكتبة لقراءة نوع المستخدم
import 'admin_page.dart';
import 'type_selctor_page.dart';

class SplashScreen extends StatefulWidget {
  final String? savedID;
  final String? userType; // ميزة نوع المستخدم موجودة مسبقاً
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
    // 1. طلب الصلاحيات الشاملة (المعدلة تقنياً لمنع الانهيار مع الحفاظ على كل الصلاحيات المطلوبة)
    // قمنا بفصل طلب systemAlertWindow لضمان استقرار التشغيل على أجهزة Redmi
    
    // طلب الصلاحيات الأساسية أولاً
    await [
      Permission.location, 
      Permission.notification,
      Permission.phone,
      Permission.sensors,
    ].request();

    // طلب صلاحية "الظهور فوق التطبيقات" بشكل منفصل (الميزة التي تسبب الانهيار إذا طلبت مع المجموعة)
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }

    // 2. قراءة نوع المستخدم المحفوظ للتأكد من الوجهة الصحيحة
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedUserType = widget.userType ?? prefs.getString('user_type');

    // 3. مؤقت الانتقال (3 ثوانٍ كما في الكود الأصلي)
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      // المنطق المعدل: التحقق من وجود ID ونوع المستخدم للانتقال
      if (widget.savedID != null) {
        // إذا كان المستخدم أدمن (أو لم يحدد نوعه بعد ولكن لديه ID) يذهب لصفحة الأدمن
        if (storedUserType == 'admin' || storedUserType == null) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AdminPage())
          );
        } else {
          // في حال وجود أنواع أخرى مستقبلاً (مثل جهاز السيارة) يتم توجيهه هنا
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AppTypeSelector())
          );
        }
      } else {
        // إذا لم يوجد ID، يذهب لصفحة اختيار النوع
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const AppTypeSelector())
        );
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
            // أيقونة الحماية (ميزة مرئية)
            CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage("assets/images/logohasba.png"),
            ),
            const SizedBox(height: 20),
            const Text(
              "HASBA ADMIN", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
            ),
            const SizedBox(height: 20),
            // مؤشر التحميل (ميزة مرئية)
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            // نص إضافي يعزز الثقة (اختياري)
            const Text(
              "تأمين النظام...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}