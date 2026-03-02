import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // إضافة المكتبة
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // إضافة مكتبة الإشعارات
import 'ui/splash_page.dart';

// تعريف الـ Notifier بشكل عالمي
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// تهيئة محرك الإشعارات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  FirebaseDatabase.instance.databaseURL = "https://car-location-67e15-default-rtdb.firebaseio.com/";

  // إعداد قنوات الإشعارات للأندرويد
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? carID = prefs.getString('car_id');
  bool isDark = prefs.getBool('dark_mode') ?? false;
  
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // استدعاء السماحيات بشكل آمن وشامل عند التشغيل
  await requestPermissions();

  // إذا كان هناك معرف سيارة، نبدأ مراقبة الرادار فوراً لاستقبال الإشعارات
  if (carID != null) {
    startForegroundMonitoring(carID);
  }

  runApp(AdminApp(savedID: carID));
}

// دالة الرادار الدائم لاستقبال التنبيهات من السيارة
void startForegroundMonitoring(String carID) {
  DatabaseReference ref = FirebaseDatabase.instance.ref('devices/$carID/responses');
  
  ref.onValue.listen((event) async {
    if (event.snapshot.value != null) {
      Map data = event.snapshot.value as Map;
      String type = data['type'] ?? '';
      String msg = data['message'] ?? '';
      String currentId = data['id']?.toString() ?? "";

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastId = prefs.getString('last_handled_id');

      if (currentId != lastId && currentId.isNotEmpty) {
        await prefs.setString('last_handled_id', currentId);
        _triggerUrgentNotification(type, msg);
      }
    }
  });
}

// دالة إظهار الإشعار على الشاشة
Future<void> _triggerUrgentNotification(String type, String msg) async {
  AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'car_radar_channel', 
    'رادار الحماية',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true, 
    ongoing: type == 'alert', 
    styleInformation: BigTextStyleInformation(msg),
    playSound: true,
    enableVibration: true,
  );

  NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await flutterLocalNotificationsPlugin.show(
    0, 
    type == 'alert' ? "🚨 تنبيه أمني خطير!" : "ℹ️ تحديث من السيارة",
    msg, 
    platformChannelSpecifics
  );
}

// دالة طلب الصلاحيات الشاملة (كما كانت في الكود القديم)
Future<void> requestPermissions() async {
  await Permission.notification.request();

  if (!await Permission.ignoreBatteryOptimizations.isGranted) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.phone,
    Permission.sensors,
    Permission.systemAlertWindow, 
  ].request();
  
  print("Permissions status: $statuses");
}

class AdminApp extends StatelessWidget {
  final String? savedID;
  const AdminApp({super.key, this.savedID});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Hasba Admin',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          home: SplashScreen(savedID: savedID),
        );
      },
    );
  }
}