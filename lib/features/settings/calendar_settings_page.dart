import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/settings_repository.dart';
import '../../core/models/settings.dart';
import '../../l10n/strings.dart';
import '../../services/calendar/calendar_service.dart';
import '../../state/app_state.dart';

/// 日历同步设置页（需求 6.2）：
/// 全局总开关、删除默认选项、日历状态、立即同步、删除专属日历。
class CalendarSettingsPage extends StatefulWidget {
  const CalendarSettingsPage({super.key});

  @override
  State<CalendarSettingsPage> createState() => _CalendarSettingsPageState();
}

class _CalendarSettingsPageState extends State<CalendarSettingsPage> {
  bool? _calendarExists;
  bool? _hasPermission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final calendar = context.read<CalendarService>();
    final settingsRepo = context.read<SettingsRepository>();
    try {
      final hasPermission = await calendar.hasPermissions();
      var exists = false;
      if (hasPermission) {
        final id = settingsRepo.settings.calendarId;
        if (id != null) {
          exists = await calendar.ensureCalendar().then((_) => true);
        }
      }
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _calendarExists = exists;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _calendarExists = false;
        });
      }
    }
  }

  Future<void> _resyncAll() async {
    setState(() => _busy = true);
    final calendar = context.read<CalendarService>();
    final repository = context.read<AppState>().taskRepository;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (ok, failed) = await calendar.resyncAll(repository);
      messenger.showSnackBar(SnackBar(
        content: Text('同步完成：成功 $ok 个，失败 $failed 个'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
    }
    if (mounted) {
      setState(() => _busy = false);
      await _loadStatus();
    }
  }

  Future<void> _deleteAppCalendar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteAppCalendarTitle),
        content: const Text(S.deleteAppCalendarBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<CalendarService>().deleteAppCalendar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.deleteAppCalendarDone)),
      );
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsRepo = context.watch<SettingsRepository>();
    final s = settingsRepo.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsCalendar)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.sync_alt),
            title: const Text(S.calendarSyncGlobalSwitch),
            subtitle: const Text(S.calendarSyncGlobalSubtitle),
            value: s.calendarSyncEnabled,
            onChanged: (v) =>
                settingsRepo.update((s) => s.calendarSyncEnabled = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.delete_sweep_outlined),
            title: const Text(S.calendarDeleteDefaultSwitch),
            subtitle: const Text(S.calendarDeleteDefaultSubtitle),
            value: s.deleteCalendarDefault,
            onChanged: (v) =>
                settingsRepo.update((s) => s.deleteCalendarDefault = v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(S.calendarStatusTitle),
            subtitle: Text(_statusText(s)),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadStatus,
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text(S.resyncAllTitle),
            subtitle: const Text(S.resyncAllSubtitle),
            onTap: _busy ? null : _resyncAll,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              S.deleteAppCalendarTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text(S.deleteAppCalendarSubtitle),
            onTap: _deleteAppCalendar,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(S.calendarOneWayNote),
          ),
        ],
      ),
    );
  }

  String _statusText(ReminderSettings s) {
    if (_hasPermission == false) return S.calendarStatusNoPermission;
    if (_calendarExists == true && s.calendarId != null) {
      return '${s.calendarName ?? CalendarService.calendarName}（已创建）';
    }
    if (_calendarExists == false && s.calendarId != null) {
      return S.calendarStatusMissing;
    }
    return S.calendarStatusNotCreated;
  }
}
