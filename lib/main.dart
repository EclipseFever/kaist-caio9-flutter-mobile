import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/monitoring_provider.dart';
import 'screens/home_screen.dart';
import 'services/mqtt_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 알림 서비스 초기화
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
  } catch (e) {
    debugPrint('[Main] Notification service initialization failed: $e');
    // Firebase 초기화 실패 시에도 앱은 계속 실행
  }

  // MQTT 서비스 생성
  // 실제 배포 시 브로커 주소 변경 필요
  final mqttService = MqttService(
    broker: 'localhost', // MQTT 브로커 주소
    port: 1883, // MQTT 브로커 포트
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MonitoringProvider(
            mqttService: mqttService,
            notificationService: notificationService,
          ),
        ),
      ],
      child: const ElderlyHealthApp(),
    ),
  );
}

/// 독거노인 안전 돌봄 앱
class ElderlyHealthApp extends StatelessWidget {
  const ElderlyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '환자 모니터링 시스템',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
