/// 手机号脱敏：13800138000 → 138****8000
String maskPhone(String phone) {
  final value = phone.trim();
  if (value.isEmpty) return value;
  if (value.contains('****')) return value;

  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}****${digits.substring(7)}';
  }
  if (digits.length >= 7) {
    return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
  }
  return value;
}

bool isFullPhone(String? phone) {
  if (phone == null || phone.isEmpty) return false;
  return RegExp(r'^1\d{10}$').hasMatch(phone.trim());
}
