import 'chinese_numbers.dart';
import 'quantity.dart';

/// 时间提取结果。
class TimeExtract {
  const TimeExtract({
    this.start,
    this.end,
    this.hour,
    this.minute,
    this.absolute,
    this.noPeriod = false,
  });

  final int? start;
  final int? end;

  /// 钟点（已按时段词换算为 24 小时制）。
  final int? hour;
  final int? minute;

  /// 相对时间（N分钟后等）换算后的绝对时间。
  final DateTime? absolute;

  /// 是否无时段词（「3点」无「下午」——用于顺延判断）。
  final bool noPeriod;
}

/// 时间提取（纯 Dart）。
///
/// 支持：
/// - 时段词 + 钟点：下午三点、晚上8点半、九点一刻、十一点零五分、上午10点30分
/// - 无时段词钟点：3点（无日期且已过则按下午顺延 12 小时）
/// - 相对时间：15分钟后、半小时后、2小时后、3天后、一个半小时后
/// 未识别返回空 [TimeExtract]（容错：UI 弹时间选择器）。
class TimeParser {
  TimeParser._();

  static const Map<String, int> _periods = {
    '凌晨': 0,
    '清晨': 0,
    '早上': 0,
    '早晨': 0,
    '上午': 0,
    '中午': 12,
    '下午': 12,
    '傍晚': 12,
    '晚上': 12,
    '夜里': 12,
    '夜间': 12,
  };

  static final RegExp _clock = RegExp(
      '(凌晨|清晨|早上|早晨|上午|中午|下午|傍晚|晚上|夜里|夜间)?'
      '($numberPattern)[点时]'
      '((?:零?$numberPattern)分|半|一刻|三刻|零$numberPattern)?');

  static final RegExp _relative =
      RegExp('($quantityPattern)($durationUnitPattern)后');

  static TimeExtract extract(String text, DateTime now) {
    // 相对时间优先（15分钟后 / 半小时后）
    final rel = _relative.firstMatch(text);
    if (rel != null) {
      final minutes = parseQuantityToMinutes(rel.group(1)!, rel.group(2)!);
      if (minutes != null) {
        return TimeExtract(
          start: rel.start,
          end: rel.end,
          absolute: now.add(Duration(minutes: minutes)),
        );
      }
    }

    final m = _clock.firstMatch(text);
    if (m == null) return const TimeExtract();
    final hourRaw = parseChineseNumber(m.group(2)!);
    if (hourRaw == null || hourRaw > 24) return const TimeExtract();

    var hour = hourRaw;
    var minute = 0;
    final minStr = m.group(3);
    if (minStr != null) {
      if (minStr == '半') {
        minute = 30;
      } else if (minStr == '一刻') {
        minute = 15;
      } else if (minStr == '三刻') {
        minute = 45;
      } else {
        final mm =
            RegExp('零?($numberPattern)分').firstMatch(minStr);
        if (mm != null) {
          minute = parseChineseNumber(mm.group(1)!) ?? 0;
        }
      }
    }

    final period = m.group(1);
    if (period != null) {
      final base = _periods[period]!;
      if (base == 12 && hour < 12) {
        // 下午3点 → 15 点
        hour += 12;
      } else if (base == 12 && hour == 12) {
        // 晚上12点 → 24 点（跨日 0 点）；中午/下午 12 点保持 12 点
        if (period == '晚上' || period == '夜里' || period == '夜间') {
          hour = 24;
        }
      } else if (base == 0 && hour == 12) {
        // 上午12点 → 0 点（罕见，按凌晨处理）
        hour = 0;
      }
    }

    return TimeExtract(
      start: m.start,
      end: m.end,
      hour: hour,
      minute: minute,
      noPeriod: period == null,
    );
  }
}
