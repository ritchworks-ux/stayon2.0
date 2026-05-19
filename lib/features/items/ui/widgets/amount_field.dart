import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/money.dart';

/// Optional PHP amount input.
///
/// - Pre-fills from [initialMinor] (centavos) as a decimal string "12.34"
/// - Emits an `int?` minor-units value via [onChanged] on every keystroke
///   (null when input is empty or unparseable)
/// - Validates: empty is allowed; non-numeric shows "Enter a valid amount"
///
/// Stores results as minor units (centavos) so the backend never sees a
/// floating-point amount. Display formatting (₱1,234.50) is the caller's
/// concern — see [pesoFromMinor] for read-only contexts.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.initialMinor,
    required this.onChanged,
    this.labelText = 'Amount (optional)',
  });

  final int? initialMinor;
  final ValueChanged<int?> onChanged;
  final String labelText;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialMinor));
  }

  String _format(int? minor) {
    if (minor == null) return '';
    final whole = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '$whole.$cents';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Allow digits + at most one decimal point. Anything else is
        // stripped at keypress so the field can never enter a state the
        // validator alone wouldn't accept.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixText: '₱',
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        widget.onChanged(minorFromDecimal(raw));
      },
      validator: (v) {
        final raw = (v ?? '').trim();
        if (raw.isEmpty) return null; // optional
        if (minorFromDecimal(raw) == null) return 'Enter a valid amount';
        return null;
      },
    );
  }
}
