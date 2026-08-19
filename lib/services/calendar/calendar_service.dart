import 'dart:ui' show Color;

import 'package:device_calendar/device_calendar.dart';

import '../../core/db/app_database.dart';
import '../../core/db/settings_repository.dart';
import '../../core/db/task_repository.dart';
import '../../core/models/task.dart';
import '../../core/time/tz_init.dart';

/// 日历同步异常（权限、平台错误等，统一由上层软失败处理）。
class CalendarException implements Exception {
  CalendarException(this.message);
  final String message;

  @override
  String toString() => 'CalendarException: $message';
}

/// 系统日历同步服务（全部调用系统原生日历 API，纯本地操作）。
///
/// 设计约定（与需求一致）：
/// - 首次同步自动创建专属本地日历「离线语音提醒」；
/// - 所有 App 任务统一归入该日历；
/// - App 为主数据源，单向同步：不监听系统日历中的外部修改；
/// - v1 事件映射：重复任务只同步「下一次发生」为单个事件，
///   任务触发/编辑/App 打开时刷新，保证幂等更新。
class CalendarService {
  CalendarService({
    required this.database,
    required this.settingsRepository,
  });

  final AppDatabase database;
  final SettingsRepository settingsRepository;

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  /// 专属日历名称（App 内与系统日历统一使用）。
  static const calendarName = '离线语音提醒';

  static const _calendarColor = Color(0xFF00897B);

  // ---- 权限 ----

  Future<bool> hasPermissions() => _plugin.hasPermissions();

  /// 请求日历读写权限（Android/iOS 均弹系统授权）。
  Future<bool> requestPermissions() => _plugin.requestPermissions();

  // ---- 专属日历 ----

  /// 确保专属日历存在，返回其 ID。
  ///
  /// 缓存的日历被用户在系统日历中删除时：清空任务绑定后重建。
  Future<String> ensureCalendar() async {
    final cachedId = _cachedCalendarId();
    if (cachedId != null) {
      final result = await _plugin.retrieveCalendars();
      if (result.isSuccess &&
          result.data!.any((c) => c.id == cachedId)) {
        return cachedId;
      }
      // 日历已不存在：解绑全部事件，重新创建
      await _clearEventBindings();
    }
    final createResult = await _plugin.createCalendar(
      calendarName,
      localAccountName: calendarName,
      calendarColor: _calendarColor,
    );
    if (!createResult.isSuccess || createResult.data == null) {
      throw CalendarException(
          '创建专属日历失败：${createResult.errors.join('; ')}');
    }
    final id = createResult.data!;
    await settingsRepository.update((s) {
      s.calendarId = id;
      s.calendarName = calendarName;
    });
    await database.updateMeta((m) => m['calendarId'] = id);
    return id;
  }

  String? _cachedCalendarId() =>
      settingsRepository.settings.calendarId ??
      (database.readMeta()['calendarId'] as String?);

  /// 清空日历 ID 缓存与全部任务的日历事件绑定（日历被删除后调用）。
  Future<void> _clearEventBindings() async {
    await settingsRepository.update((s) => s.calendarId = null);
    await database.updateMeta((m) => m.remove('calendarId'));
    final now = DateTime.now();
    for (final task in database.tasks.values) {
      if (task.calendarEventId != null) {
        await database.tasks.put(task.id, task.copy()
          ..calendarEventId = null
          ..calendarSyncError = false
          ..modifiedAt = now);
      }
    }
  }

  // ---- 任务同步 ----

  /// 同步任务到系统日历：创建或更新绑定事件，返回事件 ID。
  Future<String> syncTask(Task task) async {
    if (!await hasPermissions()) {
      final granted = await requestPermissions();
      if (!granted) {
        throw CalendarException('日历权限未授予，请在系统设置中开启');
      }
    }
    final calendarId = await ensureCalendar();
    final event = _buildEvent(calendarId, task);
    final result = await _plugin.createOrUpdateEvent(event);
    if (!result.isSuccess || result.data == null) {
      throw CalendarException(
          '写入日历失败：${result.errors.join('; ')}');
    }
    return result.data!;
  }

