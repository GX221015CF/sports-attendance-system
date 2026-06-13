import 'package:intl/intl.dart';

final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

String formatDateTime(DateTime value) {
  return _dateTimeFormat.format(value);
}
