import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  int _testTaskIndex = 0;

  Future<void> _addTestTask() async {
    final now = DateTime.now();

    final testTasks = [
      _TestTaskData(
        title: '時刻付きタスク',
        description: '時刻表示確認用のタスクです。',
        startDate: DateTime(
          now.year,
          now.month,
          now.day,
        ),
        endDate: DateTime(
          now.year,
          now.month,
          now.day,
        ),
        startAt: DateTime(
          now.year,
          now.month,
          now.day,
          9,
          0,
        ),
        endAt: null,
      ),
      _TestTaskData(
        title: '期間タスク',
        description: '期間表示確認用のタスクです。',
        startDate: DateTime(
          now.year,
          now.month,
          now.day - 3,
        ),
        endDate: DateTime(
          now.year,
          now.month,
          now.day + 1,
        ),
        startAt: DateTime(
          now.year,
          now.month,
          now.day - 3,
          10,
          0,
        ),
        endAt: DateTime(
          now.year,
          now.month,
          now.day + 1,
          18,
          0,
        ),
      ),
    ];

    final data = testTasks[_testTaskIndex % testTasks.length];

    await ref.read(taskNotifierProvider.notifier).addTask(
          title: data.title,
          description: data.description,
          startDate: data.startDate,
          endDate: data.endDate,
          startAt: data.startAt,
          endAt: data.endAt,
        );

    setState(() {
      _testTaskIndex++;
    });
  }

  Future<void> _toggleCompleted(Task task) async {
    await ref
        .read(taskNotifierProvider.notifier)
        .toggleCompleted(task.id);
  }

  Future<void> _showEditDialog(Task task) async {
    final result = await showDialog<_EditDialogResult>(
      context: context,
      builder: (context) {
        return _TaskEditDialog(task: task);
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.delete) {
      await _deleteTask(task);
      return;
    }

    await ref
        .read(taskNotifierProvider.notifier)
        .updateTask(result.task);
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Taskを削除しますか？'),
          content: Text(
            '「${task.title}」を削除します。\n'
            'この操作は元に戻せません。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await ref
        .read(taskNotifierProvider.notifier)
        .deleteTask(task.id);
  }

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              '読み込みに失敗しました\n$error',
            ),
          );
        },
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                '右下の＋からテストタスクを追加してください',
              ),
            );
          }

          return _TaskTimeline(
            tasks: tasks,
            onToggleCompleted: _toggleCompleted,
            onEdit: _showEditDialog,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTestTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TestTaskData {
  const _TestTaskData({
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.startAt,
    required this.endAt,
  });

  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? startAt;
  final DateTime? endAt;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.task,
    required this.displayDate,
    required this.isOriginalStart,
  });

  final Task task;
  final DateTime displayDate;
  final bool isOriginalStart;
}

/// タイムライン全体のレイアウトに使用する定数。
///
/// 日時欄だけに幅の制約を設け、Task側は残りの幅を利用する。
class _TimelineLayoutConstants {
  const _TimelineLayoutConstants._();

  /// スマートフォンとタブレットを分ける幅。
  static const double tabletBreakpoint = 600;

  /// スマートフォンで日時欄に使用する画面幅の割合。
  static const double dateColumnRatio = 0.28;

  /// 日時欄の最小幅。
  static const double minDateColumnWidth = 100;

  /// スマートフォンでの日時欄の最大幅。
  static const double maxPhoneDateColumnWidth = 125;

  /// タブレット以上での日時欄の幅。
  static const double tabletDateColumnWidth = 140;

  /// Timeline全体の左右余白。
  static const double horizontalPadding = 16;

  /// 日時欄とTimelineの間隔。
  static const double dateToTimelineSpacing = 12;

  /// Taskカード下側の間隔。
  static const double taskBottomSpacing = 16;

  static double dateColumnWidth(double availableWidth) {
    if (availableWidth >= tabletBreakpoint) {
      return tabletDateColumnWidth;
    }

    final calculatedWidth =
        availableWidth * dateColumnRatio;

    ///return calculatedWidth.clamp(
      ///minDateColumnWidth,
      ///maxPhoneDateColumnWidth,
    ///);

    return calculatedWidth;
  }
}

class _TaskTimeline extends StatelessWidget {
  const _TaskTimeline({
    required this.tasks,
    required this.onToggleCompleted,
    required this.onEdit,
  });

  final List<Task> tasks;
  final Future<void> Function(Task task) onToggleCompleted;
  final Future<void> Function(Task task) onEdit;

  static const double _maxTimelineWidth = 900;

