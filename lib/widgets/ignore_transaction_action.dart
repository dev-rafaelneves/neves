import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';

/// Alterna o estado "ignorada" de uma transação. Para parcelas com parcelas
/// futuras, pergunta se deve estender a ação às próximas parcelas.
///
/// Retorna null se o usuário cancelou; caso contrário, true/false indicando
/// se a ação foi estendida às parcelas futuras (útil para desfazer).
Future<bool?> toggleIgnoreTransaction(
  BuildContext context,
  AppState state,
  TransactionModel tx,
) async {
  final ignore = !tx.isIgnored;
  var includeFuture = false;

  final hasFuture = tx.installmentGroupId != null &&
      state.transactions.any((t) =>
          t.installmentGroupId == tx.installmentGroupId &&
          t.installmentIndex > tx.installmentIndex);

  if (hasFuture) {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ignore ? 'Ignorar parcela' : 'Reativar parcela'),
        content: Text(
          ignore
              ? 'Deseja ignorar também as parcelas futuras desta compra?'
              : 'Deseja reativar também as parcelas futuras desta compra?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Só esta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('Esta e futuras'),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    includeFuture = choice == 1;
  }

  await state.setTransactionIgnored(
    tx,
    ignore,
    includeFutureInstallments: includeFuture,
  );
  return includeFuture;
}
