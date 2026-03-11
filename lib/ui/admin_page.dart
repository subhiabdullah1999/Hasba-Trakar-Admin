import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hasba_trakar_admin/ui/dashboard_page.dart';
import 'package:hasba_trakar_admin/ui/geofence_map.dart';
import 'package:hasba_trakar_admin/ui/notification_page.dart';
import 'package:hasba_trakar_admin/ui/settings_page.dart';
import 'package:hasba_trakar_admin/ui/trips_history_page.dart';
import 'package:hasba_trakar_admin/ui/type_selctor_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert'; 

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  
  final TextEditingController _n1 = TextEditingController();
  final TextEditingController _n2 = TextEditingController();
  final TextEditingController _n3 = TextEditingController();
  
  StreamSubscription? _statusSub;
  String _lastStatus = "انتظار التحديثات...";
  String? _carID;
  bool _isDialogShowing = false;
  
  // تعديل: القيمة الافتراضية false وسنتحكم بها برمجياً عند التحميل
  bool _isExpanded = false; 

  List<Map<String, String>> _allNotifications = [];
  String? _lastMessageId; 
  
  int _unreadCount = 0; 

  final List<int> _sensitivityLevels = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100];

  @override
  void initState() {
    super.initState();
    _setupNotifs();
    _loadSavedNumbers();
  }

  void _saveUnreadCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unread_count_$_carID', _unreadCount);
  }

  void _loadSavedNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _carID = prefs.getString('car_id');
    
    if (_carID != null) {
      await FirebaseMessaging.instance.subscribeToTopic(_carID!);
      _listenToStatus();
      _loadNotificationsFromDisk();
      
      String localN1 = prefs.getString('num1_$_carID') ?? "";
      String localN2 = prefs.getString('num2_$_carID') ?? "";
      String localN3 = prefs.getString('num3_$_carID') ?? "";

      setState(() {
        _unreadCount = prefs.getInt('unread_count_$_carID') ?? 0;
        _n1.text = localN1;
        _n2.text = localN2;
        _n3.text = localN3;

        // التعديل: إذا كانت الأرقام فارغة عند الفتح، نجعل الحقل يتوسع تلقائياً
        if (localN1.isEmpty && localN2.isEmpty && localN3.isEmpty) {
          _isExpanded = true;
        } else {
          _isExpanded = false;
        }
      });

      _dbRef.child('devices/$_carID/numbers').get().then((snapshot) {
        if (snapshot.exists && snapshot.value != null) {
          var data = snapshot.value;
          setState(() {
            if (data is Map) {
              _n1.text = data['num1']?.toString() ?? _n1.text;
              _n2.text = data['num2']?.toString() ?? _n2.text;
              _n3.text = data['num3']?.toString() ?? _n3.text;

              // إعادة فحص الحالة بعد الجلب من Firebase لضمان الدقة
              if (_n1.text.isEmpty && _n2.text.isEmpty && _n3.text.isEmpty) {
                _isExpanded = true;
              }
            }
          });
        }
      });
    }
  }

  void _saveNotificationsToDisk() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encodedData = json.encode(_allNotifications);
    await prefs.setString('saved_notifs_$_carID', encodedData);
  }

  void _loadNotificationsFromDisk() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_notifs_$_carID');
    if (savedData != null) {
      setState(() {
        _allNotifications = List<Map<String, String>>.from(
          json.decode(savedData).map((item) => Map<String, String>.from(item))
        );
        if (_allNotifications.isNotEmpty) _lastMessageId = _allNotifications.first['id'];
      });
    }
  }

  void _setupNotifs() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notif.initialize(const InitializationSettings(android: androidInit));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        Map<String, dynamic> data = {
          'id': message.data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'type': message.data['type'] ?? 'alert',
          'message': message.notification!.body ?? '',
          'lat': message.data['lat'] ?? '',
          'lng': message.data['lng'] ?? '',
        };
        _handleResponse(data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationInboxPage(
        notifications: _allNotifications,
        onDelete: (index) { setState(() { _allNotifications.removeAt(index); _saveNotificationsToDisk(); }); },
        onClearAll: () { setState(() { _allNotifications.clear(); _saveNotificationsToDisk(); }); },
      )));
    });
  }

  void _listenToStatus() {
    _statusSub = _dbRef.child('devices/$_carID/responses').onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      try {
        var data = event.snapshot.value;
        if (data is Map) {
          Map d = Map<dynamic, dynamic>.from(data);
          String currentMsgId = d['id']?.toString() ?? "";
          if (currentMsgId != _lastMessageId) {
            _lastMessageId = currentMsgId; 
            setState(() { _lastStatus = d['message'] ?? ""; });
            _handleResponse(d);
          }
        }
      } catch (e) { debugPrint("❌ Error: $e"); }
    });
  }

 void _handleResponse(Map d) async {
    String type = d['type'] ?? '';
    String msg = d['message'] ?? '';
    
    if (_allNotifications.isNotEmpty && _allNotifications.first['id'] == d['id']?.toString()) return;

    setState(() {
      _allNotifications.insert(0, {
        'id': d['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), 
        'type': type,
        'message': msg,
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        'lat': d['lat']?.toString() ?? "",
        'lng': d['lng']?.toString() ?? "",
        'timestamp': d['timestamp']?.toString() ?? "0",
      });
      _unreadCount++; 
      _saveUnreadCount();
      _saveNotificationsToDisk();
    });

    await _audioPlayer.stop();

    // --- التعديل الأخير: جلب الإعدادات المخصصة للنغمات ---
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String soundAsset = 'sounds/notification.mp3'; 
    if (msg.contains("سرقة") || msg.contains("اهتزاز") || msg.contains("محاولة اختراق")) {
      // يحاول جلب النغمة المخصصة للسرقة، وإذا لم توجد يستخدم sounds/b.mp3 كافتراضي
      soundAsset = prefs.getString('sound_theft') ?? 'sounds/b.mp3';
    } else if (msg.contains("سرعة") || msg.contains("تجاوز")) {
      // يحاول جلب النغمة المخصصة للسرعة، وإذا لم توجد يستخدم sounds/a.mp3 كافتراضي
      soundAsset = prefs.getString('sound_speed') ?? 'sounds/a.mp3';
    } else if (msg.contains("نطاق") || msg.contains("المنطقة الآمنة") || msg.contains("تحركت")) {
      // يحاول جلب النغمة المخصصة للسياج الجغرافي، وإذا لم توجد يستخدم sounds/c.mp3 كافتراضي
      soundAsset = prefs.getString('sound_geofence') ?? 'sounds/c.mp3';
    } else if (type == 'alert') {
      // يحاول جلب النغمة المخصصة للتنبيهات العامة، وإذا لم توجد يستخدم sounds/alarm.mp3 كافتراضي
      soundAsset = prefs.getString('sound_alarm') ?? 'sounds/alarm.mp3';
    }

    try {
      // نستخدم replaceFirst لإزالة 'sounds/' لأن AssetSource تبدأ من مجلد assets/ تلقائياً
      await _audioPlayer.play(AssetSource(soundAsset.replaceFirst('sounds/', '')));
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    }
    
    await _notif.show(
      DateTime.now().millisecond, 
      type == 'alert' ? "🚨 تنبيه أمني" : "ℹ️ تحديث HASBA", 
      msg, 
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel', 
          'إشعارات هصبة الهامة', 
          importance: Importance.max, 
          priority: Priority.high,
          playSound: true,
          )
        )
      );
    
    if (mounted && !_isDialogShowing) _showSimpleDialog(type, msg, d);
  }

  void _showSimpleDialog(String type, String msg, Map d) {
    _isDialogShowing = true;
    showDialog(context: context, barrierDismissible: false, builder: (c) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(type == 'alert' ? "🚨 تحذير أمني" : "ℹ️ إشعار جديد"),
        content: Text(msg),
        actions: [
          if (d['lat'] != null && d['lat'].toString().isNotEmpty) 
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              onPressed: () => launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=${d['lat']},${d['lng']}")), 
              label: const Text("موقع السيارة")
            ),
          TextButton(onPressed: () { _isDialogShowing = false; Navigator.pop(c); }, child: const Text("موافق")),
        ],
      );
    }).then((_) => _isDialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("تحكم السيارة (${_carID ?? ''})"),
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.blue.shade900,
        leading: IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppTypeSelector()))),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
          _notifBadge(), 
        ],
      ),
      body: _carID == null 
          ? const Center(child: CircularProgressIndicator()) 
          : RefreshIndicator(
              onRefresh: () async => _loadSavedNumbers(),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _statusWidget(isDark),
                    _sensitivityLevelsWidget(isDark), 
                    _numbersWidget(isDark),
                    _actionsWidget(isDark), 
                  ],
                ),
              ),
            ),
    );
  }

  Widget _notifBadge() => Stack(
    alignment: Alignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_active, color: Colors.white),
        onPressed: () {
          setState(() {
            _unreadCount = 0;
            _saveUnreadCount();
          });
          Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationInboxPage(
            notifications: _allNotifications,
            onDelete: (index) { setState(() { _allNotifications.removeAt(index); _saveNotificationsToDisk(); }); },
            onClearAll: () { setState(() { _allNotifications.clear(); _saveNotificationsToDisk(); }); },
          )));
        },
      ),
      if (_unreadCount > 0)
        Positioned(
          right: 8, top: 8, 
          child: Container(
            padding: const EdgeInsets.all(2), 
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), 
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16), 
            child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center)
          )
        ),
    ],
  );

  Widget _statusWidget(bool isDark) => InkWell(
    onTap: () {
      setState(() { _unreadCount = 0; _saveUnreadCount(); });
      Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationInboxPage(notifications: _allNotifications, onDelete: (i){}, onClearAll: (){})));
    },
    child: Container(
      padding: const EdgeInsets.all(20), margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [BoxShadow(color: isDark ? Colors.black54 : Colors.black12, blurRadius: 10)],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      child: Row(children: [
        Icon(Icons.history, color: isDark ? Colors.blue.shade300 : Colors.blue), 
        const SizedBox(width: 15), 
        Expanded(child: Text(_lastStatus, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
        Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.grey),
      ]),
    ),
  );

  Widget _sensitivityLevelsWidget(bool isDark) => StreamBuilder(
    stream: _dbRef.child('devices/$_carID/sensitivity').onValue,
    builder: (context, snapshot) {
      int currentVal = 20; 
      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
        currentVal = int.parse(snapshot.data!.snapshot.value.toString());
      }
      return Card(
        margin: const EdgeInsets.all(15),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(children: [
            Text("🎚️ مستوى حساسية الاهتزاز", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 40), 
                onPressed: () {
                  int idx = _sensitivityLevels.indexOf(currentVal);
                  if (idx > 0) _dbRef.child('devices/$_carID/sensitivity').set(_sensitivityLevels[idx - 1]);
                }
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text("$currentVal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade300 : Colors.blue)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 40), 
                onPressed: () {
                  int idx = _sensitivityLevels.indexOf(currentVal);
                  if (idx < _sensitivityLevels.length - 1) _dbRef.child('devices/$_carID/sensitivity').set(_sensitivityLevels[idx + 1]);
                }
              ),
            ])
          ]),
        ),
      );
    }
  );

  Widget _numbersWidget(bool isDark) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 15),
    child: ExpansionTile(
      // استخدام UniqueKey يجبر الـ Widget على التحديث عند تغيير _isExpanded برمجياً
      key: UniqueKey(),
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (val) => setState(() => _isExpanded = val),
      title: Text("📞 أرقام الطوارئ المحفوظة", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      children: [
        Padding(padding: const EdgeInsets.all(15), child: Column(children: [
          TextField(controller: _n1, keyboardType: TextInputType.phone, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: const InputDecoration(labelText: "رقم 1", prefixIcon: Icon(Icons.phone))),
          TextField(controller: _n2, keyboardType: TextInputType.phone, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: const InputDecoration(labelText: "رقم 2", prefixIcon: Icon(Icons.phone))),
          TextField(controller: _n3, keyboardType: TextInputType.phone, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: const InputDecoration(labelText: "رقم 3", prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, minimumSize: const Size(double.infinity, 50)),
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () async {
              if (_carID == null) return;
              await _dbRef.child('devices/$_carID/numbers').set({
                'num1': _n1.text.trim(),
                'num2': _n2.text.trim(),
                'num3': _n3.text.trim(),
              });
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('num1_$_carID', _n1.text.trim());
              await prefs.setString('num2_$_carID', _n2.text.trim());
              await prefs.setString('num3_$_carID', _n3.text.trim());

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ تم حفظ الأرقام بنجاح"))
              );
              setState(() { _isExpanded = false; });
            },
            label: const Text("حفظ وتعديل الأرقام", style: TextStyle(color: Colors.white)),
          ),
        ])),
      ],
    ),
  );

  Widget _actionsWidget(bool isDark) => Column(
    children: [
      StreamBuilder(
        stream: _dbRef.child('devices/$_carID/vibration_enabled').onValue,
        builder: (context, snapshot) {
          bool isVibeOn = snapshot.hasData && snapshot.data!.snapshot.value != null 
              ? snapshot.data!.snapshot.value == true 
              : true; 
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isVibeOn ? Colors.redAccent : Colors.green, 
                minimumSize: const Size(double.infinity, 55),
                elevation: 5
              ),
              icon: Icon(isVibeOn ? Icons.vibration_outlined : Icons.vibration, color: Colors.white),
              label: Text(isVibeOn ? "إيقاف نظام الاهتزاز" : "تشغيل نظام الاهتزاز", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () => _dbRef.child('devices/$_carID/vibration_enabled').set(!isVibeOn),
            ),
          );
        },
      ),
      GridView.count(
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        crossAxisCount: 2, 
        padding: const EdgeInsets.all(15), 
        mainAxisSpacing: 10, 
        crossAxisSpacing: 10, 
        childAspectRatio: 1.2,
        children: [
          _actionBtn(1, "تتبع الموقع", Icons.map, Colors.blue, isDark),
          _actionBtn(2, "حالة البطارية", Icons.battery_charging_full, Colors.green, isDark),
          _customActionBtn("نطاق الأمان", Icons.track_changes, Colors.purple, isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => GeofencePage(carID: _carID!)));
          }),
          _actionBtn(5, "اتصال بالسيارة", Icons.phone_forwarded, Colors.teal, isDark),
          _customActionBtn("مراقبة الرحلة", Icons.speed, Colors.orange, isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardPage(carID: _carID!)));
          }),
          _customActionBtn("سجل الرحلات", Icons.history_edu, Colors.brown, isDark, () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const TripsHistoryPage()));
          }),
          _actionBtn(8, "إعادة تشغيل", Icons.power_settings_new, Colors.redAccent, isDark),
          _actionBtn(9, "نقطة الاتصال", Icons.wifi_tethering, Colors.indigo, isDark),
          _actionBtn(10, "إغلاق الاتصال", Icons.portable_wifi_off, Colors.grey, isDark),
        ],
      ),
    ],
  );

  Widget _actionBtn(int id, String l, IconData i, Color c, bool isDark) => Card(
    elevation: 2,
    child: InkWell(
      onTap: () {
        _dbRef.child('devices/$_carID/commands').set({
          'id': id, 
          'timestamp': ServerValue.timestamp
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("جاري طلب $l من جهاز السيارة..."), duration: const Duration(seconds: 1))
        );
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 40), const SizedBox(height: 8), Text(l, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))]),
    ),
  );

  Widget _customActionBtn(String l, IconData i, Color c, bool isDark, VoidCallback action) => Card(
    elevation: 2,
    child: InkWell(
      onTap: action,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 40), const SizedBox(height: 8), Text(l, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))]),
    ),
  );

  @override
  void dispose() { 
    _statusSub?.cancel(); 
    _n1.dispose(); _n2.dispose(); _n3.dispose();
    _audioPlayer.dispose(); 
    super.dispose(); 
  }
}