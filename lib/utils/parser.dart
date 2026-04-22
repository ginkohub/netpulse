int parseCountOnly(dynamic value) {
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

int parseIntSafe(dynamic value, {int defaultValue = 0}) {
  return int.tryParse(value?.toString() ?? '0') ?? defaultValue;
}
