import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/vital_data.dart';

/// MQTT 연결 상태
enum MqttConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// MQTT 서비스 - 센서 데이터 수신 및 알림 처리
class MqttService {
  MqttServerClient? _client;

  // 연결 설정
  final String broker;
  final int port;
  final String clientId;

  // 토픽
  static const String topicVitalSigns = 'mm/j';
  static const String topicFallStatus = 'fall/status';
  static const String topicFallAlert = 'fall/alert';

  // 상태
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  MqttConnectionState get connectionState => _connectionState;

  // 스트림 컨트롤러
  final _connectionStateController = StreamController<MqttConnectionState>.broadcast();
  final _vitalDataController = StreamController<VitalData>.broadcast();
  final _fallDataController = StreamController<FallData>.broadcast();
  final _alertController = StreamController<AlertEvent>.broadcast();

  // 스트림
  Stream<MqttConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<VitalData> get vitalDataStream => _vitalDataController.stream;
  Stream<FallData> get fallDataStream => _fallDataController.stream;
  Stream<AlertEvent> get alertStream => _alertController.stream;

  // 재연결 타이머
  Timer? _reconnectTimer;

  MqttService({
    this.broker = 'localhost',
    this.port = 1883,
    String? clientId,
  }) : clientId = clientId ?? 'flutter_elderly_care_${DateTime.now().millisecondsSinceEpoch}';

  /// MQTT 브로커에 연결
  Future<bool> connect() async {
    if (_connectionState == MqttConnectionState.connecting) {
      return false;
    }

    _updateConnectionState(MqttConnectionState.connecting);

    _client = MqttServerClient(broker, clientId);
    _client!.port = port;
    _client!.keepAlivePeriod = 60;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    _client!.logging(on: kDebugMode);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('flutter/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      return _client!.connectionStatus?.state == MqttConnectionState.connected;
    } on NoConnectionException catch (e) {
      debugPrint('[MQTT] Connection exception: $e');
      _client!.disconnect();
      _updateConnectionState(MqttConnectionState.error);
      _scheduleReconnect();
      return false;
    } on SocketException catch (e) {
      debugPrint('[MQTT] Socket exception: $e');
      _client!.disconnect();
      _updateConnectionState(MqttConnectionState.error);
      _scheduleReconnect();
      return false;
    } catch (e) {
      debugPrint('[MQTT] Unknown exception: $e');
      _client!.disconnect();
      _updateConnectionState(MqttConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  /// 연결 해제
  void disconnect() {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _updateConnectionState(MqttConnectionState.disconnected);
  }

  /// 리소스 해제
  void dispose() {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _connectionStateController.close();
    _vitalDataController.close();
    _fallDataController.close();
    _alertController.close();
  }

  void _onConnected() {
    debugPrint('[MQTT] Connected to $broker:$port');
    _updateConnectionState(MqttConnectionState.connected);
    _subscribeToTopics();
    _listenToMessages();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected');
    _updateConnectionState(MqttConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    debugPrint('[MQTT] Subscribed to $topic');
  }

  void _onAutoReconnect() {
    debugPrint('[MQTT] Auto reconnecting...');
    _updateConnectionState(MqttConnectionState.connecting);
  }

  void _onAutoReconnected() {
    debugPrint('[MQTT] Auto reconnected');
    _updateConnectionState(MqttConnectionState.connected);
  }

  void _updateConnectionState(MqttConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_connectionState != MqttConnectionState.connected) {
        debugPrint('[MQTT] Attempting to reconnect...');
        connect();
      }
    });
  }

  void _subscribeToTopics() {
    if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    _client!.subscribe(topicVitalSigns, MqttQos.atMostOnce);
    _client!.subscribe(topicFallStatus, MqttQos.atLeastOnce);
    _client!.subscribe(topicFallAlert, MqttQos.atLeastOnce);
  }

  void _listenToMessages() {
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null) return;

      for (final message in messages) {
        final topic = message.topic;
        final payload = message.payload as MqttPublishMessage;
        final messageString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

        try {
          final data = jsonDecode(messageString) as Map<String, dynamic>;
          _handleMessage(topic, data);
        } catch (e) {
          debugPrint('[MQTT] Message parse error: $e');
        }
      }
    });
  }

  void _handleMessage(String topic, Map<String, dynamic> data) {
    // timestamp 처리 - 없거나 작은 값이면 현재 시간 사용
    if (!data.containsKey('timestamp') ||
        (data['timestamp'] is num && (data['timestamp'] as num) < 100000000)) {
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    switch (topic) {
      case topicVitalSigns:
        final vitalData = VitalData.fromJson(data);
        _vitalDataController.add(vitalData);
        break;

      case topicFallStatus:
        final fallData = FallData.fromJson(data);
        _fallDataController.add(fallData);
        break;

      case topicFallAlert:
        final fallData = FallData.fromJson(data);
        _fallDataController.add(fallData);

        // 알림 이벤트 생성
        final alertEvent = AlertEvent.fromFallData(fallData);
        _alertController.add(alertEvent);
        break;
    }
  }
}
