import '../models/repeat_rule.dart';

/// 自然语言解析结果（纯 Dart）。
///
/// 各字段为可空：未识别到的字段保持 null，由 UI 层按容错策略处理
/// （时间缺失弹时间选择器、重复缺失默认单次、提前量缺失默认 10 分钟）。
class ParsedTask {
  ParsedTask({
    this.title = '',
    this.start,
    this.end,
    this.repeat,
    this.repeatWeekday,
    this.repeatMonthDay,
    this.advanceMinutes,
    this.note = '',
    this.hasDate = false,
    this.hasTime = false,
    this.hasEnd = false,
    this.hasRepeat = false,
    this.hasAdvance = false,
  });

  /// 任务标题（去除时间/重复等已识别片段后的剩余文本）。
  String title;

  /// 开始时间（含日期；时间缺失时以 9:00 占位并置 [hasTime] = false）。
  DateTime? start;

  /// 结束时间（由时长推导）。
  DateTime? end;

  RepeatRule? repeat;
  int? repeatWeekday;
  int? repeatMonthDay;
  int? advanceMinutes;
  String note;

  /// 置信标志：各维度是否被明确识别。
  bool hasDate;
  bool hasTime;
  bool hasEnd;
  bool hasRepeat;
  bool hasAdvance;
}
