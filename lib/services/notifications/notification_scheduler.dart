import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/db/app_database.dart';
import '../../core/db/settings_repository.dart';
import '../../core/db/task_repository.dart';
import '../../core/models/task.dart';
import '../../core/scheduling/occurrence_planner.dart';
import '../../core/time/date_format.dart';
import '../../core/time/tz_init.dart';
import 'notification_service.dart';

/// 本地通知调度器：预排未来 N 次、全局上限分配、开机/恢复补排。
///
/// 设计要点（与需求 4.3 对应）：
/// - 循环任务：一次性预排未来 K 次（后台 Dart 不随闹钟运行，通知由插件
///   原生展示；每次 App 打开/恢复/点击通知时补排，等价于
///   「本次提醒完成，自动注册下一次周期」）；
/// - 单次任务：只排一次，触发后自然过期；
/// - 平台上限：iOS 待处理通知 64 条 → 全局预算 60；Android 三星等机型
///   约 500 条闹钟 → 全局预算 400，每任务最多 10 期；
/// - 精确闹钟：SCHEDULE_EXACT_ALARM 被系统回收时自动降级非精确模式。
class NotificationScheduler {
  NotificationScheduler({
    required this.service,
    required this.database,
    required this.tasks,
    required this.settingsRepository,
  });

  final NotificationService service;
  final AppDatabase database;
  final TaskRepository tasks;
  final SettingsRepository settingsRepository;

  static const _maxSlotsPerTaskAndroid = 10;
  static const _maxSlotsPerTaskIos = 3;
  static const _globalCapAndroid = 400;
  static const _globalCapIos = 60;

  /// 每任务预留的通知 ID 槽位数（blockId * 100 + slot）。
  static const _blockSize = 100;

  bool get _isAndroid => Platform.isAndroid;

  int get _maxSlotsPerTask =>
      _isAndroid ? _maxSlotsPerTaskAndroid : _maxSlotsPerTaskIos;

  int get _globalCap => _isAndroid ? _globalCapAndroid : _globalCapIos;

  // ---- 对外 API（TaskCoordinator 钩子） ----

  /// 重建指定任务的预排通知（保存/编辑/开关切换后调用）。
  Future<void> rescheduleFor(Task task) async {
    await service.ensureNotificationPermission();
    await _cancelScheduled(task);
    if (!task.enabled) return;

    final settings = settingsRepository.settings;
    final times = OccurrencePlanner.remindTimesFor(
      task,
      DateTime.now(),
      maxSlots: _maxSlotsPerTask,
      expiredTaskNotify: settings.expiredTaskNotify,
    );
    if (times.isEmpty) return;

    var blockId = task.notifBlockId;
    if (blockId <= 0) {
      blockId = await _allocateBlock();
    }
    final ids = <int>[];
    final exact = await service.canScheduleExactNotifications();
    for (var i = 0; i < times.length; i++) {
      final id = blockId * _blockSize + i;
      await _schedule(task, times[i], id, exact: exact);
      ids.add(id);
    }
    await tasks.put(task.copy()
      ..notifBlockId = blockId
      ..scheduledNotificationIds = ids);
  }

  /// 取消指定任务的全部预排通知。
  Future<void> cancelFor(Task task) async {
    await _cancelScheduled(task);
  }

  // ---- 全量补排 ----

  /// 全量补排：按「下一次提醒时间」优先级在全局预算内预排。
  ///
  /// 触发时机：App 启动、App 恢复到前台、通知点击。
  /// 预算外的任务保留现有排程，下次补排时轮转。
  Future<void> topUpAll() async {
    final now = DateTime.now();
    final pending = tasks
        .all()
        .where((t) => t.enabled)
        .toList()
      ..sort((a, b) => (_priorityTime(a, now) ?? DateTime(3000))
          .compareTo(_priorityTime(b, now) ?? DateTime(3000)));

    var budget = _globalCap;
    final toReschedule = <Task>[];
    for (final task in pending) {
      final slots = OccurrencePlanner.remindTimesFor(
        task,
        now,
        maxSlots: _maxSlotsPerTask,
        expiredTaskNotify: settingsRepository.settings.expiredTaskNotify,
      ).length;
      if (slots <= budget) {
        budget -= slots;
        toReschedule.add(task);
      }
    }
    for (final task in toReschedule) {
      try {
        await rescheduleFor(task);
      } catch (_) {
        // 单任务失败不阻塞其余（软失败）
      }
    }
  }

  /// 全部取消（重置 App 时使用）。
  Future<void> cancelAll() async {
    await service.plugin.cancelAll();
    final now = DateTime.now();
    for (final task in tasks.all()) {
      await tasks.put(task.copy()
        ..scheduledNotificationIds = []
        ..modifiedAt = now);
    }
  }

  // ---- 内部实现 ----

  static DateTime? _priorityTime(Task task, DateTime now) =>
      OccurrencePlanner.nextRemindAt(task, now);

  Future<int> _allocateBlock() async {
    final meta = database.readMeta();
    final next = (meta['nextNotifBlockId'] as int?) ?? 1;
    await database.updateMeta((m) => m['nextNotifBlockId'] = next + 1);
    return next;
  }

  Future<void> _cancelScheduled(Task task) async {
    for (final id in task.scheduledNotificationIds) {
      await service.plugin.cancel(id);
    }
    if (task.scheduledNotificationIds.isNotEmpty) {
      await tasks.put(task.copy()..scheduledNotificationIds = []);
    }
  }

  Future<void> _schedule(Task task, DateTime remindAt, int id,
      {required bool exact}) async {
    final settings = settingsRepository.settings;
    final body = StringBuffer(DateFmt.dateTime(task.start));
    if (task.note.isNotEmpty) {
      body.write('\n${task.note}');
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationService.channelId,
        NotificationService.channelName,
        channelDescription: NotificationService.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: settings.notificationSound,
        enableVibration: settings.notificationVibrate,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: settings.notificationSound,
      ),
    );
    await service.plugin.zonedSchedule(
      id: id,
      scheduledDate: toTz(remindAt),
      notificationDetails: details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: task.title,
      body: body.toString(),
      payload: task.id,
    );
  }
}
