import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/navigation.dart';
import '../../features/detail/task_detail_page.dart';

/// 本地通知服务：插件初始化、通知渠道、权限、点击跳转。
///
/// 底层调度由 flutter_local_notifications 原生管理
/// （Android AlarmManager / iOS UNUserNotificationCenter），
/// 不使用 App 内定时器（前台存活才生效，需求禁止）。
class NotificationService {
  static const channelId = 'task_reminders';
  static const channelName = '任务提醒';
  static const channelDescription = '到达提醒时间的任务通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationPermissionRequested = false;

  /// 冷启动时通知点击携带的任务 ID（Navigator 就绪后消费，见 [openPendingLaunchTask]）。
  String? _pendingLaunchTaskId;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// 初始化（幂等）。
  ///
  /// 说明：
  /// - iOS 权限弹窗延迟到用户首次保存任务时（[ensureNotificationPermission]）；
  /// - 冷启动点击通知通过 [getNotificationAppLaunchDetails] 处理；
  /// - 应用存活期间点击通知走 [onDidReceiveNotificationResponse]。
  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onResponse,
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        enableVibration: true,
      ),
    );
    _initialized = true;

    // 冷启动：应用被通知点击拉起。
    // 注意：此时 runApp 尚未执行、Navigator 未构建，无法直接跳转，
    // 先暂存任务 ID，由 main() 在首帧后调用 [openPendingLaunchTask]。
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) _pendingLaunchTaskId = payload;
    }
  }

  /// 消费冷启动通知点击（main() 在 runApp 后调用；内部延迟到首帧）。
  void openPendingLaunchTask() {
    final taskId = _pendingLaunchTaskId;
    if (taskId == null) return;
    _pendingLaunchTaskId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openTaskDetail(taskId);
    });
  }

  /// 请求通知权限（Android 13+ POST_NOTIFICATIONS / iOS 授权）。
  /// 在用户主动保存任务的手势中调用，幂等。
  Future<void> ensureNotificationPermission() async {
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    await _android?.requestNotificationsPermission();
    await _ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Android 通知是否被用户允许。
  Future<bool?> areNotificationsEnabled() async {
    final a = _android;
    if (a == null) return null;
    return a.areNotificationsEnabled();
  }

  /// 是否可用精确闹钟（Android 12+；iOS 返回 true 表示无此限制）。
  Future<bool> canScheduleExactNotifications() async {
    final a = _android;
    if (a == null) return true;
    return await a.canScheduleExactNotifications() ?? false;
  }

  /// 跳转系统「闹钟与提醒」设置页（请求精确闹钟权限）。
  Future<void> requestExactAlarmsPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) openTaskDetail(payload);
  }

  /// 打开任务详情（通知点击 / 冷启动）。
  void openTaskDetail(String taskId) {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailPage(taskId: taskId),
      ),
    );
  }
}
