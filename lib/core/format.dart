String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatDuration(int ms) {
  if (ms <= 0) return '0:00';
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

String formatDurationPrecise(int ms) {
  final base = formatDuration(ms);
  final tenths = (ms % 1000) ~/ 100;
  return '$base.$tenths';
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}

String formatPercent(double fraction) => '${(fraction * 100).round()}%';

String formatEta(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s left';
  if (d.inMinutes < 60) return '${d.inMinutes} min left';
  return '${d.inHours} h ${d.inMinutes % 60} min left';
}

String baseName(String path) => path.split('/').last;

String stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

String parentDir(String path) {
  final i = path.lastIndexOf('/');
  return i > 0 ? path.substring(0, i) : path;
}
