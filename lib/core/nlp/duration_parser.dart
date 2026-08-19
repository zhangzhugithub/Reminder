import 'quantity.dart';

/// 时长提取结果。
class DurationExtract {
  const DurationExtract({this.start, this.end, this.minutes});

  final int? start;
  final int? end;

  /// 时长（分钟）。
  final int? minutes;
}

/// 任务时长提取（纯 Dart）。
///
/// 支持：持续1小时、持续半小时、耗时两个钟头、要花45分钟。
/// 未识别返回空 [DurationExtract]（结束时间选填，缺失不报错）。
class DurationParser {
  DurationParser._();

  static final RegExp _pattern = RegExp(
      '(?:持续|耗时|时长|要花)(?:约)?($quantityPattern)($durationUnitPattern)');

  static DurationExtract extract(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) return const DurationExtract();
    final minutes = parseQuantityToMinutes(m.group(1)!, m.group(2)!);
    if (minutes == null) return const DurationExtract();
    return DurationExtract(start: m.start, end: m.end, minutes: minutes);
  }
}
