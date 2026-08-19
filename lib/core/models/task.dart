import 'package:hive_ce/hive.dart';

import 'repeat_rule.dart';

/// 提醒任务（本地数据库主实体，typeId 0）。
///
/// 除 Hive 存储外，还支持 JSON 序列化（用于本地备份导出/恢复）。
class Task {
  Task({
    required this.id,
    required this.title,
    this.note = '',
    required this.start,
    this.end,
    this.repeat = RepeatRule.none,
    this.repeatWeekday = 1,
    this.repeatMonthDay = 1,
    this.advanceMinutes = 10,
    this.enabled = true,
    this.syncToCalendar = true,
    this.calendarEventId,
    this.calendarSyncError = false,
    required this.createdAt,
    required this.modifiedAt,
    List<int>? scheduledNotificationIds,
    this.notifBlockId = 0,
  }) : scheduledNotificationIds = scheduledNotificationIds ?? [];

  /// 任务唯一 ID（uuid v4）。
  String id;

  /// 标题（必填）。
  String title;

  /// 备注（选填）。
  String note;

  /// 开始时间（本地时间，锚点：重复任务按此时间循环）。
  DateTime start;

  /// 结束时间（选填）。
  DateTime? end;

  /// 重复规则。
  RepeatRule repeat;

  /// 每周重复时锁定星期几（1=周一 … 7=周日）。
  int repeatWeekday;

  /// 每月重复时锁定日期（1-31，天数不足时月末钳制）。
  int repeatMonthDay;

  /// 提前提醒分钟数（0 = 准时提醒）。
  int advanceMinutes;

  /// 任务启用状态（关闭后不触发本地通知）。
  bool enabled;

  /// 是否同步到系统日历（任务级开关，受全局开关约束）。
  bool syncToCalendar;

  /// 关联系统日历事件 ID（与日历事件双向绑定）。
  String? calendarEventId;

  /// 日历同步软失败标记（列表展示重试入口）。
  bool calendarSyncError;

  DateTime createdAt;
  DateTime modifiedAt;

  /// 当前已注册的本地通知 ID 列表。
  List<int> scheduledNotificationIds;

  /// 通知 ID 块号（每任务预留 100 个 ID：block*100 + slot），0 表示未分配。
  int notifBlockId;

  // ---- 计算属性 ----

  bool get isRecurring => repeat != RepeatRule.none;

  /// 单次任务且开始时间已过（不含循环任务）。
  bool isExpiredAt(DateTime now) => !isRecurring && start.isBefore(now);

  /// 相对 [now] 的下一次发生时间（循环任务）；单次任务返回 null。
  DateTime? nextOccurrenceAfter(DateTime now) {
    if (!isRecurring) return null;
    return RepeatMath.nextOccurrence(
      repeat,
      start,
      now.subtract(const Duration(seconds: 1)),
      weekday: repeatWeekday,
      monthDay: repeatMonthDay,
    );
  }

  /// 相对 [now] 下一次发生的提醒触发时间（开始时间 - 提前量）。
  DateTime? nextRemindAt(DateTime now) {
    final next = isRecurring ? nextOccurrenceAfter(now) : start;
    if (next == null) return null;
    return next.subtract(Duration(minutes: advanceMinutes));
  }

  Task copy() => Task(
        id: id,
        title: title,
        note: note,
        start: start,
        end: end,
        repeat: repeat,
        repeatWeekday: repeatWeekday,
        repeatMonthDay: repeatMonthDay,
        advanceMinutes: advanceMinutes,
        enabled: enabled,
        syncToCalendar: syncToCalendar,
        calendarEventId: calendarEventId,
        calendarSyncError: calendarSyncError,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        scheduledNotificationIds: List.of(scheduledNotificationIds),
        notifBlockId: notifBlockId,
      );

  // ---- JSON（备份导出/恢复） ----

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'repeat': repeat.index,
        'repeatWeekday': repeatWeekday,
        'repeatMonthDay': repeatMonthDay,
        'advanceMinutes': advanceMinutes,
        'enabled': enabled,
        'syncToCalendar': syncToCalendar,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  /// 从备份 JSON 恢复。日历绑定与通知 ID 属于设备本地状态，
  /// 恢复时重置（由保存管线重新同步/重新调度）。
  static Task fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        note: (json['note'] as String?) ?? '',
        start: DateTime.parse(json['start'] as String),
        end: json['end'] == null
            ? null
            : DateTime.parse(json['end'] as String),
        repeat: _repeatFromIndex(json['repeat']),
        repeatWeekday: (json['repeatWeekday'] as int?) ?? 1,
        repeatMonthDay: (json['repeatMonthDay'] as int?) ?? 1,
        advanceMinutes: (json['advanceMinutes'] as int?) ?? 10,
        enabled: (json['enabled'] as bool?) ?? true,
        syncToCalendar: (json['syncToCalendar'] as bool?) ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      );

  static RepeatRule _repeatFromIndex(dynamic v) {
    final i = v is int ? v : int.tryParse('$v') ?? 0;
    return (i >= 0 && i < RepeatRule.values.length)
        ? RepeatRule.values[i]
        : RepeatRule.none;
  }
}

/// Task 的 Hive 适配器（手写，避免 build_runner 代码生成）。
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      note: fields[2] as String? ?? '',
      start: fields[3] as DateTime,
      end: fields[4] as DateTime?,
      repeat: _readRepeat(fields[5]),
      repeatWeekday: fields[6] as int? ?? 1,
      repeatMonthDay: fields[7] as int? ?? 1,
      advanceMinutes: fields[8] as int? ?? 10,
      enabled: fields[9] as bool? ?? true,
      syncToCalendar: fields[10] as bool? ?? true,
      calendarEventId: fields[11] as String?,
      calendarSyncError: fields[12] as bool? ?? false,
      createdAt: fields[13] as DateTime,
      modifiedAt: fields[14] as DateTime,
      scheduledNotificationIds:
          (fields[15] as List?)?.cast<int>() ?? <int>[],
      notifBlockId: fields[16] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.start)
      ..writeByte(4)
      ..write(obj.end)
      ..writeByte(5)
      ..write(obj.repeat.index)
      ..writeByte(6)
      ..write(obj.repeatWeekday)
      ..writeByte(7)
      ..write(obj.repeatMonthDay)
      ..writeByte(8)
      ..write(obj.advanceMinutes)
      ..writeByte(9)
      ..write(obj.enabled)
      ..writeByte(10)
      ..write(obj.syncToCalendar)
      ..writeByte(11)
      ..write(obj.calendarEventId)
      ..writeByte(12)
      ..write(obj.calendarSyncError)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.modifiedAt)
      ..writeByte(15)
      ..write(obj.scheduledNotificationIds)
      ..writeByte(16)
      ..write(obj.notifBlockId);
  }

  static RepeatRule _readRepeat(dynamic v) {
    final i = v is int ? v : int.tryParse('$v') ?? 0;
    return (i >= 0 && i < RepeatRule.values.length)
        ? RepeatRule.values[i]
        : RepeatRule.none;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TaskAdapter && runtimeType == other.runtimeType;

  @override
  int get hashCode => typeId.hashCode;
}
