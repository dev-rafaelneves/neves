import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/app_state.dart';
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

  bool _importToCard = false;
  String? _selectedAccountId;
  String? _selectedCardId;
  List<ImportedTransactionCandidate> _candidates = [];
  String? _loadedFileName;

  @override
  void initState() {
    super.initState();
    final state = widget.appState;
    if (state.accounts.isNotEmpty) {
      _selectedAccountId = state.accounts.first.id;
    }
    if (state.creditCards.isNotEmpty) {
      _selectedCardId = state.creditCards.first.id;
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
    final parsed = ImportService.parseStatementContent(
      content: content,
      extension: ext,
      categories: widget.appState.categories,
      existingTransactions: widget.appState.transactions,
      forceExpenseForCreditCard: _importToCard,
    );
    HapticFeedback.lightImpact();
    setState(() {
      _candidates = parsed;
      _loadedFileName = sourceLabel;
    });
  }

  Future<void> _confirmImport() async {
    final selected = _candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final state = widget.appState;
    final card = _importToCard ? state.getCardById(_selectedCardId) : null;

    for (final item in selected) {
      final compMonth = card != null
          ? card.computeCompetenceMonth(item.date)
          : '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';

      final tx = TransactionModel(
        id: _uuid.v4(),
        title: item.title,
        amount: item.amount,
        type: item.type,
        date: item.date,
        competenceMonth: compMonth,
        status:
            _importToCard ? TransactionStatus.pending : TransactionStatus.paid,
        accountId: _importToCard ? null : _selectedAccountId,
        cardId: _importToCard ? _selectedCardId : null,
        categoryId: item.suggestedCategoryId,
        importHash: item.importHash,
      );
      await state.addOrUpdateTransaction(tx);
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
                        '1. Destino dos Lançamentos',
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
                              label: const Text('Conta Bancária'),
                              selected: !_importToCard,
                              onSelected: (_) =>
                                  setState(() => _importToCard = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Fatura de Cartão'),
                              selected: _importToCard,
                              onSelected: state.creditCards.isNotEmpty
                                  ? (_) => setState(() => _importToCard = true)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_importToCard && state.creditCards.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCardId,
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
                          onChanged: (v) => setState(() => _selectedCardId = v),
                        )
                      else
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
                Text(
                  'FONTE: ${_loadedFileName!.toUpperCase()} (${_candidates.length} ITENS ENCONTRADOS)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.indigoPrimary,
                  ),
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
                                Text(
                                  AppFormatters.currency(c.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: c.type == TransactionType.income
                                        ? AppColors.emerald
                                        : AppColors.rose,
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
                                          '${cat.name} (${cat.pillar.label})',
                                          style: const TextStyle(fontSize: 12.5),
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
