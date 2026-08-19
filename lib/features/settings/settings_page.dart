import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import 'about_page.dart';
import 'appearance_settings_page.dart';
import 'backup_page.dart';
import 'calendar_settings_page.dart';
import 'notification_settings_page.dart';
import 'permissions_page.dart';
import 'voice_settings_page.dart';

/// 设置中心（需求模块 6）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabSettings)),
      body: ListView(
        children: [
          _entry(context, Icons.mic_none, S.settingsVoice,
              const VoiceSettingsPage()),
          _entry(context, Icons.calendar_month_outlined, S.settingsCalendar,
              const CalendarSettingsPage()),
          _entry(context, Icons.notifications_outlined, S.settingsNotification,
              const NotificationSettingsPage()),
          _entry(context, Icons.palette_outlined, S.settingsAppearance,
              const AppearanceSettingsPage()),
          _entry(context, Icons.admin_panel_settings_outlined,
              S.settingsPermissions, const PermissionsPage()),
          _entry(context, Icons.backup_outlined, S.settingsBackup,
              const BackupPage()),
          const Divider(),
          _entry(context, Icons.info_outline, S.settingsAbout,
              const AboutPage()),
        ],
      ),
    );
  }

  Widget _entry(
      BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
