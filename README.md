# Input Formatter

This library contains formatters for TextField, Money (Decimal) formatter, credit card formatter, phone number formatter, etc.

## Installation

First, add `input_formatter` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/).

```
input_formatter: ^1.0.0
```

## Example
```
AdvTextField(
    inputFormatters: [
      NumberThousandDecimalFormatter(digitLimit: 16, precision: 2),
    ],
),
AdvTextField(
    inputFormatters: [
      NumberThousandFormatter(digitLimit: 16),
    ],
)
```

## Future developments
- Credit card input formatter
- Phone input formatter
- Custom input formatter

## Support
This repository is new, and I will try to keep it well-maintained as much as possible. Please consider support me..

[![Buy me a coffee](https://www.buymeacoffee.com/assets/img/custom_images/white_img.png)](https://www.buymeacoffee.com/rthayeb)

<br>
