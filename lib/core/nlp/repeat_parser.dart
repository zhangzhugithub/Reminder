import '../models/repeat_rule.dart';
import 'chinese_numbers.dart';

/// 重复规则提取结果。
class RepeatExtract {
  const RepeatExtract({this.start, this.end, this.rule, this.weekday, this.monthDay});

  /// 匹配片段在原文中的起止位置（用于剥离）。
  final int? start;
  final int? end;
  final RepeatRule? rule;

  /// 每周X 的星期几（1=周一 … 7=周日）。
  final int? weekday;

  /// 每月X号 的日期（1-31）。
  final int? monthDay;
}

/// 重复规则提取（纯 Dart）。
///
/// 支持：每天|每日|每晚|每早、每周X|每星期X|每周、每月N号|每月、一次性|单次。
/// 未识别返回空 [RepeatExtract]（容错：默认单次任务）。
class RepeatParser {
  RepeatParser._();

  static const Map<String, int> _weekdayNames = {
    '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7,
  };

  /// 匹配顺序即优先级（每周X 先于 每周；每月N号 先于 每月）。
  static final List<RegExp> _patterns = [
    RegExp(r'每(?:周|星期|礼拜)([一二三四五六日天1-7])'),
    RegExp(r'每月(' + numberPattern + r')(?:号|日)'),
    RegExp(r'每(?:晚|早|晨|天|日)'),
    RegExp(r'每月'),
    RegExp(r'每(?:周|星期|礼拜)'),
    RegExp(r'一次性|单次'),
  ];

  static RepeatExtract extract(String text) {
    for (var i = 0; i < _patterns.length; i++) {
      final m = _patterns[i].firstMatch(text);
      if (m == null) continue;
      switch (i) {
        case 0: // 每周X
          final wd = m.group(1)!;
          return RepeatExtract(
            start: m.start,
            end: m.end,
            rule: RepeatRule.weekly,
            weekday: _weekdayNames[wd] ?? int.tryParse(wd),
          );
        case 1: // 每月N号
          final day = parseChineseNumber(m.group(1)!);
          if (day == null || day < 1 || day > 31) continue;
          return RepeatExtract(
            start: m.start,
            end: m.end,
            rule: RepeatRule.monthly,
            monthDay: day,
          );
        case 2: // 每天/每晚/每早
          return RepeatExtract(
              start: m.start, end: m.end, rule: RepeatRule.daily);
        case 3: // 每月
          return RepeatExtract(
              start: m.start, end: m.end, rule: RepeatRule.monthly);
        case 4: // 每周
          return RepeatExtract(
              start: m.start, end: m.end, rule: RepeatRule.weekly);
        case 5: // 一次性/单次
          return RepeatExtract(
              start: m.start, end: m.end, rule: RepeatRule.none);
      }
    }
    return const RepeatExtract();
  }
}
