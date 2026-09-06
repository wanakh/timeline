import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('予定'),
      ),
      body: taskState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) {
          return Center(
            child: Text('読み込みに失敗しました\n$error'),
          );
        },
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text('予定はありません'),
            );
          }

          return _TaskTimeline(tasks: tasks);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref
              .read(taskNotifierProvider.notifier)
              .addTask(
                title: 'テストタスク',
                description: 'Timeline表示確認用のタスクです。',
                startDate: DateTime.now(),
                endDate: DateTime.now(),
              );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// すべてのTaskを1つのTimelineに表示する。
class _TaskTimeline extends StatelessWidget {
  const _TaskTimeline({
    required this.tasks,
  });

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final items = _buildTimelineItems(tasks);

    return Timeline.tileBuilder(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 24,
      ),
      builder: TimelineTileBuilder.connected(
        itemCount: items.length,
        connectionDirection: ConnectionDirection.after,
        contentsAlign: ContentsAlign.basic,

        oppositeContentsBuilder: (context, index) {
          return const SizedBox.shrink();
        },

        contentsBuilder: (context, index) {
          final item = items[index];

          if (item.isDateHeader) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ),
              child: _DateHeader(
                date: item.date!,
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(
              left: 12,
              bottom: 16,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _TaskContent(
                  task: item.task!,
                ),
              ),
            ),
          );
        },

        indicatorBuilder: (context, index) {
          final item = items[index];

          if (item.isDateHeader) {
            return const SizedBox(
              width: 1,
              height: 1,
            );
          }

          return const DotIndicator();
        },

        connectorBuilder: (context, index, type) {
          final item = items[index];

          if (item.isDateHeader) {
            return const SizedBox.shrink();
          }

          return const SolidLineConnector();
        },
      ),
    );
  }

  List<_TimelineItem> _buildTimelineItems(List<Task> tasks) {
    final grouped = <DateTime, List<Task>>{};

    for (final task in tasks) {
      final date = DateTime(
        task.startDate.year,
        task.startDate.month,
        task.startDate.day,
      );

      grouped.putIfAbsent(date, () => []).add(task);
    }

    final dates = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final items = <_TimelineItem>[];

    for (final date in dates) {
      items.add(
        _TimelineItem.dateHeader(date),
      );

      for (final task in grouped[date]!) {
        items.add(
          _TimelineItem.task(task),
        );
      }
    }

    return items;
  }
}

/// Timeline上の1項目。
class _TimelineItem {
  const _TimelineItem.dateHeader(this.date)
      : task = null,
        isDateHeader = true;

  const _TimelineItem.task(this.task)
      : date = null,
        isDateHeader = false;

  final DateTime? date;
  final Task? task;
  final bool isDateHeader;
}

/// 日付ヘッダー。
class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dateOnly = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final isToday = dateOnly == today;

    final text = isToday
        ? '${date.month}/${date.day} (今日)'
        : '${date.month}/${date.day}';

    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Taskの内容。
class _TaskContent extends StatelessWidget {
  const _TaskContent({
    required this.task,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
        ),
        if (task.description != null &&
            task.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(task.description!),
        ],
      ],
    );
  }
}

