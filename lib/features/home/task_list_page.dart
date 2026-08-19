import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/task_repository.dart';
import '../../core/models/task.dart';
import '../../core/nlp/parser.dart';
import '../../l10n/strings.dart';
import '../../services/task_coordinator.dart';
import '../../state/task_list_state.dart';
import '../detail/task_detail_page.dart';
import '../edit/task_edit_page.dart';
import '../voice/voice_input_page.dart';
import 'task_list_item.dart';

/// 任务列表页（首页提醒 Tab）：
/// 分类筛选、升序排序、上拉分页、左滑删除、任务开关、语音/新建入口。
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      context.read<TaskListState>().loadMore();
    }
  }

  Future<void> _openEdit({Task? initial}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditPage(initial: initial)),
    );
    if (saved == true && mounted) {
      context.read<TaskListState>().refresh();
    }
  }

  Future<void> _delete(Task task) async {
    final settings = context.read<TaskCoordinator>().settings.settings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var deleteCalendar = settings.deleteCalendarDefault;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(S.deleteTaskTitle(task.title)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.deleteTaskConfirm(task.title)),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(S.deleteCalendarWithTask),
                  value: deleteCalendar,
                  onChanged: (v) =>
                      setState(() => deleteCalendar = v ?? true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(S.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(S.delete),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await context.read<TaskCoordinator>().deleteTask(
          task,
          deleteCalendarEvent: deleteCalendar,
        );
    if (mounted) {
      context.read<TaskListState>().refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.deletedToast(task.title))));
    }
  }

  /// 左滑快捷删除：按设置默认值处理日历事件。
  Future<void> _swipeDelete(Task task) async {
    final coordinator = context.read<TaskCoordinator>();
    await coordinator.deleteTask(
      task,
      deleteCalendarEvent: coordinator.settings.settings.deleteCalendarDefault,
    );
    if (mounted) {
      context.read<TaskListState>().refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.deletedToast(task.title))));
    }
  }

  Future<void> _toggle(Task task, bool enabled) async {
    final coordinator = context.read<TaskCoordinator>();
    // 关闭任务时：若已绑定日历事件，询问保留还是同步删除（需求 2.5）
    var deleteCalendarEvent = false;
    if (!enabled &&
        task.syncToCalendar &&
        task.calendarEventId != null &&
        coordinator.settings.settings.calendarSyncEnabled) {
      deleteCalendarEvent = await _askDeleteCalendarOnDisable(task) ?? false;
      if (!mounted) return;
    }
    await coordinator.toggleEnabled(task, enabled,
        deleteCalendarEvent: deleteCalendarEvent);
    if (mounted) context.read<TaskListState>().refresh();
  }

  Future<bool?> _askDeleteCalendarOnDisable(Task task) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.disableTaskTitle),
        content: Text(S.disableTaskCalendarBody(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(S.keepCalendarEvent),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(S.deleteCalendarEvent),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(Task task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
    );
    if (mounted) context.read<TaskListState>().refresh();
  }

  Future<void> _openVoice() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const VoiceInputPage()),
    );
    if (mounted) context.read<TaskListState>().refresh();
  }

  /// 文本快速录入（需求 1.4 兜底）：输入一句话 → 本地规则解析 → 预览编辑。
  Future<void> _openTextInput() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.textInputTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: S.textInputHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text(S.textParse),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;

    final parsed = parseNaturalLanguage(text, now: DateTime.now());
    if (!parsed.hasTime || !parsed.hasDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!parsed.hasDate && !parsed.hasTime
              ? S.noDateTimeHint
              : S.noTimeHint),
        ),
      );
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TaskEditPage(presets: TaskEditPresets.fromParsed(parsed)),
      ),
    );
    if (saved == true && mounted) {
      context.read<TaskListState>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = context.watch<TaskListState>();
    final visible = listState.visible;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.taskListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: S.textInput,
            onPressed: _openTextInput,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(listState),
          Expanded(
            child: visible.isEmpty
                ? _EmptyView(filter: listState.filter)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: visible.length + (listState.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final task = visible[index];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onDismissed: (_) => _swipeDelete(task),
                        child: TaskListItem(
                          task: task,
                          now: now,
                          onTap: () => _openDetail(task),
                          onToggle: (v) => _toggle(task, v),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'voice_fab',
            tooltip: S.voiceInput,
            onPressed: _openVoice,
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new_task_fab',
            onPressed: () => _openEdit(),
            icon: const Icon(Icons.add),
            label: const Text(S.newTask),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(TaskListState listState) {
    const filters = [
      (TaskFilter.all, S.filterAll),
      (TaskFilter.today, S.filterToday),
      (TaskFilter.future, S.filterFuture),
      (TaskFilter.expired, S.filterExpired),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];
          return ChoiceChip(
            label: Text(label),
            selected: listState.filter == filter,
            onSelected: (_) => listState.setFilter(filter),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});

  final TaskFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filter == TaskFilter.expired
                ? Icons.task_alt
                : Icons.notifications_none,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            filter == TaskFilter.all ? S.emptyTaskList : S.emptyFiltered,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
