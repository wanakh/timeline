import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../services/local_notification_service.dart';
import '../services/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final taskNotifierProvider =
    AsyncNotifierProvider<TaskNotifier, List<Task>>(TaskNotifier.new);

class TaskNotifier extends AsyncNotifier<List<Task>> {
  late final TaskRepository _repository;

  final LocalNotificationService _notificationService =
      LocalNotificationService.instance;

  @override
  Future<List<Task>> build() async {
    _repository = ref.read(taskRepositoryProvider);

    await _notificationService.initialize();

    return _repository.getAll();
  }

  Future<void> addTask({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? reminderAt,
  }) async {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      startAt: startAt,
      endAt: endAt,
      reminderAt: reminderAt,
    );

    await _repository.add(task);

    await _notificationService.scheduleTaskReminder(task);

    await _reload();
  }

  Future<void> updateTask(Task task) async {
    await _notificationService.cancelTaskReminder(task);

    await _repository.update(task);

    await _notificationService.scheduleTaskReminder(task);

    await _reload();
  }

  Future<void> deleteTask(String id) async {
    final currentTasks = state.value ?? const <Task>[];

    Task? task;

    for (final item in currentTasks) {
      if (item.id == id) {
        task = item;
        break;
      }
    }

    if (task != null) {
      await _notificationService.cancelTaskReminder(task);
    }

    await _repository.delete(id);

    await _reload();
  }

  Future<void> toggleCompleted(String id) async {
    final currentTasks = state.value ?? const <Task>[];

    Task? oldTask;

    for (final task in currentTasks) {
      if (task.id == id) {
        oldTask = task;
        break;
      }
    }

    if (oldTask != null) {
      await _notificationService.cancelTaskReminder(oldTask);
    }

    await _repository.toggleCompleted(id);

    final updatedTasks = await _repository.getAll();

    Task? updatedTask;

    for (final task in updatedTasks) {
      if (task.id == id) {
        updatedTask = task;
        break;
      }
    }

    if (updatedTask != null) {
      await _notificationService.scheduleTaskReminder(updatedTask);
    }

    state = AsyncData(updatedTasks);
  }

  Future<void> _reload() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _repository.getAll(),
    );
  }
}
