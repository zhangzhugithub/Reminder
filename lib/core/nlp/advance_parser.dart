import 'quantity.dart';

/// 提前提醒提取结果。
class AdvanceExtract {
  const AdvanceExtract({this.start, this.end, this.minutes});

  final int? start;
  final int? end;

  /// 提前分钟数。
  final int? minutes;
}

/// 提前提醒时长提取（纯 Dart）。
///
/// 支持：提前15分钟、提前半小时、提前一个小时、提前2天、提前一个半小时。
/// 未识别返回空 [AdvanceExtract]（容错：默认提前 10 分钟）。
class AdvanceParser {
  AdvanceParser._();

  static final RegExp _pattern =
      RegExp('提前(?:约)?($quantityPattern)($durationUnitPattern)');

  static AdvanceExtract extract(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) return const AdvanceExtract();
    final minutes = parseQuantityToMinutes(m.group(1)!, m.group(2)!);
    if (minutes == null) return const AdvanceExtract();
    return AdvanceExtract(start: m.start, end: m.end, minutes: minutes);
  }
}
