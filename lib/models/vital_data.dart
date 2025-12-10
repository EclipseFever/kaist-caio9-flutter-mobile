/// Vital Sign 데이터 모델
class VitalData {
  final double? heartRate;
  final double? breathRate;
  final double? distance;
  final DateTime timestamp;

  VitalData({
    this.heartRate,
    this.breathRate,
    this.distance,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory VitalData.fromJson(Map<String, dynamic> json) {
    return VitalData(
      heartRate: (json['hr'] as num?)?.toDouble(),
      breathRate: (json['br'] as num?)?.toDouble(),
      distance: (json['d'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt() * 1000,
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hr': heartRate,
      'br': breathRate,
      'd': distance,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// 심박수 상태 평가 (정상: 60-100 bpm)
  String get heartRateStatus {
    if (heartRate == null) return 'unknown';
    if (heartRate! < 40) return 'critical';
    if (heartRate! < 60) return 'warning';
    if (heartRate! > 120) return 'warning';
    if (heartRate! > 150) return 'critical';
    return 'normal';
  }

  /// 호흡수 상태 평가 (정상: 12-20 bpm)
  String get breathRateStatus {
    if (breathRate == null) return 'unknown';
    if (breathRate! < 8) return 'critical';
    if (breathRate! < 12) return 'warning';
    if (breathRate! > 25) return 'warning';
    if (breathRate! > 30) return 'critical';
    return 'normal';
  }

  /// 전체 위험도 평가
  String get riskLevel {
    if (heartRateStatus == 'critical' || breathRateStatus == 'critical') {
      return 'High';
    }
    if (heartRateStatus == 'warning' || breathRateStatus == 'warning') {
      return 'Medium';
    }
    return 'Low';
  }
}

/// 낙상 감지 데이터 모델
class FallData {
  final bool fall;
  final bool human;
  final String type;
  final int duration;
  final DateTime timestamp;
  final String? gateway;
  final String? sensorId;
  final bool isTest;

  FallData({
    required this.fall,
    required this.human,
    required this.type,
    required this.duration,
    DateTime? timestamp,
    this.gateway,
    this.sensorId,
    this.isTest = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory FallData.fromJson(Map<String, dynamic> json) {
    return FallData(
      fall: json['fall'] == 1,
      human: json['human'] == 1,
      type: json['type'] ?? 'NORMAL',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] as num).toInt() * 1000,
            )
          : DateTime.now(),
      gateway: json['gw'] as String?,
      sensorId: json['id'] as String?,
      isTest: json['test'] == true,
    );
  }

  /// 낙상 상태 체크
  bool get isFallDetected => fall && type != 'NORMAL' && type != 'RECOVERED';

  /// 위급 상황 체크
  bool get isCritical => type == 'FALL_CRITICAL';

  /// 상태 표시 텍스트
  String get statusText {
    switch (type) {
      case 'FALL_DETECTED':
        return '낙상 감지됨';
      case 'FALL_CONFIRMED':
        return '낙상 확정';
      case 'FALL_CRITICAL':
        return '위급 상황';
      case 'RECOVERED':
        return '회복됨';
      default:
        return '정상';
    }
  }

  /// 위치 정보
  String get location {
    if (gateway != null && sensorId != null) {
      return '$gateway - $sensorId';
    }
    return 'Bed Room';
  }
}

/// 알림 이벤트 모델
class AlertEvent {
  final String type;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  AlertEvent({
    required this.type,
    required this.title,
    required this.body,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AlertEvent.fromFallData(FallData fallData) {
    String title;
    String body;

    switch (fallData.type) {
      case 'FALL_DETECTED':
        title = '낙상 감지';
        body = '${fallData.location}에서 낙상이 감지되었습니다.';
        break;
      case 'FALL_CONFIRMED':
        title = '낙상 확정';
        body = '${fallData.location}에서 낙상이 확정되었습니다. 확인이 필요합니다.';
        break;
      case 'FALL_CRITICAL':
        title = '위급 상황';
        body = '${fallData.location}에서 ${fallData.duration}초간 움직임이 없습니다. 즉시 확인하세요!';
        break;
      case 'RECOVERED':
        title = '회복됨';
        body = '${fallData.location} 환자가 회복되었습니다.';
        break;
      default:
        title = '알림';
        body = '상태 변화가 감지되었습니다.';
    }

    return AlertEvent(
      type: fallData.type,
      title: title,
      body: body,
      timestamp: fallData.timestamp,
      data: {
        'gateway': fallData.gateway,
        'sensorId': fallData.sensorId,
        'duration': fallData.duration,
      },
    );
  }
}
