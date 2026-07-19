import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_logger.dart';
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

  // The values currently in the DB for the athlete these fields are seeded from.
  // _persist compares against these and skips the write when nothing changed.
  // Without this guard, dispose/didUpdateWidget write on *every* unmount, and
  // because a write re-fires the athletes query stream (which rebuilds this
  // subtree and unmounts the fields again), the app spins in a write→rebuild→
  // write loop that also corrupts the row with stale controller text.
  late String _savedName;
  int? _savedMaxHr;
  int? _savedRestingHr;

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
    _seedSavedFrom(widget.athlete);
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
      _seedSavedFrom(widget.athlete);
    }
  }

  /// Snapshot the row's stored values so [_persist] can detect a genuine edit.
  void _seedSavedFrom(Athlete athlete) {
    _savedName = athlete.name.trim();
    _savedMaxHr = athlete.maxHeartrate;
    _savedRestingHr = athlete.restingHeartrate;
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
    final name = _nameController.text.trim();
    final maxText = _maxHrController.text.trim();
    final restingText = _restingHrController.text.trim();
    // A swapped max<=resting pair would lock zones while looking saved. Leave the
    // HR columns untouched (keeping the last valid values) until the pair is
    // fixed, but still save the name. The warning row prompts the correction.
    final swapped = _isHRSwapped;
    final newMax = swapped
        ? null
        : (maxText.isEmpty ? null : int.tryParse(maxText));
    final newResting = swapped
        ? null
        : (restingText.isEmpty ? null : int.tryParse(restingText));

    // Skip no-op writes. dispose/didUpdateWidget call _persist on every unmount,
    // and a write re-fires the athletes query stream — which rebuilds and
    // unmounts these fields again. Writing only on a real change is what keeps
    // that from becoming an endless write→rebuild→write loop.
    final nameChanged = name != _savedName;
    final hrChanged =
        !swapped && (newMax != _savedMaxHr || newResting != _savedRestingHr);
    if (!nameChanged && !hrChanged) return;

    // Saves are user-driven and rare, so one line each is cheap. A *burst* of
    // these is the fingerprint of the write→rebuild→write loop this guard exists
    // to prevent (see docs/design/app-building-strategy.md) — if it ever
    // regresses, the log makes it obvious instead of just flickering the UI.
    appLog('Athlete', 'saved id=$athleteId (name=$nameChanged hr=$hrChanged)');

    _db.updateAthlete(
      id: athleteId,
      name: name,
      maxHeartrate: newMax,
      clearMax: swapped ? false : maxText.isEmpty,
      restingHeartrate: newResting,
      clearResting: swapped ? false : restingText.isEmpty,
    );

    _savedName = name;
    if (!swapped) {
      _savedMaxHr = newMax;
      _savedRestingHr = newResting;
    }
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
