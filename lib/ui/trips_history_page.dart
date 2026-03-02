import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class TripsHistoryPage extends StatefulWidget {
  const TripsHistoryPage({super.key});

  @override
  State<TripsHistoryPage> createState() => _TripsHistoryPageState();
}

class _TripsHistoryPageState extends State<TripsHistoryPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _trips = [];
  bool _isLoading = true;
  String? _carID;

  @override
  void initState() {
    super.initState();
    _loadCarIdAndTrips();
  }

  // تحميل معرف السيارة وجلب الرحلات من Firebase
Future<void> _loadCarIdAndTrips() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  _carID = prefs.getString('car_id');
  print("🔍 [Page] جاري مراقبة السجل للسيارة: $_carID");

  if (_carID != null && _carID!.isNotEmpty) {
    _dbRef.child('devices/$_carID/trips_history').onValue.listen((event) {
      print("📥 [Page] وصلت بيانات جديدة من Firebase");
      
      final data = event.snapshot.value;
      List<Map<dynamic, dynamic>> tempTrips = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            Map<dynamic, dynamic> tripWithKey = Map.from(value);
            tripWithKey['key'] = key;
            tempTrips.add(tripWithKey);
          }
        });

        // ترتيب: الأحدث فوق
        tempTrips.sort((a, b) {
          String dateA = a['start_time'] ?? "";
          String dateB = b['start_time'] ?? "";
          return dateB.compareTo(dateA);
        });
      }

      print("📊 [Page] عدد الرحلات التي تم تحليلها: ${tempTrips.length}");

      if (mounted) {
        setState(() {
          _trips = tempTrips;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("❌ [Page] خطأ في Firebase: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }
}
  // --- دالة مسح السجل الجديدة ---
  void _clearHistory() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("مسح السجل"),
        content: const Text("هل أنت متأكد من حذف جميع الرحلات المسجلة نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف الآن", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm && _carID != null) {
      await _dbRef.child('devices/$_carID/trips_history').remove();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم مسح السجل بنجاح")));
    }
  }

@override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("سجل الرحلات والتقارير"),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.blue.shade900,
        // --- إضافة زر المسح هنا ---
        actions: [
          if (_trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _clearHistory,
              tooltip: "مسح السجل بالكامل",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _trips.length,
                  itemBuilder: (context, index) => _buildTripCard(_trips[index], isDark),
                ),
    );
  }

  Widget _buildTripCard(Map<dynamic, dynamic> trip, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.route, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("تقرير رحلة", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  _formatDate(trip['start_time']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _buildTimeColumn(trip['start_time'], "بداية", Colors.green),
                const Expanded(child: Divider(indent: 10, endIndent: 10, thickness: 1)),
                _buildTimeColumn(trip['end_time'] ?? "مستمرة...", "نهاية", Colors.redAccent),
              ],
            ),
          ),
          if (trip['lat'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${trip['lat']},${trip['lng']}")),
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text("عرض مسار الرحلة", style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

 Widget _buildTimeColumn(String time, String label, Color color) {
    String formattedTime = time;
    try {
      // تحويل صيغة ISO إلى وقت مقروء
      DateTime dt = DateTime.parse(time).toLocal();
      formattedTime = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      // إذا فشل التحويل (مثلاً نص "مستمرة...") يعرض النص كما هو
      formattedTime = time;
    }

    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(formattedTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDate(dynamic fullDate) {
    if (fullDate == null || fullDate is! String) return "--/--/----";
    try {
      DateTime dt = DateTime.parse(fullDate).toLocal();
      return DateFormat('yyyy/MM/dd').format(dt);
    } catch (e) {
      return fullDate.toString().split('T')[0];
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 10),
          const Text("لا يوجد سجل رحلات لهذه السيارة بعد"),
        ],
      ),
    );
  }
}