import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';
import 'runtime_environment.dart';

Future<void> exportSupportLogs(BuildContext context) async {
  try {
    final env = await runtimeEnvironmentInfo();
    appLog('Export', env.activityLogLabel);
  } catch (_) {}
  if (!context.mounted) return;
  await shareSupportFile(
    context,
    getFile: AppLogger.instance.resolveLogFile,
    subject: 'Cardio Rounds logs',
  );
}

Future<void> shareSupportFile(
  BuildContext context, {
  required Future<File?> Function() getFile,
  required String subject,
}) async {
  if (kIsWeb) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$subject export not available on web')),
    );
    return;
  }
  final file = await getFile();
  if (file == null || !await file.exists()) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('File not found')));
    return;
  }
  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: subject,
    sharePositionOrigin: box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size,
  );
}
