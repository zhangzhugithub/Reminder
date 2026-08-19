import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 初始化时区数据库并把本地时区设为设备时区。
///
/// flutter_local_notifications 与 device_calendar 的 TZDateTime
/// 均依赖 tz.local 为正确值。
Future<void> initTimeZone() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    // 取不到设备时区时保持 tz 默认（UTC 基准的本地位置），
    // 调度器仍按 DateTime 本地时间换算，仅夏令时地区可能偏差。
  }
}

/// DateTime（本地墙钟时间）→ TZDateTime（本地时区）。
tz.TZDateTime toTz(DateTime local) => tz.TZDateTime.from(local, tz.local);
