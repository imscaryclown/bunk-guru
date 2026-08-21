class TimeFormatter {
  static String formatTime(String timeStr) {
    try {
      final List<int> parts = timeStr.split(':').map(int.parse).toList();
      if (parts.length < 2) return timeStr;
      
      final int hour = parts[0];
      final int minute = parts[1];
      
      final String ampm = hour >= 12 ? 'PM' : 'AM';
      final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
      
      final String minuteStr = minute.toString().padLeft(2, '0');
      return '$hour12:$minuteStr $ampm';
    } catch (_) {
      return timeStr;
    }
  }
}
