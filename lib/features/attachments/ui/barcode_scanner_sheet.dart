import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stayon/app/theme/colors.dart';
import 'package:stayon/core/models/extraction_result.dart';
import 'package:stayon/features/attachments/providers/barcode_provider.dart';
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';
import 'package:stayon/features/attachments/ui/widgets/barcode_overlay.dart';

/// State for the barcode scanner state machine.
enum _ScannerState { idle, loading, success, notFound, error, permissionDenied }

/// Modal bottom sheet widget for scanning barcodes.
///
/// Features:
/// - Camera permission request with Settings fallback
/// - Live barcode preview with crosshair overlay
/// - Haptic feedback on successful scan
/// - State machine: idle → loading → success/notFound/error
/// - Result callback to parent
class BarcodeScannerSheet extends ConsumerStatefulWidget {
  const BarcodeScannerSheet({super.key, required this.onResult});

  /// Callback when a barcode is successfully scanned and API lookup completes.
  ///
  /// Receives the [ExtractionResult] with product data.
  /// If the user selects "Manual Entry", `null` is passed.
  final void Function(ExtractionResult?) onResult;

  @override
  ConsumerState<BarcodeScannerSheet> createState() =>
      _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<BarcodeScannerSheet> {
  late MobileScannerController _scannerController;
  late final TextEditingController _manualBarcodeController;

  _ScannerState _state = _ScannerState.idle;
  String? _scannedBarcode;
  ExtractionResult? _extractionResult;
  String? _errorMessage;
  PermissionStatus _cameraPermission = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _manualBarcodeController = TextEditingController();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  /// Request camera permission from the user.
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _cameraPermission = status);

