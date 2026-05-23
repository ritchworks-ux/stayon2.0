import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/colors.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_category.dart';
import '../../../core/models/item_date_type.dart';
import '../controllers/item_form_controller.dart';
import '../data/item_repository.dart';
import 'widgets/amount_field.dart';
import 'widgets/category_chip_selector.dart';

/// Modal sheet used for both Add Item and Edit Item flows.
///
/// - `existing == null` → Add mode: blank form with sensible defaults
/// - `existing != null` → Edit mode: every field pre-filled from the item
///
/// Validation: name, category, date type, and target date are required.
/// notes / assignee / amount are optional.
///
/// On successful submit the controller invalidates `itemsProvider` so
/// Home re-fetches; this sheet pops itself off the navigator stack.
class ItemFormSheet extends ConsumerStatefulWidget {
  const ItemFormSheet({super.key, this.existing, this.testInitialDate});

  /// Edit mode payload. Null for Add mode.
  final Item? existing;

  /// Overrides the initial [_targetDate] in Add mode for unit tests.
  /// The real DatePicker dialog cannot be triggered in headless tests, so
  /// tests set this to drive the past-date warning without opening the picker.
  /// Must not be set in production — it is ignored in Edit mode.
  @visibleForTesting
  final DateTime? testInitialDate;

  @override
  ConsumerState<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _assignee;

  late ItemCategory _category;
  late ItemDateType _dateType;
  late DateTime _targetDate;
  int? _amountMinor;

  bool get _isEdit => widget.existing != null;

  /// True when the selected date is strictly before today (midnight-level).
  /// Only relevant in Add mode — Edit mode suppresses the warning because
  /// past dates on existing items are expected (the user may not have
  /// renewed yet).
  bool get _targetIsInPast {
    if (_isEdit) return false;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final targetMidnight = DateTime(
      _targetDate.year,
      _targetDate.month,
      _targetDate.day,
    );
    return targetMidnight.isBefore(todayMidnight);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _assignee = TextEditingController(text: e?.assigneeLabel ?? '');
    _category = e?.category ?? ItemCategory.other;
    _dateType = e?.dateType ?? ItemDateType.expires;
    _targetDate = e?.targetDate ?? widget.testInitialDate ?? DateTime.now();
    _amountMinor = e?.amountMinor;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _assignee.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture pre-await so we don't touch the sheet's BuildContext after
    // it pops (the snackbar lives on the root ScaffoldMessenger and
    // survives the pop).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(itemFormControllerProvider.notifier);

    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final assignee = _assignee.text.trim().isEmpty
        ? null
        : _assignee.text.trim();

    if (_isEdit) {
      await notifier.submitEdit(
        widget.existing!.id,
        name: _name.text.trim(),
        category: _category,
        dateType: _dateType,
        targetDate: _targetDate,
        notes: notes,
        assigneeLabel: assignee,
        amountMinor: _amountMinor,
      );
    } else {
      await notifier.submitNew(
        name: _name.text.trim(),
        category: _category,
        dateType: _dateType,
        targetDate: _targetDate,
        notes: notes,
        assigneeLabel: assignee,
        amountMinor: _amountMinor,
      );
    }

    if (!mounted) return;
    // Error path keeps the sheet open; the ref.listen below surfaces
    // the failure message.
    if (ref.read(itemFormControllerProvider).hasError) return;

    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Item updated.' : 'Item added.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemFormControllerProvider);
    final loading = state.isLoading;

    ref.listen(itemFormControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final err = next.error;
        final msg = err is ItemException ? err.message : 'Couldn\'t save item';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    final t = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grabHandle(),
                  const SizedBox(height: 16),
                  Text(_isEdit ? 'Edit item' : 'Add item', style: t.titleLarge),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: !_isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Name is required';
                      if (t.length > 120) return 'At most 120 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Category
                  Text('Category', style: t.titleMedium),
                  const SizedBox(height: 8),
                  CategoryChipSelector(
                    selected: _category,
                    onChanged: (c) => setState(() => _category = c),
                  ),
                  const SizedBox(height: 24),

                  // Date type
                  Text('Date type', style: t.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<ItemDateType>(
                    segments: const [
                      ButtonSegment(
                        value: ItemDateType.expires,
                        label: Text('Expires'),
                      ),
                      ButtonSegment(
                        value: ItemDateType.renews,
                        label: Text('Renews'),
                      ),
                      ButtonSegment(
                        value: ItemDateType.due,
                        label: Text('Due'),
                      ),
                    ],
                    selected: {_dateType},
                    onSelectionChanged: (s) =>
                        setState(() => _dateType = s.first),
                  ),
                  const SizedBox(height: 24),

                  // Target date
                  Text('Target date', style: t.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18),
                          const SizedBox(width: 12),
                          Text(DateFormat('MMM d, y').format(_targetDate)),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _targetIsInPast
                        ? Padding(
                            key: const Key('past_date_warning'),
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppColors.coral,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'This date is in the past — item will appear as Overdue.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.coral),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // Amount (optional)
                  AmountField(
                    initialMinor: _amountMinor,
                    onChanged: (m) => _amountMinor = m,
                  ),
                  const SizedBox(height: 16),

                  // Assignee (optional)
                  TextFormField(
                    controller: _assignee,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Assignee (optional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length > 60) return 'At most 60 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes (optional)
                  TextFormField(
                    controller: _notes,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length > 500) return 'At most 500 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Add item'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grabHandle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
