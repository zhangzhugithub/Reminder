import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/db/app_database.dart';
import '../core/db/settings_repository.dart';
import '../core/db/task_repository.dart';
import '../services/backup/backup_service.dart';
import '../services/calendar/calendar_service.dart';
import '../services/notifications/notification_scheduler.dart';
import '../services/notifications/notification_service.dart';
import '../services/task_coordinator.dart';

/// 应用全局状态门面：持有数据库、服务与保存管线协调器。
///
/// 页面通过 Provider 获取所需实例。
class AppState {
  AppState({
    required this.database,
    required this.taskRepository,
    required this.settingsRepository,
    required this.calendarService,
    required this.notificationService,
    required this.notificationScheduler,
    required this.coordinator,
    required this.backupService,
  });

  final AppDatabase database;
  final TaskRepository taskRepository;
  final SettingsRepository settingsRepository;
  final CalendarService calendarService;
  final NotificationService notificationService;
  final NotificationScheduler notificationScheduler;
  final TaskCoordinator coordinator;
  final BackupService backupService;

  /// 前台恢复补排监听（持有引用防止被 GC）。
  AppLifecycleListener? lifecycleListener;

  /// 异步初始化：Hive → 时区 → 服务装配与钩子注入（顺序敏感，由 main() 调用）。
  static Future<AppState> create() async {
    final database = AppDatabase();
    await database.init();

    final taskRepository = TaskRepository(database.tasks);
    final settingsRepository = SettingsRepository(database);
    final calendarService = CalendarService(
      database: database,
      settingsRepository: settingsRepository,
    );
    final notificationService = NotificationService();
    final notificationScheduler = NotificationScheduler(
      service: notificationService,
      database: database,
      tasks: taskRepository,
      settingsRepository: settingsRepository,
    );

    final coordinator = TaskCoordinator(
      tasks: taskRepository,
      settings: settingsRepository,
    );
    coordinator.syncTaskToCalendar = calendarService.syncTask;
    coordinator.deleteCalendarEventForTask = calendarService.deleteEventForTask;
    coordinator.recordPendingCalendarDelete =
        calendarService.recordPendingDelete;
    coordinator.scheduleNotificationsFor = notificationScheduler.rescheduleFor;
    coordinator.cancelNotificationsFor = notificationScheduler.cancelFor;

    final backupService = BackupService(
      database: database,
      taskRepository: taskRepository,
      settingsRepository: settingsRepository,
      coordinator: coordinator,
    );

    // 启动时静默重试日历删除墓碑（失败保留，下次再试）
    try {
      await calendarService.retryPendingDeletes();
    } catch (_) {}

    return AppState(
      database: database,
      taskRepository: taskRepository,
      settingsRepository: settingsRepository,
      calendarService: calendarService,
      notificationService: notificationService,
      notificationScheduler: notificationScheduler,
      coordinator: coordinator,
      backupService: backupService,
    );
  }
}

/// 供 ChangeNotifier 复用的基类：避免子类重复 dispose 样板。
abstract class BaseNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
