const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Monday, 28 September" (Home greeting).
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "Good morning" (5 AM to noon), "Good afternoon" (noon to 6 PM), otherwise "Good evening".
String timeGreeting(DateTime t) => switch (t.hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 18 => 'Good afternoon',
      _ => 'Good evening',
    };

/// "10:32 AM"
String clockTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today", "Yesterday", "Mon 28 Sep", or "Mon 28 Sep 2025" for another year.
String dayName(DateTime t, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  final short = '${_weekdays[t.weekday - 1].substring(0, 3)} ${t.day} ${_months[t.month - 1].substring(0, 3)}';
  return t.year == today.year ? short : '$short ${t.year}';
}

/// "Today, 10:32 AM"
String dayAndTime(DateTime t, {DateTime? now}) => '${dayName(t, now: now)}, ${clockTime(t)}';

/// "under a minute", "12 min", "1 h 5 min"
String durationLabel(Duration d) {
  if (d.inMinutes < 1) return 'under a minute';
  if (d.inHours < 1) return '${d.inMinutes} min';
  final minutes = d.inMinutes % 60;
  return minutes == 0 ? '${d.inHours} h' : '${d.inHours} h $minutes min';
}
