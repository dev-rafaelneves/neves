import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class IosActionSheet {
  static Future<void> show({
    required BuildContext context,
    required String title,
    String? description,
    String confirmText = 'Excluir',
    String cancelText = 'Cancelar',
    required VoidCallback onConfirm,
  }) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        message: description != null
            ? Text(
                description,
                style: const TextStyle(fontSize: 13),
              )
            : null,
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            cancelText,
            style: const TextStyle(
              color: Color(0xFF059669),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
