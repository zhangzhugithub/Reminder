/// 应用内全部中文文案（硬编码，无 intl 依赖）。
///
/// 产品名：离线语音提醒
/// 所有界面文本集中在此，便于统一修改与文案终审。
class S {
  S._();

  // ---- 通用 ----
  static const appName = '离线语音提醒';
  static const ok = '确定';
  static const cancel = '取消';
  static const confirm = '确认';
  static const save = '保存';
  static const delete = '删除';
  static const edit = '编辑';
  static const retry = '重试';
  static const close = '关闭';
  static const enable = '开启';
  static const disable = '关闭';
  static const enabled = '已开启';
  static const disabled = '已关闭';
  static const loading = '加载中…';

  // ---- 主导航 ----
  static const tabTasks = '提醒';
  static const tabSettings = '设置';

  // ---- 任务 ----
  static const taskListTitle = '提醒任务';
  static const newTask = '新建任务';
  static const editTask = '编辑任务';
  static const voiceInput = '语音录入';
  static const textInput = '文本录入';
  static const taskTitle = '任务标题';
  static const taskTitleHint = '要提醒什么？';
  static const taskNote = '备注';
  static const taskNoteHint = '选填';
  static const startTime = '开始时间';
  static const endTime = '结束时间';
  static const noEndTime = '无结束时间';
  static const repeat = '重复';
  static const advanceReminder = '提前提醒';
  static const syncToCalendar = '同步到系统日历';
  static const filterAll = '全部';
  static const filterToday = '今日';
  static const filterFuture = '未来';
  static const filterExpired = '已过期';
  static const emptyTaskList = '还没有任务\n点击下方按钮创建第一个提醒';
  static const emptyFiltered = '该分类下暂无任务';
  static const taskExpiredTag = '已过期';
  static const calendarSyncErrorTag = '日历同步失败';
  static const titleRequired = '请输入任务标题';
  static const endBeforeStart = '结束时间不能早于开始时间';
  static const repeatFollowsWeekday = '每周按开始时间的星期几重复';
  static const repeatFollowsMonthDay = '每月按开始时间的日期重复';
  static const expiredConfirmTitle = '开始时间已过';
  static const expiredConfirmBody =
      '该任务开始时间早于当前时间，保存后将不会再触发提醒，仅作记录保留。确定保存吗？';
  static const enabledSwitch = '启用任务';

  static String deleteTaskTitle(String title) => '删除「$title」';
  static String deleteTaskConfirm(String title) => '确定删除「$title」吗？';
  static String deletedToast(String title) => '已删除「$title」';
  static const deleteCalendarWithTask = '同时删除系统日历内对应的事件';
  static const taskDetail = '任务详情';
  static const taskNotFound = '任务不存在或已被删除';
  static const nextOccurrence = '下次发生';
  static const createdAt = '创建时间';
  static const modifiedAt = '最后修改';
  static const calendarSyncTaskOff = '未同步（任务已关闭日历同步）';
  static const calendarSyncGlobalOff = '未同步（全局日历同步已关闭）';
  static const calendarSyncFailed = '日历同步失败';
  static const calendarSyncPending = '已开启同步（保存时写入日历）';
  static const calendarSynced = '已同步到系统日历';
  static const calendarSyncRetriedToast = '已重试日历同步';
  static const calendarGlobalOffHint = '全局日历同步已关闭，可在设置中开启';
  static const disableNotifHint = '关闭后不再触发本地提醒';
  static const disableTaskTitle = '关闭任务';
  static String disableTaskCalendarBody(String title) =>
      '「$title」已同步到系统日历。关闭任务将停止本地通知，日历事件要如何处理？';
  static const keepCalendarEvent = '保留日历事件';
  static const deleteCalendarEvent = '删除日历事件';

  // ---- 文本录入 ----
  static const textInputTitle = '文本录入';
  static const textInputHint = '例如：明天下午三点开会，提前15分钟';
  static const textParse = '解析';
  static const noDateTimeHint = '未识别到日期和时间，请在编辑页手动选择';
  static const noTimeHint = '未识别到具体时间，请在编辑页确认开始时间';

