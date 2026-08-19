import '../core/db/task_repository.dart';
import '../core/models/task.dart';
import 'app_state.dart';

/// 任务列表页状态：分类筛选 + 本地分页。
class TaskListState extends BaseNotifier {
  TaskListState(this.repo);

  final TaskRepository repo;

  TaskFilter _filter = TaskFilter.all;
  int _visibleCount = TaskRepository.pageSize;

  TaskFilter get filter => _filter;

  /// 当前可见任务（已按开始时间升序，分页截断）。
  List<Task> get visible =>
      repo.query(_filter, DateTime.now(), limit: _visibleCount);

  int get totalCount => repo.count(_filter, DateTime.now());

  bool get hasMore => _visibleCount < totalCount;

  void setFilter(TaskFilter f) {
    _filter = f;
    _visibleCount = TaskRepository.pageSize;
    notifyListeners();
  }

  void loadMore() {
    _visibleCount += TaskRepository.pageSize;
    notifyListeners();
  }

  /// 数据变更后刷新（保存/删除/开关切换后调用）。
  void refresh() => notifyListeners();
}
