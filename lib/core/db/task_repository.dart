import 'package:hive_ce/hive.dart';

import '../models/repeat_rule.dart';
import '../models/task.dart';

/// 任务列表分类标签（与需求「全部/今日/未来/已过期」一致）。
enum TaskFilter { all, today, future, expired }

/// 任务仓储：本地分页读取、排序、分类筛选。
///
/// 数据规模为个人提醒级别，排序与筛选在内存中完成，
/// 分页 = 排序后按索引区间读取（配合列表上拉加载）。
class TaskRepository {
  TaskRepository(this.box);

  final Box<Task> box;

  static const pageSize = 20;

  Task? getById(String id) => box.get(id);

  List<Task> all() => box.values.toList();

  /// 全部任务按开始时间升序（默认排序）。
  List<Task> sortedByStart() => all()..sort(_byStartAsc);

  /// 按筛选条件取一页。
  List<Task> query(TaskFilter filter, DateTime now, {int offset = 0, int limit = pageSize}) {
    final list = sortedByStart().where((t) => matches(t, filter, now)).toList();
    final end = (offset + limit).clamp(0, list.length);
    if (offset >= list.length) return const [];
    return list.sublist(offset, end);
  }

  int count(TaskFilter filter, DateTime now) =>
      sortedByStart().where((t) => matches(t, filter, now)).length;

  /// 分类判定：已过期 / 今日 / 未来 三者互斥且覆盖全集。
  static bool matches(Task t, TaskFilter filter, DateTime now) {
    switch (filter) {
      case TaskFilter.all:
        return true;
      case TaskFilter.expired:
        return t.isExpiredAt(now);
      case TaskFilter.today:
        if (t.isExpiredAt(now)) return false;
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfTomorrow = startOfToday.add(const Duration(days: 1));
        final next = t.isRecurring ? t.nextOccurrenceAfter(now) : t.start;
        return next != null &&
            !next.isBefore(startOfToday) &&
            next.isBefore(startOfTomorrow);
      case TaskFilter.future:
        if (t.isExpiredAt(now)) return false;
        final startOfTomorrow =
            DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        final next = t.isRecurring ? t.nextOccurrenceAfter(now) : t.start;
        return next != null && !next.isBefore(startOfTomorrow);
    }
  }

  Future<void> put(Task task) => box.put(task.id, task);

  Future<void> delete(String id) => box.delete(id);

  /// 批量删除。
  Future<void> deleteAll(Iterable<String> ids) async {
    await box.deleteAll(ids);
  }

  /// 清理全部已过期的单次任务，返回清理数量。
  Future<int> clearExpired(DateTime now) async {
    final expired = sortedByStart()
        .where((t) => t.isExpiredAt(now))
        .map((t) => t.id)
        .toList();
    if (expired.isNotEmpty) await box.deleteAll(expired);
    return expired.length;
  }

  /// 任务的下一次通知触发点（供调度器与列表展示使用）。
  static DateTime? nextRemindAt(Task t, DateTime now) => t.nextRemindAt(now);

  static int _byStartAsc(Task a, Task b) => a.start.compareTo(b.start);
}

/// 便捷扩展：重复规则展示名等（UI 层使用）。
extension RepeatRuleText on RepeatRule {
  String get shortName {
    switch (this) {
      case RepeatRule.none:
        return '单次';
      case RepeatRule.daily:
        return '每天';
      case RepeatRule.weekly:
        return '每周';
      case RepeatRule.monthly:
        return '每月';
    }
  }
}
