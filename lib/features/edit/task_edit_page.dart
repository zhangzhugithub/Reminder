import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/settings_repository.dart';
import '../../core/db/task_repository.dart';
import '../../core/models/repeat_rule.dart';
import '../../core/models/task.dart';
import '../../core/nlp/parsed_task.dart';
import '../../core/time/date_format.dart';
import '../../l10n/strings.dart';
import '../../services/task_coordinator.dart';

/// 语音/文本解析结果的预设值（供编辑页预填）。
class TaskEditPresets {
  const TaskEditPresets({
    this.title,
    this.start,
    this.end,
    this.repeat,
    this.advanceMinutes,
    this.note,
  });

  final String? title;
  final DateTime? start;
  final DateTime? end;
  final RepeatRule? repeat;
  final int? advanceMinutes;
  final String? note;

  /// 由 NLP 解析结果构造（语音/文本录入流程预填）。
  factory TaskEditPresets.fromParsed(ParsedTask p) => TaskEditPresets(
        title: p.title.isEmpty ? null : p.title,
        start: p.start,
        end: p.end,
        repeat: p.repeat,
        advanceMinutes: p.advanceMinutes,
        note: p.note.isEmpty ? null : p.note,
      );
}

/// 任务新建/编辑页。
///
/// 两种创建入口共用：手动新建（[initial] 为 null）与语音/文本录入后的
/// 预览编辑（[presets] 预填解析结果），所有字段均可手动修改。
class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key, this.initial, this.presets});

  /// 编辑已有任务时传入；null 表示新建。
  final Task? initial;

  /// 语音/文本解析预填值。
  final TaskEditPresets? presets;

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  static const _advanceOptions = [0, 5, 10, 15, 30, 60];

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _start;
  DateTime? _end;
  late RepeatRule _repeat;
  late int _advanceMinutes;
  late bool _syncToCalendar;
  late bool _enabled;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    final p = widget.presets;
    final now = DateTime.now();
    // 默认开始时间：下一个整半点（手动新建体验更自然）
    var defaultStart = DateTime(now.year, now.month, now.day, now.hour, 0);
    if (now.minute >= 30) {
      defaultStart = defaultStart.add(const Duration(hours: 1));
    } else {
      defaultStart = defaultStart.add(const Duration(minutes: 30));
    }
    _titleController = TextEditingController(text: t?.title ?? p?.title ?? '');
    _noteController = TextEditingController(text: t?.note ?? p?.note ?? '');
    _start = t?.start ?? p?.start ?? defaultStart;
    _end = t?.end ?? p?.end;
    _repeat = t?.repeat ?? p?.repeat ?? RepeatRule.none;
    // 默认提前提醒时长取设置预设（需求 6.3）
    _advanceMinutes = t?.advanceMinutes ??
        p?.advanceMinutes ??
        context.read<SettingsRepository>().settings.defaultAdvanceMinutes;
    _syncToCalendar = t?.syncToCalendar ?? true;
    _enabled = t?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_start);
    if (picked != null) {
      setState(() {
        _start = picked;
        // 结束时间早于新开始时间时自动顺延
        if (_end != null && _end!.isBefore(picked)) {
          _end = null;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_end ?? _start.add(const Duration(hours: 1)));
    if (picked != null) setState(() => _end = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickCustomAdvance() async {
    final controller = TextEditingController(
      text: _advanceOptions.contains(_advanceMinutes) ? '' : '$_advanceMinutes',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.advanceCustomTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: S.advanceCustomUnitMinute,
            hintText: '例如 90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text.trim());
              if (minutes == null || minutes <= 0) return;
              Navigator.pop(dialogContext, minutes.clamp(1, 10080).toInt());
            },
            child: const Text(S.ok),
          ),
        ],
      ),
    );
    if (value != null) setState(() => _advanceMinutes = value);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.titleRequired)),
      );
      return;
    }
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.endBeforeStart)),
      );
      return;
    }

    final now = DateTime.now();
    final original = widget.initial;
    final task = Task(
      id: original?.id ?? const Uuid().v4(),
      title: title,
      note: _noteController.text.trim(),
      start: _start,
      end: _end,
      repeat: _repeat,
      repeatWeekday: _start.weekday,
      repeatMonthDay: _start.day,
      advanceMinutes: _advanceMinutes,
      enabled: _enabled,
      syncToCalendar: _syncToCalendar,
      calendarEventId: original?.calendarEventId,
      calendarSyncError: original?.calendarSyncError ?? false,
      createdAt: original?.createdAt ?? now,
      modifiedAt: now,
      scheduledNotificationIds: original?.scheduledNotificationIds,
      notifBlockId: original?.notifBlockId ?? 0,
    );

    // 过期任务确认提示（需求：开始时间不能早于当前时间，过期任务给予确认提示）
    if (!task.isRecurring && task.start.isBefore(now)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(S.expiredConfirmTitle),
          content: const Text(S.expiredConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(S.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await context.read<TaskCoordinator>().save(task);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<TaskCoordinator>();
    final globalCalendarOn = coordinator.settings.settings.calendarSyncEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? S.editTask : S.newTask),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(S.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: S.taskTitle,
                hintText: S.taskTitleHint,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: S.taskNote,
                hintText: S.taskNoteHint,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _sectionTitle(S.startTime),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(DateFmt.dateTime(_start)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickStart,
          ),
          _sectionTitle(S.endTime),
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: Text(_end == null ? S.noEndTime : DateFmt.dateTime(_end!)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_end != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: S.noEndTime,
                    onPressed: () => setState(() => _end = null),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _pickEnd,
          ),
          _sectionTitle(S.repeat),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final rule in RepeatRule.values)
                  ChoiceChip(
                    label: Text(rule.shortName),
                    selected: _repeat == rule,
                    onSelected: (_) => setState(() => _repeat = rule),
                  ),
              ],
            ),
          ),
          if (_repeat == RepeatRule.weekly)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                S.repeatFollowsWeekday,
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (_repeat == RepeatRule.monthly)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                S.repeatFollowsMonthDay,
                style: TextStyle(fontSize: 12),
              ),
            ),
          _sectionTitle(S.advanceReminder),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(DateFmt.advance(_advanceMinutes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAdvancePicker,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_month_outlined),
            title: const Text(S.syncToCalendar),
            subtitle: globalCalendarOn
                ? null
                : const Text(S.calendarGlobalOffHint),
            value: _syncToCalendar,
            onChanged: (v) => setState(() => _syncToCalendar = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text(S.enabledSwitch),
            subtitle: const Text(S.disableNotifHint),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  void _showAdvancePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(S.advanceReminder, style: TextStyle(fontSize: 16)),
            ),
            for (final minutes in _advanceOptions)
              ListTile(
                leading: Icon(
                  _advanceMinutes == minutes
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(DateFmt.advance(minutes)),
                onTap: () {
                  setState(() => _advanceMinutes = minutes);
                  Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: Icon(
                _advanceOptions.contains(_advanceMinutes)
                    ? Icons.radio_button_off
                    : Icons.radio_button_checked,
              ),
              title: const Text(S.advanceCustom),
              subtitle: _advanceOptions.contains(_advanceMinutes)
                  ? null
                  : Text(DateFmt.advance(_advanceMinutes)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickCustomAdvance();
              },
            ),
          ],
        ),
      ),
    );
  }
}
