import 'chinese_numbers.dart';

/// 解析「数量 + 单位」为分钟数（纯 Dart）。
///
/// 例：半小时→30、一个半小时→90、2小时→120、三个钟头→180、3天→4320。
/// 解析失败返回 null。
int? parseQuantityToMinutes(String numberStr, String unitStr) {
  final int? unitMinutes;
  switch (unitStr) {
    case '分钟':
    case '分':
      unitMinutes = 1;
    case '小时':
    case '钟头':
    case '个小时':
    case '个钟头':
      unitMinutes = 60;
    case '天':
      unitMinutes = 1440;
    default:
      unitMinutes = null;
  }
  if (unitMinutes == null) return null;

  final double amount;
  if (numberStr == '半') {
    amount = 0.5;
  } else if (numberStr.endsWith('个半')) {
    final n =
        parseChineseNumber(numberStr.substring(0, numberStr.length - 2));
    if (n == null) return null;
    amount = n + 0.5;
  } else {
    final n = parseChineseNumber(numberStr);
    if (n == null) return null;
    amount = n.toDouble();
  }
  return (amount * unitMinutes).round();
}

/// 数量模式片段：`N个半 | N | 半`（N 为中文或阿拉伯数字）。
const String quantityPattern =
    '(?:' + numberPattern + r'个半|' + numberPattern + r'|半)';

/// 时长单位模式片段。
const String durationUnitPattern = '(?:分钟|小时|钟头|天|分|个钟头|个小时)';
