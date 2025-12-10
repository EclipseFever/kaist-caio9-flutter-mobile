import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/vital_data.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';

/// 모니터링 상태 관리 Provider
class MonitoringProvider extends ChangeNotifier {
  final MqttService _mqttService;
  final NotificationService _notificationService;

  // 구독
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _vitalSubscription;
  StreamSubscription? _fallSubscription;
  StreamSubscription? _alertSubscription;

  // 현재 데이터
  VitalData? _currentVitalData;
  FallData? _currentFallData;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;

  // 히스토리 (최근 30초)
  final Queue<VitalData> _vitalHistory = Queue<VitalData>();
  static const int maxHistoryLength = 30;

  // 알림 히스토리
  final List<AlertEvent> _alertHistory = [];
  static const int maxAlertHistory = 20;

  // 낙상 알림 다이얼로그 표시 여부
  bool _showFallAlert = false;
  FallData? _pendingFallAlert;

  // Getters
  VitalData? get currentVitalData => _currentVitalData;
  FallData? get currentFallData => _currentFallData;
  MqttConnectionState get connectionState => _connectionState;
  List<VitalData> get vitalHistory => _vitalHistory.toList();
  List<AlertEvent> get alertHistory => List.unmodifiable(_alertHistory);
  bool get showFallAlert => _showFallAlert;
  FallData? get pendingFallAlert => _pendingFallAlert;

  // 연결 상태 문자열
  String get connectionStatusText {
    switch (_connectionState) {
      case MqttConnectionState.connected:
        return 'LIVE';
      case MqttConnectionState.connecting:
        return 'CONNECTING...';
      case MqttConnectionState.error:
        return 'ERROR';
      case MqttConnectionState.disconnected:
      default:
        return 'OFFLINE';
    }
  }

  // 연결 상태 색상
  Color get connectionStatusColor {
    switch (_connectionState) {
      case MqttConnectionState.connected:
        return Colors.green;
      case MqttConnectionState.connecting:
        return Colors.orange;
      case MqttConnectionState.error:
        return Colors.red;
      case MqttConnectionState.disconnected:
      default:
        return Colors.grey;
    }
  }

  MonitoringProvider({
    required MqttService mqttService,
    required NotificationService notificationService,
  })  : _mqttService = mqttService,
        _notificationService = notificationService {
    _setupListeners();
  }

  /// 리스너 설정
  void _setupListeners() {
    // 연결 상태
    _connectionSubscription = _mqttService.connectionStateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    // Vital Sign 데이터
    _vitalSubscription = _mqttService.vitalDataStream.listen((data) {
      _currentVitalData = data;

      // 히스토리 추가
      _vitalHistory.add(data);
      while (_vitalHistory.length > maxHistoryLength) {
        _vitalHistory.removeFirst();
      }

      // 위험 상태 확인
      if (data.riskLevel == 'High') {
        _notificationService.showVitalAlert(data);
      }

      notifyListeners();
    });

    // 낙상 데이터
    _fallSubscription = _mqttService.fallDataStream.listen((data) {
      _currentFallData = data;

      // 낙상 감지 시 알림
      if (data.isFallDetected) {
        _pendingFallAlert = data;
        _showFallAlert = true;
        _notificationService.showFallAlert(data);
      } else if (data.type == 'RECOVERED') {
        _showFallAlert = false;
        _pendingFallAlert = null;
      }

      notifyListeners();
    });

    // 알림 이벤트
    _alertSubscription = _mqttService.alertStream.listen((event) {
      _alertHistory.insert(0, event);
      while (_alertHistory.length > maxAlertHistory) {
        _alertHistory.removeLast();
      }
      notifyListeners();
    });
  }

  /// MQTT 연결
  Future<void> connect({String? broker, int? port}) async {
    await _mqttService.connect();
  }

  /// 연결 해제
  void disconnect() {
    _mqttService.disconnect();
  }

  /// 낙상 알림 닫기
  void dismissFallAlert() {
    _showFallAlert = false;
    _pendingFallAlert = null;
    notifyListeners();
  }

  /// 알림 히스토리 삭제
  void clearAlertHistory() {
    _alertHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _vitalSubscription?.cancel();
    _fallSubscription?.cancel();
    _alertSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