  Event _buildEvent(String calendarId, Task task) {
    // v1：重复任务同步下一次发生；单次任务同步开始时间
    final now = DateTime.now();
    final occurrence =
        task.isRecurring ? task.nextOccurrenceAfter(now) : task.start;
    if (occurrence == null) {
      throw CalendarException('任务无有效发生时间');
    }
    final start = toTz(occurrence);
    final end = task.end == null
        ? null
        : toTz(occurrence.add(task.end!.difference(task.start)));
    return Event(
      calendarId,
      eventId: task.calendarEventId,
      title: task.title,
      description: task.note.isEmpty ? null : task.note,
      start: start,
      end: end,
      allDay: false,
      reminders: [Reminder(minutes: task.advanceMinutes)],
    );
  }

  /// 删除任务绑定的日历事件。
  Future<void> deleteEventForTask(Task task) async {
    final eventId = task.calendarEventId;
    final calendarId = _cachedCalendarId();
    if (eventId == null || calendarId == null) return;
    final result = await _plugin.deleteEvent(calendarId, eventId);
    if (!result.isSuccess) {
      throw CalendarException(
          '删除日历事件失败：${result.errors.join('; ')}');
    }
  }

  /// 日历事件删除失败时记录墓碑，待下次启动/同步重试。
  Future<void> recordPendingDelete(Task task) async {
    final eventId = task.calendarEventId;
    final calendarId = _cachedCalendarId();
    if (eventId == null || calendarId == null) return;
    await database.updateMeta((m) {
      final list = _pendingDeletesOf(m);
      if (!list.any((e) => e['eventId'] == eventId)) {
        list.add({'calendarId': calendarId, 'eventId': eventId});
      }
      m['pendingCalendarDeletes'] = list;
    });
  }

  /// 重试墓碑清理（App 启动时静默调用，失败保留下次再试）。
  Future<void> retryPendingDeletes() async {
    final meta = database.readMeta();
    final pending = _pendingDeletesOf(meta);
    if (pending.isEmpty) return;
    final remaining = <Map<String, String>>[];
    for (final entry in pending) {
      final calendarId = entry['calendarId'];
      final eventId = entry['eventId'];
      if (calendarId == null || eventId == null) continue;
      final result = await _plugin.deleteEvent(calendarId, eventId);
      if (!result.isSuccess) {
        remaining.add(entry);
      }
    }
    await database.updateMeta(
        (m) => m['pendingCalendarDeletes'] = remaining);
  }

  static List<Map<String, String>> _pendingDeletesOf(Map<String, dynamic> m) {
    final raw = m['pendingCalendarDeletes'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => {
              'calendarId': '${e['calendarId']}',
              'eventId': '${e['eventId']}',
            })
        .toList();
  }

  /// 全量重新同步（设置页「立即同步全部任务」）：
  /// 重建绑定并刷新下一次发生事件，返回成功/失败数量。
  Future<(int ok, int failed)> resyncAll(TaskRepository repository) async {
    if (!await hasPermissions()) {
      final granted = await requestPermissions();
      if (!granted) {
        throw CalendarException('日历权限未授予，请在系统设置中开启');
      }
    }
    await ensureCalendar();
    var ok = 0;
    var failed = 0;
    final now = DateTime.now();
    for (final task in repository.all()) {
      if (!task.syncToCalendar) continue;
      try {
        final eventId = await syncTask(task);
        await repository.put(task.copy()
          ..calendarEventId = eventId
          ..calendarSyncError = false
          ..modifiedAt = now);
        ok++;
      } catch (_) {
        await repository.put(task.copy()
          ..calendarSyncError = true
          ..modifiedAt = now);
        failed++;
      }
    }
    return (ok, failed);
  }

  /// 删除专属日历并清空全部任务绑定（设置页提供，需用户确认）。
  /// 任务下次保存时会自动重建日历与事件。
  Future<void> deleteAppCalendar() async {
    final calendarId = _cachedCalendarId();
    if (calendarId != null) {
      await _plugin.deleteCalendar(calendarId);
    }
    await _clearEventBindings();
  }
}
