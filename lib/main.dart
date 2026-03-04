import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:local_auth/local_auth.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; // إضافة FCM
import 'ui/splash_page.dart';

// --- ميزة الاستقبال في الخلفية العميقة (FCM Background Handler) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 إشعار مستلم في الخلفية: ${message.notification?.title}");
}

// تعريف الـ Notifier بشكل عالمي (لتبديل الثيم)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// تهيئة محرك الإشعارات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  FirebaseDatabase.instance.databaseURL = "https://car-location-67e15-default-rtdb.firebaseio.com/";

  // 1. إعداد استقبال FCM في الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 2. إعداد قنوات الإشعارات للأندرويد (دعم الصوت المخصص والخلفية)
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  // تعريف القناة عالية الأهمية مع ربط ملف الصوت
  // ملاحظة: تأكد من وضع ملف alarm.mp3 في android/app/src/main/res/raw/
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', 
    'إشعارات هصبة الهامة',
    description: 'تستخدم لتنبيهات السرعة والاهتزاز الفورية',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('a'), // اسم ملف الصوت في مجلد raw
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  // إنشاء القناة في النظام برمجياً
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? carID = prefs.getString('car_id');
  bool isDark = prefs.getBool('dark_mode') ?? false;
  
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // استدعاء السماحيات بشكل آمن وشامل عند التشغيل
  await requestPermissions();

  // 3. الاشتراك في Topic السيارة لضمان وصول الإشعارات من جوجل
  if (carID != null && carID.isNotEmpty) {
    await FirebaseMessaging.instance.subscribeToTopic(carID);
    print("✅ تم الاشتراك في رادار جوجل للسيارة: $carID");
    startForegroundMonitoring(carID);
  }

  runApp(AdminApp(savedID: carID));
}

// دالة الرادار الدائم لاستقبال التنبيهات من قاعدة البيانات مباشرة (ميزتك الأصلية)
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

// دالة إظهار الإشعار على الشاشة (محدثة لتعمل مع ملف الصوت المخصص)
Future<void> _triggerUrgentNotification(String type, String msg) async {
  AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'high_importance_channel', // استخدام القناة الموحدة
    'إشعارات هصبة الهامة',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true, 
    ongoing: type == 'alert', 
    styleInformation: BigTextStyleInformation(msg),
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('a'), // تكرار اسم ملف الصوت هنا
    enableVibration: true,
  );

  NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond, 
    type == 'alert' ? "🚨 تنبيه أمني خطير!" : "ℹ️ تحديث من السيارة",
    msg, 
    platformChannelSpecifics
  );
}

// دالة طلب الصلاحيات الشاملة
Future<void> requestPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: true,
    provisional: false,
    sound: true,
  );

  if (!await Permission.ignoreBatteryOptimizations.isGranted) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.phone,
    Permission.sensors,
    Permission.systemAlertWindow, 
    Permission.notification,
  ].request();
  
  print("Permissions status: $statuses");
}

class AdminApp extends StatefulWidget {
  final String? savedID;
  const AdminApp({super.key, this.savedID});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  
  @override
  void initState() {
    super.initState();
    
    // إعداد الاستماع للإشعارات والتطبيق مفتوح (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _triggerUrgentNotification(
          "info", 
          "${message.notification!.title}: ${message.notification!.body}"
        );
      }
    });
  }

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
          home: AuthWrapper(child: SplashScreen(savedID: widget.savedID)),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final Widget child;
  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricSetting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricSetting();
    }
  }

  Future<void> _checkBiometricSetting() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('biometric_enabled') ?? false;

    if (isEnabled) {
      setState(() {
        _isAuthenticated = false;
        _checkingAuth = true;
      });
      _authenticate();
    } else {
      setState(() {
        _isAuthenticated = true;
        _checkingAuth = false;
      });
    }
  }

  Future<void> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى تأكيد هويتك لفتح نظام هصبة للأدمن',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (didAuthenticate) {
        setState(() {
          _isAuthenticated = true;
          _checkingAuth = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAuthenticated = true;
        _checkingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth && !_isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text("التطبيق مقفل للأمان", style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text("اضغط للمحاولة مرة أخرى"),
              )
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}