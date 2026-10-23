// Design docs: docs/design/export.md, docs/design/screens.md

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_logger.dart';
import '../../core/build_info.dart';
import '../../core/db/database.dart';
import '../../core/export/activity_export.dart';

/// Exports [activityId] as TCX and opens the share sheet (a download on web,
/// via share_plus's fallback). Asks "Whose workout?" first when the activity
/// has streams from more than one owner.
Future<void> exportActivity(
  BuildContext context,
  AppDatabase db,
  int activityId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // The share sheet anchors to the export button on iPad.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final data = await loadActivityExport(db, activityId);
    final owners = data.owners;
    if (owners.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No heart-rate data to export')),
      );
      return;
    }
    var choice = (owner: owners.first, includeAllAthletes: true);
    if (owners.length > 1) {
      if (!context.mounted) return;
      final picked = await showDialog<_ExportChoice>(
        context: context,
        builder: (_) => ExportOptionsDialog(owners: owners),
      );
      if (picked == null) return;
      choice = picked;
    }
    final xml = encodeTcx(
      data,
      owner: choice.owner,
      includeAllAthletes: choice.includeAllAthletes,
      appVersion: kAppVersion,
    );
    final bytes = utf8.encode(xml);
    final fileName = exportFileName(data.activity);
    final setCount = choice.includeAllAthletes
        ? data.sets.length
        : data.sets.where(choice.owner.owns).length;
    appLog(
      'Export',
      'activity $activityId: $setCount of ${data.sets.length} sets, '
          '${data.markers.length} markers, ${bytes.length} bytes as $fileName',
    );
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: kTcxMimeType, name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: origin,
    );
  } catch (e, st) {
    appLog('Export', 'activity $activityId export failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

typedef _ExportChoice = ({ExportOwner owner, bool includeAllAthletes});

/// "Whose workout?" picker shown when an activity has several stream owners.
/// Pops an [_ExportChoice], or null on cancel.
class ExportOptionsDialog extends StatefulWidget {
  const ExportOptionsDialog({super.key, required this.owners});

  /// Primary set's owner first; that's the default choice.
  final List<ExportOwner> owners;

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  late ExportOwner _owner = widget.owners.first;
  bool _includeAll = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Whose workout?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ExportOwner>(
              groupValue: _owner,
              onChanged: (o) => setState(() => _owner = o ?? _owner),
              child: Column(
                children: [
                  for (final o in widget.owners)
                    RadioListTile<ExportOwner>(
                      value: o,
                      title: Text(o.label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            CheckboxListTile(
              value: _includeAll,
              onChanged: (v) => setState(() => _includeAll = v ?? true),
              title: const Text('Include all athletes'),
              subtitle: const Text(
                "Unchecked, other people's heart rate isn't included.",
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop<_ExportChoice>(context, (
            owner: _owner,
            includeAllAthletes: _includeAll,
          )),
          child: const Text('Export'),
        ),
      ],
    );
  }
}
