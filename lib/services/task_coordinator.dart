import '../core/db/settings_repository.dart';
import '../core/db/task_repository.dart';
import '../core/models/task.dart';

/// 保存管线钩子类型。
///
/// 由各服务在启动时注入（main → AppState.create → wireHooks）：
/// - [syncTaskToCalendar]：同步任务到系统日历，返回日历事件 ID（M3）
/// - [deleteCalendarEventForTask]：删除任务绑定的日历事件（M3）
/// - [recordPendingCalendarDelete]：日历删除失败时记录墓碑待重试（M3）
/// - [scheduleNotificationsFor]：按任务调度本地通知（M4）
/// - [cancelNotificationsFor]：取消任务的全部本地通知（M4）
typedef CalendarSyncFn = Future<String> Function(Task task);
typedef CalendarDeleteFn = Future<void> Function(Task task);
typedef NotifScheduleFn = Future<void> Function(Task task);
typedef NotifCancelFn = Future<void> Function(Task task);

/// 任务保存管线协调器（核心业务枢纽）。
///
/// 需求主线：保存 → (1) 写本地数据库 → (2) 注册系统定时提醒 → (3) 写入系统日历。
/// 其中数据库是唯一硬事务；通知与日历失败均为软失败（标记 + 可重试），
/// 绝不因日历/通知失败回滚数据库。
class TaskCoordinator {
  TaskCoordinator({
    required this.tasks,
    required this.settings,
  });

  final TaskRepository tasks;
  final SettingsRepository settings;

  CalendarSyncFn? syncTaskToCalendar;
  CalendarDeleteFn? deleteCalendarEventForTask;
  CalendarDeleteFn? recordPendingCalendarDelete;
  NotifScheduleFn? scheduleNotificationsFor;
  NotifCancelFn? cancelNotificationsFor;

  /// 保存任务（新建/编辑共用）。
  Future<void> save(Task task) async {
    // (1) 数据库写入 —— 唯一硬事务
    await tasks.put(task);
    // (2) 通知调度（M4 起生效，失败为软失败）
    final schedule = scheduleNotificationsFor;
    if (schedule != null) {
      try {
        await schedule(task);
      } catch (_) {}
    }
    // (3) 日历同步（M3 起生效，失败软标记）；
    //     关闭任务级同步时，移除已绑定的日历事件
    if (task.syncToCalendar && settings.settings.calendarSyncEnabled) {
      await syncCalendar(task);
    } else if (!task.syncToCalendar && task.calendarEventId != null) {
      await _detachCalendarEvent(task);
    }
  }

  /// 移除任务绑定的日历事件并清空绑定（失败进墓碑待重试）。
  Future<void> _detachCalendarEvent(Task task) async {
    final deleteCal = deleteCalendarEventForTask;
    final record = recordPendingCalendarDelete;
    if (deleteCal == null) return;
    try {
      await deleteCal(task);
      await tasks.put(task.copy()
        ..calendarEventId = null
        ..modifiedAt = DateTime.now());
    } catch (_) {
      if (record != null) {
        try {
          await record(task);
        } catch (_) {}
      }
    }
  }

  /// 日历同步（失败置 calendarSyncError，列表展示重试入口）。
  Future<void> syncCalendar(Task task) async {
    final sync = syncTaskToCalendar;
    if (sync == null) return;
    if (!task.syncToCalendar || !settings.settings.calendarSyncEnabled) return;
    try {
      final eventId = await sync(task);
      await tasks.put(task.copy()
        ..calendarEventId = eventId
        ..calendarSyncError = false
        ..modifiedAt = DateTime.now());
    } catch (_) {
      await tasks.put(task.copy()
        ..calendarSyncError = true
        ..modifiedAt = DateTime.now());
    }
  }

  /// 删除任务。
  ///
  /// 顺序：取消通知 → （可选）删日历事件（失败进墓碑待重试）→ 删数据库。
  /// [deleteCalendarEvent] 由调用方通过删除确认弹窗决定。
  Future<void> deleteTask(Task task, {required bool deleteCalendarEvent}) async {
    final cancel = cancelNotificationsFor;
    if (cancel != null) {
      try {
        await cancel(task);
      } catch (_) {}
    }
    if (deleteCalendarEvent) {
      final deleteCal = deleteCalendarEventForTask;
      final record = recordPendingCalendarDelete;
      if (deleteCal != null) {
        try {
          await deleteCal(task);
        } catch (_) {
          if (record != null) {
            try {
              await record(task);
            } catch (_) {}
          }
        }
      }
    }
    await tasks.delete(task.id);
  }

  /// 任务开关：关闭即停止本地通知。
  ///
  /// [deleteCalendarEvent]：关闭任务时是否同步删除日历事件（需求 2.5 的可选项，
  /// 由调用方通过确认弹窗决定；删除失败进墓碑）。
  Future<void> toggleEnabled(Task task, bool enabled,
      {bool deleteCalendarEvent = false}) async {
    var updated = task.copy()
      ..enabled = enabled
      ..modifiedAt = DateTime.now();
    if (deleteCalendarEvent && updated.calendarEventId != null) {
      final deleteCal = deleteCalendarEventForTask;
      final record = recordPendingCalendarDelete;
      if (deleteCal != null) {
        try {
          await deleteCal(updated);
          updated = updated.copy()..calendarEventId = null;
        } catch (_) {
          if (record != null) {
            try {
              await record(updated);
            } catch (_) {}
          }
        }
      }
    }
    await tasks.put(updated);
    // 重新开启且此前无绑定事件：恢复日历同步
    if (enabled &&
        updated.syncToCalendar &&
        settings.settings.calendarSyncEnabled &&
        updated.calendarEventId == null) {
      await syncCalendar(updated);
    }
    final schedule = scheduleNotificationsFor;
    if (schedule != null) {
      try {
        await schedule(updated);
      } catch (_) {}
    }
  }
}
