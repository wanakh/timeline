import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/task_validator.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  Future<void> _showCreateDialog() async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (context) => const _TaskCreateDialog(),
    );

    if (!mounted || draft == null) {
      return;
    }

    try {
      await ref.read(taskNotifierProvider.notifier).addTask(
            title: draft.title,
            description: draft.description,
            startDate: draft.startDate,
            endDate: draft.endDate,
            startAt: draft.startAt,
            endAt: draft.endAt,
            reminderAt: draft.reminderAt,
          );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ?? '入力を確認してください。',
          ),
        ),
      );
    }
  }

  Future<void> _toggleCompleted(Task task) async {
    await ref.read(taskNotifierProvider.notifier).toggleCompleted(task.id);
  }

  Future<void> _showEditDialog(Task task) async {
    final result = await showDialog<_EditDialogResult>(
      context: context,
      builder: (context) => _TaskEditDialog(task: task),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.delete) {
      await _deleteTask(task);
      return;
    }

    await ref.read(taskNotifierProvider.notifier).updateTask(result.task);
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('タスクを削除しますか？'),
          content: Text(
            '「${task.title}」を削除します。\n'
            'この操作は元に戻せません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
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
            child: Text('読み込みに失敗しました\n$error'),
          );
        },
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text('右下の＋からタスクを追加してください'),
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
        onPressed: _showCreateDialog,
        tooltip: 'タスクを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TimelineEntry {
  final Task? task;
  final DateTime displayDate;
  final bool isOriginalStart;
  final bool isTodayMarker;

  const _TimelineEntry({
    required this.task,
    required this.displayDate,
    this.isOriginalStart = true,
    this.isTodayMarker = false,
  });
}

class _TimelineLayoutConstants {
  const _TimelineLayoutConstants._();

  static const double tabletBreakpoint = 600;

  // 日付・時刻表示領域
  static const double dateColumnRatio = 0.28;
  static const double minDateColumnWidth = 100;
  static const double maxPhoneDateColumnWidth = 125;
  static const double tabletDateColumnWidth = 140;

  // 全体
  static const double horizontalPadding = 16;

  // 日付・時刻 → タイムライン
  static const double dateToTimelineSpacing = 12;

  // タイムライン
  static const double timelineColumnWidth = 24;
  static const double timelineLineWidth = 2;
  static const double nodeSize = 12;

  // タイムライン → タスク
  static const double timelineToTaskSpacing = 12;

  // タスク間
  static const double taskBottomSpacing = 16;

  static double dateColumnWidth(double availableWidth) {
    if (availableWidth >= tabletBreakpoint) {
      return tabletDateColumnWidth;
    }

    final calculatedWidth = availableWidth * dateColumnRatio;

    return calculatedWidth.clamp(
      minDateColumnWidth,
      maxPhoneDateColumnWidth,
    );
  }
}

class _TaskTimeline extends StatefulWidget {
  const _TaskTimeline({
    required this.tasks,
    required this.onToggleCompleted,
    required this.onEdit,
  });

  final List<Task> tasks;
  final Future<void> Function(Task task) onToggleCompleted;
  final Future<void> Function(Task task) onEdit;

  @override
  State<_TaskTimeline> createState() => _TaskTimelineState();
}

class _TaskTimelineState extends State<_TaskTimeline> {
  static const double _maxTimelineWidth = 900;

