import 'package:intl/intl.dart';
import 'package:rido_data/rido_data.dart';

final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

/// Indian-locale rupees: formatInr(1420) → "₹1,420", formatInr(35000) → "₹35,000".
String formatInr(num amount) => '₹${_inr.format(amount.round())}';

/// Signed rupees for breakdown lines: "+₹3".
String formatInrSigned(num amount) => '${amount >= 0 ? '+' : '−'}${formatInr(amount.abs())}';

/// "3:28 PM"
String formatTime(DateTime t) => DateFormat('h:mm a').format(t);

/// "24 Oct 2026"
String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// "22 Sep"
String formatShortDate(DateTime d) => DateFormat('d MMM').format(d);

/// "Today, 3:28 PM", "Yesterday", "22 Sep" relative to the prototype's calendar day.
String formatRelativeDay(DateTime d, {bool withTime = false}) {
  final today = RidoClock.today;
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final label = switch (diff) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => formatShortDate(d),
  };
  return withTime ? '$label, ${formatTime(d)}' : label;
}

/// "4.2 km"
String formatKm(double km) => '${km.toStringAsFixed(1)} km';

/// "0:24" / "2:45" for countdowns.
String formatCountdown(Duration d) {
  final s = d.inSeconds.clamp(0, 359999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Indian number grouping without the rupee sign: 1240 → "1,240".
String formatCount(num n) => _inr.format(n);
