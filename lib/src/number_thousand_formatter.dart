import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NumberThousandFormatter extends FilteringTextInputFormatter {
  final int digitLimit;

  NumberThousandFormatter({int? digitLimit})
      : digitLimit = digitLimit ?? 16,
        super(RegExp(r'(\d+)'), allow: true);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    var x = super.formatEditUpdate(oldValue, newValue);

    if (x.text.length > digitLimit) {
      x = super.formatEditUpdate(oldValue, oldValue);

      if (x.text.isEmpty) {
        x = super.formatEditUpdate(oldValue, newValue);

        x = x.copyWith(text: x.text.substring(0, digitLimit));
      }
    }

    return _format(oldValue, x);
  }

  TextEditingValue _format(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final nf = NumberFormat("#,##0");

    final rawText = newValue.text;
    final cleanText = rawText.replaceAll(",", "");
    final formattedText =
        cleanText.isEmpty ? "" : nf.format(int.tryParse(cleanText));

    var base = newValue.selection.baseOffset;
    var extent = newValue.selection.extentOffset;
    final length = cleanText.length;
    final totalSeparator = ((length - 1) / 3).floor();
    final x = ((length - base) / 3).floor();

    base += totalSeparator - x;
    extent += totalSeparator - x;

    base = base.clamp(0, 2 ^ 53);
    extent = extent.clamp(0, 2 ^ 53);

    return TextEditingValue(
      text: formattedText,
      selection: newValue.selection.copyWith(
        baseOffset: base,
        extentOffset: extent,
      ),
    );
  }
}