  final ScrollController _scrollController = ScrollController();

  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialPosition();
    });
  }

  @override
  void didUpdateWidget(covariant _TaskTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tasks != widget.tasks) {
      _initialScrollDone = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialPosition();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToInitialPosition() {
    if (!mounted || _initialScrollDone) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final entries = _buildTimelineEntries(widget.tasks);

    if (entries.isEmpty) {
      return;
    }

    final targetIndex = _findInitialTargetIndex(entries);

    const estimatedItemHeight = 100.0;

    final targetOffset = targetIndex * estimatedItemHeight;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    final safeOffset = targetOffset.clamp(
      0.0,
      maxScrollExtent,
    );

    _scrollController.jumpTo(safeOffset);

    _initialScrollDone = true;
  }

  int _findInitialTargetIndex(List<_TimelineEntry> entries) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final todayTaskIndices = <int>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry.task == null) {
        continue;
      }

      if (DateUtils.isSameDay(entry.displayDate, today)) {
        todayTaskIndices.add(i);
      }
    }

    if (todayTaskIndices.isEmpty) {
      final markerIndex = entries.indexWhere(
        (entry) => entry.isTodayMarker,
      );

      if (markerIndex != -1) {
        return markerIndex;
      }

      return 0;
    }

    final timedTodayIndices = <int>[];

    for (final index in todayTaskIndices) {
      final task = entries[index].task!;

      if (task.startAt != null) {
        timedTodayIndices.add(index);
      }
    }

    if (timedTodayIndices.isEmpty) {
      return todayTaskIndices.first;
    }

    for (final index in timedTodayIndices) {
      final task = entries[index].task!;
      final startAt = task.startAt!;

      if (!startAt.isBefore(now)) {
        return index;
      }
    }

    return timedTodayIndices.last;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildTimelineEntries(widget.tasks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineWidth = constraints.maxWidth.clamp(
          0.0,
          _maxTimelineWidth,
        );

        final dateColumnWidth =
            _TimelineLayoutConstants.dateColumnWidth(
          timelineWidth,
        );

        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: timelineWidth,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: _TimelineLayoutConstants.horizontalPadding,
                vertical: 24,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _TimelineListItem(
                  entry: entries[index],
                  previousEntry:
                      index == 0 ? null : entries[index - 1],
                  isLast: index == entries.length - 1,
                  dateColumnWidth: dateColumnWidth,
                  onToggleCompleted: widget.onToggleCompleted,
                  onEdit: widget.onEdit,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TimelineListItem extends StatelessWidget {
  const _TimelineListItem({
    required this.entry,
    required this.previousEntry,
    required this.isLast,
    required this.dateColumnWidth,
    required this.onToggleCompleted,
    required this.onEdit,
  });

  final _TimelineEntry entry;
  final _TimelineEntry? previousEntry;
  final bool isLast;
  final double dateColumnWidth;

  final Future<void> Function(Task task) onToggleCompleted;
  final Future<void> Function(Task task) onEdit;

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: isLast
              ? 0
              : _TimelineLayoutConstants.taskBottomSpacing,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 日付・時刻
            SizedBox(
              width: dateColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: _TimelineLayoutConstants.dateToTimelineSpacing,
                ),
                child: _DateTimeLabel(
                  entry: entry,
                  previousEntry: previousEntry,
                ),
              ),
            ),

            // タイムライン
            SizedBox(
              width: _TimelineLayoutConstants.timelineColumnWidth,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 線はタスク間の余白まで延長する。
                  //
                  // 各行の線が次の行の先頭まで届くため、
                  // タスク間で線が途切れない。
                  if (!isLast)
                    Positioned(
                      top: 0,
                      left: (_TimelineLayoutConstants
                                  .timelineColumnWidth -
                              _TimelineLayoutConstants
                                  .timelineLineWidth) /
                          2,
                      bottom: -_TimelineLayoutConstants
                          .taskBottomSpacing,
                      child: Container(
                        width:
                            _TimelineLayoutConstants.timelineLineWidth,
                        color: colorScheme.outlineVariant,
                      ),
                    )
                  else
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: (_TimelineLayoutConstants
                                  .timelineColumnWidth -
                              _TimelineLayoutConstants
                                  .timelineLineWidth) /
                          2,
                      child: Container(
                        width:
                            _TimelineLayoutConstants.timelineLineWidth,
                        color: colorScheme.outlineVariant,
                      ),
                    ),

                  // タスクノード
                  if (task != null)
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggleCompleted(task),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width:
                                  _TimelineLayoutConstants.nodeSize,
                              height:
                                  _TimelineLayoutConstants.nodeSize,
                              decoration: BoxDecoration(
                                color: task.isCompleted
                                    ? Colors.grey
                                    : colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              width: _TimelineLayoutConstants.timelineToTaskSpacing,
            ),

            // タスク本文
            if (task != null)
              Expanded(
                child: InkWell(
                  onTap: () => onEdit(task),
                  borderRadius: BorderRadius.zero,
                  child: _TaskContent(
                    task: task,
                  ),
                ),
              )
            else
              const Expanded(
                child: SizedBox(
                  height: 40,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<_TimelineEntry> _buildTimelineEntries(List<Task> tasks) {
  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final entries = <_TimelineEntry>[];

  for (final task in tasks) {
    entries.add(
      _TimelineEntry(
        task: task,
        displayDate: _dateOnly(task.startDate),
        isOriginalStart: true,
      ),
    );
  }

  // 今日の位置を確保するためのマーカー。
  // タスクを複製するのではなく、今日という日付だけを表示する。
  entries.add(
    _TimelineEntry(
      task: null,
      displayDate: today,
      isOriginalStart: false,
      isTodayMarker: true,
    ),
  );

  entries.sort((a, b) {
    final dateCompare = a.displayDate.compareTo(b.displayDate);

    if (dateCompare != 0) {
      return dateCompare;
    }

    // 今日マーカーは、その日の先頭に置く。
    if (a.isTodayMarker != b.isTodayMarker) {
      return a.isTodayMarker ? -1 : 1;
    }

    final aTask = a.task;
    final bTask = b.task;

    if (aTask == null || bTask == null) {
      return 0;
    }

    final aStartAt = aTask.startAt;
    final bStartAt = bTask.startAt;

    // 日付のみのタスクを先に表示。
    if (aStartAt == null && bStartAt != null) {
      return -1;
    }

    if (aStartAt != null && bStartAt == null) {
      return 1;
    }

    // 時刻ありの場合は開始時刻順。
    if (aStartAt != null && bStartAt != null) {
      final timeCompare = _timeOnly(aStartAt).compareTo(
        _timeOnly(bStartAt),
      );

      if (timeCompare != 0) {
        return timeCompare;
      }
    }

    // 同条件の場合は元の開始日時で安定させる。
    return aTask.startDate.compareTo(bTask.startDate);
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

DateTime _timeOnly(DateTime date) {
  return DateTime(
    2000,
    1,
    1,
    date.hour,
    date.minute,
  );
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
    final task = entry.task;
    final date = entry.displayDate;

    final isToday = DateUtils.isSameDay(
      date,
      DateTime.now(),
    );

    final dateText = isToday
        ? '${date.month}/${date.day} (今日)'
        : '${date.month}/${date.day}';

    if (task == null) {
      return Align(
        alignment: Alignment.topRight,
        child: Text(
          dateText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
      );
    }

    // 期間タスク
    if (!_isSameDate(task.startDate, task.endDate)) {
      final periodText =
          '${task.startDate.month}/${task.startDate.day}'
          ' ～ '
          '${task.endDate.month}/${task.endDate.day}';

      return Align(
        alignment: Alignment.topRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              periodText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
            if (task.startAt != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatPeriodTime(task),
                style: const TextStyle(
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ],
        ),
      );
    }

    final isFirstEntryOfDay =
        previousEntry == null ||
        !DateUtils.isSameDay(
          previousEntry!.displayDate,
          entry.displayDate,
        );

    if (!isFirstEntryOfDay && task.startAt == null) {
      return const SizedBox.shrink();
    }

    final startAt = task.startAt;
    final endAt = task.endAt;

    String? timeText;

    if (startAt != null && endAt != null) {
      timeText =
          '${_formatTime(startAt)} ～ ${_formatTime(endAt)}';
    } else if (startAt != null) {
      timeText = _formatTime(startAt);
    }

    return Align(
      alignment: Alignment.topRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isFirstEntryOfDay)
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          if (timeText != null) ...[
            if (isFirstEntryOfDay)
              const SizedBox(height: 2),
            Text(
              timeText,
              style: const TextStyle(
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }

  String _formatPeriodTime(Task task) {
    final startAt = task.startAt;
    final endAt = task.endAt;

    if (startAt != null && endAt != null) {
      return '${_formatTime(startAt)} ～ ${_formatTime(endAt)}';
    }

    if (startAt != null) {
      return _formatTime(startAt);
    }

    if (endAt != null) {
      return _formatTime(endAt);
    }

    return '';
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

    final textColor = task.isCompleted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
              color: textColor,
              decoration: textDecoration,
            ),
          ),
          if (task.description != null &&
              task.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description!,
              style: TextStyle(
                color: textColor,
                decoration: textDecoration,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.startAt,
    required this.endAt,
    required this.reminderAt,
  });

  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? reminderAt;
}

class _TaskCreateDialog extends StatefulWidget {
  const _TaskCreateDialog();

  @override
  State<_TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<_TaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;

  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _reminderAt;

  String? _dateTimeError;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _startDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _endDate = _startDate;
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

      _startAt = _withDate(
        _startDate,
        _startAt,
      );

      _endAt = _withDate(
        _endDate,
        _endAt,
      );

      // 基準日時が変わったため、既存のリマインダーは解除。
      _reminderAt = null;

      _validateDateAndTime();
    });
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = _dateOnly(selected);

      _endAt = _withDate(
        _endDate,
        _endAt,
      );

      _reminderAt = null;

      _validateDateAndTime();
    });
  }

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_startAt!),
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

      _reminderAt = null;

      _validateDateAndTime();
    });
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_endAt!),
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

      _reminderAt = null;

      _validateDateAndTime();
    });
  }

  void _validateDateAndTime() {
    _dateTimeError = TaskValidator.validate(
      title: 'valid title',
      startDate: _startDate,
      endDate: _endDate,
      startAt: _startAt,
      endAt: _endAt,
    );
  }

  void _save() {
    _validateDateAndTime();

    final formIsValid = _formKey.currentState!.validate();

    if (!formIsValid || _dateTimeError != null) {
      setState(() {});
      return;
    }

    if (_reminderAt != null &&
        !_reminderAt!.isAfter(DateTime.now())) {
      setState(() {
        _dateTimeError = 'リマインダーは現在より後の日時を指定してください。';
      });
      return;
    }

    Navigator.of(context).pop(
      _TaskDraft(
        title: _titleController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        startAt: _startAt,
        endAt: _endAt,
        reminderAt: _reminderAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = _startAt != null;

    return AlertDialog(
      title: const Text('タスクを追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: TaskValidator.maxTitleLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                autovalidateMode:
                    AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => TaskValidator.validate(
                  title: value ?? '',
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: TaskValidator.maxDescriptionLength,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                autovalidateMode:
                    AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: '説明（任意・100字以内）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => TaskValidator.validate(
                  title: 'valid title',
                  description: value,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '日付',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              const SizedBox(height: 16),
              Text(
                '時刻',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (!hasTime)
                OutlinedButton.icon(
                  onPressed: _selectStartTime,
                  icon: const Icon(Icons.access_time),
                  label: const Text('時間を設定'),
                )
              else ...[
                _TimeEditButton(
                  label: '開始時刻',
                  time: _startAt,
                  onPressed: _selectStartTime,
                ),
                const SizedBox(height: 8),
                _TimeEditButton(
                  label: '終了時刻',
                  time: _endAt,
                  onPressed: _selectEndTime,
                  clearEnabled: _endAt != null,
                  onClear: () {
                    setState(() {
                      _endAt = null;
                      _reminderAt = null;
                      _validateDateAndTime();
                    });
                  },
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startAt = null;
                      _endAt = null;
                      _reminderAt = null;
                      _validateDateAndTime();
                    });
                  },
                  child: const Text(
                    '時刻を削除して日付のみの予定にする',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _ReminderSelector(
                initialReminderAt: _reminderAt,
                onChanged: (value) {
                  setState(() {
                    _reminderAt = value;
                  });
                },
              ),
              if (_dateTimeError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dateTimeError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('追加'),
        ),
      ],
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  DateTime? _withDate(
    DateTime date,
    DateTime? time,
  ) {
    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
  DateTime? _reminderAt;

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
    _reminderAt = task.reminderAt;
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

      _startAt = _withDate(
        _startDate,
        _startAt,
      );

      _endAt = _withDate(
        _endDate,
        _endAt,
      );

      _reminderAt = null;
      _validationMessage = null;
    });
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = _dateOnly(selected);

      _endAt = _withDate(
        _endDate,
        _endAt,
      );

      _reminderAt = null;
      _validationMessage = null;
    });
  }

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_startAt!),
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

      _reminderAt = null;
      _validationMessage = null;
    });
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_endAt!),
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

      _reminderAt = null;
      _validationMessage = null;
    });
  }

  void _clearStartTime() {
    setState(() {
      _startAt = null;
      _endAt = null;
      _reminderAt = null;
      _validationMessage = null;
    });
  }

  void _clearEndTime() {
    setState(() {
      _endAt = null;
      _reminderAt = null;
      _validationMessage = null;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    final validationMessage = TaskValidator.validate(
      title: title,
      description: description,
      startDate: _startDate,
      endDate: _endDate,
      startAt: _startAt,
      endAt: _endAt,
    );

    if (validationMessage != null) {
      setState(() {
        _validationMessage = validationMessage;
      });
      return;
    }

    if (_reminderAt != null &&
        !_reminderAt!.isAfter(DateTime.now())) {
      setState(() {
        _validationMessage =
            'リマインダーは現在より後の日時を指定してください。';
      });
      return;
    }

    final updatedTask = Task(
      id: widget.task.id,
      title: title,
      description: description.isEmpty ? null : description,
      startDate: _startDate,
      endDate: _endDate,
      startAt: _startAt,
      endAt: _endAt,
      isCompleted: widget.task.isCompleted,
      reminderAt: _reminderAt,
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
      title: const Text('タスクを編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: TaskValidator.maxTitleLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: TaskValidator.maxDescriptionLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              decoration: const InputDecoration(
                labelText: '説明（任意・100字以内）',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '日付',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                time: _startAt,
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
            const SizedBox(height: 16),
            _ReminderSelector(
              initialReminderAt: _reminderAt,
              onChanged: (value) {
                setState(() {
                  _reminderAt = value;
                });
              },
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
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
          onPressed: () => Navigator.of(context).pop(),
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

  DateTime? _withDate(
    DateTime date,
    DateTime? time,
  ) {
    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }
}

/// リマインダーの選択UI。
///
/// リマインダーは「なし」または「カスタム日時」の2択とする。
/// 保存する値は常に絶対日時(DateTime)で、相対的なプリセットは持たない。
class _ReminderSelector extends StatefulWidget {
  const _ReminderSelector({
    required this.initialReminderAt,
    required this.onChanged,
  });

  final DateTime? initialReminderAt;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<_ReminderSelector> createState() => _ReminderSelectorState();
}

class _ReminderSelectorState extends State<_ReminderSelector> {
  static const String _none = 'none';
  static const String _custom = 'custom';

  String _selectedValue = _none;
  DateTime? _selectedReminderAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedReminderAt = widget.initialReminderAt;
    _selectedValue =
        widget.initialReminderAt == null ? _none : _custom;
  }

  @override
  void didUpdateWidget(
    covariant _ReminderSelector oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialReminderAt != widget.initialReminderAt) {
      _selectedReminderAt = widget.initialReminderAt;
      _selectedValue =
          widget.initialReminderAt == null ? _none : _custom;
      _errorMessage = null;
    }
  }

  void _selectNone() {
    setState(() {
      _selectedValue = _none;
      _selectedReminderAt = null;
      _errorMessage = null;
    });

    widget.onChanged(null);
  }

  Future<void> _selectCustom() async {
    final previousValue = _selectedValue;
    final previousReminderAt = _selectedReminderAt;

    final now = DateTime.now();
    final initialDateTime = previousReminderAt != null &&
            previousReminderAt.isAfter(now)
        ? previousReminderAt
        : now.add(const Duration(minutes: 10));

    final selected = await _pickCustomDateTime(
      initialDateTime: initialDateTime,
    );

    if (!mounted) {
      return;
    }

    if (selected == null) {
      setState(() {
        _selectedValue = previousValue;
        _selectedReminderAt = previousReminderAt;
      });
      return;
    }

    if (!selected.isAfter(DateTime.now())) {
      setState(() {
        _selectedValue = previousValue;
        _selectedReminderAt = previousReminderAt;
        _errorMessage = '現在より後の日時を指定してください。';
      });
      return;
    }

    setState(() {
      _selectedValue = _custom;
      _selectedReminderAt = selected;
      _errorMessage = null;
    });

    widget.onChanged(selected);
  }

  Future<DateTime?> _pickCustomDateTime({
    required DateTime initialDateTime,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final initialDate = initialDateTime.isBefore(today)
        ? today
        : DateTime(
            initialDateTime.year,
            initialDateTime.month,
            initialDateTime.day,
          );

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) {
      return null;
    }

    final currentNow = DateTime.now();
    final isToday = DateUtils.isSameDay(
      selectedDate,
      currentNow,
    );

    final defaultInitialTime = currentNow.add(
      const Duration(minutes: 10),
    );

    final initialTime = isToday
        ? TimeOfDay.fromDateTime(defaultInitialTime)
        : TimeOfDay.fromDateTime(initialDateTime);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime == null || !mounted) {
      return null;
    }

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!selectedDateTime.isAfter(DateTime.now())) {
      setState(() {
        _errorMessage = '現在より後の日時を指定してください。';
      });
      return null;
    }

    return selectedDateTime;
  }

  String _formatDateTime(DateTime value) {
    final date = '${value.year}/${value.month}/${value.day}';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$date $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'リマインダー',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _selectedValue,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            switch (value) {
              case _none:
                _selectNone();
                break;
              case _custom:
                _selectCustom();
                break;
            }
          },
          child: Column(
            children: [
              const RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('なし'),
                value: _none,
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('カスタム'),
                subtitle: _selectedReminderAt == null
                    ? const Text('日時を指定')
                    : Text(
                        _formatDateTime(_selectedReminderAt!),
                      ),
                value: _custom,
              ),
            ],
          ),
        ),
        if (_selectedValue == _custom && _selectedReminderAt != null) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _selectCustom,
            icon: const Icon(Icons.edit_calendar),
            label: const Text('日時を変更'),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
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
        minimumSize: const Size(double.infinity, 48),
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
              minimumSize: const Size(0, 48),
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
