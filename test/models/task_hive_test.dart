import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:reminder/core/models/repeat_rule.dart';
import 'package:reminder/core/models/settings.dart';
import 'package:reminder/core/models/task.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reminder_hive_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(ReminderSettingsAdapter());
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Task Hive 往返：全字段无损', () async {
    final box = await Hive.openBox<Task>('tasks');
    final original = Task(
      id: 'task-1',
      title: '开会',
      note: '项目周会',
      start: DateTime(2026, 8, 20, 15, 0),
      end: DateTime(2026, 8, 20, 16, 0),
      repeat: RepeatRule.weekly,
      repeatWeekday: DateTime.friday,
      repeatMonthDay: 20,
      advanceMinutes: 30,
      enabled: false,
      syncToCalendar: true,
      calendarEventId: 'evt-123',
      calendarSyncError: true,
      createdAt: DateTime(2026, 8, 1, 10, 0),
      modifiedAt: DateTime(2026, 8, 2, 11, 30),
      scheduledNotificationIds: [100, 101],
      notifBlockId: 1,
    );
    await box.put(original.id, original);

    final loaded = box.get('task-1')!;
    expect(loaded.id, original.id);
    expect(loaded.title, original.title);
    expect(loaded.note, original.note);
    expect(loaded.start, original.start);
    expect(loaded.end, original.end);
    expect(loaded.repeat, RepeatRule.weekly);
    expect(loaded.repeatWeekday, DateTime.friday);
    expect(loaded.repeatMonthDay, 20);
    expect(loaded.advanceMinutes, 30);
    expect(loaded.enabled, false);
    expect(loaded.syncToCalendar, true);
    expect(loaded.calendarEventId, 'evt-123');
    expect(loaded.calendarSyncError, true);
    expect(loaded.createdAt, original.createdAt);
    expect(loaded.modifiedAt, original.modifiedAt);
    expect(loaded.scheduledNotificationIds, [100, 101]);
    expect(loaded.notifBlockId, 1);
  });

  test('Task JSON 往返（备份格式）', () {
    final original = Task(
      id: 'task-json',
      title: '体检',
      note: '空腹',
      start: DateTime(2026, 9, 20, 9, 0),
      end: null,
      repeat: RepeatRule.none,
      advanceMinutes: 60,
      enabled: true,
      syncToCalendar: false,
      createdAt: DateTime(2026, 8, 19),
      modifiedAt: DateTime(2026, 8, 19),
    );
    final restored = Task.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.start, original.start);
    expect(restored.end, isNull);
    expect(restored.repeat, RepeatRule.none);
    expect(restored.advanceMinutes, 60);
    expect(restored.syncToCalendar, false);
    // 备份恢复后本地绑定重置
    expect(restored.calendarEventId, isNull);
    expect(restored.scheduledNotificationIds, isEmpty);
    expect(restored.notifBlockId, 0);
  });

  test('Task JSON 往返：枚举越界容错', () {
    final json = Task(
      id: 't',
      title: 'x',
      start: DateTime(2026, 8, 19),
      createdAt: DateTime(2026, 8, 19),
      modifiedAt: DateTime(2026, 8, 19),
    ).toJson();
    json['repeat'] = 99;
    expect(Task.fromJson(json).repeat, RepeatRule.none);
  });

  test('ReminderSettings Hive 往返', () async {
    final box = await Hive.openBox<ReminderSettings>('settings');
    final original = ReminderSettings(
      themeModeIndex: 2,
      defaultAdvanceMinutes: 15,
      calendarSyncEnabled: false,
      calendarId: 'cal-9',
      calendarName: '离线语音提醒',
      notificationSound: false,
      notificationVibrate: false,
      asrSilenceSeconds: 6,
      asrMaxRecordSeconds: 30,
      exactAlarmPromptShown: true,
      deleteCalendarDefault: false,
      voiceAutoEdit: false,
      expiredTaskNotify: true,
      sortByStartAsc: false,
    );
    await box.put('default', original);
    final loaded = box.get('default')!;
    expect(loaded.themeModeIndex, 2);
    expect(loaded.defaultAdvanceMinutes, 15);
    expect(loaded.calendarSyncEnabled, false);
    expect(loaded.calendarId, 'cal-9');
    expect(loaded.calendarName, '离线语音提醒');
    expect(loaded.notificationSound, false);
    expect(loaded.notificationVibrate, false);
    expect(loaded.asrSilenceSeconds, 6);
    expect(loaded.asrMaxRecordSeconds, 30);
    expect(loaded.exactAlarmPromptShown, true);
    expect(loaded.deleteCalendarDefault, false);
    expect(loaded.voiceAutoEdit, false);
    expect(loaded.expiredTaskNotify, true);
    expect(loaded.sortByStartAsc, false);
  });

  test('Task 计算属性：过期判定与下一次发生', () {
    final now = DateTime(2026, 8, 19, 12, 0);
    final singlePast = Task(
      id: 'a',
      title: '已过期',
      start: DateTime(2026, 8, 19, 8, 0),
      createdAt: now,
      modifiedAt: now,
    );
    expect(singlePast.isExpiredAt(now), true);

    final recurring = Task(
      id: 'b',
      title: '每日',
      start: DateTime(2026, 8, 19, 8, 0),
      repeat: RepeatRule.daily,
      createdAt: now,
      modifiedAt: now,
    );
    expect(recurring.isExpiredAt(now), false);
    expect(recurring.nextOccurrenceAfter(now), DateTime(2026, 8, 20, 8, 0));
    expect(recurring.nextRemindAt(now), DateTime(2026, 8, 20, 7, 50));
  });
}
