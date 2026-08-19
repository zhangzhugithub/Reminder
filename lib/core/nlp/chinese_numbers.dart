/// 中文数字解析（纯 Dart，无 Flutter 依赖）。
///
/// 支持：阿拉伯数字、中文数字（零~九百九十九、两、十/百 位组合），
/// 如：三 → 3、十五 → 15、二十三 → 23、一百零五 → 105。
/// 无法解析时返回 null。
library;

const Map<String, int> _digits = {
  '零': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

int? parseChineseNumber(String s) {
  s = s.trim();
  if (s.isEmpty) return null;
  final pure = int.tryParse(s);
  if (pure != null) return pure;
  if (!RegExp(r'^[零一二两三四五六七八九十百]+$').hasMatch(s)) return null;

  var total = 0;
  var current = 0;
  for (final ch in s.split('')) {
    if (ch == '十') {
      total += (current == 0 ? 1 : current) * 10;
      current = 0;
    } else if (ch == '百') {
      total += (current == 0 ? 1 : current) * 100;
      current = 0;
    } else {
      current = _digits[ch]!;
    }
  }
  return total + current;
}

/// 中文/阿拉伯混合数字模式片段（供各解析器拼接正则使用）。
const String numberPattern =
    r'(?:[0-9]+|[零一二两三四五六七八九十百]+)';
