import '../models/repeat_rule.dart';
import '../models/task.dart';

/// 中文日期/时间格式化（硬编码实现，不依赖 intl）。
class DateFmt {
  DateFmt._();

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _months = [
    '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月',
  ];

  /// HH:mm（补零）。
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// M月d日。
  static String monthDay(DateTime d) => '${d.month}月${d.day}日';

  /// yyyy年M月d日。
  static String fullDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  /// 星期几（周X）。
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// 相对日期：今天/明天/后天，否则 M月d日（跨年时含年份）+ 周X。
  static String date(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(n.year, n.month, n.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == 2) return '后天';
    final base = d.year == n.year ? monthDay(d) : fullDate(d);
    return '$base ${weekday(d)}';
  }

  /// 日期 + 时间（如「明天 14:30」）。
  static String dateTime(DateTime d, {DateTime? now}) =>
      '${date(d, now: now)} ${time(d)}';

  /// 时间段（如「14:30 - 15:30」，无结束时间时只显示开始）。
  static String timeRange(DateTime start, DateTime? end) {
    if (end == null) return time(start);
    return '${time(start)} - ${time(end)}';
  }

  /// 提前提醒展示（如「提前 10 分钟」；0 = 准时提醒）。
  static String advance(int minutes) {
    if (minutes <= 0) return '准时提醒';
    if (minutes % 60 == 0) return '提前 ${minutes ~/ 60} 小时';
    return '提前 $minutes 分钟';
  }

  /// 重复规则完整描述（如「每周五 20:00」「每月31号 09:00」）。
  static String repeatLabel(Task t) {
    switch (t.repeat) {
      case RepeatRule.none:
        return '单次';
      case RepeatRule.daily:
        return '每天 ${time(t.start)}';
      case RepeatRule.weekly:
        return '每${weekday(t.start)} ${time(t.start)}';
      case RepeatRule.monthly:
        return '每月${t.repeatMonthDay}号 ${time(t.start)}';
    }
  }
}
