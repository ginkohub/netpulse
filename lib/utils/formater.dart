String formatBytes(int b, {String? sp = ''}) {
  if (b < 1024) return '${b.toStringAsFixed(0)}${sp}B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}${sp}K';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / (1024 * 1024)).toStringAsFixed(1)}${sp}M';
  }
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)}${sp}G';
}

String formatSpeed(int s, {String? sp = ''}) {
  if (s <= 0) return '0${sp}b';
  if (s < 1000) return '${s.toStringAsFixed(0)}${sp}b';
  if (s < 1000000) return '${(s / 1000).toStringAsFixed(1)}${sp}k';
  return '${(s / 1000000).toStringAsFixed(1)}${sp}M';
}
