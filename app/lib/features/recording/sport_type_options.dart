import 'package:flutter/material.dart';

/// The autocomplete dropdown for the sport-type field, shared by the confirm
/// and recording screens. Sizes to the widest option within the incoming
/// constraints. Scrolls when the options don't fit in [maxHeight] — e.g. when
/// the on-screen keyboard leaves little room below the field.
class SportTypeOptions extends StatelessWidget {
  const SportTypeOptions({
    super.key,
    required this.options,
    required this.onSelected,
    this.alignment = Alignment.topLeft,
    this.highlightedIndex,
    this.maxHeight = double.infinity,
  });

  final Iterable<String> options;
  final ValueChanged<String> onSelected;
  final int? highlightedIndex;
  final double maxHeight;

  /// Use [Alignment.bottomLeft]/`bottomCenter` when the overlay opens upward so
  /// it grows away from the field.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final optionList = options.toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: alignment,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < optionList.length; i++)
                    _buildOption(context, i, optionList[i], colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    int index,
    String option,
    ColorScheme colorScheme,
  ) {
    final highlighted = index == highlightedIndex;
    return Builder(
      builder: (itemContext) {
        if (highlighted) {
          // Keep an arrow-key highlight visible when the list is scrolled.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (itemContext.mounted) {
              Scrollable.ensureVisible(itemContext);
            }
          });
        }
        return InkWell(
          // A full tap (not tap-down) so a drag that scrolls the list doesn't
          // select the option it started on.
          onTap: () => onSelected(option),
          child: ColoredBox(
            color: highlighted
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(option),
            ),
          ),
        );
      },
    );
  }
}
