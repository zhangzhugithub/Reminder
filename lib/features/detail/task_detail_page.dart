import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import '../../core/db/task_repository.dart';
import '../../core/models/task.dart';
import '../../core/time/date_format.dart';
import '../../l10n/strings.dart';
import '../../services/task_coordinator.dart';
import '../../state/app_state.dart';
import '../edit/task_edit_page.dart';

/// 任务详情页（通知点击跳转目标）。
///
/// 直接监听 Hive box，任务被外部修改/删除时实时反映。
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  Future<void> _edit(BuildContext context, Task task) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditPage(initial: task)),
    );
  }

  Future<void> _delete(BuildContext context, Task task) async {
    final coordinator = context.read<TaskCoordinator>();
    var deleteCalendar = coordinator.settings.settings.deleteCalendarDefault;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.deleteTaskTitle(task.title)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.deleteTaskConfirm(task.title)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(S.deleteCalendarWithTask),
                value: deleteCalendar,
                onChanged: (v) => setState(() => deleteCalendar = v ?? true),
              ),
            ],
          ),
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
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await coordinator.deleteTask(task, deleteCalendarEvent: deleteCalendar);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.deletedToast(task.title))));
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggle(BuildContext context, Task task, bool enabled) async {
    final coordinator = context.read<TaskCoordinator>();
    // 关闭任务时：若已绑定日历事件，询问保留还是同步删除（需求 2.5）
    var deleteCalendarEvent = false;
    if (!enabled &&
        task.syncToCalendar &&
        task.calendarEventId != null &&
        coordinator.settings.settings.calendarSyncEnabled) {
      deleteCalendarEvent = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text(S.disableTaskTitle),
              content: Text(S.disableTaskCalendarBody(task.title)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text(S.keepCalendarEvent),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(S.deleteCalendarEvent),
                ),
              ],
            ),
          ) ??
          false;
      if (!context.mounted) return;
    }
    await coordinator.toggleEnabled(task, enabled,
        deleteCalendarEvent: deleteCalendarEvent);
  }

  Future<void> _retryCalendarSync(BuildContext context, Task task) async {
    await context.read<TaskCoordinator>().syncCalendar(task);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.calendarSyncRetriedToast)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = context.read<AppState>().database.tasks;
    return ValueListenableBuilder<Box<Task>>(
      valueListenable: box.listenable(),
      builder: (context, _, _) {
        final task = box.get(taskId);
        if (task == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text(S.taskNotFound)),
          );
        }
        return _buildBody(context, task);
      },
    );
  }

  Widget _buildBody(BuildContext context, Task task) {
    final coordinator = context.watch<TaskCoordinator>();
    final globalCalendarOn = coordinator.settings.settings.calendarSyncEnabled;
    final now = DateTime.now();
    final next = task.isRecurring ? task.nextOccurrenceAfter(now) : task.start;
    final nextText =
        next == null ? DateFmt.dateTime(task.start, now: now) : DateFmt.dateTime(next, now: now);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.taskDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: S.edit,
            onPressed: () => _edit(context, task),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: S.delete,
            onPressed: () => _delete(context, task),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (task.isExpiredAt(now))
                  Chip(
                    label: const Text(S.taskExpiredTag),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _field(context, Icons.play_circle_outline, S.startTime,
              DateFmt.dateTime(task.start, now: now)),
          if (task.end != null)
            _field(context, Icons.stop_circle_outlined, S.endTime,
                DateFmt.dateTime(task.end!, now: now)),
          _field(context, Icons.repeat, S.repeat, DateFmt.repeatLabel(task)),
          _field(context, Icons.notifications_active_outlined,
              S.advanceReminder, DateFmt.advance(task.advanceMinutes)),
          if (task.isRecurring)
            _field(context, Icons.event_repeat, S.nextOccurrence, nextText),
          if (task.note.isNotEmpty)
            _field(context, Icons.notes, S.taskNote, task.note),
          const Divider(),
          _calendarStatusTile(context, task, globalCalendarOn),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text(S.enabledSwitch),
            subtitle: const Text(S.disableNotifHint),
            value: task.enabled,
            onChanged: (v) => _toggle(context, task, v),
          ),
          const Divider(),
          _field(context, Icons.schedule, S.createdAt,
              DateFmt.dateTime(task.createdAt, now: now)),
          _field(context, Icons.update, S.modifiedAt,
              DateFmt.dateTime(task.modifiedAt, now: now)),
        ],
      ),
    );
  }

  Widget _field(
      BuildContext context, IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label),
      dense: true,
    );
  }

  /// 日历同步状态行。
  Widget _calendarStatusTile(
      BuildContext context, Task task, bool globalCalendarOn) {
    final theme = Theme.of(context);
    final (IconData icon, String status, Widget? trailing) =
        switch ((task.syncToCalendar, globalCalendarOn, task.calendarSyncError)) {
      (false, _, _) => (
          Icons.calendar_month_outlined,
          S.calendarSyncTaskOff,
          null
        ),
      (_, false, _) => (
          Icons.calendar_month_outlined,
          S.calendarSyncGlobalOff,
          null
        ),
      (_, _, true) => (
          Icons.sync_problem,
          S.calendarSyncFailed,
          TextButton(
            onPressed: () => _retryCalendarSync(context, task),
            child: const Text(S.retry),
          )
        ),
      _ => (
          Icons.check_circle_outline,
          task.calendarEventId == null ? S.calendarSyncPending : S.calendarSynced,
          null
        ),
    };
    return ListTile(
      leading: Icon(icon, color: status == S.calendarSyncFailed ? theme.colorScheme.error : null),
      title: Text(status),
      subtitle: const Text(S.syncToCalendar),
      trailing: trailing,
    );
  }
}
