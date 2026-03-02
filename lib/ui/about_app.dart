// --- صفحة "حول التطبيق" الجديدة ---
import 'package:flutter/material.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text("حول التطبيق")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(Icons.security_rounded, size: 80, color: Colors.blue.shade800),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "HASBA TRACKER",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 40),
            const Text(
              "وصف النظام:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            const Text(
              "هو نظام أمني متطور مخصص لتتبع وإدارة حماية السيارات. يتيح لك النظام مراقبة موقع سيارتك في الوقت الفعلي واستلام تنبيهات فورية في حال حدوث أي طارئ.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 25),
            const Text(
              "أهم المميزات:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            _buildFeatureItem(Icons.location_on, "تتبع دقيق عبر خرائط جوجل."),
            _buildFeatureItem(Icons.notifications_active, "إشعارات فورية عند تحرك السيارة أو محاولة السرقة."),
            _buildFeatureItem(Icons.history, "سجل كامل للإشعارات السابقة مع إمكانية البحث."),
            _buildFeatureItem(Icons.fingerprint, "حماية التطبيق بالبصمة لضمان الخصوصية."),
            _buildFeatureItem(Icons.dark_mode, "دعم كامل للوضع الداكن لراحة العين."),
            const SizedBox(height: 30),
            Center(
              child: Text(
                "جميع الحقوق محفوظة © 2026",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}