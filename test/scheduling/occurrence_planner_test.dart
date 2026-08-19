import 'package:reminder/core/models/repeat_rule.dart';
import 'package:reminder/core/models/task.dart';
import 'package:reminder/core/scheduling/occurrence_planner.dart';
import 'package:test/test.dart';

Task _task({
  required String id,
  required DateTime start,
  RepeatRule repeat = RepeatRule.none,
  int advanceMinutes = 10,
  int repeatWeekday = 1,
  int repeatMonthDay = 1,
  bool enabled = true,
}) =>
    Task(
      id: id,
      title: '测试',
      start: start,
      repeat: repeat,
      advanceMinutes: advanceMinutes,
      repeatWeekday: repeatWeekday,
      repeatMonthDay: repeatMonthDay,
      enabled: enabled,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 8, 19, 12, 0);

  group('OccurrencePlanner - 单次任务', () {
    test('未来开始：提醒 = 开始 - 提前量', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 20, 15, 0), advanceMinutes: 30);
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 10, expiredTaskNotify: false),
        [DateTime(2026, 8, 20, 14, 30)],
      );
    });

    test('提前量 0：准时提醒', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 20, 15, 0), advanceMinutes: 0);
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 10, expiredTaskNotify: false),
        [DateTime(2026, 8, 20, 15, 0)],
      );
    });

    test('提醒时间已过但任务未开始：立即提醒', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 19, 12, 5), advanceMinutes: 30);
      final times = OccurrencePlanner.remindTimesFor(task, now,
          maxSlots: 10, expiredTaskNotify: false);
      expect(times, hasLength(1));
      expect(times.single.difference(now).inSeconds, lessThan(10));
    });

    test('任务已开始且未开启过期提醒：不排', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 19, 8, 0), advanceMinutes: 30);
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 10, expiredTaskNotify: false),
        isEmpty,
      );
    });

    test('任务已开始且开启过期提醒：立即提醒一次', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 19, 8, 0), advanceMinutes: 30);
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 10, expiredTaskNotify: true),
        hasLength(1),
      );
    });
  });

  group('OccurrencePlanner - 循环任务', () {
    test('每天：预排未来 3 次（跨日）', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 19, 9, 0), repeat: RepeatRule.daily);
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 3, expiredTaskNotify: false),
        [
          DateTime(2026, 8, 20, 8, 50),
          DateTime(2026, 8, 21, 8, 50),
          DateTime(2026, 8, 22, 8, 50),
        ],
      );
    });

    test('每周五：8-19（周三）之后的周五为 8-21', () {
      final task = _task(
        id: '1',
        start: DateTime(2026, 8, 21, 20, 0), // 周五
        repeat: RepeatRule.weekly,
        repeatWeekday: DateTime.friday,
      );
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 2, expiredTaskNotify: false),
        [
          DateTime(2026, 8, 21, 19, 50),
          DateTime(2026, 8, 28, 19, 50),
        ],
      );
    });

    test('每月 31 号：钳制 + 锚点恢复', () {
      final task = _task(
        id: '1',
        start: DateTime(2026, 1, 31, 9, 0),
        repeat: RepeatRule.monthly,
        repeatMonthDay: 31,
      );
      // now 为 8 月：下期 8-31，再下期 9-30（9 月无 31）
      expect(
        OccurrencePlanner.remindTimesFor(task, now,
            maxSlots: 3, expiredTaskNotify: false),
        [
          DateTime(2026, 8, 31, 8, 50),
          DateTime(2026, 9, 30, 8, 50),
          DateTime(2026, 10, 31, 8, 50),
        ],
      );
    });

    test('本次提醒时间已过：立即提醒补当前周期', () {
      final task = _task(
          id: '1', start: DateTime(2026, 8, 19, 9, 0), repeat: RepeatRule.daily);
      // now 12:00，今天 9:00 已过；下期明天 8:50 正常
      final times = OccurrencePlanner.remindTimesFor(task, now,
          maxSlots: 2, expiredTaskNotify: false);
      expect(times, hasLength(2));
      expect(times[0].difference(now).inSeconds, lessThan(10));
      expect(times[1], DateTime(2026, 8, 20, 8, 50));
    });
  });

  group('OccurrencePlanner.nextRemindAt', () {
    test('禁用任务返回 null', () {
      final task = _task(
        id: '1',
        start: DateTime(2026, 8, 20, 9, 0),
        enabled: false,
      );
      expect(OccurrencePlanner.nextRemindAt(task, now), isNull);
    });

    test('已过期单次任务返回 null', () {
      final task = _task(id: '1', start: DateTime(2026, 8, 19, 8, 0));
      expect(OccurrencePlanner.nextRemindAt(task, now), isNull);
    });

    test('未来任务返回提醒时间', () {
      final task = _task(id: '1', start: DateTime(2026, 8, 20, 9, 0));
      expect(OccurrencePlanner.nextRemindAt(task, now),
          DateTime(2026, 8, 20, 8, 50));
    });
  });
}
