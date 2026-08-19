import '../models/repeat_rule.dart';
import '../models/task.dart';

/// 提醒发生时间规划器（纯 Dart，可独立单元测试）。
///
/// 输入任务与当前时间，输出应预排的「通知触发时间」列表：
/// - 单次任务：开始时间 - 提前量；已过提醒时间但未到开始时间 → 立即提醒；
///   开始时间已过 → 默认不排（[expiredTaskNotify] 开启时立即提醒一次）。
/// - 循环任务：未来 [maxSlots] 次发生的提醒时间（不足则从下一次发生顺延）。
class OccurrencePlanner {
  OccurrencePlanner._();

  /// 计算任务应预排的提醒触发时间（升序，均为未来时间）。
  static List<DateTime> remindTimesFor(
    Task task,
    DateTime now, {
    required int maxSlots,
    required bool expiredTaskNotify,
  }) {
    final advance = Duration(minutes: task.advanceMinutes);
    if (task.repeat == RepeatRule.none) {
      final remindAt = task.start.subtract(advance);
      if (remindAt.isAfter(now)) return [remindAt];
      // 提醒时间已过：任务尚未开始 → 立即提醒；已开始 → 按过期设置处理
      if (task.start.isAfter(now) || expiredTaskNotify) {
        return [now.add(const Duration(seconds: 3))];
      }
      return const [];
    }

    final result = <DateTime>[];
    var cursor = now;
    for (var i = 0; i < maxSlots; i++) {
      final occurrence = RepeatMath.nextOccurrence(
        task.repeat,
        task.start,
        cursor,
        weekday: task.repeatWeekday,
        monthDay: task.repeatMonthDay,
      );
      if (occurrence == null) break;
      final remindAt = occurrence.subtract(advance);
      // 本次发生的提醒时间已过 → 立即提醒（避免错过当前周期）
      result.add(remindAt.isAfter(now)
          ? remindAt
          : now.add(Duration(seconds: 3 + i)));
      cursor = occurrence;
    }
    return result;
  }

  /// 下一次提醒触发时间（供列表排序优先级与展示使用），无则 null。
  static DateTime? nextRemindAt(Task task, DateTime now) {
    if (!task.enabled) return null;
    final times =
        remindTimesFor(task, now, maxSlots: 1, expiredTaskNotify: false);
    return times.isEmpty ? null : times.first;
  }
}
