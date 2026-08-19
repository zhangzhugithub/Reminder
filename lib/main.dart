import 'package:flutter/material.dart';

import 'app.dart';
import 'core/time/tz_init.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 时区（flutter_local_notifications / device_calendar 依赖 tz.local）
  await initTimeZone();
  // 本地数据库 + 服务装配（日历/通知钩子注入）
  final appState = await AppState.create();
  // 通知插件初始化（含冷启动点击处理）
  await appState.notificationService.init();
  // 前台恢复时补排预排通知（应对 iOS 64 条上限与厂商后台查杀）
  appState.lifecycleListener = AppLifecycleListener(
    onResume: () {
      appState.notificationScheduler.topUpAll();
    },
  );
  // 启动补排（开机/升级后系统 receiver 原生重注册 + Dart 侧补排双保险）
  await appState.notificationScheduler.topUpAll();
  runApp(ReminderApp(appState: appState));
}
