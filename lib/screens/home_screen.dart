import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vital_data.dart';
import '../providers/monitoring_provider.dart';
import '../widgets/fall_alert_dialog.dart';
import '../widgets/vital_card.dart';
import '../widgets/vital_chart.dart';

/// 홈 화면 - 환자 모니터링 시스템
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _alertShown = false;

  @override
  void initState() {
    super.initState();
    // MQTT 연결
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Consumer<MonitoringProvider>(
        builder: (context, provider, _) {
          // 낙상 알림 다이얼로그 표시
          if (provider.showFallAlert &&
              provider.pendingFallAlert != null &&
              !_alertShown) {
            _alertShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FallAlertDialog.show(
                context,
                provider.pendingFallAlert!,
                onDismiss: () {
                  provider.dismissFallAlert();
                  _alertShown = false;
                },
                onView: () {
                  provider.dismissFallAlert();
                  _alertShown = false;
                },
              );
            });
          } else if (!provider.showFallAlert) {
            _alertShown = false;
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.connect();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vital Signs Grid
                  _buildVitalSignsGrid(provider),
                  const SizedBox(height: 16),

                  // Risk Level Grid
                  _buildRiskLevelGrid(provider),
                  const SizedBox(height: 20),

                  // Chart
                  VitalChart(
                    data: provider.vitalHistory,
                    title: 'Vital Signs',
                  ),
                  const SizedBox(height: 20),

                  // 하단 차트 (복제)
                  VitalChart(
                    data: provider.vitalHistory,
                    title: 'Vital Signs',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        '환자 모니터링 시스템',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // 연결 상태 표시
        Consumer<MonitoringProvider>(
          builder: (context, provider, _) {
            return Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: provider.connectionStatusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: provider.connectionStatusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.connectionStatusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: provider.connectionStatusColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // 알림 아이콘
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // 알림 테스트
            _showTestAlert();
          },
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.medical_services,
                    size: 32,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '독거노인 돌봄 시스템',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'KAIST AI 대학원',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('대시보드'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('알림 기록'),
            onTap: () {
              Navigator.pop(context);
              _showAlertHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('정보'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsGrid(MonitoringProvider provider) {
    final data = provider.currentVitalData;

    return Row(
      children: [
        Expanded(
          child: VitalCard(
            title: 'Heart Rate',
            value: data?.heartRate?.toStringAsFixed(0) ?? '--',
            unit: 'bpm',
            valueColor: _getHeartRateColor(data?.heartRate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: VitalCard(
            title: 'Breathing',
            value: data?.breathRate?.toStringAsFixed(0) ?? '--',
            unit: 'bpm',
            valueColor: _getBreathRateColor(data?.breathRate),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskLevelGrid(MonitoringProvider provider) {
    final data = provider.currentVitalData;

    return Row(
      children: [
        Expanded(
          child: RiskLevelCard(
            title: 'Risk Level',
            level: data?.riskLevel ?? 'Low',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RiskLevelCard(
            title: 'Risk Level',
            level: data?.riskLevel ?? 'Low',
          ),
        ),
      ],
    );
  }

  Color _getHeartRateColor(double? hr) {
    if (hr == null) return const Color(0xFF1976D2);
    if (hr < 40 || hr > 150) return Colors.red;
    if (hr < 60 || hr > 120) return Colors.orange;
    return const Color(0xFF1976D2);
  }

  Color _getBreathRateColor(double? br) {
    if (br == null) return const Color(0xFF1976D2);
    if (br < 8 || br > 30) return Colors.red;
    if (br < 12 || br > 25) return Colors.orange;
    return const Color(0xFF1976D2);
  }

  void _showTestAlert() {
    final testFallData = FallData(
      fall: true,
      human: true,
      type: 'FALL_CONFIRMED',
      duration: 5,
      gateway: 'Lab 1',
      sensorId: 'Bed Room',
    );

    FallAlertDialog.show(
      context,
      testFallData,
      onDismiss: () {},
      onView: () {},
    );
  }

  void _showAlertHistory() {
    final provider = context.read<MonitoringProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '알림 기록',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      provider.clearAlertHistory();
                      Navigator.pop(context);
                    },
                    child: const Text('모두 지우기'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: provider.alertHistory.isEmpty
                  ? const Center(
                      child: Text(
                        '알림 기록이 없습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: provider.alertHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alert = provider.alertHistory[index];
                        return ListTile(
                          leading: Icon(
                            Icons.warning_rounded,
                            color: alert.type == 'FALL_CRITICAL'
                                ? Colors.red
                                : Colors.orange,
                          ),
                          title: Text(alert.title),
                          subtitle: Text(alert.body),
                          trailing: Text(
                            _formatTime(alert.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
