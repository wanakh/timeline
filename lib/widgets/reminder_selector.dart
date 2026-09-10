import 'package:flutter/material.dart';

class ReminderSelector extends StatefulWidget {
  const ReminderSelector({
    super.key,
    required this.hasTime,
    this.initialMinutes,
    required this.onChanged,
  });

  final bool hasTime;
  final int? initialMinutes;
  final ValueChanged<int?> onChanged;

  @override
  State<ReminderSelector> createState() => _ReminderSelectorState();
}

class _ReminderSelectorState extends State<ReminderSelector> {
  int? _minutes;

  final TextEditingController _customValueController =
      TextEditingController();

  String _customUnit = '分';

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _updateCustomValue();
  }

  @override
  void dispose() {
    _customValueController.dispose();
    super.dispose();
  }

  void _select(int? minutes) {
    setState(() {
      _minutes = minutes;
    });

    widget.onChanged(minutes);
  }

  void _updateCustomValue() {
    final minutes = _minutes;

    if (minutes == null) {
      _customValueController.clear();
      return;
    }

    if (widget.hasTime && (minutes == 10 || minutes == 60)) {
      return;
    }

    if (!widget.hasTime && minutes == 1440) {
      return;
    }

    if (minutes % 1440 == 0) {
      _customUnit = '日';
      _customValueController.text = '${minutes ~/ 1440}';
    } else if (minutes % 60 == 0) {
      _customUnit = '時間';
      _customValueController.text = '${minutes ~/ 60}';
    } else {
      _customUnit = '分';
      _customValueController.text = '$minutes';
    }
  }

  void _applyCustom() {
    final value = int.tryParse(
      _customValueController.text.trim(),
    );

    if (value == null || value <= 0) {
      return;
    }

    final multiplier = switch (_customUnit) {
      '時間' => 60,
      '日' => 1440,
      _ => 1,
    };

    _select(value * multiplier);
  }

  @override
  Widget build(BuildContext context) {
    final customSelected = _minutes != null &&
        (widget.hasTime
            ? _minutes != 10 && _minutes != 60
            : _minutes != 1440);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'リマインダー',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        RadioGroup<int?>(
          groupValue: _minutes,
          onChanged: _select,
          child: Column(
            children: [
              RadioListTile<int?>(
                contentPadding: EdgeInsets.zero,
                title: const Text('なし'),
                value: null,
              ),

              if (widget.hasTime) ...[
                RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('10分前'),
                  value: 10,
                ),
                RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('1時間前'),
                  value: 60,
                ),
              ] else
                RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('1日前・朝9:00'),
                  value: 1440,
                ),

              RadioListTile<int?>(
                contentPadding: EdgeInsets.zero,
                title: const Text('カスタム'),
                value: customSelected ? _minutes : -1,
              ),
            ],
          ),
        ),

        if (customSelected || _minutes == -1) ...[
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _customValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '数値',
                  ),
                  onChanged: (_) => _applyCustom(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _customUnit,
                items: const [
                  DropdownMenuItem(
                    value: '分',
                    child: Text('分前'),
                  ),
                  DropdownMenuItem(
                    value: '時間',
                    child: Text('時間前'),
                  ),
                  DropdownMenuItem(
                    value: '日',
                    child: Text('日前'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _customUnit = value;
                  });

                  _applyCustom();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
