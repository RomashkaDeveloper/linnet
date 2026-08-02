String formatClock(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

const _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Formats a chat list timestamp: today -> "HH:mm", yesterday -> "Вчера",
/// within the last week -> weekday short name, otherwise -> "dd.MM.yy".
String formatChatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(date).inDays;

  if (diffDays == 0) return formatClock(local);
  if (diffDays == 1) return 'Вчера';
  if (diffDays < 7) return _weekdaysShort[local.weekday - 1];

  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yy = (local.year % 100).toString().padLeft(2, '0');
  return '$dd.$mm.$yy';
}

/// Formats a "last seen" string, e.g. "был(а) в сети 5 мин назад".
String formatLastSeen(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inSeconds < 60) return 'был(а) в сети только что';
  if (diff.inMinutes < 60) return 'был(а) в сети ${diff.inMinutes} мин назад';
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return 'был(а) в сети сегодня в ${formatClock(local)}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'был(а) в сети вчера в ${formatClock(local)}';
  }
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return 'был(а) в сети $dd.$mm в ${formatClock(local)}';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}
