import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayon/core/models/extraction_result.dart';

/// Modal bottom sheet for reviewing and editing extracted receipt data.
///
/// Features:
/// - Photo preview thumbnail (80px height, max 200px width)
/// - Editable date field with date picker (MM/dd/yyyy format)
/// - Editable amount field with $ prefix and decimal validation
/// - Confidence badge with color coding (green > 85%, yellow 50-85%, red < 50%)
/// - Optional merchant metadata display
/// - Save and Cancel buttons
/// - Dark mode support with Material 3 theme tokens
///
/// User flow:
/// 1. Shows extracted data from Claude Vision API
/// 2. User can edit date/amount or confirm as-is
/// 3. Tapping Save returns: (date, amount in dollars, imageBytes)
/// 4. Tapping Cancel returns null without modification
///
/// Example usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (context) => ExtractionReviewSheet(
///     extractionResult: result,
///     imageBytes: imageData,
///     onSave: (date, amount, bytes) {
///       // Pre-fill form with extracted data
///     },
///   ),
/// );
/// ```
class ExtractionReviewSheet extends StatefulWidget {
  const ExtractionReviewSheet({
    super.key,
    required this.extractionResult,
    required this.imageBytes,
    required this.onSave,
    this.onCancel,
  });

  /// Extraction result from Claude Vision API.
  /// - type: 'receipt'
  /// - data: {date: "YYYY-MM-DD"?, amount_cents: integer?}
  /// - confidence: 0.0-1.0
  /// - warnings: optional list of extraction warnings
  final ExtractionResult extractionResult;

  /// Compressed image bytes to pass back in onSave callback.
  final List<int> imageBytes;

  /// Callback when user taps Save.
  /// Parameters:
  /// - date: DateTime or null if not set
  /// - amount: double (in dollars, e.g., 45.99) or null if not set
  /// - imageBytes: the original compressed image bytes
  final void Function(DateTime?, double?, List<int>) onSave;

  /// Optional callback when user taps Cancel or close.
  final VoidCallback? onCancel;

  @override
  State<ExtractionReviewSheet> createState() => _ExtractionReviewSheetState();
}

class _ExtractionReviewSheetState extends State<ExtractionReviewSheet> {
  late final TextEditingController _dateController;
  late final TextEditingController _amountController;
  late DateTime? _selectedDate;
  late double? _selectedAmount;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  /// Initialize date/amount from extraction result.
  void _initializeFields() {
    _selectedDate = _parseDate(widget.extractionResult.data['date']);
    _selectedAmount = _parseAmount(
      widget.extractionResult.data['amount_cents'],
    );

    _dateController = TextEditingController(
      text: _selectedDate != null ? _formatDate(_selectedDate!) : '',
    );

    _amountController = TextEditingController(
      text: _selectedAmount != null ? _formatAmount(_selectedAmount!) : '',
    );
  }

  /// Parse date string in YYYY-MM-DD format to DateTime.
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String) {
        return DateTime.parse(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse amount_cents (integer) to double (dollars).
  double? _parseAmount(dynamic value) {
    if (value == null) return null;
    try {
      if (value is int) {
        return value / 100.0;
      } else if (value is double) {
        return value / 100.0;
      } else if (value is String) {
        return int.parse(value) / 100.0;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Format DateTime to MM/dd/yyyy.
  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  /// Format double (dollars) to currency string with $ prefix.
  String _formatAmount(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Parse user-entered amount string back to double (dollars).
  double? _parseAmountFromInput(String text) {
    if (text.isEmpty) return null;
    try {
      // Remove non-numeric characters except decimal point
      final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// Open date picker for manual date selection.
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  /// Get confidence color based on extraction confidence score.
  Color _getConfidenceColor(BuildContext context, double confidence) {
    final colorScheme = Theme.of(context).colorScheme;
    if (confidence > 0.85) {
      return colorScheme.primary; // Green
    } else if (confidence >= 0.50) {
      return colorScheme.errorContainer; // Yellow/warning
    } else {
      return colorScheme.error; // Red
    }
  }

  /// Handle Save button tap.
  void _handleSave() {
    // Parse the current text field values
    final DateTime? finalDate = _selectedDate;
    double? finalAmount;

    if (_amountController.text.isNotEmpty) {
      finalAmount = _parseAmountFromInput(_amountController.text);
    }

    // Trigger callback with final values
    widget.onSave(finalDate, finalAmount, widget.imageBytes);

    // Close sheet
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Handle Cancel button or close button tap.
  void _handleCancel() {
    widget.onCancel?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header with title and close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Review Extracted Data', style: t.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _handleCancel,
                        ),
                      ],
                    ),
                    _buildGrabHandle(colorScheme),
                  ],
                ),
              ),
              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Photo preview
                        _buildPhotoPreview(),
                        const SizedBox(height: 24),

                        // Metadata section
                        _buildMetadataSection(t, colorScheme),
                        const SizedBox(height: 24),

                        // Editable fields section
                        _buildEditableFieldsSection(t, colorScheme),
                        const SizedBox(height: 32),

                        // Action buttons
                        FilledButton(
                          onPressed: _handleSave,
                          child: const Text('Save'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _handleCancel,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build grab handle for draggable sheet.
  Widget _buildGrabHandle(ColorScheme colorScheme) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );

  /// Build photo preview thumbnail.
  Widget _buildPhotoPreview() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      Uint8List.fromList(widget.imageBytes),
      height: 80,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  );

  /// Build metadata display section (confidence badge, merchant).
  Widget _buildMetadataSection(TextTheme t, ColorScheme colorScheme) {
    final confidence = widget.extractionResult.confidence;
    final merchant = widget.extractionResult.data['merchant'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confidence badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getConfidenceColor(
              context,
              confidence,
            ).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: _getConfidenceColor(context, confidence),
              ),
              const SizedBox(width: 8),
              Text(
                'Confidence: ${(confidence * 100).toInt()}%',
                style: t.labelSmall?.copyWith(
                  color: _getConfidenceColor(context, confidence),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (merchant != null) ...[
          const SizedBox(height: 12),
          Text(
            'Merchant: $merchant',
            style: t.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  /// Build editable date and amount fields.
  Widget _buildEditableFieldsSection(TextTheme t, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit information', style: t.titleSmall),
        const SizedBox(height: 16),

        // Date field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: const InputDecoration(
                hintText: 'MM/dd/yyyy',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Amount field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '\$0.00',
                prefixIcon: Icon(Icons.attach_money_outlined),
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