  // ---- 语音录入 ----
  static const voiceIdleHint = '点击麦克风开始说话\n例如：明天下午三点开会，提前15分钟';
  static const voicePreparing = '正在加载离线语音模型…';
  static const voiceRecordingHint = '正在录音，请说出提醒内容';
  static const voiceListening = '正在聆听…';
  static const voiceStop = '结束';
  static const voiceFinished = '识别完成';
  static const voiceRetry = '重新录音';
  static const voiceNext = '下一步';
  static const voicePermissionsTitle = '语音录入权限';
  static const permissionMic = '麦克风';
  static const permissionMicDetail = '用于离线语音识别录入提醒，全程本地处理';
  static const permissionGrant = '授权';
  static const permissionAllow = '允许';
  static const batteryOptimization = '电池优化白名单';
  static const batteryOptimizationDetail = '加入白名单可避免后台提醒被系统回收';
  static const batteryRequestFailed = '未能加入电池优化白名单，可稍后在系统设置中手动添加';
  static const vendorKillNote =
      '说明：部分厂商定制系统（MIUI/EMUI/ColorOS 等）存在后台查杀机制，'
      '即使加入白名单也无法 100% 保证后台唤醒，这是行业通用限制。'
      '建议同时开启通知与精确闹钟权限（设置 → 权限管理）。';
  static const asrModelMissing = '离线语音模型缺失，请在「设置 → 关于」中查看说明';
  static const asrErrorMicTitle = '未授予麦克风权限';
  static const asrErrorMicDetail = '需要麦克风权限才能录入语音，请授权后重试';
  static const asrErrorModelTitle = '离线语音模型缺失';
  static const asrErrorModelDetail = '模型文件缺失，请重新安装应用或联系开发者';
  static const asrErrorNoSpeechTitle = '未识别到有效语音';
  static const asrErrorNoSpeechDetail = '请靠近麦克风，语速平稳地说出提醒内容';
  static const asrErrorNoisyTitle = '收音环境噪音过大';
  static const asrErrorNoisyDetail = '请到安静的环境，或改用文字录入';
  static const asrGoPermissions = '前往授权';

  // ---- 权限中心 ----
  static const permissionGoSettings = '去设置';
  static const permissionsFootnote =
      '本应用仅申请与核心功能直接相关的权限：麦克风（语音录入）、日历（任务同步）、'
      '通知（定时提醒）、电池优化（后台保活）。不申请通讯录、位置、短信等任何无关权限，'
      '且无任何网络权限。';

  // ---- 重复规则 ----
  static const repeatNone = '单次';
  static const repeatDaily = '每天';
  static const repeatWeekly = '每周';
  static const repeatMonthly = '每月';
  static const repeatOnce = '一次性';

  // ---- 提前提醒 ----
  static const advance5 = '提前 5 分钟';
  static const advance10 = '提前 10 分钟';
  static const advance15 = '提前 15 分钟';
  static const advance30 = '提前 30 分钟';
  static const advance60 = '提前 1 小时';
  static const advanceCustom = '自定义';
  static const advanceAtTime = '准时提醒';
  static const advanceCustomTitle = '自定义提前时间';
  static const advanceCustomUnitMinute = '分钟';
  static const advanceCustomUnitHour = '小时';

  // ---- 设置 ----
  static const settingsVoice = '语音设置';
  static const settingsCalendar = '日历同步设置';
  static const settingsNotification = '通知提醒设置';
  static const settingsAppearance = '外观设置';
  static const settingsPermissions = '权限管理';
  static const settingsBackup = '备份与恢复';
  static const settingsAbout = '关于';
  static const settingsData = '数据管理';

  // ---- 日历同步设置 ----
  static const calendarSyncGlobalSwitch = '默认同步到系统日历';
  static const calendarSyncGlobalSubtitle = '新建任务时自动写入专属日历「离线语音提醒」';
  static const calendarDeleteDefaultSwitch = '删除任务时默认同步删除日历事件';
  static const calendarDeleteDefaultSubtitle = '可单独关闭，删除任务时改为仅删除 App 内任务';
  static const calendarDeleteDefaultOn = '删除任务时同步删除日历事件';
  static const calendarDeleteDefaultOff = '删除任务时保留日历事件';
  static const calendarStatusTitle = '专属日历状态';
  static const calendarStatusNoPermission = '未授予日历权限（请前往权限管理开启）';
  static const calendarStatusMissing = '专属日历已被删除（下次同步时自动重建）';
  static const calendarStatusNotCreated = '尚未创建（首次同步任务时自动创建）';
  static const resyncAllTitle = '立即同步全部任务';
  static const resyncAllSubtitle = '重新写入所有开启同步的任务（修复绑定、刷新时间）';
  static const deleteAppCalendarTitle = '删除专属日历';
  static const deleteAppCalendarBody = '将删除系统日历中的「离线语音提醒」日历及其中的全部事件，App 内任务保留。下次同步时自动重建。确定删除吗？';
  static const deleteAppCalendarSubtitle = '同时清空全部任务的日历事件绑定';
  static const deleteAppCalendarDone = '专属日历已删除';
  static const calendarOneWayNote =
      '说明：日历同步为单向（App 为主数据源）。在系统日历中手动修改事件，App 内不会自动更新，避免循环冲突。';
}
