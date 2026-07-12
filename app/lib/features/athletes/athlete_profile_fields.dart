import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';

/// The name / resting HR / max HR editing cluster for one athlete, shared by the
/// Settings profile and the athlete-management pager. Owns its controllers and
/// persistence: each field auto-saves to the athlete row on blur (there is no
/// Save button), and re-seeds when [athlete] switches to a different id.
class AthleteProfileFields extends ConsumerStatefulWidget {
  const AthleteProfileFields({super.key, required this.athlete});

  final Athlete athlete;

  @override
  ConsumerState<AthleteProfileFields> createState() =>
      _AthleteProfileFieldsState();
}

class _AthleteProfileFieldsState extends ConsumerState<AthleteProfileFields> {
  late final TextEditingController _nameController;
  late final TextEditingController _maxHrController;
  late final TextEditingController _restingHrController;
  final _nameFocus = FocusNode();
  final _maxHrFocus = FocusNode();
  final _restingHrFocus = FocusNode();
  // Cached so dispose can persist without touching ref (Riverpod forbids ref
  // access after disposal). Refreshed each build so a post-restore db swap is
  // picked up.
  late AppDatabase _db;

  @override
  void initState() {
    super.initState();
    _db = ref.read(databaseProvider);
    _nameController = TextEditingController(text: widget.athlete.name);
    _maxHrController = TextEditingController(
      text: widget.athlete.maxHeartrate?.toString() ?? '',
    );
    _restingHrController = TextEditingController(
      text: widget.athlete.restingHeartrate?.toString() ?? '',
    );
    // Save to the row when the user taps away from any field (hasFocus → false).
    for (final focus in [_nameFocus, _maxHrFocus, _restingHrFocus]) {
      focus.addListener(() {
        if (!focus.hasFocus) _persist(widget.athlete.id);
      });
    }
  }

  @override
  void didUpdateWidget(AthleteProfileFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pager reuses this state across athletes. When it switches to another
    // athlete, flush any in-flight edits to the one we're leaving before
    // re-seeding the fields — that's how edits persist "on navigation".
    if (oldWidget.athlete.id != widget.athlete.id) {
      _persist(oldWidget.athlete.id);
      _nameController.text = widget.athlete.name;
      _maxHrController.text = widget.athlete.maxHeartrate?.toString() ?? '';
      _restingHrController.text =
          widget.athlete.restingHeartrate?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    // Leaving the screen with a field still focused would otherwise drop the
    // last edit, since blur never fires.
    _persist(widget.athlete.id);
    _nameController.dispose();
    _maxHrController.dispose();
    _restingHrController.dispose();
    _nameFocus.dispose();
    _maxHrFocus.dispose();
    _restingHrFocus.dispose();
    super.dispose();
  }

  void _persist(int athleteId) {
    final maxText = _maxHrController.text.trim();
    final restingText = _restingHrController.text.trim();
    // A swapped max<=resting pair would lock zones while looking saved. Leave the
    // HR columns untouched (keeping the last valid values) until the pair is
    // fixed, but still save the name. The warning row prompts the correction.
    final swapped = _isHRSwapped;
    _db.updateAthlete(
          id: athleteId,
          name: _nameController.text.trim(),
          maxHeartrate: swapped
              ? null
              : (maxText.isEmpty ? null : int.tryParse(maxText)),
          clearMax: swapped ? false : maxText.isEmpty,
          restingHeartrate: swapped
              ? null
              : (restingText.isEmpty ? null : int.tryParse(restingText)),
          clearResting: swapped ? false : restingText.isEmpty,
        );
  }

  bool get _isHRSwapped {
    final max = int.tryParse(_maxHrController.text.trim());
    final resting = int.tryParse(_restingHrController.text.trim());
    return max != null && resting != null && max <= resting;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the cached db current for dispose's final save.
    _db = ref.read(databaseProvider);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          onTapOutside: (_) => _nameFocus.unfocus(),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Name (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _restingHrController,
          focusNode: _restingHrFocus,
          onTapOutside: (_) => _restingHrFocus.unfocus(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Resting heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message: 'Measure first thing in the morning, lying still.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxHrController,
          focusNode: _maxHrFocus,
          onTapOutside: (_) => _maxHrFocus.unfocus(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'MAX heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message:
                  'Used for zone thresholds. Estimate: 220 minus your age; or measure with an increasingly hard interval session for accuracy.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        if (_isHRSwapped) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Max HR must be greater than resting HR - are they swapped?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
