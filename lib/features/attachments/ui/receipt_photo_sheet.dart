import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:stayon/app/theme/colors.dart';
import 'package:stayon/features/attachments/services/image_compression_service.dart';

/// State for the receipt photo sheet state machine.
enum _ReceiptPhotoState { idle, loading, success, error }

/// Modal bottom sheet widget for selecting and processing receipt photos.
///
/// Features:
/// - Camera and gallery picker options
/// - Automatic image compression (JPEG, < 1 MB)
/// - Date and amount extraction (via Claude Vision API in Task #34)
/// - Editable extraction fields with input helpers
/// - Error handling and recovery
/// - Dark mode support with Material 3 theme tokens
///
/// User flow:
/// 1. Tap Camera or Gallery button
/// 2. Select/take photo
/// 3. Loading state shows "Extracting date & amount..."
/// 4. Success state shows photo preview + editable date/amount fields
/// 5. User can edit fields or select different photo
/// 6. Save button triggers callback with extracted/edited data
class ReceiptPhotoSheet extends ConsumerStatefulWidget {
  const ReceiptPhotoSheet({
    super.key,
    required this.onPhotoAttached,
    this.imageCompressionService,
  });

  /// Callback when photo is saved with extracted data.
  ///
  /// Parameters:
  /// - `dateTime`: Extracted or user-entered date (null if not set)
  /// - `amount`: Extracted or user-entered amount in cents (null if not set)
  /// - `imageBytes`: Compressed image bytes ready for storage
  final void Function(DateTime? dateTime, double? amount, List<int> imageBytes)
  onPhotoAttached;

  /// Optional: inject custom image compression service (for testing).
  final ImageCompressionService? imageCompressionService;

  @override
  ConsumerState<ReceiptPhotoSheet> createState() => _ReceiptPhotoSheetState();
}

class _ReceiptPhotoSheetState extends ConsumerState<ReceiptPhotoSheet> {
  late ImageCompressionService _compressionService;
  late final ImagePicker _imagePicker;
  late final TextEditingController _dateController;
  late final TextEditingController _amountController;

