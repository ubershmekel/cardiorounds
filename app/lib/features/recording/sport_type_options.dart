import 'package:flutter/material.dart';

/// The autocomplete dropdown for the sport-type field, shared by the confirm
/// and recording screens. Sizes to the widest option within the incoming
/// constraints and lists every option directly. Callers cap the count, so no
/// scrolling is needed.
class SportTypeOptions extends StatelessWidget {
  const SportTypeOptions({
    super.key,
    required this.options,
    required this.onSelected,
    this.alignment = Alignment.topLeft,
    this.highlightedIndex,
  });

  final Iterable<String> options;
  final ValueChanged<String> onSelected;
  final int? highlightedIndex;

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
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < optionList.length; i++)
                InkWell(
                  // Select on tap-down: releasing shifts focus and removes the
                  // overlay before a tap-up would register, so onTap never
                  // fires. The empty onTap keeps the ink splash.
                  onTapDown: (_) => onSelected(optionList[i]),
                  onTap: () {},
                  child: ColoredBox(
                    color: i == highlightedIndex
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(optionList[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
