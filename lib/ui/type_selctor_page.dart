import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// استيراد صفحة الأدمن فقط
import 'admin_page.dart'; 

class AppTypeSelector extends StatefulWidget {
  const AppTypeSelector({super.key});
  @override
  State<AppTypeSelector> createState() => _AppTypeSelectorState();
}

class _AppTypeSelectorState extends State<AppTypeSelector> {
  final TextEditingController _idController = TextEditingController();

  // دالة الحفظ والدخول للأدمن
  void _saveIDAndGoAdmin() async {
    if (_idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال رقم هاتف السيارة المراد تتبعها"))
      );
      return;
    }

    String carId = _idController.text;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // حفظ البيانات لكي يتذكر التطبيق السيارة عند الفتح مرة أخرى
    await prefs.setString('car_id', carId);
    await prefs.setString('user_type', 'admin'); // تثبيت النوع كأدمن

    // التأكد من وجود سجل للسيارة في Firebase (دون تعديل ميزات الحساسية)
    FirebaseDatabase.instance.ref().child('devices/$carId').get().then((snapshot) {
      if (!snapshot.exists) {
        // إذا كانت أول مرة، نضع قيمة افتراضية للحساسية لكي لا يحدث خطأ في واجهة الأدمن
        FirebaseDatabase.instance.ref().child('devices/$carId/sensitivity').set(20);
      }
    });

    if (!mounted) return;
    
    // الانتقال لصفحة الإدارة الرئيسية
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => const AdminPage())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 100, color: Colors.blue.shade900),
              const SizedBox(height: 20),
              const Text(
                "تسجيل دخول الأدمن",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Text(
                "أدخل معرف السيارة للبدء بالتحكم",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 50),
              TextField(
                controller: _idController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: "رقم هاتف شريحة السيارة",
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 30),
              // الزر الوحيد الآن هو زر الأدمن
              _btn(
                "دخول لوحة التحكم", 
                Icons.login_rounded, 
                Colors.blue.shade900, 
                _saveIDAndGoAdmin
              ),
              const SizedBox(height: 40),
              const Text(
                "تنبيه: يجب أن يكون تطبيق 'جهاز السيارة' مفعلاً بنفس هذا الرقم لكي تصلك التنبيهات والموقع.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String t, IconData i, Color c, VoidCallback onPress) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 65), 
        backgroundColor: c,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
      ),
      onPressed: onPress,
      icon: Icon(i, color: Colors.white),
      label: Text(
        t, 
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}