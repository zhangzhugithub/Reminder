import 'package:hive_ce/hive.dart';

/// 应用设置（typeId 1），单例存储于 settings box 的 'default' 键。
class ReminderSettings {
  ReminderSettings({
    this.themeModeIndex = 0,
    this.defaultAdvanceMinutes = 10,
    this.calendarSyncEnabled = true,
    this.calendarId,
    this.calendarName,
    this.notificationSound = true,
    this.notificationVibrate = true,
    this.asrSilenceSeconds = 8,
    this.asrMaxRecordSeconds = 60,
    this.exactAlarmPromptShown = false,
    this.deleteCalendarDefault = true,
    this.voiceAutoEdit = true,
    this.voiceVolumeMeter = true,
    this.expiredTaskNotify = false,
    this.sortByStartAsc = true,
  });

  /// 主题：0=跟随系统 1=浅色 2=深色。
  int themeModeIndex;

  /// 解析/新建任务时默认提前提醒分钟数。
  int defaultAdvanceMinutes;

  /// 日历同步全局总开关。
  bool calendarSyncEnabled;

  /// 专属日历 ID（缓存，首次同步时创建）。
  String? calendarId;

  /// 专属日历名称（缓存，默认「离线语音提醒」）。
  String? calendarName;

  /// 通知铃声开关。
  bool notificationSound;

  /// 通知震动开关。
  bool notificationVibrate;

  /// 语音录入静默自动结束秒数（无新识别结果持续该时长即结束）。
  int asrSilenceSeconds;

  /// 语音录入最长录音秒数。
  int asrMaxRecordSeconds;

  /// 是否已提示过精确闹钟引导（避免重复打扰）。
  bool exactAlarmPromptShown;

  /// 删除任务时默认是否同步删除日历事件。
  bool deleteCalendarDefault;

  /// 识别完成自动进入编辑页面（关闭则直接保存解析结果）。
  bool voiceAutoEdit;

  /// 录音音量提示（波形展示）开关。
  bool voiceVolumeMeter;

  /// 过期任务是否继续弹通知提醒（防呆设置，默认关）。
  bool expiredTaskNotify;

  /// 任务列表排序：true=开始时间升序，false=创建时间倒序。
  bool sortByStartAsc;

  ReminderSettings copy() => ReminderSettings(
        themeModeIndex: themeModeIndex,
        defaultAdvanceMinutes: defaultAdvanceMinutes,
        calendarSyncEnabled: calendarSyncEnabled,
        calendarId: calendarId,
        calendarName: calendarName,
        notificationSound: notificationSound,
        notificationVibrate: notificationVibrate,
        asrSilenceSeconds: asrSilenceSeconds,
        asrMaxRecordSeconds: asrMaxRecordSeconds,
        exactAlarmPromptShown: exactAlarmPromptShown,
        deleteCalendarDefault: deleteCalendarDefault,
        voiceAutoEdit: voiceAutoEdit,
        voiceVolumeMeter: voiceVolumeMeter,
        expiredTaskNotify: expiredTaskNotify,
        sortByStartAsc: sortByStartAsc,
      );

  Map<String, dynamic> toJson() => {
        'themeModeIndex': themeModeIndex,
        'defaultAdvanceMinutes': defaultAdvanceMinutes,
        'calendarSyncEnabled': calendarSyncEnabled,
        'notificationSound': notificationSound,
        'notificationVibrate': notificationVibrate,
        'asrSilenceSeconds': asrSilenceSeconds,
        'asrMaxRecordSeconds': asrMaxRecordSeconds,
        'deleteCalendarDefault': deleteCalendarDefault,
        'voiceAutoEdit': voiceAutoEdit,
        'voiceVolumeMeter': voiceVolumeMeter,
        'expiredTaskNotify': expiredTaskNotify,
        'sortByStartAsc': sortByStartAsc,
      };

  static ReminderSettings fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        themeModeIndex: json['themeModeIndex'] as int? ?? 0,
        defaultAdvanceMinutes: json['defaultAdvanceMinutes'] as int? ?? 10,
        calendarSyncEnabled: json['calendarSyncEnabled'] as bool? ?? true,
        notificationSound: json['notificationSound'] as bool? ?? true,
        notificationVibrate: json['notificationVibrate'] as bool? ?? true,
        asrSilenceSeconds: json['asrSilenceSeconds'] as int? ?? 8,
        asrMaxRecordSeconds: json['asrMaxRecordSeconds'] as int? ?? 60,
        deleteCalendarDefault: json['deleteCalendarDefault'] as bool? ?? true,
        voiceAutoEdit: json['voiceAutoEdit'] as bool? ?? true,
        voiceVolumeMeter: json['voiceVolumeMeter'] as bool? ?? true,
        expiredTaskNotify: json['expiredTaskNotify'] as bool? ?? false,
        sortByStartAsc: json['sortByStartAsc'] as bool? ?? true,
      );
}

class ReminderSettingsAdapter extends TypeAdapter<ReminderSettings> {
  @override
  final int typeId = 1;

  @override
  ReminderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderSettings(
      themeModeIndex: fields[0] as int? ?? 0,
      defaultAdvanceMinutes: fields[1] as int? ?? 10,
      calendarSyncEnabled: fields[2] as bool? ?? true,
      calendarId: fields[3] as String?,
      calendarName: fields[4] as String?,
      notificationSound: fields[5] as bool? ?? true,
      notificationVibrate: fields[6] as bool? ?? true,
      asrSilenceSeconds: fields[7] as int? ?? 8,
      asrMaxRecordSeconds: fields[8] as int? ?? 60,
      exactAlarmPromptShown: fields[9] as bool? ?? false,
      deleteCalendarDefault: fields[10] as bool? ?? true,
      voiceAutoEdit: fields[11] as bool? ?? true,
      voiceVolumeMeter: fields[12] as bool? ?? true,
      expiredTaskNotify: fields[13] as bool? ?? false,
      sortByStartAsc: fields[14] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSettings obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.themeModeIndex)
      ..writeByte(1)
      ..write(obj.defaultAdvanceMinutes)
      ..writeByte(2)
      ..write(obj.calendarSyncEnabled)
      ..writeByte(3)
      ..write(obj.calendarId)
      ..writeByte(4)
      ..write(obj.calendarName)
      ..writeByte(5)
      ..write(obj.notificationSound)
      ..writeByte(6)
      ..write(obj.notificationVibrate)
      ..writeByte(7)
      ..write(obj.asrSilenceSeconds)
      ..writeByte(8)
      ..write(obj.asrMaxRecordSeconds)
      ..writeByte(9)
      ..write(obj.exactAlarmPromptShown)
      ..writeByte(10)
      ..write(obj.deleteCalendarDefault)
      ..writeByte(11)
      ..write(obj.voiceAutoEdit)
      ..writeByte(12)
      ..write(obj.voiceVolumeMeter)
      ..writeByte(13)
      ..write(obj.expiredTaskNotify)
      ..writeByte(14)
      ..write(obj.sortByStartAsc);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettingsAdapter && runtimeType == other.runtimeType;

  @override
  int get hashCode => typeId.hashCode;
}
