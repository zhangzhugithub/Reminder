import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/strings.dart';

/// 语音录入权限引导页：麦克风授权 + 电池优化白名单引导。
///
/// 返回 true 表示麦克风权限已授予（调用方继续开始录音）。
class AsrPermissionPage extends StatefulWidget {
  const AsrPermissionPage({super.key});

  @override
  State<AsrPermissionPage> createState() => _AsrPermissionPageState();
}

class _AsrPermissionPageState extends State<AsrPermissionPage> {
  bool _granted = false;
  bool _batteryIgnored = false;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final micStatus = await Permission.microphone.status;
    var batteryIgnored = false;
    if (_isAndroid) {
      batteryIgnored =
          (await Permission.ignoreBatteryOptimizations.status).isGranted;
    }
    if (mounted) {
      setState(() {
        _granted = micStatus.isGranted;
        _batteryIgnored = batteryIgnored;
      });
    }
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (mounted) Navigator.of(context).pop(true);
    } else if (status.isPermanentlyDenied) {
      // 已被永久拒绝 → 跳系统设置
      await openAppSettings();
    } else {
      await _refresh();
    }
  }

  Future<void> _requestIgnoreBattery() async {
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
      appBar: AppBar(title: const Text(S.voicePermissionsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                _granted ? Icons.check_circle : Icons.mic_none,
                color: _granted ? Colors.green : null,
              ),
              title: const Text(S.permissionMic),
              subtitle: const Text(S.permissionMicDetail),
              trailing: _granted
                  ? const Text(S.enabled)
                  : FilledButton(
                      onPressed: _requestMic,
                      child: const Text(S.permissionGrant),
                    ),
            ),
          ),
          if (_isAndroid) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _batteryIgnored
                      ? Icons.check_circle
                      : Icons.battery_charging_full,
                  color: _batteryIgnored ? Colors.green : null,
                ),
                title: const Text(S.batteryOptimization),
                subtitle: const Text(S.batteryOptimizationDetail),
                trailing: _batteryIgnored
                    ? const Text(S.enabled)
                    : FilledButton.tonal(
                        onPressed: _requestIgnoreBattery,
                        child: const Text(S.permissionAllow),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              S.vendorKillNote,
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
}
