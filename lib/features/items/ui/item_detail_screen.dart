import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/colors.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_status.dart';
import '../../../core/models/money.dart';
import '../controllers/item_actions_controller.dart';
import '../controllers/item_providers.dart';
import '../data/item_repository.dart';
import '../utils/date_buckets.dart';
import 'item_form_sheet.dart';

/// Full-screen route for a single item.
///
/// Watches `itemByIdProvider(id)`; routes through loading / error / data
/// states. The action row hosts Edit / Mark renewed / Archive / Delete;
/// archive + delete confirm via AlertDialog and show an Undo snackbar
/// on success. Pop back to Home after destructive actions so the user
/// doesn't sit on a now-hidden item.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemByIdProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Item')),
      // skipLoadingOnRefresh: false → after an edit invalidates
      // itemByIdProvider, show the spinner during the refetch instead of
      // briefly re-rendering the stale pre-edit item. Guarantees the
      // detail never shows old data after a save.
      body: async.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorBody(context, e),
        data: (item) => _DetailBody(item: item),
      ),
    );
  }

  Widget _errorBody(BuildContext context, Object error) {
    final t = Theme.of(context).textTheme;
    final notFound = error is ItemException && error.code == 'not_found';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            notFound ? Icons.search_off : Icons.cloud_off_outlined,
            size: 56,
            color: AppColors.ink,
          ),
          const SizedBox(height: 16),
          Text(
            notFound ? 'Item not found' : "Couldn't load this item",
            style: t.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item});
  final Item item;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.coral)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemFormSheet(existing: item),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    // Capture EVERYTHING that touches the widget tree BEFORE any await
    // or navigation. After `router.go('/home')` the detail screen is
    // disposed and `ref` becomes defunct — closures that try to use
    // `ref.read(...)` from inside the SnackBarAction would silently
    // throw and the Undo button would do nothing.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final actions = ref.read(itemActionsControllerProvider.notifier);
    final id = item.id;

    final ok = await _confirm(
      context,
      title: 'Archive item?',
      message: 'Archived items are hidden from Home.',
      confirmLabel: 'Archive',
    );
    if (!ok) return;

    final updated = await actions.archive(id);
    if (updated == null) {
      _showError(messenger, actions, 'archive');
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Item archived.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => actions.restore(id),
        ),
      ),
    );
    router.go('/home');
  }

  Future<void> _trash(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final actions = ref.read(itemActionsControllerProvider.notifier);
    final id = item.id;

    final ok = await _confirm(
      context,
      title: 'Delete item?',
      message: 'This moves the item to Trash. You can restore it right away.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;

    final updated = await actions.trash(id);
    if (updated == null) {
      _showError(messenger, actions, 'delete');
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Item moved to Trash.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Restore',
          onPressed: () => actions.restore(id),
        ),
      ),
    );
    router.go('/home');
  }

  String _statusLabel(ItemStatus s) {
    switch (s) {
      case ItemStatus.active:
        return 'Active';
      case ItemStatus.archived:
        return 'Archived';
      case ItemStatus.trashed:
        return 'In Trash';
    }
  }

  void _showError(
    ScaffoldMessengerState messenger,
    ItemActionsController actions,
    String verb,
  ) {
    final msg = actions.lastError?.message ?? "Couldn't $verb this item";
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final actions = ref.watch(itemActionsControllerProvider);
    final loading = actions.isLoading;
    final rel = relativeDateLabel(item.targetDate);
    final dateStr = DateFormat('MMM d, y').format(item.targetDate);
    final amount = pesoFromMinor(item.amountMinor);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category-tinted header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: item.category.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.category.icon, size: 20, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Text(
                        item.category.label.toUpperCase(),
                        style: t.labelSmall?.copyWith(color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    style: t.titleLarge?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(rel, style: t.bodyLarge?.copyWith(color: AppColors.ink)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Field(
              label: '${item.dateType.label} on',
              value: dateStr,
              icon: Icons.calendar_today_outlined,
            ),
            if (amount.isNotEmpty)
              _Field(
                label: 'Amount',
                value: amount,
                icon: Icons.payments_outlined,
              ),
            if (item.assigneeLabel != null)
              _Field(
                label: 'Assigned to',
                value: item.assigneeLabel!,
                icon: Icons.person_outline,
              ),
            if ((item.notes ?? '').trim().isNotEmpty)
              _Field(
                label: 'Notes',
                value: item.notes!,
                icon: Icons.notes_outlined,
                multiline: true,
              ),
            _Field(
              label: 'Status',
              value: _statusLabel(item.status),
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 24),

            // Action row — only valid for active items
            if (item.status == ItemStatus.active) ...[
              FilledButton.icon(
                onPressed: loading ? null : () => _openEditSheet(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading ? null : () => _archive(context, ref),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading ? null : () => _trash(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ] else
              FilledButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        // Capture pre-await for consistency with _archive
                        // / _trash even though we don't navigate here.
                        final messenger = ScaffoldMessenger.of(context);
                        final actions = ref.read(
                          itemActionsControllerProvider.notifier,
                        );
                        final updated = await actions.restore(item.id);
                        if (updated == null) {
                          _showError(messenger, actions, 'restore');
                          return;
                        }
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Item restored.')),
                        );
                      },
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.icon,
    this.multiline = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.labelSmall?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: t.bodyLarge?.copyWith(color: AppColors.ink),
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
