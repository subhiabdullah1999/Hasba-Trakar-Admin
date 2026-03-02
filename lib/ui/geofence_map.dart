import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // تأكد من إضافة هذه المكتبة في pubspec.yaml

class GeofencePage extends StatefulWidget {
  final String carID;
  const GeofencePage({super.key, required this.carID});

  @override
  _GeofencePageState createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  GoogleMapController? _mapController;
  
  // تغيير الإحداثيات الافتراضية لتكون متغيرة بناءً على موقع الأدمن
  LatLng _center = const LatLng(24.7136, 46.6753); 
  double _radius = 500.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _determineAdminPosition(); // البدء بجلب موقع الأدمن أولاً
  }

  // دالة جديدة لجلب موقع الأدمن الحالي
  Future<void> _determineAdminPosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fastLoadGeofence(); // العودة لتحميل موقع السيارة إذا كانت الخدمة معطلة
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fastLoadGeofence();
          return;
        }
      }
      
      // جلب الموقع الحالي للأدمن
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
      
      // بعد تحديد موقع الأدمن، نحرك الكاميرا لموقعه ونكمل تحميل بيانات النطاق
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 9));
      _fastLoadGeofence();
      
    } catch (e) {
      debugPrint("Error getting admin location: $e");
      _fastLoadGeofence();
    }
  }

  void _fastLoadGeofence() async {
    try {
      final snap = await _dbRef.child('devices/${widget.carID}/geofence').get();
      if (snap.exists) {
        var data = snap.value as Map;
        _center = LatLng(
          double.parse(data['lat'].toString()), 
          double.parse(data['lng'].toString())
        );
        _radius = double.parse(data['radius'].toString());
      } else {
        final locSnap = await _dbRef.child('devices/${widget.carID}/responses').get();
        if (locSnap.exists) {
          var d = locSnap.value as Map;
          _center = LatLng(
            double.parse(d['lat'].toString()), 
            double.parse(d['lng'].toString())
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading geofence: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 9));
      }
    }
  }

  void _save() {
    _dbRef.child('devices/${widget.carID}/geofence').set({
      'lat': _center.latitude,
      'lng': _center.longitude,
      'radius': _radius.toInt(),
    });
    _dbRef.child('devices/${widget.carID}/geofence_radius').set(_radius.toInt());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ نطاق الأمان بنجاح")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تحديد دائرة الحماية"), backgroundColor: Colors.blue.shade900),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 8),
            onMapCreated: (c) => _mapController = c,
            onTap: (pos) => setState(() => _center = pos),
            markers: {Marker(markerId: const MarkerId("center"), position: _center)},
            myLocationEnabled: true, // إظهار نقطة زرقاء لموقع الأدمن الحالي
            myLocationButtonEnabled: true,
            circles: {
              Circle(
                circleId: const CircleId("zone"),
                center: _center,
                radius: _radius,
                fillColor: Colors.blue.withOpacity(0.2),
                strokeColor: Colors.blue,
                strokeWidth: 2,
              )
            },
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "المسافة المسموحة: ${(_radius / 1000).toStringAsFixed(1)} كم",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _radius,
                    min: 100,
                    max: 100000,
                    divisions: 200,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      minimumSize: const Size(double.infinity, 50)
                    ),
                    onPressed: _save,
                    child: const Text("حفظ الإعدادات", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}