  @override
  Widget build(BuildContext context) {
    final entries = _buildTimelineEntries(tasks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineWidth = constraints.maxWidth
            .clamp(0.0, _maxTimelineWidth);

        final dateColumnWidth =
            _TimelineLayoutConstants.dateColumnWidth(
          timelineWidth,
        );

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: timelineWidth,
            child: Timeline.tileBuilder(
              padding: const EdgeInsets.symmetric(
                horizontal:
                    _TimelineLayoutConstants.horizontalPadding,
                vertical: 24,
              ),
              builder: TimelineTileBuilder.connected(
                itemCount: entries.length,
                connectionDirection: ConnectionDirection.after,
                contentsAlign: ContentsAlign.basic,

                nodePositionBuilder: (context, index) {
                  // パディングを除いた実際のコンテンツ幅
                  final contentWidth = timelineWidth -
                      (_TimelineLayoutConstants.horizontalPadding * 2);

                  if (contentWidth <= 0) return 0.2;
                  // 日時カラムの幅が全体に占める割合を求める
                  final position = dateColumnWidth / contentWidth;

                  // 0.0 ~ 1.0 の範囲に収める
                  return position.clamp(0.0, 1.0);
                },

                oppositeContentsBuilder: (context, index) {
                  final entry = entries[index];

                  return SizedBox(
                    width: dateColumnWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right:
                            _TimelineLayoutConstants
                                .dateToTimelineSpacing,
                      ),
                      child: _DateTimeLabel(
                        entry: entry,
                        previousEntry:
                            index == 0
                                ? null
                                : entries[index - 1],
                      ),
                    ),
                  );
                },

                contentsBuilder: (context, index) {
                  final entry = entries[index];

                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      bottom:
                          _TimelineLayoutConstants
                              .taskBottomSpacing,
                    ),
                    child: _TaskCard(
                      task: entry.task,
                      onToggleCompleted: () {
                        return onToggleCompleted(entry.task);
                      },
                      onEdit: () {
                        return onEdit(entry.task);
                      },
                    ),
                  );
                },

                indicatorBuilder: (context, index) {
                  final task = entries[index].task;

                  return GestureDetector(
                    onTap: () {
                      onToggleCompleted(task);
                    },
                    child: DotIndicator(
                      color: task.isCompleted
                          ? Colors.grey
                          : null,
                    ),
                  );
                },

                connectorBuilder: (context, index, type) {
                  return const SolidLineConnector();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<_TimelineEntry> _buildTimelineEntries(
    List<Task> tasks,
  ) {
    final entries = <_TimelineEntry>[];

    final today = _dateOnly(DateTime.now());

    for (final task in tasks) {
      final startDate = _dateOnly(task.startDate);
      final endDate = _dateOnly(task.endDate);

      entries.add(
        _TimelineEntry(
          task: task,
          displayDate: startDate,
          isOriginalStart: true,
        ),
      );

      final isTodayInsidePeriod =
          startDate.isBefore(today) &&
          !endDate.isBefore(today);

      if (isTodayInsidePeriod) {
        entries.add(
          _TimelineEntry(
            task: task,
            displayDate: today,
            isOriginalStart: false,
          ),
        );
      }
    }

    entries.sort((a, b) {
      final dateCompare =
          a.displayDate.compareTo(b.displayDate);

      if (dateCompare != 0) {
        return dateCompare;
      }

      if (a.isOriginalStart != b.isOriginalStart) {
        return a.isOriginalStart ? -1 : 1;
      }

      final aTime = a.task.startAt;
      final bTime = b.task.startAt;

      if (aTime == null && bTime == null) {
        return 0;
      }

      if (aTime == null) {
        return -1;
      }

      if (bTime == null) {
        return 1;
      }

      return aTime.compareTo(bTime);
    });

    return entries;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggleCompleted,
    required this.onEdit,
  });

