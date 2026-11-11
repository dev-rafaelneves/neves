import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/gemini_service.dart';
import '../services/import_service.dart';
import '../theme/app_theme.dart';

class StatementImportScreen extends StatefulWidget {
  final AppState appState;

  const StatementImportScreen({super.key, required this.appState});

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  static const _uuid = Uuid();

  ImportTargetMode _targetMode = ImportTargetMode.checking;
  bool _invertSigns = false;
  bool _isAiCategorizing = false;
  bool _aiCategorizedSuccess = false;
  String? _selectedAccountId;
  String? _selectedCounterpartAccountId;
  String? _selectedCardId;
  String? _selectedGoalId;
  List<ImportedTransactionCandidate> _candidates = [];
  String? _loadedFileName;
  String? _rawContent;
  String _rawExtension = 'csv';

  bool get _importToCard => _targetMode == ImportTargetMode.creditCard;

  @override
  void initState() {
    super.initState();
    final state = widget.appState;
    if (state.accounts.isNotEmpty) {
      _selectedAccountId = state.accounts.first.id;
      final other = state.accounts.where((a) => a.id != _selectedAccountId);
      _selectedCounterpartAccountId =
          other.isNotEmpty ? other.first.id : state.accounts.first.id;
    }
    if (state.creditCards.isNotEmpty) {
      _selectedCardId = state.creditCards.first.id;
    }
    if (state.goals.isNotEmpty) {
      _selectedGoalId = state.goals.first.id;
    }
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'Extratos Bancários (OFX, CSV, TXT)',
      extensions: ['ofx', 'csv', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final content = await file.readAsString();
    final ext = file.name.split('.').last;
    _parseContent(content, ext, file.name);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A área de transferência está vazia. Copie as linhas do seu extrato PDF ou CSV primeiro.',
          ),
        ),
      );
      return;
    }
    _parseContent(text, 'txt', 'Texto Colado (PDF/CSV)');
  }

  void _parseContent(String content, String ext, String sourceLabel) {
    _rawContent = content;
    _rawExtension = ext;
    final parsed = ImportService.parseStatementContent(
      content: content,
      extension: ext,
      categories: widget.appState.categories,
      existingTransactions: widget.appState.transactions,
      goals: widget.appState.goals,
      accounts: widget.appState.accounts,
      defaultGoalId: _selectedGoalId,
      sourceAccountId: _selectedAccountId,
      defaultCounterpartAccountId: _selectedCounterpartAccountId,
      forceExpenseForCreditCard: _importToCard,
      invertSigns: _invertSigns,
    );
    HapticFeedback.lightImpact();
    setState(() {
      _candidates = parsed;
      _loadedFileName = sourceLabel;
      _aiCategorizedSuccess = false;
    });

    if (_targetMode == ImportTargetMode.checking ||
        _targetMode == ImportTargetMode.creditCard) {
      _runAiCategorization(silentIfNoKey: true);
    }
  }

  Future<void> _runAiCategorization({bool silentIfNoKey = false}) async {
    if (_candidates.isEmpty || _isAiCategorizing) return;

    final hasKey = await GeminiService.hasApiKey();
    if (!hasKey) {
      if (!silentIfNoKey && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configure sua chave da API Gemini na aba Ajustes para categorizar com IA.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isAiCategorizing = true);
    }

    try {
      final mapping = await GeminiService.categorizeImportedTransactions(
        candidates: _candidates,
        categories: widget.appState.categories,
      );
      if (!mounted) return;
      setState(() {
        mapping.forEach((idx, catId) {
          if (idx >= 0 && idx < _candidates.length) {
            _candidates[idx].suggestedCategoryId = catId;
          }
        });
        _isAiCategorizing = false;
        _aiCategorizedSuccess = mapping.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiCategorizing = false);
      if (!silentIfNoKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao categorizar com IA: $e')),
        );
      }
    }
  }

  void _handleInvertAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _invertSigns = !_invertSigns;
      _aiCategorizedSuccess = false;
      ImportService.invertAllCandidateTypes(
        candidates: _candidates,
        categories: widget.appState.categories,
        existingTransactions: widget.appState.transactions,
      );
    });
    if (_targetMode == ImportTargetMode.checking ||
        _targetMode == ImportTargetMode.creditCard) {
      _runAiCategorization(silentIfNoKey: true);
    }
  }

  void _toggleSingleCandidateType(ImportedTransactionCandidate c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_targetMode == ImportTargetMode.transfer) {
        c.isOutgoingTransfer = !c.isOutgoingTransfer;
        return;
      }
      if (_targetMode == ImportTargetMode.cofrinho) {
        switch (c.cofrinhoOp) {
          case CofrinhoOperationKind.deposit:
            c.cofrinhoOp = CofrinhoOperationKind.withdraw;
            break;
          case CofrinhoOperationKind.withdraw:
            c.cofrinhoOp = CofrinhoOperationKind.yieldGain;
            break;
          case CofrinhoOperationKind.yieldGain:
            c.cofrinhoOp = CofrinhoOperationKind.deposit;
            break;
        }
        return;
      }
      c.type = c.type == TransactionType.expense
          ? TransactionType.income
          : TransactionType.expense;
      c.suggestedCategoryId = ImportService.suggestCategory(
        title: c.title,
        type: c.type,
        categories: widget.appState.categories,
        existingTransactions: widget.appState.transactions,
      );
    });
  }

  Future<void> _quickCreateNubankCard() async {
    HapticFeedback.mediumImpact();
    final card = CreditCardModel(
      id: _uuid.v4(),
      name: 'Nubank',
      creditLimit: 5000.0,
      closingDay: 5,
      dueDay: 12,
      colorValue: 0xFF059669,
    );
    await widget.appState.saveCreditCard(card);
    setState(() {
      _selectedCardId = card.id;
      _targetMode = ImportTargetMode.creditCard;
    });
  }

  Future<void> _showQuickCreateGoalDialog() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '10.000,00');
    final created = await showDialog<GoalModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Cofrinho / Caixinha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do Cofrinho (ex: Reserva Mercado Pago)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: const [CentavosCurrencyFormatter()],
              decoration: const InputDecoration(
                labelText: 'Meta do Cofrinho (R\$)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().isEmpty
                  ? 'Cofrinho Mercado Pago'
                  : nameCtrl.text.trim();
              final target = CentavosCurrencyFormatter.parseValue(
                targetCtrl.text,
              );
              final goal = GoalModel(
                id: _uuid.v4(),
                name: name,
                targetAmount: target > 0 ? target : 10000.0,
                currentAmount: 0.0,
                colorValue: 0xFF059669,
                iconName: 'savings',
              );
              Navigator.of(ctx).pop(goal);
            },
            child: const Text('Criar Cofrinho'),
          ),
        ],
      ),
    );

    if (created != null) {
      await widget.appState.saveGoal(created);
      setState(() {
        _selectedGoalId = created.id;
        for (final c in _candidates) {
          c.targetGoalId ??= created.id;
        }
      });
    }
  }

  Future<void> _showQuickCreateAccountDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<Account>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Conta Bancária'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do Banco / Conta (ex: Nubank, Mercado Pago)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().isEmpty
                  ? 'Nova Conta'
                  : nameCtrl.text.trim();
              final acc = Account(
                id: _uuid.v4(),
                name: name,
                type: AccountType.checking,
                initialBalance: 0.0,
                currentBalance: 0.0,
                colorValue: 0xFF059669,
                iconName: 'account_balance',
              );
              Navigator.of(ctx).pop(acc);
            },
            child: const Text('Criar Conta'),
          ),
        ],
      ),
    );

    if (created != null) {
      await widget.appState.saveAccount(created);
      setState(() {
        _selectedCounterpartAccountId = created.id;
        for (final c in _candidates) {
          c.counterpartAccountId = created.id;
        }
      });
    }
  }

  Future<void> _confirmImport() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final state = widget.appState;
    CreditCardModel? card;
    if (_importToCard) {
      if (state.creditCards.isEmpty) {
        await _quickCreateNubankCard();
      }
      _selectedCardId ??= state.creditCards.first.id;
      card = state.getCardById(_selectedCardId);
    }

    if (_targetMode == ImportTargetMode.cofrinho && state.goals.isEmpty) {
      final defaultGoal = GoalModel(
        id: _uuid.v4(),
        name: 'Cofrinho Principal',
        targetAmount: 10000.0,
        currentAmount: 0.0,
        colorValue: 0xFF059669,
        iconName: 'savings',
      );
      await state.saveGoal(defaultGoal);
      _selectedGoalId = defaultGoal.id;
    }

    for (final item in selected) {
      final compMonth = card != null
          ? card.computeCompetenceMonth(item.date)
          : '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';

      if (_targetMode == ImportTargetMode.cofrinho) {
        final goalId = item.targetGoalId ??
            _selectedGoalId ??
            (state.goals.isNotEmpty ? state.goals.first.id : null);

        late final TransactionType txType;
        late final String? txAccountId;
        late final String? txCategoryId;
        late final List<String> txTags;

        switch (item.cofrinhoOp) {
          case CofrinhoOperationKind.deposit:
            // Aporte: tira da Conta Corrente e soma no Cofrinho
            txType = TransactionType.expense;
            txAccountId = _selectedAccountId;
            txCategoryId = 'cat_aportes';
            txTags = const ['cofrinho_aporte'];
            break;
          case CofrinhoOperationKind.withdraw:
            // Resgate: devolve para a Conta Corrente e subtrai do Cofrinho
            txType = TransactionType.income;
            txAccountId = _selectedAccountId;
            txCategoryId = 'cat_outras_receitas';
            txTags = const ['resgate_cofrinho'];
            break;
          case CofrinhoOperationKind.yieldGain:
            // Rendimento: soma apenas no saldo do Cofrinho (accountId = null para não inflar a Conta Corrente)
            txType = TransactionType.income;
            txAccountId = null;
            txCategoryId = 'cat_rendimentos';
            txTags = const ['rendimento_cofrinho'];
            break;
        }

        final tx = TransactionModel(
          id: _uuid.v4(),
          title: item.title,
          amount: item.amount,
          type: txType,
          date: item.date,
          competenceMonth: compMonth,
          status: TransactionStatus.paid,
          accountId: txAccountId,
          categoryId: txCategoryId,
          goalId: goalId,
          tags: txTags,
          importHash: item.importHash,
        );
        await state.addOrUpdateTransaction(tx);
      } else if (_targetMode == ImportTargetMode.transfer) {
        final otherAccId = item.counterpartAccountId ??
            _selectedCounterpartAccountId ??
            _selectedAccountId;
        final sourceAccId =
            item.isOutgoingTransfer ? _selectedAccountId : otherAccId;
        final destAccId =
            item.isOutgoingTransfer ? otherAccId : _selectedAccountId;

        final tx = TransactionModel(
          id: _uuid.v4(),
          title: item.title,
          amount: item.amount,
          type: TransactionType.transfer,
          date: item.date,
          competenceMonth: compMonth,
          status: TransactionStatus.paid,
          accountId: sourceAccId,
          destinationAccountId: destAccId,
          importHash: item.importHash,
        );
        await state.addOrUpdateTransaction(tx);
      } else {
        final tx = TransactionModel(
          id: _uuid.v4(),
          title: item.title,
          amount: item.amount,
          type: item.type,
          date: item.date,
          competenceMonth: compMonth,
          status: _importToCard
              ? TransactionStatus.pending
              : TransactionStatus.paid,
          accountId: _importToCard ? null : _selectedAccountId,
          cardId: _importToCard ? _selectedCardId : null,
          categoryId: item.suggestedCategoryId,
          importHash: item.importHash,
        );
        await state.addOrUpdateTransaction(tx);
      }
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} lançamentos importados com sucesso!',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final selectedCount = _candidates.where((c) => c.selected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Extrato / Fatura'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Destino da Importação
              Material(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. O que você está importando?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Conta Corrente'),
                              selected:
                                  _targetMode == ImportTargetMode.checking,
                              onSelected: (_) {
                                setState(
                                  () =>
                                      _targetMode = ImportTargetMode.checking,
                                );
                                if (_rawContent != null &&
                                    _loadedFileName != null) {
                                  _parseContent(
                                    _rawContent!,
                                    _rawExtension,
                                    _loadedFileName!,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Fatura de Cartão'),
                              selected:
                                  _targetMode == ImportTargetMode.creditCard,
                              onSelected: (_) {
                                setState(
                                  () => _targetMode =
                                      ImportTargetMode.creditCard,
                                );
                                if (_rawContent != null &&
                                    _loadedFileName != null) {
                                  _parseContent(
                                    _rawContent!,
                                    _rawExtension,
                                    _loadedFileName!,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Cofrinho / Caixinha'),
                              selected:
                                  _targetMode == ImportTargetMode.cofrinho,
                              onSelected: (_) {
                                setState(
                                  () =>
                                      _targetMode = ImportTargetMode.cofrinho,
                                );
                                if (_rawContent != null &&
                                    _loadedFileName != null) {
                                  _parseContent(
                                    _rawContent!,
                                    _rawExtension,
                                    _loadedFileName!,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Transferência'),
                              selected:
                                  _targetMode == ImportTargetMode.transfer,
                              onSelected: (_) {
                                setState(
                                  () =>
                                      _targetMode = ImportTargetMode.transfer,
                                );
                                if (_rawContent != null &&
                                    _loadedFileName != null) {
                                  _parseContent(
                                    _rawContent!,
                                    _rawExtension,
                                    _loadedFileName!,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_targetMode == ImportTargetMode.creditCard)
                        if (state.creditCards.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCardId ??
                                state.creditCards.first.id,
                            decoration: const InputDecoration(
                              labelText: 'Selecione o Cartão de Crédito',
                              isDense: true,
                            ),
                            items: state.creditCards
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCardId = v),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.indigoSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.credit_card_rounded,
                                  color: AppColors.indigoPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Nenhum cartão cadastrado ainda.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _quickCreateNubankCard,
                                  child: const Text(
                                    '+ Criar Cartão Nubank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.indigoPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                      else if (_targetMode == ImportTargetMode.cofrinho) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText:
                                'Conta Corrente Vinculada (Aportes/Resgates)',
                            isDense: true,
                          ),
                          items: state.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAccountId = v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: state.goals.isNotEmpty
                                  ? DropdownButtonFormField<String>(
                                      initialValue: state.goals.any(
                                        (g) => g.id == _selectedGoalId,
                                      )
                                          ? _selectedGoalId
                                          : state.goals.first.id,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Cofrinho / Caixinha Padrão',
                                        isDense: true,
                                      ),
                                      items: state.goals
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g.id,
                                              child: Text(g.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedGoalId = v;
                                          for (final c in _candidates) {
                                            c.targetGoalId = v;
                                          }
                                        });
                                      },
                                    )
                                  : const Text(
                                      'Nenhum Cofrinho cadastrado.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _showQuickCreateGoalDialog,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('+ Cofrinho'),
                            ),
                          ],
                        ),
                      ] else if (_targetMode == ImportTargetMode.transfer) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Conta do Extrato',
                            isDense: true,
                          ),
                          items: state.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAccountId = v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: state.accounts.any(
                                  (a) => a.id == _selectedCounterpartAccountId,
                                )
                                    ? _selectedCounterpartAccountId
                                    : (state.accounts.isNotEmpty
                                        ? state.accounts.first.id
                                        : null),
                                decoration: const InputDecoration(
                                  labelText: 'Outra Conta Padrão',
                                  isDense: true,
                                ),
                                items: state.accounts
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedCounterpartAccountId = v;
                                    for (final c in _candidates) {
                                      c.counterpartAccountId = v;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _showQuickCreateAccountDialog,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('+ Conta'),
                            ),
                          ],
                        ),
                      ] else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Selecione a Conta Bancária',
                            isDense: true,
                          ),
                          items: state.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAccountId = v),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Seleção de Arquivo OFX/CSV ou Colar de PDF
              Material(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Carregar Arquivo ou Texto de Fatura',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Suporta arquivos OFX e CSV de bancos brasileiros (Nubank, Itaú, Inter, Bradesco, C6) ou linhas copiadas de faturas em PDF.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickFile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.indigoPrimary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(
                                Icons.upload_file_rounded,
                                size: 18,
                              ),
                              label: const Text('Abrir OFX / CSV'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pasteFromClipboard,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                size: 18,
                              ),
                              label: const Text('Colar de PDF/CSV'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_loadedFileName != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'FONTE: ${_loadedFileName!.toUpperCase()} (${_candidates.length} ITENS)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.indigoPrimary,
                        ),
                      ),
                    ),
                    if (_candidates.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: [
                          if (_targetMode == ImportTargetMode.checking ||
                              _targetMode == ImportTargetMode.creditCard)
                            TextButton.icon(
                              onPressed: _isAiCategorizing
                                  ? null
                                  : () => _runAiCategorization(
                                        silentIfNoKey: false,
                                      ),
                              icon: _isAiCategorizing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 16,
                                      color: _aiCategorizedSuccess
                                          ? AppColors.emerald
                                          : AppColors.indigoPrimary,
                                    ),
                              label: Text(
                                _isAiCategorizing
                                    ? 'IA Categorizando...'
                                    : (_aiCategorizedSuccess
                                        ? 'Categorizado c/ IA'
                                        : 'Categorizar c/ IA'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _aiCategorizedSuccess
                                      ? AppColors.emerald
                                      : AppColors.indigoPrimary,
                                ),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: _handleInvertAll,
                            icon: const Icon(Icons.swap_vert_rounded, size: 17),
                            label: const Text(
                              'Inverter Sinal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Nenhuma transação válida identificada no arquivo.',
                      ),
                    ),
                  )
                else
                  ..._candidates.map((c) {
                    late final Color badgeColor;
                    late final String badgeText;

                    if (_targetMode == ImportTargetMode.cofrinho) {
                      switch (c.cofrinhoOp) {
                        case CofrinhoOperationKind.deposit:
                          badgeColor = AppColors.indigoPrimary;
                          badgeText = 'Aporte (+ Cofrinho) ⇄';
                          break;
                        case CofrinhoOperationKind.withdraw:
                          badgeColor = AppColors.amber;
                          badgeText = 'Resgate (- Cofrinho) ⇄';
                          break;
                        case CofrinhoOperationKind.yieldGain:
                          badgeColor = AppColors.emerald;
                          badgeText = 'Rendimento (+ Cofrinho) ⇄';
                          break;
                      }
                    } else if (_targetMode == ImportTargetMode.transfer) {
                      badgeColor = c.isOutgoingTransfer
                          ? AppColors.rose
                          : AppColors.emerald;
                      badgeText = c.isOutgoingTransfer
                          ? 'Saída ➔ Outra Conta ⇄'
                          : 'Entrada ⬅ Outra Conta ⇄';
                    } else {
                      badgeColor = c.type == TransactionType.income
                          ? AppColors.emerald
                          : AppColors.rose;
                      badgeText = c.type == TransactionType.income
                          ? 'Receita ⇄'
                          : 'Despesa ⇄';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: c.selected,
                                  onChanged: (v) =>
                                      setState(() => c.selected = v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(c.date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _toggleSingleCandidateType(c),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(c.amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: badgeColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (c.isDuplicate)
                              const Padding(
                                padding: EdgeInsets.only(left: 12, bottom: 4),
                                child: Text(
                                  '⚠️ Possível duplicata já existente no seu extrato (desmarcado automaticamente)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_targetMode == ImportTargetMode.cofrinho &&
                                state.goals.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: DropdownButton<String>(
                                  value: state.goals.any(
                                    (g) => g.id == c.targetGoalId,
                                  )
                                      ? c.targetGoalId
                                      : (_selectedGoalId ??
                                          state.goals.first.id),
                                  isExpanded: true,
                                  isDense: true,
                                  items: state.goals
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g.id,
                                          child: Text(
                                            'Cofrinho: ${g.name}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.indigoPrimary,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => c.targetGoalId = v),
                                ),
                              )
                            else if (_targetMode == ImportTargetMode.transfer &&
                                state.accounts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: DropdownButton<String>(
                                  value: state.accounts.any(
                                    (a) => a.id == c.counterpartAccountId,
                                  )
                                      ? c.counterpartAccountId
                                      : (_selectedCounterpartAccountId ??
                                          state.accounts.first.id),
                                  isExpanded: true,
                                  isDense: true,
                                  items: state.accounts
                                      .map(
                                        (a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                            c.isOutgoingTransfer
                                                ? 'Para Conta: ${a.name}'
                                                : 'Vindo da Conta: ${a.name}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => c.counterpartAccountId = v,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: DropdownButton<String>(
                                  value: c.suggestedCategoryId,
                                  isExpanded: true,
                                  isDense: true,
                                  items: state.categories
                                      .where((cat) => cat.type == c.type)
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat.id,
                                          child: Text(
                                            cat.name,
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => c.suggestedCategoryId = v),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: selectedCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _confirmImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigoPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download_done_rounded),
                  label: Text(
                    'Importar $selectedCount Lançamentos Selecionados',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
