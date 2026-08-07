import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/time_service.dart';

void main() {
  final service = TimeService();
  final requiredTime = DateTime(2026, 8, 7, 18);
  final endTime = DateTime(2026, 8, 7, 19);

  test('required time or earlier is a normal check-in', () {
    final preview = service.previewCheckin(
      now: requiredTime,
      requiredTime: requiredTime,
      endTime: endTime,
    );

    expect(preview.canCheckin, isTrue);
    expect(preview.status, 'normal');
    expect(preview.lateMinutes, 0);
  });

  test('after required time is a late check-in', () {
    final preview = service.previewCheckin(
      now: requiredTime.add(const Duration(minutes: 12)),
      requiredTime: requiredTime,
      endTime: endTime,
    );

    expect(preview.canCheckin, isTrue);
    expect(preview.status, 'late');
    expect(preview.lateMinutes, 12);
  });

  test('after end time cannot check in', () {
    final preview = service.previewCheckin(
      now: endTime.add(const Duration(seconds: 1)),
      requiredTime: requiredTime,
      endTime: endTime,
    );

    expect(preview.canCheckin, isFalse);
    expect(preview.status, 'closed');
  });
}
