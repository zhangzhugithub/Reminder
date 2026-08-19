import 'package:reminder/core/models/repeat_rule.dart';
import 'package:test/test.dart';

void main() {
  group('RepeatMath.nextOccurrence - daily', () {
    final anchor = DateTime(2026, 8, 19, 9, 0);

    test('晚于 after 时返回当天', () {
      final n = RepeatMath.nextOccurrence(
          RepeatRule.daily, anchor, DateTime(2026, 8, 19, 8, 0));
      expect(n, DateTime(2026, 8, 19, 9, 0));
    });

    test('已过当天时间则顺延次日', () {
      final n = RepeatMath.nextOccurrence(
          RepeatRule.daily, anchor, DateTime(2026, 8, 19, 10, 0));
      expect(n, DateTime(2026, 8, 20, 9, 0));
    });

    test('恰好在发生时间不返回该时刻（严格晚于）', () {
      final n = RepeatMath.nextOccurrence(
          RepeatRule.daily, anchor, DateTime(2026, 8, 19, 9, 0));
      expect(n, DateTime(2026, 8, 20, 9, 0));
    });
  });

  group('RepeatMath.nextOccurrence - weekly', () {
    // 2026-08-19 是周三
    final anchor = DateTime(2026, 8, 21, 20, 0); // 周五 20:00

    test('本周五已到之前返回本周五', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.weekly, anchor,
          DateTime(2026, 8, 19, 12, 0),
          weekday: DateTime.friday);
      expect(n, DateTime(2026, 8, 21, 20, 0));
    });

    test('本周五已过则返回下周五', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.weekly, anchor,
          DateTime(2026, 8, 22, 0, 0),
          weekday: DateTime.friday);
      expect(n, DateTime(2026, 8, 28, 20, 0));
    });

    test('下周指定星期几', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.weekly, anchor,
          DateTime(2026, 8, 19, 12, 0),
          weekday: DateTime.monday);
      expect(n, DateTime(2026, 8, 24, 20, 0));
    });
  });

  group('RepeatMath.nextOccurrence - monthly', () {
    final anchor = DateTime(2026, 1, 31, 9, 30);

    test('普通月份返回锚点日', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor,
          DateTime(2026, 2, 1, 0, 0),
          monthDay: 31);
      // 2 月无 31 号 → 钳制到 2 月 28 日
      expect(n, DateTime(2026, 2, 28, 9, 30));
    });

    test('钳制后下一期仍按锚点日计算', () {
      final feb = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor,
          DateTime(2026, 2, 1, 0, 0),
          monthDay: 31);
      final mar = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor, feb,
          monthDay: 31);
      expect(mar, DateTime(2026, 3, 31, 9, 30));
    });

    test('4 月 30 日钳制', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor,
          DateTime(2026, 4, 29, 10, 0),
          monthDay: 31);
      expect(n, DateTime(2026, 4, 30, 9, 30));
    });

    test('跨年', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor,
          DateTime(2026, 12, 31, 10, 0),
          monthDay: 31);
      expect(n, DateTime(2027, 1, 31, 9, 30));
    });

    test('当天晚于锚点时间则顺延到下月', () {
      final n = RepeatMath.nextOccurrence(RepeatRule.monthly, anchor,
          DateTime(2026, 1, 31, 10, 0),
          monthDay: 31);
      expect(n, DateTime(2026, 2, 28, 9, 30));
    });
  });

  group('RepeatMath.nextOccurrence - none', () {
    test('单次任务恒返回 null', () {
      expect(
          RepeatMath.nextOccurrence(
              RepeatRule.none, DateTime(2026, 8, 19), DateTime(2026, 8, 1)),
          isNull);
    });
  });

  group('RepeatMath.nextOccurrences', () {
    test('daily 连续 3 次', () {
      final list = RepeatMath.nextOccurrences(
          RepeatRule.daily, DateTime(2026, 8, 19, 7, 0),
          DateTime(2026, 8, 19, 8, 0), 3);
      expect(list, [
        DateTime(2026, 8, 20, 7, 0),
        DateTime(2026, 8, 21, 7, 0),
        DateTime(2026, 8, 22, 7, 0),
      ]);
    });

    test('weekly 跨月', () {
      final list = RepeatMath.nextOccurrences(
          RepeatRule.weekly, DateTime(2026, 8, 28, 18, 0), // 周五
          DateTime(2026, 8, 28, 19, 0), 2,
          weekday: DateTime.friday);
      expect(list, [
        DateTime(2026, 9, 4, 18, 0),
        DateTime(2026, 9, 11, 18, 0),
      ]);
    });

    test('monthly 31 号连续钳制序列', () {
      final list = RepeatMath.nextOccurrences(
          RepeatRule.monthly, DateTime(2026, 1, 31, 9, 0),
          DateTime(2026, 2, 1, 0, 0), 4,
          monthDay: 31);
      expect(list, [
        DateTime(2026, 2, 28, 9, 0),
        DateTime(2026, 3, 31, 9, 0),
        DateTime(2026, 4, 30, 9, 0),
        DateTime(2026, 5, 31, 9, 0),
      ]);
    });

    test('none 返回空列表', () {
      expect(
          RepeatMath.nextOccurrences(
              RepeatRule.none, DateTime(2026, 8, 19), DateTime(2026, 8, 1), 5),
          isEmpty);
    });
  });

  group('RepeatMath.daysInMonth', () {
    test('闰年 2 月', () {
      expect(RepeatMath.daysInMonth(2028, 2), 29);
    });
    test('平年 2 月', () {
      expect(RepeatMath.daysInMonth(2026, 2), 28);
    });
    test('大月', () {
      expect(RepeatMath.daysInMonth(2026, 7), 31);
    });
  });
}
