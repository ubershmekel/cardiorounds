import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import 'sport_type_options.dart';

const recentSportsTypeLimit = 10;

/// Free-text sport-type field with autocomplete over previously used types.
///
/// Owns loading the past types (via [distinctSportTypesProvider]); the caller
/// supplies the [controller]/[focusNode] (so it can persist on blur) and the
/// visual treatment. Used standalone on the pre-recording screen and inside
/// [ActivityMetaFields].
class SportTypeField extends ConsumerStatefulWidget {
  const SportTypeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.textAlign = TextAlign.start,
    this.openDirection = OptionsViewOpenDirection.down,
    this.prefillWithMostRecent = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextAlign textAlign;
  final OptionsViewOpenDirection openDirection;

  /// When true, fills an empty field with the most recent past type once the
  /// list loads — a sensible default when starting a new recording.
  final bool prefillWithMostRecent;

  @override
  ConsumerState<SportTypeField> createState() => _SportTypeFieldState();
}

class _SportTypeFieldState extends ConsumerState<SportTypeField> {
  // Anchor the overlay to the field edge it grows from, matching text alignment.
  Alignment get _optionsAlignment => Alignment(
    widget.textAlign == TextAlign.center ? 0 : -1,
    widget.openDirection == OptionsViewOpenDirection.up ? 1 : -1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.prefillWithMostRecent) {
      // listenManual with fireImmediately so an already-loaded value still
      // prefills (a plain build-time listener only fires on change, which is
      // missed if the provider is already AsyncData when this field mounts).
      // It only fires on provider changes, so clearing the field won't refill.
      ref.listenManual(distinctSportTypesProvider, fireImmediately: true, (
        _,
        next,
      ) {
        final types = next.valueOrNull;
        // Don't clobber anything the user typed while the query was in flight.
        if (types != null &&
            types.isNotEmpty &&
            widget.controller.text.isEmpty) {
          widget.controller.text = types.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    final pastTypes =
        ref.watch(distinctSportTypesProvider).valueOrNull ?? const [];

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsViewOpenDirection: widget.openDirection,
      optionsBuilder: (_) => pastTypes.take(recentSportsTypeLimit).toList(),
      optionsViewBuilder: (context, onSelected, options) => TapRegion(
        groupId: focusNode,
        child: SportTypeOptions(
          options: options,
          onSelected: onSelected,
          alignment: _optionsAlignment,
        ),
      ),
      fieldViewBuilder: (context, fieldController, fieldFocusNode, _) {
        // Grouped with the overlay above so a tap outside both drops focus.
        return TapRegion(
          groupId: focusNode,
          onTapOutside: (_) => fieldFocusNode.unfocus(),
          child: TextField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            textAlign: widget.textAlign,
            style: widget.style,
            decoration: widget.decoration,
          ),
        );
      },
    );
  }
}