  final Task task;
  final Future<void> Function() onToggleCompleted;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: (_) {
                onToggleCompleted();
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                  ),
                  child: _TaskContent(
                    task: task,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeLabel extends StatelessWidget {
  const _DateTimeLabel({
    required this.entry,
    required this.previousEntry,
  });

  final _TimelineEntry entry;
  final _TimelineEntry? previousEntry;

  @override
  Widget build(BuildContext context) {
    final date = entry.displayDate;
    final previousDate = previousEntry?.displayDate;

    final isNewDate =
        previousDate == null ||
        !_isSameDate(date, previousDate);

    final dateText = isNewDate
        ? _formatDate(date)
        : null;

    final timeText = entry.task.startAt == null
        ? null
        : _formatTime(entry.task.startAt!);

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (dateText != null)
              Text(
                dateText,
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            if (timeText != null) ...[
              if (dateText != null)
                const SizedBox(height: 2),
              Text(
                timeText,
                textAlign: TextAlign.right,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (_isSameDate(date, today)) {
      return '${date.month}/${date.day} (今日)';
    }

    return '${date.month}/${date.day}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _TaskContent extends StatelessWidget {
  const _TaskContent({
    required this.task,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final textDecoration = task.isCompleted
        ? TextDecoration.lineThrough
        : TextDecoration.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: TextStyle(
            decoration: textDecoration,
          ),
        ),
        if (task.description != null &&
            task.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            task.description!,
            style: TextStyle(
              decoration: textDecoration,
            ),
          ),
        ],
        if (!_isSameDate(
          task.startDate,
          task.endDate,
        )) ...[
          const SizedBox(height: 8),
          Text(
            _formatPeriod(task),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  decoration: textDecoration,
                ),
          ),
        ],
      ],
    );
  }

  String _formatPeriod(Task task) {
    final startDate = task.startDate;
    final endDate = task.endDate;

    final startDateText =
        '${startDate.month}/${startDate.day}';

    final endDateText =
        '${endDate.month}/${endDate.day}';

    final startTime = task.startAt == null
        ? null
        : _formatTime(task.startAt!);

    final endTime = task.endAt == null
        ? null
        : _formatTime(task.endAt!);

    if (startTime != null && endTime != null) {
      return '$startDateText $startTime ～ '
          '$endDateText $endTime';
    }

    if (startTime != null) {
      return '$startDateText $startTime ～ '
          '$endDateText';
    }

    return '$startDateText ～ $endDateText';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _EditDialogResult {
  const _EditDialogResult({
    required this.task,
    required this.delete,
  });

  final Task task;
  final bool delete;
}

class _TaskEditDialog extends StatefulWidget {
  const _TaskEditDialog({
    required this.task,
  });

  final Task task;

  @override
  State<_TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<_TaskEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _startDate;
  late DateTime _endDate;

  DateTime? _startAt;
  DateTime? _endAt;

  String? _validationMessage;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(
      text: task.title,
    );

    _descriptionController = TextEditingController(
      text: task.description ?? '',
    );

    _startDate = _dateOnly(task.startDate);
    _endDate = _dateOnly(task.endDate);

    _startAt = task.startAt;
    _endAt = task.endAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = _dateOnly(selected);

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }

      _validationMessage = null;
    });
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate
          : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = _dateOnly(selected);
      _validationMessage = null;
    });
  }

  Future<void> _selectStartTime() async {
    final initialTime = _startAt == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(_startAt!);

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startAt = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        selected.hour,
        selected.minute,
      );

      _validationMessage = null;
    });
  }

  Future<void> _selectEndTime() async {
    final initialTime = _endAt == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(_endAt!);

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endAt = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        selected.hour,
        selected.minute,
      );

      _validationMessage = null;
    });
  }

  void _clearStartTime() {
    setState(() {
      _startAt = null;
      _endAt = null;
      _validationMessage = null;
    });
  }

  void _clearEndTime() {
    setState(() {
      _endAt = null;
      _validationMessage = null;
    });
  }

  void _save() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _validationMessage = 'タイトルを入力してください。';
      });
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      setState(() {
        _validationMessage =
            '終了日は開始日より前にできません。';
      });
      return;
    }

    if (_startAt != null &&
        _endAt != null &&
        _endDate == _startDate &&
        _endAt!.isBefore(_startAt!)) {
      setState(() {
        _validationMessage =
            '終了時刻は開始時刻より前にできません。';
      });
      return;
    }

    final updatedTask = Task(
      id: widget.task.id,
      title: title,
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      startAt: _startAt,
      endAt: _endAt,
      isCompleted: widget.task.isCompleted,
    );

    Navigator.of(context).pop(
      _EditDialogResult(
        task: updatedTask,
        delete: false,
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      _EditDialogResult(
        task: widget.task,
        delete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = _startAt != null;

    return AlertDialog(
      title: const Text('Taskを編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '日付',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _DateEditButton(
              label: '開始日',
              date: _startDate,
              onPressed: _selectStartDate,
            ),
            const SizedBox(height: 8),
            _DateEditButton(
              label: '終了日',
              date: _endDate,
              onPressed: _selectEndDate,
            ),
            const SizedBox(height: 20),
            Text(
              '時刻',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (!hasTime)
              OutlinedButton.icon(
                onPressed: _selectStartTime,
                icon: const Icon(Icons.access_time),
                label: const Text('時刻を設定'),
              )
            else ...[
              _TimeEditButton(
                label: '開始時刻',
                time: _startAt!,
                onPressed: _selectStartTime,
              ),
              const SizedBox(height: 8),
              _TimeEditButton(
                label: '終了時刻',
                time: _endAt,
                onPressed: _selectEndTime,
                clearEnabled: _endAt != null,
                onClear: _clearEndTime,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _clearStartTime,
                child: const Text(
                  '時刻を削除して日付のみの予定にする',
                ),
              ),
            ],
            if (_validationMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationMessage!,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _delete,
          child: const Text('削除'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}

class _DateEditButton extends StatelessWidget {
  const _DateEditButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          double.infinity,
          48,
        ),
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        '$label  ${_formatDate(date)}',
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

class _TimeEditButton extends StatelessWidget {
  const _TimeEditButton({
    required this.label,
    required this.time,
    required this.onPressed,
    this.clearEnabled = false,
    this.onClear,
  });

  final String label;
  final DateTime? time;
  final VoidCallback onPressed;
  final bool clearEnabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                0,
                48,
              ),
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              time == null
                  ? '$label  未設定'
                  : '$label  ${_formatTime(time!)}',
            ),
          ),
        ),
        if (clearEnabled && onClear != null)
          IconButton(
            onPressed: onClear,
            tooltip: '時刻を削除',
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}