  _ReceiptPhotoState _state = _ReceiptPhotoState.idle;
  File? _selectedImage;
  DateTime? _extractedDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _compressionService =
        widget.imageCompressionService ??
        ImageCompressionService(
          targetSizeBytes: 1024 * 1024, // 1 MB
          initialQuality: 85,
          minQuality: 60,
        );
    _imagePicker = ImagePicker();
    _dateController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Pick image from camera.
  Future<void> _pickFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Full quality; compression happens separately
      );

      if (pickedFile != null) {
        _processImage(File(pickedFile.path));
      }
    } catch (e) {
      _handleError('Camera error: $e');
    }
  }

  /// Pick image from gallery.
  Future<void> _pickFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        _processImage(File(pickedFile.path));
      }
    } catch (e) {
      _handleError('Gallery error: $e');
    }
  }

  /// Process selected image: compress and prepare for extraction.
  void _processImage(File imageFile) async {
    setState(() {
      _state = _ReceiptPhotoState.loading;
      _errorMessage = null;
    });

    try {
      // Validate image by attempting compression (will be re-done on save)
      await _compressionService.compressImage(imageFile);

      // In Task #34, Claude Vision extraction will be called here
      // For now, we store the image and await user editing of extracted fields
      setState(() {
        _selectedImage = imageFile;
        _state = _ReceiptPhotoState.success;
        _extractedDate =
            null; // Placeholder; will be populated by Claude Vision
        _dateController.clear();
        _amountController.clear();
      });

      // Haptic feedback
      await HapticFeedback.lightImpact();
    } on CompressionException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('Unexpected error: $e');
    }
  }

  /// Handle errors and reset to idle state.
  void _handleError(String message) {
    setState(() {
      _state = _ReceiptPhotoState.error;
      _errorMessage = message;
    });

    // Auto-dismiss error after 3 seconds
    Future<void>.delayed(const Duration(seconds: 3)).then((_) {
      if (mounted) {
        _resetToIdle();
      }
    });
  }

  /// Reset state to idle for new photo selection.
  void _resetToIdle() {
    setState(() {
      _state = _ReceiptPhotoState.idle;
      _selectedImage = null;
      _extractedDate = null;
      _errorMessage = null;
      _dateController.clear();
      _amountController.clear();
    });
  }

  /// Open date picker for manual date entry.
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _extractedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _extractedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  /// Format DateTime to "May 24, 2026" style.
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Parse amount string to double (remove non-numeric chars except decimal).
  double? _parseAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(cleaned);
    return parsed;
  }

  /// Format amount as "45.99" (no currency prefix).
  void _onAmountChanged(String value) {
    // Just validate; actual amount is parsed during save
    if (value.isNotEmpty) {
      _parseAmount(value); // Validate format
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
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
              // Header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add receipt photo', style: t.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    _grabHandle(),
                  ],
                ),
              ),
              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildContent(t, colorScheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build content based on current state.
  Widget _buildContent(TextTheme t, ColorScheme colorScheme) {
    switch (_state) {
      case _ReceiptPhotoState.idle:
        return _buildPhotoPickerView(t, colorScheme);

      case _ReceiptPhotoState.loading:
        return _buildLoadingView(t);

      case _ReceiptPhotoState.success:
        return _buildSuccessView(t, colorScheme);

      case _ReceiptPhotoState.error:
        return _buildErrorView(t);
    }
  }

  /// Photo picker view with camera/gallery buttons.
  Widget _buildPhotoPickerView(TextTheme t, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Choose photo source',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Tap camera to take a photo or gallery to select existing',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Camera button
          _PhotoPickerButton(
            icon: Icons.camera_alt_outlined,
            label: 'Take photo',
            onPressed: _pickFromCamera,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          // Gallery button
          _PhotoPickerButton(
            icon: Icons.image_outlined,
            label: 'Choose from gallery',
            onPressed: _pickFromGallery,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Loading state with spinner.
  Widget _buildLoadingView(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Preparing photo...',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Compressing and processing your receipt',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Success view with photo preview and extraction fields.
  Widget _buildSuccessView(TextTheme t, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo preview
          _PhotoPreviewCard(imageFile: _selectedImage, height: 240),
          const SizedBox(height: 32),

          // Extraction fields section
          _ExtractionFieldsSection(
            dateController: _dateController,
            amountController: _amountController,
            onDateTap: _selectDate,
            onAmountChanged: _onAmountChanged,
            colorScheme: colorScheme,
            textTheme: t,
          ),
          const SizedBox(height: 32),

          // Action buttons
          FilledButton(
            onPressed: _confirmSave,
            child: const Text('Save with attachment'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _resetToIdle,
            child: const Text('Choose different photo'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Confirm and save photo with extracted/edited data (internal helper).
  Future<void> _confirmSave() async {
    if (_selectedImage == null) return;

    try {
      // Compress image (cached version from _processImage or fresh compression)
      final compressedBytes = await _compressionService.compressImage(
        _selectedImage!,
      );

      // Parse date and amount from text fields
      DateTime? finalDate;
      double? finalAmount;

      if (_dateController.text.isNotEmpty) {
        try {
          finalDate = DateFormat('MMM d, yyyy').parse(_dateController.text);
        } catch (_) {
          // Invalid date format; leave as null
        }
      }

      if (_amountController.text.isNotEmpty) {
        finalAmount = _parseAmount(_amountController.text);
      }

      // Trigger callback
      widget.onPhotoAttached(finalDate, finalAmount, compressedBytes);

      // Close sheet
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _handleError('Save error: $e');
    }
  }

  /// Error view.
  Widget _buildErrorView(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
          const SizedBox(height: 24),
          Text(
            'Error processing photo',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _resetToIdle, child: const Text('Try again')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Draggable sheet grab handle.
  Widget _grabHandle() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// Button for photo picker options (Camera, Gallery).
class _PhotoPickerButton extends StatelessWidget {
  const _PhotoPickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }
}

/// Card displaying photo preview.
class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({required this.imageFile, this.height = 240});

  final File? imageFile;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageFile == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imageFile!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: AppColors.green),
            const SizedBox(width: 8),
            Text(
              'Photo attached',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section for editing extracted date and amount.
class _ExtractionFieldsSection extends StatelessWidget {
  const _ExtractionFieldsSection({
    required this.dateController,
    required this.amountController,
    required this.onDateTap,
    required this.onAmountChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  final TextEditingController dateController;
  final TextEditingController amountController;
  final VoidCallback onDateTap;
  final ValueChanged<String> onAmountChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extracted information', style: textTheme.titleSmall),
        const SizedBox(height: 16),

        // Date field
        // ignore: prefer_const_constructors
        _EditableField(
          label: 'Date',
          controller: dateController,
          hint: 'MMM d, yyyy',
          icon: Icons.calendar_today_outlined,
          onTap: onDateTap,
          enabled: true,
        ),
        const SizedBox(height: 16),

        // Amount field
        // ignore: prefer_const_constructors
        _EditableField(
          label: 'Amount',
          controller: amountController,
          hint: '0.00',
          icon: Icons.attach_money_outlined,
          onChanged: onAmountChanged,
          // ignore: prefer_const_constructors
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          enabled: true,
        ),
      ],
    );
  }
}

/// Editable input field with optional icon and tap handler.
class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
    this.onTap,
    this.onChanged,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          onTap: onTap,
          keyboardType: keyboardType ?? TextInputType.text,
          enabled: enabled,
          readOnly: onTap != null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon) : null,
            border: const UnderlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
