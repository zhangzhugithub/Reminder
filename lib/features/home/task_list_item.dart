import 'package:flutter/material.dart';

import '../../core/models/repeat_rule.dart';
import '../../core/models/task.dart';
import '../../core/time/date_format.dart';
import '../../l10n/strings.dart';

/// 任务列表卡片：标题、时间、重复标识、提醒设置、开关状态。
class TaskListItem extends StatelessWidget {
  const TaskListItem({
    super.key,
    required this.task,
    required this.now,
    required this.onTap,
    required this.onToggle,
    this.onRetryCalendarSync,
  });

  final Task task;
  final DateTime now;

  /// 点击卡片回调（进入详情页）。
  final VoidCallback onTap;

  /// 开关切换回调。
  final ValueChanged<bool> onToggle;

  /// 日历同步失败重试回调（null 表示当前无重试能力）。
  final VoidCallback? onRetryCalendarSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = task.isExpiredAt(now);
    final next = task.isRecurring ? task.nextOccurrenceAfter(now) : task.start;
    final timeText = switch (task.repeat) {
      RepeatRule.none => DateFmt.dateTime(task.start, now: now),
      _ when next != null => '${DateFmt.dateTime(next, now: now)} 起',
      _ => DateFmt.dateTime(task.start, now: now),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: _LeadingIcon(task: task, expired: expired),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: task.enabled
              ? null
              : TextStyle(
                  color: theme.disabledColor,
                  decoration: TextDecoration.lineThrough,
                ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(timeText),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                if (task.isRecurring)
                  _Tag(
                    label: DateFmt.repeatLabel(task),
                    icon: Icons.repeat,
                    color: theme.colorScheme.primary,
                  ),
                _Tag(
                  label: DateFmt.advance(task.advanceMinutes),
                  icon: Icons.notifications_active_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                if (expired)
                  _Tag(
                    label: S.taskExpiredTag,
                    icon: Icons.history,
                    color: theme.colorScheme.error,
                  ),
                if (task.calendarSyncError)
                  InkWell(
                    onTap: onRetryCalendarSync,
                    child: _Tag(
                      label: S.calendarSyncErrorTag,
                      icon: Icons.sync_problem,
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: task.enabled,
          onChanged: onToggle,
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.task, required this.expired});

  final Task task;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    if (expired) {
      icon = Icons.history;
      color = scheme.errorContainer;
    } else if (task.isRecurring) {
      icon = Icons.repeat;
      color = scheme.primaryContainer;
    } else {
      icon = Icons.alarm;
      color = scheme.secondaryContainer;
    }
    return CircleAvatar(
      backgroundColor: color,
      foregroundColor: scheme.onSurfaceVariant,
      child: Icon(icon, size: 22),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
