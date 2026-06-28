import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import 'sport_type_field.dart';

/// The name / note / sport-type editing cluster shown on the recording and
/// activity screens. Owns its controllers and persistence: each field saves to
/// the activity row on blur, and the fields seed from the row once it loads.
class ActivityMetaFields extends ConsumerStatefulWidget {
  const ActivityMetaFields({
    super.key,
    required this.activityId,
    this.sportTypeOpenDirection = OptionsViewOpenDirection.down,
  });

  final int activityId;

  /// Open the sport-type overlay upward when the field sits low in a scroll
  /// view (the live recording screen), so the keyboard can't hide it.
  final OptionsViewOpenDirection sportTypeOpenDirection;

  @override
  ConsumerState<ActivityMetaFields> createState() => _ActivityMetaFieldsState();
}

class _ActivityMetaFieldsState extends ConsumerState<ActivityMetaFields> {
  bool _controllersInitialized = false;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _sportTypeController = TextEditingController();
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _sportTypeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // FocusNodes let us save to the row when the user taps away (hasFocus →
    // false); the name field also jumps focus to the note on Enter.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _save(name: _nameController.text);
    });
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _save(note: _noteController.text);
    });
    _sportTypeFocus.addListener(() {
      if (!_sportTypeFocus.hasFocus) {
        _save(sportType: _sportTypeController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _sportTypeController.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    _sportTypeFocus.dispose();
    super.dispose();
  }

  void _save({String? name, String? note, String? sportType}) {
    ref
        .read(databaseProvider)
        .updateActivity(
          activityId: widget.activityId,
          name: name,
          note: note,
          sportType: sportType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Seed the fields once the row is available; afterwards the controllers own
    // the text so we don't clobber what the user is typing.
    ref.watch(activityProvider(widget.activityId)).whenData((a) {
      if (!_controllersInitialized) {
        _controllersInitialized = true;
        _nameController.text = a.name ?? '';
        _noteController.text = a.note ?? '';
        _sportTypeController.text = a.sportType ?? '';
      }
    });

    final subtleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          onTapOutside: (_) => _nameFocus.unfocus(),
          onSubmitted: (_) => _noteFocus.requestFocus(),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.titleLarge,
          decoration: const InputDecoration(
            hintText: 'Add a name…',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        TextField(
          controller: _noteController,
          focusNode: _noteFocus,
          onTapOutside: (_) => _noteFocus.unfocus(),
          maxLines: null,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          style: subtleStyle,
          decoration: const InputDecoration(
            hintText: 'Add a note…',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SportTypeField(
          controller: _sportTypeController,
          focusNode: _sportTypeFocus,
          textAlign: TextAlign.center,
          style: subtleStyle,
          openDirection: widget.sportTypeOpenDirection,
          decoration: const InputDecoration(
            hintText: 'Sport type…',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
