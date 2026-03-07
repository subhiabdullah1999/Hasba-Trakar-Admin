import 'dart:io';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:local_auth/local_auth.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'ui/splash_page.dart';

// --- ميزة الاستقبال في الخلفية العميقة (FCM Background Handler) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // استخراج البيانات بشكل آمن لضمان عدم حدوث null
  String type = message.data['type'] ?? 'alert';
  String body = message.notification?.body ?? message.data['message'] ?? 'تنبيه أمني جديد من السيارة';
  
  // إظهار إشعار محلي عند استلام FCM والتطبيق مغلق تماماً لضمان الصوت وإيقاظ الشاشة
  await _triggerUrgentNotification(type, body);
  
  print("📩 إشعار مستلم في الخلفية العميقة: ${message.notification?.title}");
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

  // 2. إعداد قنوات الإشعارات للأندرويد مع الصوت المخصص a.mp3
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  // إنشاء القناة مع ملف الصوت المخصص وتعديل الأهمية للقصوى
  const RawResourceAndroidNotificationSound customSound = RawResourceAndroidNotificationSound('a');
  
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', 
    'إشعارات هصبة الهامة',
    description: 'تستخدم لتنبيهات السرعة والاهتزاز الفورية',
    importance: Importance.max, // قصوى لضمان ظهور البوب أب
    playSound: true,
    sound: customSound, // ربط ملف الصوت a.mp3
    enableVibration: true,
    enableLights: true,
    showBadge: true,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      // هنا يمكنك برمجة الأكشن عند الضغط على الإشعار
    },
  );

  // إنشاء القناة فعلياً في نظام أندرويد
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // إعدادات الـ FCM الإضافية لنظام أندرويد لضمان الظهور والتنبيه الصوتي
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

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

// دالة الرادار الدائم لاستقبال التنبيهات من قاعدة البيانات مباشرة
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

// دالة إظهار الإشعار على الشاشة (محدثة لدعم الصوت وإيقاظ الشاشة بقوة)
Future<void> _triggerUrgentNotification(String type, String msg) async {
  const RawResourceAndroidNotificationSound customSound = RawResourceAndroidNotificationSound('a');

  AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'high_importance_channel', 
    'إشعارات هصبة الهامة',
    channelDescription: 'تنبيهات الحماية الفورية',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true, // ضروري جداً لإيقاظ الشاشة وفتح واجهة تنبيه
    category: AndroidNotificationCategory.alarm, // تصنيف كمنبه ليتجاوز وضع الصامت أحياناً
    ongoing: type == 'alert', 
    styleInformation: BigTextStyleInformation(msg),
    playSound: true,
    sound: customSound, // استخدام الصوت a.mp3
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500]), // نمط اهتزاز مخصص
    visibility: NotificationVisibility.public, // يظهر المحتوى على شاشة القفل
  );

  NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond, 
    type == 'alert' ? "🚨 تنبيه أمني خطير!" : "ℹ️ تحديث من السيارة",
    msg, 
    platformChannelSpecifics
  );
}

Future<void> _openChannelSettings() async {
  if (Platform.isAndroid) {
    final intent = AndroidIntent(
      action: 'android.settings.CHANNEL_NOTIFICATION_SETTINGS',
      arguments: {
        'android.provider.extra.APP_PACKAGE': 'com.example.hasba_trakar_admin', // تأكد من مطابقة اسم حزمتك
        'android.provider.extra.CHANNEL_ID': 'high_importance_channel', // معرف القناة الذي حددناه سابقاً
      },
    );
    await intent.launch();
  }
}

// دالة إظهار رسالة التنبيه للمستخدم
void _showPermissionDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // لا يختفي إلا بالضغط على الزر
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
          SizedBox(width: 10),
          Text("تفعيل صوت الإنذار"),
        ],
      ),
      content: const Text(
        "لضمان سماع صوت إنذار السيارة وتنبيهك فوراً، يجب تفعيل (السماح بالصوت) و (العرض على شاشة القفل) في الصفحة التالية.",
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("لاحقاً", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            _openChannelSettings();
          },
          child: const Text("اذهب للإعدادات", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// دالة طلب الصلاحيات الشاملة
Future<void> requestPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: true,
    provisional: false,
    sound: true,
  );

  // صلاحية العرض فوق التطبيقات الأخرى (System Alert Window) ضرورية لإيقاظ الشاشة في بعض الموديلات
  if (await Permission.systemAlertWindow.isDenied) {
     await Permission.systemAlertWindow.request();
  }

  if (!await Permission.ignoreBatteryOptimizations.isGranted) {
    await Permission.ignoreBatteryOptimizations.request();
  }

  // صلاحية Schedule Alarm مهمة جداً للأندرويد 13+ لضمان توقيت الإشعارات
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String msgBody = message.notification?.body ?? message.data['message'] ?? "";
      if (msgBody.isNotEmpty) {
        _triggerUrgentNotification("info", msgBody);
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
          theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.light, useMaterial3: true),
          darkTheme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue, useMaterial3: true),
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

    // --- الفحص الذكي: التأكد من حالة قناة الإشعارات قبل إظهار التنبيه ---
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _checkAndShowPermissionDialog();
      }
    });
  }

  // دالة الفحص الذكي المضافة حديثاً
  Future<void> _checkAndShowPermissionDialog() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final List<AndroidNotificationChannel>? channels = await androidImplementation.getNotificationChannels();
        
        if (channels != null) {
          // البحث عن قناتنا
          final target = channels.firstWhere(
            (c) => c.id == 'high_importance_channel', 
            orElse: () => const AndroidNotificationChannel('', '')
          );

          // إذا كانت القناة مفقودة أو أهميتها أقل من القصوى (مما يعني أن الصوت قد يكون معطلاً)
          if (target.id.isEmpty || target.importance.value < Importance.max.value) {
            _showPermissionDialog(context);
          }
        }
      }
    }
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
      setState(() { _isAuthenticated = false; _checkingAuth = true; });
      _authenticate();
    } else {
      setState(() { _isAuthenticated = true; _checkingAuth = false; });
    }
  }

  Future<void> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'يرجى تأكيد هويتك لفتح نظام هصبة للأدمن',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (didAuthenticate) {
        setState(() { _isAuthenticated = true; _checkingAuth = false; });
      }
    } catch (e) {
      setState(() { _isAuthenticated = true; _checkingAuth = false; });
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
              ElevatedButton(onPressed: _authenticate, child: const Text("اضغط للمحاولة مرة أخرى"))
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}