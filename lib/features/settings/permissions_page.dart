import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// 权限管理中心（需求 6.5）：集中展示所需权限，支持跳转系统设置。
///
/// 同时承担需求 4.4 的系统限制适配提示：
/// 精确闹钟状态、电池优化引导、厂商后台查杀免责说明。
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _loading = true;
  PermissionStatus _mic = PermissionStatus.denied;
  bool _calendar = false;
  bool? _notification;
  bool _exactAlarm = false;
  bool _batteryIgnored = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final appState = context.read<AppState>();
    final mic = await Permission.microphone.status;
    var calendar = false;
    try {
      calendar = await appState.calendarService.hasPermissions();
    } catch (_) {}
    bool? notification;
    try {
      notification =
          await appState.notificationService.areNotificationsEnabled();
    } catch (_) {}
    var exactAlarm = true;
    var battery = true;
    if (_isAndroid) {
      try {
        exactAlarm =
            await appState.notificationService.canScheduleExactNotifications();
      } catch (_) {}
      battery = (await Permission.ignoreBatteryOptimizations.status).isGranted;
    }
    if (mounted) {
      setState(() {
        _mic = mic;
        _calendar = calendar;
        _notification = notification;
        _exactAlarm = exactAlarm;
        _batteryIgnored = battery;
        _loading = false;
      });
    }
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
    await _refresh();
  }

  Future<void> _requestExactAlarm() async {
    final appState = context.read<AppState>();
    await appState.notificationService.requestExactAlarmsPermission();
    await _refresh();
    if (!mounted) return;
    if (!_exactAlarm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未开启精确闹钟，提醒将降级为非精确模式（可能延迟数分钟）')),
      );
    }
  }

  Future<void> _requestBattery() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    await _refresh();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.batteryRequestFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsPermissions)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _statusTile(
                  icon: Icons.mic_none,
                  title: S.permissionMic,
                  subtitle: S.permissionMicDetail,
                  granted: _mic.isGranted,
                  onTap: _openSystemSettings,
                ),
                _statusTile(
                  icon: Icons.calendar_month_outlined,
                  title: '日历读写',
                  subtitle: '用于将任务同步到系统日历',
                  granted: _calendar,
                  onTap: _openSystemSettings,
                ),
                _statusTile(
                  icon: Icons.notifications_outlined,
                  title: '通知',
                  subtitle: '用于定时提醒通知',
                  granted: _notification == true,
                  onTap: _openSystemSettings,
                ),
                if (_isAndroid)
                  _statusTile(
                    icon: Icons.alarm_on,
                    title: '精确闹钟',
                    subtitle: 'Android 12+ 可撤销权限；关闭后提醒可能延迟数分钟',
                    granted: _exactAlarm,
                    onTap: _requestExactAlarm,
                  ),
                if (_isAndroid)
                  _statusTile(
                    icon: Icons.battery_charging_full,
                    title: S.batteryOptimization,
                    subtitle: S.batteryOptimizationDetail,
                    granted: _batteryIgnored,
                    onTap: _requestBattery,
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    S.permissionsFootnote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: granted ? Colors.green : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: granted
          ? const Text(S.enabled, style: TextStyle(color: Colors.green))
          : TextButton(
              onPressed: onTap,
              child: const Text(S.permissionGoSettings),
            ),
      onTap: granted ? null : onTap,
    );
  }
}
