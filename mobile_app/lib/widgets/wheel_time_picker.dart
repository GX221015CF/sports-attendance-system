import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays a 24-hour, minute-precision picker and returns a value only after
/// the user confirms their selection.
Future<TimeOfDay?> showWheelTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) async {
  final hourController = FixedExtentScrollController(
    initialItem: initialTime.hour,
  );
  final minuteController = FixedExtentScrollController(
    initialItem: initialTime.minute,
  );
  var selectedHour = initialTime.hour;
  var selectedMinute = initialTime.minute;

  try {
    return await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final pickerHeight = (screenHeight * 0.34).clamp(140.0, 210.0);

        return SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppTheme.textStrong,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(
                            TimeOfDay(
                              hour: selectedHour,
                              minute: selectedMinute,
                            ),
                          ),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('小时', textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 36),
                        const Expanded(
                          child: Text('分钟', textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: pickerHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: hourController,
                              itemExtent: 38,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(),
                              onSelectedItemChanged: (value) {
                                selectedHour = value;
                              },
                              children: List.generate(
                                24,
                                (hour) => Center(
                                  child: Text(hour.toString().padLeft(2, '0')),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              ':',
                              style: TextStyle(
                                color: AppTheme.textStrong,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: minuteController,
                              itemExtent: 38,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(),
                              onSelectedItemChanged: (value) {
                                selectedMinute = value;
                              },
                              children: List.generate(
                                60,
                                (minute) => Center(
                                  child: Text(
                                    minute.toString().padLeft(2, '0'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  } finally {
    hourController.dispose();
    minuteController.dispose();
  }
}
