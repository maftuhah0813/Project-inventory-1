/// Formatter mata uang Rupiah independen dan cepat tanpa overhead eksternal
class CurrencyFormatter {
  /// Format angka integer/double menjadi format standar Rupiah (e.g. 50000 -> "Rp 50.000")
  static String format(num value) {
    final isNegative = value < 0;
    final absVal = value.abs().round();
    final str = absVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    final formattedNumber = buffer.toString().split('').reversed.join('');
    return '${isNegative ? "-Rp " : "Rp "}$formattedNumber';
  }

  /// Ekstraksi nilai numerik dari string format Rupiah
  static double parse(String formatted) {
    final clean = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }
}
