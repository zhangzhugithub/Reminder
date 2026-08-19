import '../models/repeat_rule.dart';
import 'advance_parser.dart';
import 'date_parser.dart';
import 'duration_parser.dart';
import 'parsed_task.dart';
import 'repeat_parser.dart';
import 'time_parser.dart';

/// 离线自然语言解析器（纯 Dart 规则引擎，无任何云端依赖）。
///
/// 管线（各阶段剥离已识别片段后继续）：
/// 备注 → 重复 → 提前提醒 → 时长 → 日期 → 时间 → 组装开始时间 → 剩余为标题。
///
/// 容错策略（与需求 1.3 一致）：
/// - 时间缺失：start 以 9:00 占位并置 hasTime=false（UI 弹时间选择器）；
/// - 重复缺失：默认单次（UI 处理）；
/// - 提前量缺失：UI 使用默认 10 分钟。
ParsedTask parseNaturalLanguage(String input, {required DateTime now}) {
  var text = _normalize(input);
  final result = ParsedTask();

  // 1. 备注
  final noteM = RegExp(r'备注[:：](.*)$').firstMatch(text);
  if (noteM != null) {
    result.note = noteM.group(1)!.trim();
    text = _cut(text, noteM.start, noteM.end);
  }

  // 2. 重复规则
  final rep = RepeatParser.extract(text);
  if (rep.rule != null && rep.start != null) {
    result.repeat = rep.rule;
    result.repeatWeekday = rep.weekday;
    result.repeatMonthDay = rep.monthDay;
    result.hasRepeat = true;
    text = _cut(text, rep.start!, rep.end!);
  }

  // 3. 提前提醒
  final adv = AdvanceParser.extract(text);
  if (adv.minutes != null && adv.start != null) {
    result.advanceMinutes = adv.minutes;
    result.hasAdvance = true;
    text = _cut(text, adv.start!, adv.end!);
  }

  // 4. 时长
  final dur = DurationParser.extract(text);
  if (dur.minutes != null && dur.start != null) {
    result.hasEnd = true;
    text = _cut(text, dur.start!, dur.end!);
  }

  // 5. 日期
  final date = DateParser.extract(text, now);
  if (date.start != null) {
    result.hasDate = true;
    text = _cut(text, date.start!, date.end!);
  }

  // 6. 时间
  final time = TimeParser.extract(text, now);
  if (time.start != null) {
    text = _cut(text, time.start!, time.end!);
  }

  // 7. 组装开始时间
  _assembleStart(result, date, time, dur, now);

  // 8. 剩余文本 = 标题
  result.title = _cleanTitle(text);
  return result;
}

// ---- 组装 ----

