import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/import_service.dart';
import '../theme/app_theme.dart';

class UnifiedImportScreen extends StatefulWidget {
  final AppState appState;
  final ImportDestinationType? initialDestination;
  final String? initialCardId;

  const UnifiedImportScreen({
    super.key,
    required this.appState,
    this.initialDestination,
    this.initialCardId,
  });

  static Future<void> open(
    BuildContext context, {
    required AppState appState,
    ImportDestinationType? initialDestination,
    String? initialCardId,
  }) {
    HapticFeedback.mediumImpact();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnifiedImportScreen(
          appState: appState,
          initialDestination: initialDestination,
          initialCardId: initialCardId,
        ),
      ),
    );
  }

  @override
  State<UnifiedImportScreen> createState() => _UnifiedImportScreenState();
}

class _UnifiedImportScreenState extends State<UnifiedImportScreen> {
  late ImportDestinationType _destination;
  String? _selectedCardId;
  late String _selectedInvoiceMonth;

  String _rawLoadedContent = '';
  String? _loadedSourceName;
  bool _invertSigns = false;
  List<ImportCandidate> _candidates = [];

  @override
  void initState() {
    super.initState();
    _selectedInvoiceMonth = widget.appState.selectedYearMonth;
    if (widget.initialCardId != null) {
      _destination = ImportDestinationType.creditCard;
      _selectedCardId = widget.initialCardId;
    } else if (widget.initialDestination != null) {
      _destination = widget.initialDestination!;
      _selectedCardId = widget.appState.cards.isNotEmpty
          ? widget.appState.cards.first.id
          : null;
    } else {
      _destination = ImportDestinationType.checking;
      _selectedCardId = widget.appState.cards.isNotEmpty
          ? widget.appState.cards.first.id
          : null;
    }
  }

  void _reparseCurrentContent() {
    if (_rawLoadedContent.trim().isEmpty) return;
    setState(() {
      _candidates = ImportService.parseContent(
        content: _rawLoadedContent,
        defaultDestination: _destination,
        selectedInvoiceMonth: _selectedInvoiceMonth,
        defaultCardId: _selectedCardId,
        categories: widget.appState.categories,
        existingTransactions: widget.appState.allTransactions,
        invertSigns: _invertSigns,
      );
    });
  }

