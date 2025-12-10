import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/vital_data.dart';

/// 백그라운드 메시지 핸들러 (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// 알림 서비스 - Firebase Cloud Messaging + Local Notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 알림 채널 ID
  static const String channelId = 'elderly_care_alerts';
  static const String channelName = '독거노인 돌봄 알림';
  static const String channelDescription = '낙상 및 위험 상황 알림';

  // FCM 토큰
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // 콜백
  Function(Map<String, dynamic>)? onNotificationTap;

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    // Firebase 초기화
    await Firebase.initializeApp();

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 알림 권한 요청
    await _requestPermission();

    // Local Notifications 초기화
    await _initializeLocalNotifications();

    // FCM 토큰 가져오기
    await _getToken();

    // 메시지 리스너 설정
    _setupMessageListeners();

    debugPrint('[NotificationService] Initialized');
  }

  /// 알림 권한 요청
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // 중요 알림 (iOS)
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  /// Local Notifications 초기화
  Future<void> _initializeLocalNotifications() async {
    // Android 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// FCM 토큰 가져오기
  Future<void> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('[FCM] Token: $_fcmToken');

      // 토큰 갱신 리스너
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('[FCM] Token refreshed: $token');
      });
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

  /// 메시지 리스너 설정
  void _setupMessageListeners() {
    // 포그라운드 메시지
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      _showLocalNotification(
        title: message.notification?.title ?? 'Alert',
        body: message.notification?.body ?? '',
        payload: message.data.toString(),
      );
    });

    // 백그라운드에서 앱 열기
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Message opened app: ${message.notification?.title}');
      onNotificationTap?.call(message.data);
    });

    // 앱이 종료된 상태에서 열기
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM] Initial message: ${message.notification?.title}');
        onNotificationTap?.call(message.data);
      }
    });
  }

  /// 알림 탭 핸들러
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Notification] Tapped: ${response.payload}');
    if (response.payload != null) {
      onNotificationTap?.call({'payload': response.payload});
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isCritical = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// 낙상 알림 표시
  Future<void> showFallAlert(FallData fallData) async {
    final alert = AlertEvent.fromFallData(fallData);

    await _showLocalNotification(
      title: alert.title,
      body: alert.body,
      payload: fallData.type,
      isCritical: fallData.isCritical,
    );
  }

  /// 위험 상태 알림 표시
  Future<void> showVitalAlert(VitalData vitalData) async {
    if (vitalData.riskLevel == 'High') {
      await _showLocalNotification(
        title: '위험 상태 감지',
        body: '심박수: ${vitalData.heartRate?.toStringAsFixed(0) ?? "N/A"} bpm, 호흡수: ${vitalData.breathRate?.toStringAsFixed(0) ?? "N/A"} bpm',
        isCritical: true,
      );
    }
  }

  /// 테스트 알림 표시
  Future<void> showTestNotification() async {
    await _showLocalNotification(
      title: 'MEDICAL ALERT',
      body: 'Fall Detected: Bed Room',
      payload: 'test',
    );
  }
}
