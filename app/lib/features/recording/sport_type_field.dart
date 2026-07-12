import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// The options overlay is hand-rolled rather than using [RawAutocomplete]
/// because that widget only recomputes its options inside its text-change
/// listener, so a pre-filled field shows nothing until the user edits the
/// text — we want the recent list to open on tap. Reproducing the same
/// keyboard navigation is the cost of that control.
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
  /// list loads - a sensible default when starting a new recording.
  final bool prefillWithMostRecent;

  @override
  ConsumerState<SportTypeField> createState() => _SportTypeFieldState();
}

class _SportTypeFieldState extends ConsumerState<SportTypeField> {
  final _layerLink = LayerLink();
  OverlayEntry? _optionsEntry;
  List<String> _options = const [];
  double _fieldWidth = 0;
  int _highlightedOptionIndex = 0;
  // Whether a highlight is actually shown. Stays false until the user arrows
  // into the list, so Enter with nothing highlighted submits the typed text
  // rather than snapping to an option.
  bool _highlightedOptionActive = false;
  bool _overlayUpdateScheduled = false;

  // Anchor the overlay to the field edge it grows from, matching text alignment.
  Alignment get _optionsAlignment => Alignment(
    widget.textAlign == TextAlign.center ? 0 : -1,
    widget.openDirection == OptionsViewOpenDirection.up ? 1 : -1,
  );

  bool get _shouldShowOptions =>
      widget.focusNode.hasFocus && _options.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_deactivateHighlightedOption);
    widget.focusNode.addListener(_updateOptionsOverlay);
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
  void didUpdateWidget(covariant SportTypeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_deactivateHighlightedOption);
      widget.controller.addListener(_deactivateHighlightedOption);
      _deactivateHighlightedOption();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_updateOptionsOverlay);
      widget.focusNode.addListener(_updateOptionsOverlay);
      _updateOptionsOverlay();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_deactivateHighlightedOption);
    widget.focusNode.removeListener(_updateOptionsOverlay);
    _removeOptionsOverlay();
    super.dispose();
  }

  void _selectOption(String sport) {
    widget.controller.value = TextEditingValue(
      text: sport,
      selection: TextSelection.collapsed(offset: sport.length),
    );
    widget.focusNode.unfocus();
  }

  void _highlightPreviousOption() {
    if (!_shouldShowOptions) {
      return;
    }
    // The first arrow press just reveals the highlight at the current index;
    // only a repeat press steps off it.
    _activateHighlightedOption(
      _highlightedOptionActive
          ? _highlightedOptionIndex - 1
          : _highlightedOptionIndex,
    );
  }

  void _highlightNextOption() {
    if (!_shouldShowOptions) {
      return;
    }
    _activateHighlightedOption(
      _highlightedOptionActive
          ? _highlightedOptionIndex + 1
          : _highlightedOptionIndex,
    );
  }

  void _submitOrSelectHighlightedOption() {
    if (!_shouldShowOptions || !_highlightedOptionActive) {
      widget.focusNode.unfocus();
      return;
    }
    _selectOption(_options[_highlightedOptionIndex]);
  }

  void _activateHighlightedOption(int index) {
    _highlightedOptionActive = true;
    _setHighlightedOptionIndex(index);
    _optionsEntry?.markNeedsBuild();
  }

  void _deactivateHighlightedOption() {
    if (!_highlightedOptionActive) {
      return;
    }

    _highlightedOptionActive = false;
    _optionsEntry?.markNeedsBuild();
  }

  void _setHighlightedOptionIndex(int index) {
    if (_options.isEmpty) {
      _highlightedOptionIndex = 0;
      return;
    }

    final clamped = index.clamp(0, _options.length - 1).toInt();
    if (clamped == _highlightedOptionIndex) {
      return;
    }

    _highlightedOptionIndex = clamped;
    _optionsEntry?.markNeedsBuild();
  }

  void _setOptions(List<String> options) {
    if (listEquals(_options, options)) {
      return;
    }

    _options = options;
    if (_options.isEmpty) {
      _highlightedOptionIndex = 0;
      _highlightedOptionActive = false;
    } else if (_highlightedOptionIndex >= _options.length) {
      _highlightedOptionIndex = _options.length - 1;
    }
    _scheduleOptionsOverlayUpdate();
  }

  void _setFieldWidth(double width) {
    if ((_fieldWidth - width).abs() < 0.5) {
      return;
    }

    _fieldWidth = width;
    _scheduleOptionsOverlayUpdate();
  }

  void _scheduleOptionsOverlayUpdate() {
    if (_overlayUpdateScheduled) {
      return;
    }

    _overlayUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayUpdateScheduled = false;
      _updateOptionsOverlay();
    });
  }

  void _updateOptionsOverlay() {
    if (!mounted) {
      return;
    }

    if (!_shouldShowOptions) {
      _removeOptionsOverlay();
      return;
    }

    if (_optionsEntry == null) {
      _highlightedOptionIndex = 0;
      _highlightedOptionActive = false;
      _optionsEntry = OverlayEntry(builder: _buildOptionsOverlay);
      Overlay.of(context).insert(_optionsEntry!);
    } else {
      _optionsEntry!.markNeedsBuild();
    }
  }

  void _removeOptionsOverlay() {
    _optionsEntry?.remove();
    _optionsEntry = null;
  }

  Widget _buildOptionsOverlay(BuildContext context) {
    final opensUp = widget.openDirection == OptionsViewOpenDirection.up;

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: opensUp ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: opensUp ? Alignment.bottomLeft : Alignment.topLeft,
      offset: Offset(0, opensUp ? -4 : 4),
      child: TapRegion(
        groupId: widget.focusNode,
        child: SizedBox(
          width: _fieldWidth > 0 ? _fieldWidth : null,
          child: SportTypeOptions(
            options: _options,
            onSelected: _selectOption,
            alignment: _optionsAlignment,
            highlightedIndex: _highlightedOptionActive
                ? _highlightedOptionIndex
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    final pastTypes =
        ref.watch(distinctSportTypesProvider).valueOrNull ?? const [];
    _setOptions(pastTypes.take(recentSportsTypeLimit).toList());

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) {
          _setFieldWidth(constraints.maxWidth);
        }

        // Grouped with the overlay above so a tap outside both drops focus.
        return TapRegion(
          groupId: focusNode,
          onTapOutside: (_) => focusNode.unfocus(),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowUp):
                  _highlightPreviousOption,
              const SingleActivator(LogicalKeyboardKey.arrowDown):
                  _highlightNextOption,
              const SingleActivator(LogicalKeyboardKey.enter):
                  _submitOrSelectHighlightedOption,
              const SingleActivator(LogicalKeyboardKey.numpadEnter):
                  _submitOrSelectHighlightedOption,
            },
            child: CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                textAlign: widget.textAlign,
                style: widget.style,
                decoration: widget.decoration,
              ),
            ),
          ),
        );
      },
    );
  }
}
