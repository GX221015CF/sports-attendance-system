import 'package:intl/intl.dart';

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

String formatDateTime(DateTime value) {
  return _dateTimeFormat.format(value);
}

String formatTrainingSessionTitle(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}_$month$day训练';
}
