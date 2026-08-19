import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/db/settings_repository.dart';
import 'core/navigation.dart';
import 'features/home/home_shell.dart';
import 'l10n/strings.dart';
import 'services/backup/backup_service.dart';
import 'services/calendar/calendar_service.dart';
import 'services/task_coordinator.dart';
import 'state/app_state.dart';
import 'state/task_list_state.dart';

/// 应用根组件：Provider 装配 + 主题 + 路由。
class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppState>.value(value: appState),
        Provider.value(value: appState.taskRepository),
        ChangeNotifierProvider<SettingsRepository>.value(
          value: appState.settingsRepository,
        ),
        Provider<TaskCoordinator>.value(value: appState.coordinator),
        Provider<CalendarService>.value(value: appState.calendarService),
        Provider<BackupService>.value(value: appState.backupService),
        ChangeNotifierProvider<TaskListState>(
          create: (_) => TaskListState(appState.taskRepository),
        ),
      ],
      child: Consumer<SettingsRepository>(
        builder: (context, settingsRepo, _) {
          final themeMode = switch (settingsRepo.settings.themeModeIndex) {
            1 => ThemeMode.light,
            2 => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: S.appName,
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00897B),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeMode,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
