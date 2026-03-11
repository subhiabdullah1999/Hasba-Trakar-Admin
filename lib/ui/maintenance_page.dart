import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // ستحتاج لإضافة intl في pubspec.yaml لتنسيق التاريخ

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _oilLimitController = TextEditingController();
  
  String? _carID;
  double _currentOdometer = 0.0;
  double _oilLimit = 5000.0;
  double _distanceSinceLastReset = 0.0;

  // متغيرات الرخصة الجديدة
  DateTime? _licenseExpiryDate;
  int _daysUntilExpiry = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _carID = prefs.getString('car_id');

    if (_carID != null) {
      _dbRef.child('devices/$_carID/maintenance').onValue.listen((event) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          setState(() {
            _currentOdometer = (data['current_odometer'] ?? 0.0).toDouble();
            _oilLimit = (data['oil_limit'] ?? 5000.0).toDouble();
            _distanceSinceLastReset = (data['dist_since_reset'] ?? 0.0).toDouble();
            _oilLimitController.text = _oilLimit.toString();

            // تحميل تاريخ الرخصة
            if (data['license_expiry'] != null) {
              _licenseExpiryDate = DateTime.parse(data['license_expiry']);
              _daysUntilExpiry = _licenseExpiryDate!.difference(DateTime.now()).inDays;
            }
          });
        }
      });
    }
  }

  // دالة اختيار تاريخ الرخصة
  Future<void> _pickLicenseDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null && _carID != null) {
      await _dbRef.child('devices/$_carID/maintenance').update({
        'license_expiry': picked.toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث تاريخ انتهاء الرخصة")));
    }
  }

  void _updateOilLimit() {
    if (_carID != null && _oilLimitController.text.isNotEmpty) {
      _dbRef.child('devices/$_carID/maintenance').update({
        'oil_limit': double.parse(_oilLimitController.text),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث حد تغيير الزيت")));
    }
  }

  void _resetOilCounter() {
    if (_carID != null) {
      _dbRef.child('devices/$_carID/maintenance').update({
        'dist_since_reset': 0.0,
        'last_reset_date': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تصفير عداد الزيت بنجاح")));
    }
  }

  @override
  Widget build(BuildContext context) {
    double oilProgress = (_distanceSinceLastReset / _oilLimit).clamp(0.0, 1.0);
    bool isUrgentLicense = _daysUntilExpiry <= 7 && _daysUntilExpiry >= 0;

    return Scaffold(
      appBar: AppBar(title: const Text("صيانة السيارة ورخصتها")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("قسم الزيت والصيانة الميكانيكية"),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("المسافة المقطوعة بالزيت الحالي", style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 5),
                    Text("${_distanceSinceLastReset.toStringAsFixed(1)} كم", 
                         style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: oilProgress, minHeight: 8, color: oilProgress > 0.9 ? Colors.red : Colors.green),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _oilLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "تغيير الزيت كل (كم)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixText: "كم",
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _updateOilLimit,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                      child: const Text("حفظ حد الزيت"),
                    ),
                    TextButton.icon(
                      onPressed: () => _showResetDialog(),
                      icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
                      label: const Text("تصفير العداد", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            _buildSectionTitle("قسم الأوراق الرسمية والرخصة"),
            
            Card(
              color: isUrgentLicense ? Colors.red.shade50 : null,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: isUrgentLicense ? const BorderSide(color: Colors.red, width: 1) : BorderSide.none
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("تاريخ انتهاء الرخصة:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_licenseExpiryDate == null 
                             ? "لم يحدد بعد" 
                             : DateFormat('yyyy/MM/dd').format(_licenseExpiryDate!)),
                      ],
                    ),
                    const Divider(height: 30),
                    if (_licenseExpiryDate != null) ...[
                       Text(
                        _daysUntilExpiry < 0 ? "الرخصة منتهية!" : "متبقي على التجديد: $_daysUntilExpiry يوم",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: isUrgentLicense || _daysUntilExpiry < 0 ? Colors.red : Colors.green
                        ),
                      ),
                      if (isUrgentLicense)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text("⚠️ سيصلك إشعار تنبيه يومي حتى التجديد", 
                                     style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickLicenseDate,
                      icon: const Icon(Icons.date_range),
                      label: const Text("تحديد/تحديث تاريخ الرخصة"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        minimumSize: const Size(double.infinity, 50)
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تصفير العداد"),
        content: const Text("هل قمت بتغيير الزيت بالفعل؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () { _resetOilCounter(); Navigator.pop(context); }, child: const Text("نعم، صفر العداد")),
        ],
      ),
    );
  }
}