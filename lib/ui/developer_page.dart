import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart'; // المكتبة الجديدة للباركود

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  // دالة موحدة لفتح الروابط (اتصال، واتساب، ويب، إيميل)
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'تعذر فتح الرابط $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // بيانات الكود (الرابط الذي سيفتح عند مسح الباركود)
    // قمت ببرمجته ليفتح محادثة واتساب معك مباشرة عند المسح
    const String qrData = "https://wa.me/963936798549";

    return Scaffold(
      appBar: AppBar(
        title: const Text("مطور التطبيق"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              
              // قسم الباركود الجديد
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 150.0,
                        gapless: false,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "امسح الكود للتواصل السريع",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              
              // معلومات المطور
              const Text(
                "المهندس صبحي عبدالعزيز عبدالله",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                "مطور تطبيقات موبايل",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 10),
              
              // أزرار التواصل
              _buildContactBtn(
                icon: Icons.phone_in_talk,
                label: "اتصال هاتفي",
                color: Colors.blue,
                onTap: () => _launchURL("tel:+963936798549"),
              ),

              _buildContactBtn(
                icon: Icons.chat_bubble,
                label: "تواصل عبر واتساب",
                color: Colors.green,
                onTap: () => _launchURL("https://wa.me/963936798549"),
              ),

              _buildContactBtn(
                icon: Icons.email,
                label: "إرسال إيميل",
                color: Colors.redAccent,
                onTap: () => _launchURL("mailto:subhiabdullah1999@gmail.com"),
              ),

              _buildContactBtn(
                icon: Icons.palette,
                label: "متابعة أعمال المطور (Behance)",
                color: const Color(0xFF1769ff),
                onTap: () => _launchURL("https://www.behance.net/subhiabdullah"),
              ),

              const SizedBox(height: 30),
              
              // التذييل الحصري
              Container(
                padding: const EdgeInsets.all(15),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: const Text(
                  "تم تطوير هذا التطبيق بشكل حصري لصالح HASBA TRAKAR",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
    );
  }
}