  void _updateGlobalDestination(
    ImportDestinationType dest, {
    String? cardId,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _destination = dest;
      if (cardId != null) _selectedCardId = cardId;
      if (_candidates.isNotEmpty) {
        ImportService.applyGlobalDestination(
          candidates: _candidates,
          destination: _destination,
          selectedInvoiceMonth: _selectedInvoiceMonth,
          cardId: _selectedCardId,
          categories: widget.appState.categories,
          existingTransactions: widget.appState.allTransactions,
        );
      }
    });
  }

  void _changeInvoiceMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedInvoiceMonth =
          AppFormatters.addMonths(_selectedInvoiceMonth, delta);
      if (_candidates.isNotEmpty &&
          _destination == ImportDestinationType.creditCard) {
        ImportService.applyGlobalDestination(
          candidates: _candidates,
          destination: _destination,
          selectedInvoiceMonth: _selectedInvoiceMonth,
          cardId: _selectedCardId,
          categories: widget.appState.categories,
          existingTransactions: widget.appState.allTransactions,
        );
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      const group = XTypeGroup(
        label: 'Extratos e Faturas (OFX, CSV, TXT)',
        extensions: ['ofx', 'csv', 'txt'],
      );
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      setState(() {
        _rawLoadedContent = content;
        _loadedSourceName = file.name;
        _invertSigns = false;
      });
      _reparseCurrentContent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível ler o arquivo: $e')),
      );
    }
  }

  Future<void> _openPasteModal() async {
    final ctrl = TextEditingController(
      text: _loadedSourceName == 'Texto colado' ? _rawLoadedContent : '',
    );

    final pasted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + inset),
          decoration: BoxDecoration(
            color: AppColors.surface(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Colar Extrato ou Fatura',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          ctrl.text = data!.text!;
                        }
                      },
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      label: const Text('Colar Área de Transf.'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 8,
                  minLines: 5,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText:
                        'Exemplos aceitos:\n12/11 Supermercado Extra 150,20\n15/11 Shopee 2/6 89,90\n2026-11-10;Uber;-24,90',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text(
                      'Processar Lançamentos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pasted != null && pasted.trim().isNotEmpty) {
      setState(() {
        _rawLoadedContent = pasted;
        _loadedSourceName = 'Texto colado';
        _invertSigns = false;
      });
      _reparseCurrentContent();
    }
  }

  Future<void> _commitImport() async {
    final selectedCount = _candidates.where((c) => c.selected).length;
    if (selectedCount == 0) return;

    HapticFeedback.mediumImpact();
    final savedCount = await widget.appState.commitImportedCandidates(
      candidates: _candidates,
      selectedInvoiceMonth: _selectedInvoiceMonth,
    );

    if (_destination == ImportDestinationType.creditCard) {
      widget.appState.setSelectedYearMonth(_selectedInvoiceMonth);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$savedCount ${savedCount == 1 ? 'lançamento importado' : 'lançamentos importados'} com sucesso!',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickCategoryForCandidate(ImportCandidate c) async {
    final txType =
        (c.destination == ImportDestinationType.checking && c.isCreditOrRefund)
            ? TransactionType.income
            : TransactionType.expense;
    final cats = widget.appState.categoriesByType(txType);

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            color: AppColors.surface(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categoria para "${c.title}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats.map((cat) {
                    final selected = c.categoryId == cat.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(ctx).pop(cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cat.color.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected ? cat.color : AppColors.border(ctx),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 17, color: cat.color),
                            const SizedBox(width: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      setState(() => c.categoryId = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.appState.cards;
    final selectedCandidates = _candidates.where((c) => c.selected).toList();
    final selectedCount = selectedCandidates.length;

    double netImpact = 0.0;
    int futureInstallmentsCount = 0;

    for (final c in selectedCandidates) {
      if (c.destination == ImportDestinationType.checking) {
        netImpact += c.isCreditOrRefund ? c.amount : -c.amount;
      } else {
        // Na fatura do cartão: compras somam na fatura, estornos e pagamentos antecipados abatem da fatura
        netImpact +=
            (c.isCreditOrRefund || c.isInvoicePayment) ? -c.amount : c.amount;
        if (c.canProjectFuture && c.projectFutureInstallments) {
          futureInstallmentsCount += (c.installmentTotal - c.installmentIndex);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Extrato / Fatura'),
        actions: [
          if (_candidates.isNotEmpty)
            IconButton(
              tooltip: 'Colar outro texto',
              onPressed: _openPasteModal,
              icon: const Icon(Icons.content_paste_rounded, size: 20),
            ),
          if (_candidates.isNotEmpty)
            IconButton(
              tooltip: 'Abrir outro arquivo',
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 20),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Cabeçalho Unificado de Destino (Conta Corrente / Pix vs Fatura de Cartão)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border(context),
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESTINO DOS LANÇAMENTOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),

                // Lista (Dropdown) Principal: Conta Corrente vs Fatura de Cartão
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.isDark(context)
                        ? AppColors.darkBackground
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border(context),
                      width: 0.8,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ImportDestinationType>(
                      value: _destination,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(
                          value: ImportDestinationType.checking,
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                size: 18,
                                color: AppColors.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Conta Corrente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: ImportDestinationType.creditCard,
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card_rounded,
                                size: 18,
                                color: AppColors.purple,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Fatura de Cartão',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateGlobalDestination(
                            val,
                            cardId: _selectedCardId ??
                                (cards.isNotEmpty ? cards.first.id : null),
                          );
                        }
                      },
                    ),
                  ),
                ),

                // Seleção do Cartão e do Mês da Fatura quando Fatura estiver ativa
                if (_destination == ImportDestinationType.creditCard) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context)
                                ? AppColors.darkBackground
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border(context),
                              width: 0.8,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: cards.any((c) => c.id == _selectedCardId)
                                  ? _selectedCardId
                                  : (cards.isNotEmpty ? cards.first.id : null),
                              isExpanded: true,
                              hint: const Text('Selecione o Cartão'),
                              borderRadius: BorderRadius.circular(12),
                              items: cards
                                  .map(
                                    (card) => DropdownMenuItem<String>(
                                      value: card.id,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.credit_card_rounded,
                                            size: 16,
                                            color: card.color,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              card.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (cardId) {
                                if (cardId != null) {
                                  _updateGlobalDestination(
                                    ImportDestinationType.creditCard,
                                    cardId: cardId,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => _changeInvoiceMonth(-1),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 20,
                              ),
                            ),
                            Text(
                              AppFormatters.monthLabel(
                                _selectedInvoiceMonth,
                                short: true,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.purple,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => _changeInvoiceMonth(1),
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Barra de Ferramentas da Revisão (quando há itens carregados)
                if (_candidates.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.swap_vert_rounded, size: 16),
                          label: Text(
                            _invertSigns
                                ? 'Sinais Invertidos (+/-)'
                                : 'Inverter Sinais (+/-)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _invertSigns = !_invertSigns);
                            _reparseCurrentContent();
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text(
                            'Marcar / Desmarcar Válidos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            final anySelected =
                                _candidates.any((c) => c.selected);
                            setState(() {
                              for (final c in _candidates) {
                                if (anySelected) {
                                  c.selected = false;
                                } else if (!c.isDuplicate &&
                                    c.ignoreReason == null) {
                                  c.selected = true;
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Estado vazio (Escolher Arquivo ou Colar Texto) vs Lista de Revisão
          Expanded(
            child: _candidates.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    itemCount: _candidates.length,
                    itemBuilder: (context, index) {
                      final c = _candidates[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CandidateCard(
                          candidate: c,
                          appState: widget.appState,
                          selectedInvoiceMonth: _selectedInvoiceMonth,
                          onToggleSelected: () {
                            HapticFeedback.selectionClick();
                            setState(() => c.selected = !c.selected);
                          },
                          onToggleSign: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              c.isCreditOrRefund = !c.isCreditOrRefund;
                              final txType = (c.destination ==
                                          ImportDestinationType.checking &&
                                      c.isCreditOrRefund)
                                  ? TransactionType.income
                                  : TransactionType.expense;
                              c.categoryId = ImportService.suggestCategoryId(
                                title: c.title,
                                type: txType,
                                categories: widget.appState.categories,
                                existingTransactions:
                                    widget.appState.allTransactions,
                              );
                            });
                          },
                          onToggleDestination: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (c.destination ==
                                  ImportDestinationType.checking) {
                                c.destination =
                                    ImportDestinationType.creditCard;
                                c.cardId = _selectedCardId ??
                                    (cards.isNotEmpty ? cards.first.id : null);
                              } else {
                                c.destination = ImportDestinationType.checking;
                              }
                            });
                          },
                          onToggleProjectFuture: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              c.projectFutureInstallments =
                                  !c.projectFutureInstallments;
                            });
                          },
                          onToggleIgnored: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              c.isIgnored = !c.isIgnored;
                            });
                          },
                          onPickCategory: () => _pickCategoryForCandidate(c),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // 3. Barra Inferior Fixa de Confirmação
      bottomNavigationBar: _candidates.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border(context),
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            futureInstallmentsCount > 0
                                ? '$selectedCount deste mês (+$futureInstallmentsCount parc.)'
                                : '$selectedCount de ${_candidates.length} selecionados',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _destination == ImportDestinationType.creditCard
                              ? 'Fatura: ${AppFormatters.currency(netImpact)}'
                              : 'Líquido: ${AppFormatters.currency(netImpact)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: selectedCount > 0 ? _commitImport : null,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          'Importar $selectedCount ${selectedCount == 1 ? 'Lançamento' : 'Lançamentos'}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        HigGroupedCard(
          padding: const EdgeInsets.all(22),
          children: [
            const Icon(
              Icons.upload_file_rounded,
              size: 46,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Importador Unificado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Importe arquivos OFX ou CSV do seu banco, ou cole o texto copiado da fatura em PDF. Pagamentos de fatura e cofrinhos/RDB são ignorados automaticamente para nunca duplicar seus gastos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text(
                  'Selecionar Arquivo (.OFX ou .CSV)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openPasteModal,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text(
                  'Colar Texto (Extrato / PDF)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final ImportCandidate candidate;
  final AppState appState;
  final String selectedInvoiceMonth;
  final VoidCallback onToggleSelected;
  final VoidCallback onToggleSign;
  final VoidCallback onToggleDestination;
  final VoidCallback onToggleProjectFuture;
  final VoidCallback onToggleIgnored;
  final VoidCallback onPickCategory;

  const _CandidateCard({
    required this.candidate,
    required this.appState,
    required this.selectedInvoiceMonth,
    required this.onToggleSelected,
    required this.onToggleSign,
    required this.onToggleDestination,
    required this.onToggleProjectFuture,
    required this.onToggleIgnored,
    required this.onPickCategory,
  });

  @override
  Widget build(BuildContext context) {
    final cat = appState.categoryById(candidate.categoryId);
    final isCard = candidate.destination == ImportDestinationType.creditCard;
    final card = appState.cardById(candidate.cardId);

    // Determina rótulo e cor do valor conforme o destino
    final bool isPositiveDisplay =
        candidate.isCreditOrRefund || candidate.isInvoicePayment;
    final Color amountColor = isPositiveDisplay
        ? AppColors.success(context)
        : AppColors.danger(context);
    final String signPrefix = isPositiveDisplay ? '+' : '-';
    final String typeLabel = isCard
        ? (candidate.isInvoicePayment
            ? 'Pagamento Antecipado'
            : (candidate.isCreditOrRefund
                ? 'Estorno na Fatura'
                : 'Compra Cartão'))
        : (candidate.isCreditOrRefund ? 'Receita (+)' : 'Saída Conta');

    return Opacity(
      opacity: candidate.selected ? 1.0 : 0.58,
      child: Material(
        color: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: candidate.selected
                ? AppColors.border(context)
                : AppColors.border(context).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: candidate.selected,
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => onToggleSelected(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isCard
                              ? 'Compra em ${AppFormatters.shortDate(candidate.date)} • Fatura ${AppFormatters.monthLabel(selectedInvoiceMonth, short: true)}'
                              : 'Data: ${AppFormatters.shortDate(candidate.date)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleSign,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$signPrefix ${AppFormatters.currency(candidate.amount)}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                            ),
                          ),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: amountColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Avisos de Pagamento Antecipado, Ignorado Automático ou Duplicata
              if (candidate.isInvoicePayment ||
                  candidate.ignoreReason != null ||
                  candidate.isDuplicate) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (candidate.isInvoicePayment)
                        _StatusBadge(
                          icon: Icons.payments_rounded,
                          text: 'Pagamento da Fatura (abate saldo a pagar)',
                          color: AppColors.success(context),
                        ),
                      if (candidate.ignoreReason != null)
                        _StatusBadge(
                          icon: Icons.filter_alt_off_rounded,
                          text: 'Ignorado: ${candidate.ignoreReason}',
                          color: AppColors.orange,
                        ),
                      if (candidate.isDuplicate)
                        const _StatusBadge(
                          icon: Icons.copy_all_rounded,
                          text: 'Já lançado neste mês',
                          color: AppColors.blue,
                        ),
                    ],
                  ),
                ),
              ],

              // Pílulas rápidas: Categoria, Destino e Projeção de Parcelas
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Categoria
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onPickCategory,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 13, color: cat.color),
                            const SizedBox(width: 4),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Alternar Destino da linha (Conta vs Cartão)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onToggleDestination,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isCard
                                  ? (card?.color ?? AppColors.purple)
                                  : AppColors.blue)
                              .withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCard
                                  ? Icons.credit_card_rounded
                                  : Icons.account_balance_rounded,
                              size: 13,
                              color: isCard
                                  ? (card?.color ?? AppColors.purple)
                                  : AppColors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCard
                                  ? (card?.name ?? 'Cartão')
                                  : 'Conta Corrente',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Botão toggle ativo/inativo 'Ignorar'
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onToggleIgnored,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: candidate.isIgnored
                              ? AppColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidate.isIgnored
                                ? AppColors.orange
                                : AppColors.border(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              candidate.isIgnored
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_off_outlined,
                              size: 12,
                              color: candidate.isIgnored
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ignorar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: candidate.isIgnored
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Badge de Parcela + Projeção Futura
                    if (candidate.hasInstallments && isCard)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: candidate.canProjectFuture
                            ? onToggleProjectFuture
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: candidate.projectFutureInstallments
                                ? AppColors.primary.withValues(alpha: 0.16)
                                : AppColors.border(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                candidate.projectFutureInstallments
                                    ? Icons.event_repeat_rounded
                                    : Icons.tag_rounded,
                                size: 13,
                                color: candidate.projectFutureInstallments
                                    ? AppColors.primary
                                    : AppColors.textSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                candidate.canProjectFuture
                                    ? (candidate.projectFutureInstallments
                                        ? 'Parcela ${candidate.installmentIndex}/${candidate.installmentTotal} (+ projetar próximas)'
                                        : 'Parcela ${candidate.installmentIndex}/${candidate.installmentTotal} (só este mês)')
                                    : 'Parcela ${candidate.installmentIndex}/${candidate.installmentTotal}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: candidate.projectFutureInstallments
                                      ? AppColors.primary
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
