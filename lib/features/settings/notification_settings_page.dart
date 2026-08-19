import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/settings_repository.dart';
import '../../core/time/date_format.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// 通知提醒设置页（需求 6.3）。
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const _advanceOptions = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final settingsRepo = context.watch<SettingsRepository>();
    final s = settingsRepo.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsNotification)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('提醒铃声'),
            value: s.notificationSound,
            onChanged: (v) =>
                settingsRepo.update((s) => s.notificationSound = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('提醒震动'),
            value: s.notificationVibrate,
            onChanged: (v) =>
                settingsRepo.update((s) => s.notificationVibrate = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.history_toggle_off),
            title: const Text('过期任务继续提醒'),
            subtitle: const Text('任务开始时间已过仍未提醒时，开启后立即补发一次通知'),
            value: s.expiredTaskNotify,
            onChanged: (v) {
              final appState = context.read<AppState>();
              settingsRepo.update((s) {
                s.expiredTaskNotify = v;
              }).then((_) {
                // 设置变化后重建全部排程
                appState.notificationScheduler.topUpAll();
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('默认提前提醒时长'),
            subtitle: Text(DateFmt.advance(s.defaultAdvanceMinutes)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final minutes in _advanceOptions)
                  ChoiceChip(
                    label: Text(DateFmt.advance(minutes)),
                    selected: s.defaultAdvanceMinutes == minutes,
                    onSelected: (_) => settingsRepo.update(
                        (s) => s.defaultAdvanceMinutes = minutes),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '通知由系统级调度触发（Android AlarmManager / iOS 通知中心），'
              'App 被杀后仍能提醒。请确保已开启通知权限（设置 → 权限管理）。',
            ),
          ),
        ],
      ),
    );
  }
}