    if (status.isDenied) {
      setState(() => _state = _ScannerState.permissionDenied);
    } else if (status.isGranted) {
      _startScanning();
    }
  }

  /// Programmatically open app settings (iOS: prefs, Android: app settings).
  Future<void> _openAppSettings() async {
    await openAppSettings();
    // After returning from settings, check permission again
    final status = await Permission.camera.status;
    setState(() => _cameraPermission = status);

    if (status.isGranted) {
      _startScanning();
    }
  }

  /// Start listening to the scanner stream.
  void _startScanning() {
    _scannerController.start();
  }

  /// Handle a barcode detection.
  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_state != _ScannerState.idle) return; // Ignore if already processing

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    // Haptic feedback
    await HapticFeedback.mediumImpact();

    // Stop scanner and update state
    await _scannerController.stop();
    setState(() {
      _scannedBarcode = barcode;
      _state = _ScannerState.loading;
    });

    // Lookup barcode in API
    await _lookupBarcode(barcode);
  }

  /// Lookup barcode using Open Food Facts API.
  Future<void> _lookupBarcode(String barcode) async {
    try {
      // FutureProvider returns AsyncValue, so we need to await the future
      final service = await ref.read(openFoodFactsServiceProvider.future);
      final result = await service.lookupBarcode(barcode);

      if (!mounted) return;

      setState(() {
        _extractionResult = result;
        _state = _ScannerState.success;
      });
    } on BarcodeException catch (e) {
      if (!mounted) return;

      if (e.code == 'not_found') {
        setState(() => _state = _ScannerState.notFound);
      } else {
        setState(() {
          _errorMessage = e.message;
          _state = _ScannerState.error;
        });
        // Auto-restart scanner after a delay
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          _resetScanner();
        }
      }
    }
  }

  /// Reset the scanner to idle state and restart.
  void _resetScanner() {
    setState(() {
      _scannedBarcode = null;
      _extractionResult = null;
      _errorMessage = null;
      _state = _ScannerState.idle;
    });
    _scannerController.start();
  }

  /// Proceed with manual barcode entry.
  void _proceedWithManualEntry() {
    widget.onResult(null);
    Navigator.of(context).pop();
  }

  /// Confirm the scanned result and return it to the parent.
  void _confirmResult() {
    if (_extractionResult != null) {
      widget.onResult(_extractionResult);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        Text('Scan barcode', style: t.titleLarge),
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
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the content based on the current state.
  Widget _buildContent(BuildContext context) {
    final t = Theme.of(context).textTheme;

    switch (_state) {
      case _ScannerState.permissionDenied:
        return _buildPermissionDenied(t);

      case _ScannerState.idle:
      case _ScannerState.loading:
        return _buildScannerView();

      case _ScannerState.success:
        return _buildSuccessView(t);

      case _ScannerState.notFound:
        return _buildNotFoundView(t);

      case _ScannerState.error:
        return _buildErrorView(t);
    }
  }

  /// Permission denied UI with "Enable camera in Settings" button.
  Widget _buildPermissionDenied(TextTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.videocam_off, size: 64, color: AppColors.coral),
          const SizedBox(height: 24),
          Text(
            'Camera access denied',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Enable camera access in Settings to scan barcodes.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _openAppSettings,
            child: const Text('Open Settings'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Scanner view with camera preview and crosshair overlay.
  Widget _buildScannerView() {
    if (_cameraPermission.isDenied) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Camera feed
        MobileScanner(
          controller: _scannerController,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error, child) {
            final message = error.errorDetails?.message ?? 'Unknown error';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.coral,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera error: $message',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _scannerController.start,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),
        // Crosshair overlay
        BarcodeOverlay(
          statusText: _state == _ScannerState.loading
              ? 'Looking up barcode...'
              : 'Point camera at barcode',
          statusColor: _state == _ScannerState.loading
              ? AppColors.green
              : Colors.white,
        ),
      ],
    );
  }

  /// Success view showing product data.
  Widget _buildSuccessView(TextTheme t) {
    if (_extractionResult == null) {
      return const SizedBox.shrink();
    }

    final data = _extractionResult!.data;
    final productName = data['product_name'] as String? ?? 'Unknown product';
    final brands = data['brands'] as String?;
    final expirationDate = data['expiration_date'] as String?;
    final confidence = _extractionResult!.confidence;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success icon
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.green,
          ),
          const SizedBox(height: 24),

          // Barcode code
          if (_scannedBarcode != null) ...[
            Text('Barcode', style: t.titleSmall),
            const SizedBox(height: 8),
            Text(
              _scannedBarcode!,
              style: t.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Product name
          Text('Product', style: t.titleSmall),
          const SizedBox(height: 8),
          Text(productName, style: t.bodyLarge),
          const SizedBox(height: 24),

          // Brand (if available)
          if (brands != null) ...[
            Text('Brand', style: t.titleSmall),
            const SizedBox(height: 8),
            Text(brands, style: t.bodyMedium),
            const SizedBox(height: 24),
          ],

          // Expiration date (if available)
          if (expirationDate != null) ...[
            Text('Estimated expiry', style: t.titleSmall),
            const SizedBox(height: 8),
            Text(expirationDate, style: t.bodyMedium),
            const SizedBox(height: 24),
          ],

          // Confidence indicator
          Row(
            children: [
              Icon(
                confidence >= 0.9
                    ? Icons.check_circle
                    : confidence >= 0.7
                    ? Icons.info
                    : Icons.warning,
                size: 18,
                color: confidence >= 0.9
                    ? AppColors.green
                    : confidence >= 0.7
                    ? Colors.orange
                    : AppColors.coral,
              ),
              const SizedBox(width: 8),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}% confident',
                style: t.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action buttons
          FilledButton(onPressed: _confirmResult, child: const Text('Confirm')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _resetScanner, child: const Text('Rescan')),
        ],
      ),
    );
  }

  /// Barcode not found view.
  Widget _buildNotFoundView(TextTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(
            Icons.search_off_outlined,
            size: 64,
            color: AppColors.coral,
          ),
          const SizedBox(height: 24),
          Text(
            'Barcode not found',
            style: t.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'The scanned barcode is not in our database.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (_scannedBarcode != null) ...[
            const SizedBox(height: 16),
            Text(
              'Code: $_scannedBarcode',
              style: t.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _proceedWithManualEntry,
            child: const Text('Enter manually'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _resetScanner,
            child: const Text('Try another barcode'),
          ),
        ],
      ),
    );
  }

  /// Error view (network, server, etc.).
  Widget _buildErrorView(TextTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.error_outline, size: 64, color: AppColors.coral),
          const SizedBox(height: 24),
          Text(
            'Error scanning barcode',
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
          FilledButton(onPressed: _resetScanner, child: const Text('Retry')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _grabHandle() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
