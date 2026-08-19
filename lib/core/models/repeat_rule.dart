import 'dart:math' as math;

/// 任务重复规则。
///
/// 纯 Dart 模块：不依赖 Flutter，可独立单元测试。
enum RepeatRule { none, daily, weekly, monthly }

/// 重复规则的数学计算：下一次/未来 N 次发生时间。
///
/// 约定：
/// - 所有发生时间保留锚点（任务开始时间）的时分；
/// - 每周：按锚点所在星期几循环；
/// - 每月：按锚点日期循环，目标月份天数不足时钳制到月末
///   （例如 31 号任务在 4 月钳制为 4 月 30 日，下一期仍按 31 号计算）。
class RepeatMath {
  RepeatMath._();

  /// 返回严格晚于 [after] 的下一次发生时间；单次任务返回 null。
  static DateTime? nextOccurrence(
    RepeatRule rule,
    DateTime anchor,
    DateTime after, {
    int weekday = 1,
    int monthDay = 1,
  }) {
    final hour = anchor.hour;
    final minute = anchor.minute;
    switch (rule) {
      case RepeatRule.none:
        return null;
      case RepeatRule.daily:
        var d = DateTime(after.year, after.month, after.day, hour, minute);
        if (!d.isAfter(after)) {
          d = d.add(const Duration(days: 1));
        }
        return d;
      case RepeatRule.weekly:
        var d = DateTime(after.year, after.month, after.day, hour, minute);
        while (d.weekday != weekday || !d.isAfter(after)) {
          d = d.add(const Duration(days: 1));
        }
        return d;
      case RepeatRule.monthly:
        var y = after.year;
        var m = after.month;
        var day = _clampDay(monthDay, y, m);
        var d = DateTime(y, m, day, hour, minute);
        if (!d.isAfter(after)) {
          m += 1;
          if (m > 12) {
            m = 1;
            y += 1;
          }
          day = _clampDay(monthDay, y, m);
          d = DateTime(y, m, day, hour, minute);
        }
        return d;
    }
  }

  /// 未来 [count] 次发生时间（升序）。
  static List<DateTime> nextOccurrences(
    RepeatRule rule,
    DateTime anchor,
    DateTime after,
    int count, {
    int weekday = 1,
    int monthDay = 1,
  }) {
    if (rule == RepeatRule.none || count <= 0) return const [];
    final result = <DateTime>[];
    var cursor = after;
    for (var i = 0; i < count; i++) {
      final n = nextOccurrence(rule, anchor, cursor,
          weekday: weekday, monthDay: monthDay);
      if (n == null) break;
      result.add(n);
      cursor = n;
    }
    return result;
  }

  /// 将目标日钳制到所在月份的最后一天。
  static int _clampDay(int day, int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return math.min(day, daysInMonth);
  }

  /// 目标月份天数（供 UI 展示钳制说明）。
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
