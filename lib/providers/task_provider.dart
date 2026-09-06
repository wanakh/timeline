import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../services/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final taskNotifierProvider =
    AsyncNotifierProvider<TaskNotifier, List<Task>>(TaskNotifier.new);

class TaskNotifier extends AsyncNotifier<List<Task>> {
  late final TaskRepository _repository;

  @override
  Future<List<Task>> build() async {
    _repository = ref.read(taskRepositoryProvider);
    return _repository.getAll();
  }

  /// Taskを追加
  Future<void> addTask({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      startAt: startAt,
      endAt: endAt,
    );

    await _repository.add(task);
    await _reload();
  }

  /// Taskを更新
  Future<void> updateTask(Task task) async {
    await _repository.update(task);
    await _reload();
  }

  /// Taskを削除
  Future<void> deleteTask(String id) async {
    await _repository.delete(id);
    await _reload();
  }

  /// 完了状態を切り替え
  Future<void> toggleCompleted(String id) async {
    await _repository.toggleCompleted(id);
    await _reload();
  }

  Future<void> _reload() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _repository.getAll(),
    );
  }
}
