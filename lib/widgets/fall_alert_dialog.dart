import 'package:flutter/material.dart';

import '../models/vital_data.dart';

/// 낙상 알림 다이얼로그 위젯
class FallAlertDialog extends StatelessWidget {
  final FallData fallData;
  final VoidCallback? onDismiss;
  final VoidCallback? onView;

  const FallAlertDialog({
    super.key,
    required this.fallData,
    this.onDismiss,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 경고 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getAlertColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                size: 50,
                color: _getAlertColor(),
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            Text(
              _getAlertTitle(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getAlertColor(),
              ),
            ),
            const SizedBox(height: 12),

            // 위치 및 시간
            Text(
              'Now - ${fallData.location}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            // 지속 시간 (Critical 상태일 때)
            if (fallData.isCritical) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${fallData.duration}초간 움직임 없음',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // VIEW 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onView?.call();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'VIEW',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // 닫기 버튼
            TextButton(
              onPressed: () {
                onDismiss?.call();
                Navigator.of(context).pop();
              },
              child: Text(
                'Dismiss',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAlertColor() {
    switch (fallData.type) {
      case 'FALL_CRITICAL':
        return Colors.red;
      case 'FALL_CONFIRMED':
        return Colors.orange;
      case 'FALL_DETECTED':
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  String _getAlertTitle() {
    switch (fallData.type) {
      case 'FALL_CRITICAL':
        return '위급 상황';
      case 'FALL_CONFIRMED':
        return '낙상 확정';
      case 'FALL_DETECTED':
        return '낙상 감지';
      default:
        return '낙상 발생';
    }
  }

  /// 다이얼로그 표시 헬퍼
  static Future<void> show(
    BuildContext context,
    FallData fallData, {
    VoidCallback? onDismiss,
    VoidCallback? onView,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FallAlertDialog(
        fallData: fallData,
        onDismiss: onDismiss,
        onView: onView,
      ),
    );
  }
}
