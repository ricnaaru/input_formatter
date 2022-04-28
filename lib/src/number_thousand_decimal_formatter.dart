import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NumberThousandDecimalFormatter extends FilteringTextInputFormatter {
  final int digitLimit;
  final int precision;

  NumberThousandDecimalFormatter({int? digitLimit, int? precision})
      : digitLimit = digitLimit ?? 16,
        precision = precision ?? 2,
        super(RegExp(r'(\d+)(\.(\d+))?'), allow: true);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    /// since IOS keyboard doesn't have . but ,
    /// we have to overwrite the comma into period
    final oldOffset = oldValue.selection.baseOffset;
    final newOffset = newValue.selection.baseOffset;

    if (newOffset - oldOffset == 1 &&
        newValue.text.substring(oldOffset, newOffset) == ",") {
      newValue = newValue.copyWith(
        text:
            "${newValue.text.substring(0, oldOffset)}.${newValue.text.substring(newOffset, newValue.text.length)}",
      );
    }

    /// if something pasted to here and starts with 0, we will basically reduce the position by 1
    /// because
    /// 01 will become 1
    /// 02 will become 2
    if (newValue.text.startsWith("0") && newValue.selection.baseOffset > 0) {
      newValue = newValue.copyWith(
        selection: newValue.selection.copyWith(
          baseOffset: newValue.selection.baseOffset - 1,
          extentOffset: newValue.selection.extentOffset - 1,
        ),
      );
    }

    /// because the zero position for textfield is 0.00
    /// this script below will ignore the 0 when user type
    /// |0.00 => user type 1 => 1|0.00
    /// with this script, it will become 1|.00

    final oldPeriodIndex = oldValue.text.indexOf(".");
    final newPeriodIndex = newValue.text.indexOf(".");

    if (oldPeriodIndex >0 && newPeriodIndex >0) {
      if (oldValue.text
                  .substring(oldPeriodIndex - 1, oldPeriodIndex + 1) ==
              "0." &&
          newValue.text.substring(newPeriodIndex - 1, newPeriodIndex + 1) ==
              "0." &&
          oldValue.selection.baseOffset == 0) {
        newValue = newValue.copyWith(
          text:
              "${newValue.text.substring(0, newValue.text.length - 4)}.${newValue.text.substring(newValue.text.length - 2)}",
          selection: newValue.selection.copyWith(
            baseOffset: newValue.selection.baseOffset,
            extentOffset: newValue.selection.extentOffset,
          ),
        );
      }
    }

    var newNormalizedValue = newValue;

    final dotIndex = newNormalizedValue.text.indexOf(".") + 1;

    /// if the decimal being deleted, will replace the deleted digit with 0
    if (oldValue.text.length > newValue.text.length &&
        newNormalizedValue.selection.baseOffset >= dotIndex &&
        dotIndex != 0) {
      final text = newNormalizedValue.text;

      newNormalizedValue = newNormalizedValue.copyWith(
        text:
            "${text.substring(0, newNormalizedValue.selection.baseOffset)}0${newNormalizedValue.selection.baseOffset > text.length ? "" : text.substring(newNormalizedValue.selection.baseOffset)}",
      );
    }

    /// remove comma from the old value, and update base & extent offset accordingly
    final cleanOldValueText = oldValue.text.replaceAll(",", "");
    final cleanOldValueBase = oldValue.selection.baseOffset -
        ","
            .allMatches(
                oldValue.text.substring(0, oldValue.selection.baseOffset))
            .length;
    final cleanOldValueExtent = oldValue.selection.extentOffset -
        ","
            .allMatches(
                oldValue.text.substring(0, oldValue.selection.extentOffset))
            .length;
    final cleanOldValue = oldValue.copyWith(
      text: cleanOldValueText,
      selection: oldValue.selection.copyWith(
        baseOffset: cleanOldValueBase,
        extentOffset: cleanOldValueExtent,
      ),
    );

    /// remove comma from the new value, and update base & extent offset accordingly
    final oldValueDotIndex = oldValue.text.indexOf(".");
    var cleanNewValueText = newNormalizedValue.text.replaceAll(",", "");

    /// if the decimal separator is deleted, will revert to the old value (the one with dot)
    if (oldValueDotIndex >= 0 &&
        oldValue.text.length > newValue.text.length &&
        newNormalizedValue.selection.baseOffset == oldValueDotIndex) {
      cleanNewValueText = cleanOldValueText;
    }

    var cleanNewValueBase = newNormalizedValue.selection.baseOffset -
        ","
            .allMatches(newNormalizedValue.text
                .substring(0, newNormalizedValue.selection.baseOffset))
            .length;
    var cleanNewValueExtent = newNormalizedValue.selection.extentOffset -
        ","
            .allMatches(newNormalizedValue.text
                .substring(0, newNormalizedValue.selection.extentOffset))
            .length;

    /// to make any typing in decimal replace the next digit instead appending one more
    cleanNewValueText = normalizeDecimal(
      cleanNewValueText,
      newNormalizedValue.copyWith(
        selection: newNormalizedValue.selection.copyWith(
          baseOffset: cleanNewValueBase,
          extentOffset: cleanNewValueExtent,
        ),
      ),
      oldValue,
      precision,
    );

    cleanNewValueBase = cleanNewValueBase.clamp(0, cleanNewValueText.length);
    cleanNewValueExtent =
        cleanNewValueExtent.clamp(0, cleanNewValueText.length);

    final cleanNewValue = newNormalizedValue.copyWith(
      text: cleanNewValueText,
      selection: newNormalizedValue.selection.copyWith(
        baseOffset: cleanNewValueBase,
        extentOffset: cleanNewValueExtent,
      ),
    );

    /// call super to filter all excluded characters
    var x = super.formatEditUpdate(cleanOldValue, cleanNewValue);

    /// after calling super, the decimal separator will be deleted
    /// normalize is to divide the parsed normalized text with factor
    /// initial value: 1234.99
    /// after calling super: 123499
    /// after normalized: 1234.99
    x = normalize(x, oldValue, cleanNewValue, newNormalizedValue);

    /// if the length of text is exceeded
    if (x.text.length > (digitLimit + 1 + precision)) {
      /// will call super again but with oldvalue
      x = super.formatEditUpdate(cleanOldValue, cleanOldValue);

      /// after that it will be normalized
      x = normalize(x, oldValue, cleanOldValue, newNormalizedValue);

      /// if the result is empty, will trim the text instead
      if (x.text.isEmpty) {
        x = super.formatEditUpdate(cleanOldValue, cleanNewValue);

        x = x.copyWith(text: x.text.substring(0, digitLimit));
      }
    }

    /// format text with NumberFormat
    final finalResult = _format(cleanOldValue, x);

    return finalResult;
  }

  TextEditingValue _format(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final rawText = newValue.text;

    final cleanText = rawText.replaceAll(",", "");
    final parsed = truncate(Decimal.tryParse(cleanText) ?? Decimal.zero, precision);

    final formattedText =
        cleanText.isEmpty ? "" : formatButWithDecimal(parsed, "#,##0");

    var base = newValue.selection.baseOffset;
    var extent = newValue.selection.extentOffset;
    final length = cleanText.length - precision - 1;

    var modLength = length % 3;
    modLength = modLength == 0 ? 3 : modLength;

    /// if the edited digit is not decimal numbers, will add base / extent with this
    final addFactor = ((base - modLength) / 3).ceil();

    /// if the edited digit is decimal numbers, will add base / extent with this
    final commaCount = ",".allMatches(formattedText).length;

    base += base <= length - 3 ? addFactor : commaCount;
    extent += extent <= length - 3 ? addFactor : commaCount;

    /// to prevent base & extent minus or exceed the limit
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

  String normalizeDecimal(
    String value,
    TextEditingValue newValue,
    TextEditingValue oldValue,
    int precision,
  ) {
    var result = value;

    /// basically all typed decimal should replace the digit on the right, not to append it
    final dotIndex = value.indexOf(".");

    if (dotIndex >= 0) {
      final currentPrecisionCount = value.length - (dotIndex + 1);
      final oldDotIndex = oldValue.text.indexOf(".");
      final oldPrecisionCount =
          oldDotIndex >= 0 ? oldValue.text.length - (oldDotIndex + 1) : 0;

      if (currentPrecisionCount > precision) {
        /// initial value: 1.|23, base: 2
        /// after typing: 1.9|23, base: 3
        /// after normalized: 1.9|3, base: 3
        ///
        /// initial value: 1.|234567890, base: 2
        /// after typing: 1.9876|234567890, base: 3
        /// after normalized: 1.9876|67890, base: 3

        final typedCount = newValue.selection.baseOffset - (dotIndex + 1);
        final left = value.substring(
            0, newValue.selection.baseOffset.clamp(0, value.length));
        var right = "";

        if (typedCount < oldPrecisionCount) {
          right = oldValue.text.substring(
              oldValue.text.length - (oldPrecisionCount - typedCount),
              oldValue.text.length);
        }

        result = left + right;
      }
    }

    final resultDotIndex = result.indexOf(".");
    if (resultDotIndex >= 0) {
      final left = result.substring(0, resultDotIndex);
      final right = result.substring(resultDotIndex + 1);

      return "$left.${right.substring(0, min(precision, right.length))}";
    } else {
      return result;
    }
  }

  Decimal truncate(Decimal value, int precision) {
    final stringed = value.toString();
    final dotIndex = stringed.indexOf(".");
    if (dotIndex >= 0) {
      final left = stringed.substring(0, dotIndex);
      final right = stringed.substring(dotIndex + 1);
      return Decimal.tryParse(
          "$left.${right.substring(0, min(precision, right.length))}") ?? Decimal.zero;
    } else {
      return value;
    }
  }

  TextEditingValue normalize(
    TextEditingValue x,
    TextEditingValue oldValue,
    TextEditingValue cleanNewValue,
    TextEditingValue newNormalizedValue,
  ) {
    if (!x.text.contains(".") && oldValue.text.contains(".")) {
      final parsed =
          Decimal.tryParse(cleanNewValue.text.replaceAll("..", ".")) ??
              Decimal.zero;

      final text = formatButWithDecimal(parsed, "###0");
      var base = x.selection.baseOffset;
      var extent = x.selection.extentOffset;

      if (newNormalizedValue.text.startsWith("0")) {
        /// if the text starts with 0
        /// initial: 0|
        /// after edit: 01|
        base = base - 1;
        extent = extent - 1;
      } else if (cleanNewValue.text.contains("..")) {
        /// if the dot is typed more than once
        /// initial: 1.|99
        /// after edit: 1..|99
        base = base + 1;
        extent = extent + 1;
      } else if (cleanNewValue.text == text) {
        /// if the digit after decimal separator is deleted
        /// initial: 1.9|9
        /// after edit: 1.|09
        base = cleanNewValue.selection.baseOffset;
        extent = cleanNewValue.selection.extentOffset;
      }

      x = x.copyWith(
        text: text,
        selection: x.selection.copyWith(
          baseOffset: base,
          extentOffset: extent,
        ),
      );
    }

    return x;
  }

  String formatButWithDecimal(Decimal parsed, String format) {
    /// it's dangerous to deal with money and double
    /// and Decimal cannot be formatted with NumberFormat
    /// so, I have to format this manually by converting the digits and decimal to string

    final nf = NumberFormat(format);
    final parsedUp = parsed.floor();
    final difference = parsed - parsedUp;
    var decimalString = ".${"0" * precision}";

    if (difference != Decimal.zero) {
      final differenceString = difference.toString();
      decimalString = differenceString.substring(1, differenceString.length);

      if (decimalString.length < precision + 1) {
        decimalString = decimalString.padRight(precision + 1, "0");
      }
    }

    return "${nf.format(DecimalIntl(parsedUp))}$decimalString";
  }
}