void _assembleStart(ParsedTask r, DateExtract date, TimeExtract time,
    DurationExtract dur, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  if (time.absolute != null) {
    // 相对时间（N分钟后）：绝对化结果
    r.start = time.absolute;
    r.hasDate = true;
    r.hasTime = true;
  } else if (date.date != null) {
    final h = time.hour ?? 9;
    final m = time.minute ?? 0;
    var start =
        DateTime(date.date!.year, date.date!.month, date.date!.day, h, m);
    r.hasTime = time.hour != null;
    // 周X 推导且时间已过 → 顺延一周（「周三」默认指即将到来的周三）
    if (date.weekdayBased && !start.isAfter(now)) {
      start = start.add(const Duration(days: 7));
    }
    r.start = start;
  } else if (time.hour != null) {
    // 只有时间、无日期
    if (r.hasRepeat && r.repeat == RepeatRule.weekly && r.repeatWeekday != null) {
      var offset = (r.repeatWeekday! - now.weekday) % 7;
      if (offset < 0) offset += 7;
      var start = DateTime(today.year, today.month, today.day + offset,
          time.hour!, time.minute ?? 0);
      if (!start.isAfter(now)) start = start.add(const Duration(days: 7));
      r.start = start;
      r.hasDate = true;
      r.hasTime = true;
    } else if (r.hasRepeat &&
        r.repeat == RepeatRule.monthly &&
        r.repeatMonthDay != null) {
      var start = _clampToDay(
          now.year, now.month, r.repeatMonthDay!, time.hour!, time.minute ?? 0);
      if (!start.isAfter(now)) {
        var y = now.year;
        var mo = now.month + 1;
        if (mo > 12) {
          mo = 1;
          y++;
        }
        start = _clampToDay(
            y, mo, r.repeatMonthDay!, time.hour!, time.minute ?? 0);
      }
      r.start = start;
      r.hasDate = true;
      r.hasTime = true;
    } else if (r.hasRepeat && r.repeat == RepeatRule.daily) {
      // 每天：锚点可为过去（循环任务按锚点顺延）
      r.start = DateTime(
          today.year, today.month, today.day, time.hour!, time.minute ?? 0);
      r.hasDate = true;
      r.hasTime = true;
    } else {
      var start = DateTime(
          now.year, now.month, now.day, time.hour!, time.minute ?? 0);
      // 无时段词且已过 → 视为下午（「3点」在上午说指下午 3 点）
      if (time.noPeriod && !start.isAfter(now)) {
        start = start.add(const Duration(hours: 12));
      }
      if (!start.isAfter(now)) start = start.add(const Duration(days: 1));
      r.start = start;
      r.hasTime = true;
    }
  } else if (r.hasRepeat) {
    // 有重复规则、无日期时间 → 从重复规则推导锚点（9:00 占位）
    if (r.repeat == RepeatRule.weekly && r.repeatWeekday != null) {
      var offset = (r.repeatWeekday! - now.weekday) % 7;
      if (offset < 0) offset += 7;
      var start = today.add(Duration(days: offset));
      if (!start.isAfter(now)) start = start.add(const Duration(days: 7));
      r.start = DateTime(start.year, start.month, start.day, 9, 0);
      r.hasDate = true;
    } else if (r.repeat == RepeatRule.monthly && r.repeatMonthDay != null) {
      var start = _clampToDay(now.year, now.month, r.repeatMonthDay!, 9, 0);
      if (!start.isAfter(now)) {
        var y = now.year;
        var mo = now.month + 1;
        if (mo > 12) {
          mo = 1;
          y++;
        }
        start = _clampToDay(y, mo, r.repeatMonthDay!, 9, 0);
      }
      r.start = start;
      r.hasDate = true;
    } else {
      r.start = DateTime(today.year, today.month, today.day, 9, 0);
      r.hasDate = true;
    }
  }
  // else: start 保持 null → UI 进入全手动填写

  // 时长 → 结束时间
  if (dur.minutes != null && r.start != null) {
    r.end = r.start!.add(Duration(minutes: dur.minutes!));
  }
}

DateTime _clampToDay(int year, int month, int day, int hour, int minute) {
  final maxDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > maxDay ? maxDay : day, hour, minute);
}

// ---- 工具 ----

String _cut(String s, int start, int end) =>
    s.substring(0, start) + s.substring(end);

/// 预处理：去空白、全角转半角、早晚组合词展开。
String _normalize(String s) {
  s = s.replaceAll(RegExp(r'\s+'), '');
  const fullwidth = {
    '０': '0', '１': '1', '２': '2', '３': '3', '４': '4',
    '５': '5', '６': '6', '７': '7', '８': '8', '９': '9',
    '：': ':', '．': '.',
  };
  fullwidth.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll('明早', '明天早上');
  s = s.replaceAll('明晨', '明天早上');
  s = s.replaceAll('明晚', '明天晚上');
  s = s.replaceAll('今早', '今天早上');
  s = s.replaceAll('今晨', '今天早上');
  s = s.replaceAll('今晚', '今天晚上');
  // 每晚/每早 展开后，重复解析剥离「每天」时保留时段词（晚上/早上）
  s = s.replaceAll('每晚', '每天晚上');
  s = s.replaceAll('每早', '每天早上');
  s = s.replaceAll('每晨', '每天早上');
  return s;
}

/// 标题清理：去标点、去连接词前缀、去语气词后缀。
String _cleanTitle(String s) {
  s = s.replaceAll(RegExp(r'[，。！？!?；;、,]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.trim();
  s = s.replaceFirst(
      RegExp(r'^(?:提醒我|提醒|记得|请|帮我|麻烦|给我|要|去|给|该)'), '');
  s = s.replaceFirst(RegExp(r'(?:提醒|一下|吧|哦|啊|哈|呢|了|呀|啦)$'), '');
  return s.trim();
}
