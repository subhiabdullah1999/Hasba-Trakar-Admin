
import 'package:flutter/material.dart';
import 'package:hasba_trakar_admin/main.dart';
import 'package:hasba_trakar_admin/ui/about_app.dart';
import 'package:hasba_trakar_admin/ui/developer_page.dart';
import 'package:hasba_trakar_admin/ui/type_selctor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  bool _isBiometricEnabled = false; 
  final LocalAuthentication _auth = LocalAuthentication();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    setState(() {
      _isDarkMode = value;
    });
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  void _toggleBiometric(bool value) async {
    bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    
    if (!canCheck && value == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("عذراً، جهازك لا يدعم تقنية البصمة"))
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
  }

  void _clearNotifications() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد المسح"),
        content: const Text("هل تريد حذف سجل الإشعارات المحفوظ على هذا الجهاز؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              String? carID = prefs.getString('car_id');
              
              await prefs.remove('saved_notifs_$carID');
              await prefs.setInt('unread_count_$carID', 0);
              
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم مسح السجل وتصفير العداد بنجاح"))
                );
              }
            }, 
            child: const Text("حذف الآن", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _resetCarID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('car_id');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppTypeSelector()), 
        (route) => false
      );
    }
  }

  // --- دالة الحذف النهائي المحدثة مع إيقاف النظام ---
 void _deleteCarFromDatabase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? carID = prefs.getString('car_id');

    if (carID == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ حذف نهائي وشامل", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("سيتم إيقاف النظام وتصفير كافة البيانات (الأرقام، المواقع، الإعدادات) ثم حذفها نهائياً من السيرفر."),
            const SizedBox(height: 10),
            Text("معرف السيارة: $carID", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                // 1. إرسال أمر إيقاف فوري (Command 6)
                await _dbRef.child('devices/$carID/commands').set({
                  'id': 6,
                  'timestamp': ServerValue.timestamp,
                });

                // 2. تصفير الحقول الحساسة أولاً لضمان عدم استرجاعها من الذاكرة المؤقتة
                // نقوم بوضع قيم فارغة للأرقام والإعدادات
                await _dbRef.child('devices/$carID').update({
                  'numbers': null,
                  'trip_data': null,
                  'responses': null,
                  'system_active_status': false,
                  'vibration_enabled': false,
                });

                // انتظار بسيط لضمان تنفيذ التحديثات في السيرفر
                await Future.delayed(const Duration(milliseconds: 800));

                // 3. الحذف النهائي والجذري للعقدة بالكامل
                await _dbRef.child('devices/$carID').remove();
                
                // 4. مسح كافة البيانات المحلية من هاتف الأدمن
                await prefs.remove('car_id');
                await prefs.remove('saved_notifs_$carID');
                await prefs.remove('unread_count_$carID');
                await prefs.setBool('was_system_active', false);
                
                // تذكير: يجب مسح أي بيانات أخرى متعلقة بالإشعارات لضمان التصفير الشامل
                final allKeys = prefs.getKeys();
                for (String key in allKeys) {
                  if (key.contains(carID)) {
                    await prefs.remove(key);
                  }
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AppTypeSelector()), 
                    (route) => false
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم تطهير وحذف كافة بيانات السيارة بنجاح"))
                  );
                }
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("خطأ أثناء التطهير: $e"))
                );
              }
            }, 
            child: const Text("تأكيد الحذف النهائي", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Widget _buildOption(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // كرت الوضع الداكن
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                secondary: Icon(
                  _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: _isDarkMode ? Colors.amber : Colors.blue,
                ),
                title: const Text("الوضع الداكن", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isDarkMode ? "تفعيل المظهر الأسود" : "تفعيل المظهر الفاتح"),
                value: _isDarkMode,
                onChanged: _toggleTheme,
              ),
            ),

            // كرت قفل البصمة
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: SwitchListTile(
                secondary: Icon(
                  Icons.fingerprint,
                  color: _isBiometricEnabled ? Colors.teal : Colors.grey,
                ),
                title: const Text("قفل التطبيق", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("طلب البصمة عند فتح التطبيق"),
                value: _isBiometricEnabled,
                onChanged: _toggleBiometric,
              ),
            ),

            const Divider(height: 30, indent: 20, endIndent: 20),

            // إدارة البيانات
            _buildOption(
              Icons.delete_sweep_outlined, 
              "إدارة البيانات", 
              "مسح سجل الإشعارات المحفوظ", 
              Colors.redAccent, 
              _clearNotifications
            ),

            // تغيير السيارة
            _buildOption(
              Icons.directions_car_filled_outlined, 
              "تغيير السيارة", 
              "التبديل إلى معرف سيارة آخر", 
              Colors.green, 
              _resetCarID
            ),

            // حذف السيارة نهائياً (الميزة الجديدة)
            _buildOption(
              Icons.no_crash_outlined, 
              "حذف السيارة نهائياً", 
              "إيقاف النظام وإزالة البيانات من السيرفر", 
              Colors.red, 
              _deleteCarFromDatabase
            ),

            // حول التطبيق
            _buildOption(
              Icons.info_outline_rounded, 
              "حول التطبيق", 
              "تعرف على مهام ونظام HASBA TRACKER", 
              Colors.blueGrey, 
              () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutAppPage()));
              }
            ),

            // مطور التطبيق
            _buildOption(
              Icons.code_rounded, 
              "مطور التطبيق", 
              "تعرف على المطور ووسائل التواصل", 
              Colors.deepPurple, 
              () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DeveloperPage()));
              }
            ),

            const SizedBox(height: 10),

            // الدعم الفني
            _buildOption(
              Icons.support_agent_outlined, 
              "الدعم الفني", 
              "تواصل معنا للمساعدة عبر واتساب", 
              Colors.orange, 
              () => launchUrl(Uri.parse("https://wa.me/+905396617266")) 
            ),

            const SizedBox(height: 10),

            // كرت إصدار التطبيق
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: const ListTile(
                leading: Icon(Icons.verified_outlined, color: Colors.grey),
                title: Text("إصدار التطبيق"),
                trailing: Text("v2.5.0", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 40),
            
            Text(
              "HASBA TRACKER SECURITY SYSTEM",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}