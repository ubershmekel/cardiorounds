import 'package:flutter/material.dart';

/// The autocomplete dropdown for the sport-type field, shared by the confirm
/// and recording screens. Sizes to the widest option (not the full field
/// width) and lists every option directly — callers cap the count, so no
/// scrolling is needed.
class SportTypeOptions extends StatelessWidget {
  const SportTypeOptions({
    super.key,
    required this.options,
    required this.onSelected,
    this.alignment = Alignment.topLeft,
  });

  final Iterable<String> options;
  final ValueChanged<String> onSelected;

  /// Use [Alignment.bottomLeft]/`bottomCenter` when the overlay opens upward so
  /// it grows away from the field.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
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
              for (final sport in options)
                InkWell(
                  onTap: () => onSelected(sport),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(sport),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
