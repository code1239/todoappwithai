import 'package:intl/intl.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');
final _timeFmt = DateFormat('HH:mm');
final _dayFmt = DateFormat('d MMMM EEEE', 'tr_TR');
final _shortFmt = DateFormat('d MMM', 'tr_TR');

String fmtDate(DateTime d) => _dateFmt.format(d);
String fmtTime(DateTime d) => _timeFmt.format(d);

String fmtDayLabel(DateTime d) {
  final today = DateTime.now();
  if (_dateFmt.format(d) == _dateFmt.format(today)) return 'Bugun';
  if (_dateFmt.format(d) == _dateFmt.format(today.add(const Duration(days: 1)))) {
    return 'Yarin';
  }
  try {
    return _dayFmt.format(d);
  } catch (_) {
    return _dateFmt.format(d);
  }
}

String fmtShort(DateTime d) => _shortFmt.format(d);

DateTime weekStartOf(DateTime d) {
  final monday = d.subtract(Duration(days: (d.weekday - 1)));
  return DateTime(monday.year, monday.month, monday.day);
}

DateTime parseDay(String s) => DateTime.parse(s);
