import 'package:reminder/core/models/repeat_rule.dart';
import 'package:reminder/core/nlp/chinese_numbers.dart';
import 'package:reminder/core/nlp/parser.dart';
import 'package:test/test.dart';

void main() {
  // 统一基准时间：2026-08-19 周三 12:00
  final now = DateTime(2026, 8, 19, 12, 0);

  group('需求示例指令', () {
    test('「明天下午三点开会，提醒提前15分钟」', () {
      final r = parseNaturalLanguage('明天下午三点开会，提醒提前15分钟', now: now);
      expect(r.title, '开会');
      expect(r.start, DateTime(2026, 8, 20, 15, 0));
      expect(r.advanceMinutes, 15);
      expect(r.hasAdvance, true);
      expect(r.hasDate, true);
      expect(r.hasTime, true);
      expect(r.repeat, isNull);
      expect(r.end, isNull);
    });

    test('「每周五晚上8点健身，持续1小时」', () {
      final r = parseNaturalLanguage('每周五晚上8点健身，持续1小时', now: now);
      expect(r.title, '健身');
      expect(r.repeat, RepeatRule.weekly);
      expect(r.repeatWeekday, DateTime.friday);
      // 2026-08-19 周三 → 本周五 8-21
      expect(r.start, DateTime(2026, 8, 21, 20, 0));
      expect(r.end, DateTime(2026, 8, 21, 21, 0));
      expect(r.hasEnd, true);
    });

    test('「9月20日上午9点体检，一次性提醒」', () {
      final r = parseNaturalLanguage('9月20日上午9点体检，一次性提醒', now: now);
      expect(r.title, '体检');
      expect(r.start, DateTime(2026, 9, 20, 9, 0));
      expect(r.repeat, RepeatRule.none);
      expect(r.hasRepeat, true);
    });
  });

  group('日期解析', () {
    test('今天', () {
      final r = parseNaturalLanguage('今天下午3点开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 15, 0));
    });
    test('明天（无时间 → 9:00 占位，hasTime=false）', () {
      final r = parseNaturalLanguage('明天交房租', now: now);
      expect(r.start, DateTime(2026, 8, 20, 9, 0));
      expect(r.hasDate, true);
      expect(r.hasTime, false);
    });
    test('后天', () {
      final r = parseNaturalLanguage('后天上午10点体检', now: now);
      expect(r.start, DateTime(2026, 8, 21, 10, 0));
    });
    test('大后天', () {
      final r = parseNaturalLanguage('大后天晚上7点聚餐', now: now);
      expect(r.start, DateTime(2026, 8, 22, 19, 0));
    });
    test('周三（未来，本周）', () {
      final r = parseNaturalLanguage('周五晚上8点健身', now: now);
      expect(r.start, DateTime(2026, 8, 21, 20, 0));
    });
    test('周三（当天已过 → 顺延一周）', () {
      final r = parseNaturalLanguage('周三上午8点开会', now: now);
      // 本周三 8:00 已过（now 12:00）→ 下周三
      expect(r.start, DateTime(2026, 8, 26, 8, 0));
    });
    test('下周三', () {
      final r = parseNaturalLanguage('下周三上午8点开会', now: now);
      expect(r.start, DateTime(2026, 8, 26, 8, 0));
    });
    test('星期三（全称）', () {
      final r = parseNaturalLanguage('星期五下午2点复查', now: now);
      expect(r.start, DateTime(2026, 8, 21, 14, 0));
    });
    test('X月X日（未来）', () {
      final r = parseNaturalLanguage('12月1日上午10点年会', now: now);
      expect(r.start, DateTime(2026, 12, 1, 10, 0));
    });
    test('X月X日（今年已过 → 明年）', () {
      final r = parseNaturalLanguage('3月5日下午2点纪念日', now: now);
      expect(r.start, DateTime(2027, 3, 5, 14, 0));
    });
    test('中文数字日期', () {
      final r = parseNaturalLanguage('九月二十号上午九点体检', now: now);
      expect(r.start, DateTime(2026, 9, 20, 9, 0));
    });
    test('X月X日无日字', () {
      final r = parseNaturalLanguage('10月8号下午5点接机', now: now);
      expect(r.start, DateTime(2026, 10, 8, 17, 0));
    });
    test('下周（无星期）', () {
      final r = parseNaturalLanguage('下周出差', now: now);
      expect(r.start, DateTime(2026, 8, 26, 9, 0));
    });
  });

  group('时间解析', () {
    test('上午/下午/晚上时段换算', () {
      expect(parseNaturalLanguage('明天上午10点开会', now: now).start,
          DateTime(2026, 8, 20, 10, 0));
      expect(parseNaturalLanguage('明天下午2点开会', now: now).start,
          DateTime(2026, 8, 20, 14, 0));
      expect(parseNaturalLanguage('明天晚上8点开会', now: now).start,
          DateTime(2026, 8, 20, 20, 0));
    });
    test('中午12点', () {
      final r = parseNaturalLanguage('明天中午12点午饭', now: now);
      expect(r.start, DateTime(2026, 8, 20, 12, 0));
    });
    test('晚上12点 → 次日0点', () {
      final r = parseNaturalLanguage('明天晚上12点跨年', now: now);
      expect(r.start, DateTime(2026, 8, 21, 0, 0));
    });
    test('半点', () {
      final r = parseNaturalLanguage('明天下午三点半开会', now: now);
      expect(r.start, DateTime(2026, 8, 20, 15, 30));
    });
    test('一刻/三刻', () {
      expect(parseNaturalLanguage('明天下午三点一刻开会', now: now).start,
          DateTime(2026, 8, 20, 15, 15));
      expect(parseNaturalLanguage('明天下午三点三刻开会', now: now).start,
          DateTime(2026, 8, 20, 15, 45));
    });
    test('N时X分', () {
      final r = parseNaturalLanguage('明天上午10点30分开会', now: now);
      expect(r.start, DateTime(2026, 8, 20, 10, 30));
    });
    test('零五分', () {
      final r = parseNaturalLanguage('明天上午十一点零五分开会', now: now);
      expect(r.start, DateTime(2026, 8, 20, 11, 5));
    });
    test('中文数字钟点', () {
      final r = parseNaturalLanguage('明天下午三点开会', now: now);
      expect(r.start, DateTime(2026, 8, 20, 15, 0));
    });
    test('只有时间无日期 → 今天，已过顺延到明天', () {
      final r = parseNaturalLanguage('晚上8点跑步', now: now);
      expect(r.start, DateTime(2026, 8, 19, 20, 0));
      expect(r.hasDate, false);
      final r2 = parseNaturalLanguage('上午8点跑步', now: now);
      expect(r2.start, DateTime(2026, 8, 20, 8, 0));
    });
    test('无时段词钟点已过 → 视为下午', () {
      final r = parseNaturalLanguage('3点开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 15, 0));
    });
    test('无时段词钟点未过 → 保持', () {
      final r = parseNaturalLanguage('2点开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 14, 0));
    });
    test('相对时间：15分钟后', () {
      final r = parseNaturalLanguage('15分钟后喝水', now: now);
      expect(r.start, DateTime(2026, 8, 19, 12, 15));
    });
    test('相对时间：半小时后', () {
      final r = parseNaturalLanguage('半小时后开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 12, 30));
    });
    test('相对时间：一个半小时后', () {
      final r = parseNaturalLanguage('一个半小时后开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 13, 30));
    });
    test('相对时间：2小时后', () {
      final r = parseNaturalLanguage('2小时后开会', now: now);
      expect(r.start, DateTime(2026, 8, 19, 14, 0));
    });
    test('相对时间：3天后', () {
      final r = parseNaturalLanguage('3天后复查', now: now);
      expect(r.start, DateTime(2026, 8, 22, 12, 0));
    });
  });

  group('重复解析', () {
    test('每天', () {
      final r = parseNaturalLanguage('每天上午9点吃药', now: now);
      expect(r.repeat, RepeatRule.daily);
      expect(r.start, DateTime(2026, 8, 19, 9, 0));
    });
    test('每晚8点', () {
      final r = parseNaturalLanguage('每晚8点散步', now: now);
      expect(r.repeat, RepeatRule.daily);
      expect(r.start, DateTime(2026, 8, 19, 20, 0));
    });
    test('每周三（无日期，按重复锚点推导）', () {
      final r = parseNaturalLanguage('每周三下午3点组会', now: now);
      expect(r.repeat, RepeatRule.weekly);
      expect(r.repeatWeekday, DateTime.wednesday);
      // now 为周三 12:00，下午 3 点尚未到 → 锚点为今天 15:00
      expect(r.start, DateTime(2026, 8, 19, 15, 0));
    });
    test('每周三（当天时间已过 → 顺延下周）', () {
      final r = parseNaturalLanguage('每周三上午8点组会', now: now);
      expect(r.repeat, RepeatRule.weekly);
      expect(r.start, DateTime(2026, 8, 26, 8, 0));
    });
    test('每周五晚上8点（需求示例）', () {
      final r = parseNaturalLanguage('每周五晚上8点健身', now: now);
      expect(r.repeat, RepeatRule.weekly);
      expect(r.start, DateTime(2026, 8, 21, 20, 0));
    });
    test('每月1号', () {
      final r = parseNaturalLanguage('每月1号上午9点交报表', now: now);
      expect(r.repeat, RepeatRule.monthly);
      expect(r.repeatMonthDay, 1);
      expect(r.start, DateTime(2026, 9, 1, 9, 0));
    });
    test('每月三十一号（中文数字）', () {
      final r = parseNaturalLanguage('每月三十一号上午9点对账', now: now);
      expect(r.repeat, RepeatRule.monthly);
      expect(r.repeatMonthDay, 31);
      expect(r.start, DateTime(2026, 8, 31, 9, 0));
    });
    test('每月（无日期）', () {
      final r = parseNaturalLanguage('每月理发', now: now);
      expect(r.repeat, RepeatRule.monthly);
    });
    test('一次性', () {
      final r = parseNaturalLanguage('明天下午3点面试，一次性提醒', now: now);
      expect(r.repeat, RepeatRule.none);
      expect(r.hasRepeat, true);
    });
    test('无重复 → 默认单次（hasRepeat=false）', () {
      final r = parseNaturalLanguage('明天下午3点开会', now: now);
      expect(r.repeat, isNull);
      expect(r.hasRepeat, false);
    });
  });

  group('提前提醒解析', () {
    test('提前30分钟', () {
      final r = parseNaturalLanguage('明天下午3点开会，提前30分钟', now: now);
      expect(r.advanceMinutes, 30);
    });
    test('提前一小时', () {
      final r = parseNaturalLanguage('明天下午3点开会，提前一小时', now: now);
      expect(r.advanceMinutes, 60);
    });
    test('提前半天', () {
      final r = parseNaturalLanguage('明天下午3点开会，提前半天', now: now);
      expect(r.advanceMinutes, 720);
    });
    test('提前2天', () {
      final r = parseNaturalLanguage('9月20日上午9点体检，提前2天', now: now);
      expect(r.advanceMinutes, 2880);
    });
    test('提前一个半小时', () {
      final r = parseNaturalLanguage('明天下午3点开会，提前一个半小时', now: now);
      expect(r.advanceMinutes, 90);
    });
    test('无提前 → hasAdvance=false（UI 默认 10 分钟）', () {
      final r = parseNaturalLanguage('明天下午3点开会', now: now);
      expect(r.advanceMinutes, isNull);
      expect(r.hasAdvance, false);
    });
  });

  group('时长解析', () {
    test('持续半小时', () {
      final r = parseNaturalLanguage('明天下午3点开会，持续半小时', now: now);
      expect(r.end, DateTime(2026, 8, 20, 15, 30));
    });
    test('耗时两个钟头', () {
      final r = parseNaturalLanguage('明天下午3点开会，耗时两个钟头', now: now);
      expect(r.end, DateTime(2026, 8, 20, 17, 0));
    });
    test('要花45分钟', () {
      final r = parseNaturalLanguage('明天下午3点开会，要花45分钟', now: now);
      expect(r.end, DateTime(2026, 8, 20, 15, 45));
    });
  });

  group('备注与标题', () {
    test('备注后缀', () {
      final r = parseNaturalLanguage('明天下午3点开会，备注：记得带电脑', now: now);
      expect(r.note, '记得带电脑');
      expect(r.title, '开会');
    });
    test('提醒我前缀清理', () {
      final r = parseNaturalLanguage('提醒我明天下午3点开会', now: now);
      expect(r.title, '开会');
    });
    test('记得前缀清理', () {
      final r = parseNaturalLanguage('记得明天买牛奶', now: now);
      expect(r.title, '买牛奶');
    });
    test('语气词后缀清理', () {
      final r = parseNaturalLanguage('明天下午3点锻炼一下吧', now: now);
      expect(r.title, '锻炼');
    });
    test('今晚/明早组合词', () {
      final r = parseNaturalLanguage('今晚8点看电影', now: now);
      expect(r.start, DateTime(2026, 8, 19, 20, 0));
      final r2 = parseNaturalLanguage('明早7点晨跑', now: now);
      expect(r2.start, DateTime(2026, 8, 20, 7, 0));
    });
    test('全角数字与冒号', () {
      final r = parseNaturalLanguage('明天下午３点开会，备注：带材料', now: now);
      expect(r.start, DateTime(2026, 8, 20, 15, 0));
      expect(r.note, '带材料');
    });
  });

  group('垃圾输入与容错', () {
    test('空输入', () {
      final r = parseNaturalLanguage('', now: now);
      expect(r.title, '');
      expect(r.start, isNull);
      expect(r.hasDate, false);
      expect(r.hasTime, false);
    });
    test('纯废话输入', () {
      final r = parseNaturalLanguage('哈哈哈哈', now: now);
      expect(r.title, '哈哈哈哈');
      expect(r.start, isNull);
    });
    test('无任何时间信息 → start=null（UI 全手动）', () {
      final r = parseNaturalLanguage('记得开会', now: now);
      expect(r.title, '开会');
      expect(r.start, isNull);
    });
    test('只有重复规则无时间 → 锚点推导', () {
      final r = parseNaturalLanguage('每天喝水', now: now);
      expect(r.repeat, RepeatRule.daily);
      expect(r.start, DateTime(2026, 8, 19, 9, 0));
      expect(r.hasTime, false);
    });
  });

  group('中文数字解析', () {
    test('基本数字', () {
      expect(parseChineseNumber('三'), 3);
      expect(parseChineseNumber('十'), 10);
      expect(parseChineseNumber('十一'), 11);
      expect(parseChineseNumber('二十'), 20);
      expect(parseChineseNumber('二十三'), 23);
      expect(parseChineseNumber('九十九'), 99);
      expect(parseChineseNumber('一百零五'), 105);
      expect(parseChineseNumber('两'), 2);
      expect(parseChineseNumber('15'), 15);
    });
    test('非法输入返回 null', () {
      expect(parseChineseNumber(''), isNull);
      expect(parseChineseNumber('abc'), isNull);
      expect(parseChineseNumber('点半'), isNull);
    });
  });
}
