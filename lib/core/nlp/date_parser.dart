import 'chinese_numbers.dart';

/// 日期提取结果。
class DateExtract {
  const DateExtract({
    this.start,
    this.end,
    this.date,
    this.explicit = false,
    this.weekdayBased = false,
  });

  final int? start;
  final int? end;

  /// 日期（仅年月日，时间由时间解析器补充）。
  final DateTime? date;

  /// 是否明确写出日期（如「9月20日」「明天」）。
  final bool explicit;

  /// 是否由「周X」推导（时间已过需顺延一周）。
  final bool weekdayBased;
}

/// 日期提取（纯 Dart）。
///
/// 支持：X月X日（可无「日/号」）、今天/明天/后天/大后天、
/// 周X/星期X/礼拜X（可带 下/本 前缀）、下周。
/// 未识别返回空 [DateExtract]（容错：UI 预选今天）。
class DateParser {
  DateParser._();

  static const Map<String, int> _weekdayNames = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7,
  };

  static final RegExp _monthDay =
      RegExp('($numberPattern)月($numberPattern)(?:日|号)?');

  static final RegExp _relDay = RegExp(r'大后天|后天|明天|今天');

  static final RegExp _weekday =
      RegExp(r'(下|本)?(?:周|星期|礼拜)([一二三四五六日天1-7])');

  static final RegExp _nextWeek = RegExp(r'下周');

  static DateExtract extract(String text, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    // 1. X月X日
    final md = _monthDay.firstMatch(text);
    if (md != null) {
      final month = parseChineseNumber(md.group(1)!);
      final day = parseChineseNumber(md.group(2)!);
      if (month != null && month >= 1 && month <= 12 && day != null && day >= 1) {
        var date = _clampDay(now.year, month, day);
        // 已过的日期（无年份信息）→ 顺延一年
        if (date.isBefore(today)) {
          date = _clampDay(now.year + 1, month, day);
        }
        return DateExtract(
            start: md.start, end: md.end, date: date, explicit: true);
      }
    }

    // 2. 今天/明天/后天/大后天
    final rel = _relDay.firstMatch(text);
    if (rel != null) {
      final offset = switch (rel.group(0)) {
        '今天' => 0,
        '明天' => 1,
        '后天' => 2,
        _ => 3,
      };
      return DateExtract(
        start: rel.start,
        end: rel.end,
        date: today.add(Duration(days: offset)),
        explicit: true,
      );
    }

    // 3. 周X（下周三/本周五/周三）
    final wd = _weekday.firstMatch(text);
    if (wd != null) {
      final target = _weekdayNames[wd.group(2)!] ?? int.tryParse(wd.group(2)!);
      if (target != null) {
        final plus7 = wd.group(1) == '下';
        var offset = (target - now.weekday) % 7;
        if (offset < 0) offset += 7;
        if (plus7) offset += 7;
        return DateExtract(
          start: wd.start,
          end: wd.end,
          date: today.add(Duration(days: offset)),
          explicit: true,
          weekdayBased: true,
        );
      }
    }

    // 4. 下周（无星期）
    final nw = _nextWeek.firstMatch(text);
    if (nw != null) {
      return DateExtract(
        start: nw.start,
        end: nw.end,
        date: today.add(const Duration(days: 7)),
        explicit: true,
      );
    }

    return const DateExtract();
  }

  static DateTime _clampDay(int year, int month, int day) {
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > maxDay ? maxDay : day);
  }
}
