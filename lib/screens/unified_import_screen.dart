import 'dart:convert';
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
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
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      CupertinoPageRoute(
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController(
      text: _loadedSourceName == 'Texto colado' ? _rawLoadedContent : '',
    );

    final pasted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + inset),
              decoration: BoxDecoration(
                color: AppColors.surface(ctx).withValues(alpha: 0.94),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border(ctx),
                    width: AppSpacing.hairlineBorder,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(ctx)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Colar Extrato ou Fatura',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              ctrl.text = data!.text!;
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.doc_on_clipboard,
                                size: 15,
                                color: AppColors.iosBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Colar Área de Transf.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.iosBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface(ctx),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.border(ctx),
                          width: AppSpacing.hairlineBorder,
                        ),
                      ),
                      child: TextField(
                        controller: ctrl,
                        maxLines: 8,
                        minLines: 5,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontFeatures: AppTypography.tabular,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Exemplos aceitos:\n12/11 Supermercado Extra 150,20\n15/11 Shopee 2/6 89,90\n2026-11-10;Uber;-24,90',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: AppColors.iosBlue,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop(ctrl.text);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.sparkles,
                              size: 17,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Processar Lançamentos',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    final txType =
        (c.destination == ImportDestinationType.checking && c.isCreditOrRefund)
            ? TransactionType.income
            : TransactionType.expense;
    final cats = widget.appState.categoriesByType(txType);

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                color: AppColors.surface(ctx).withValues(alpha: 0.94),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: AppColors.border(ctx),
                    width: AppSpacing.hairlineBorder,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(ctx)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Text(
                      'Categoria para "${c.title}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cats.map((cat) {
                        final selected = c.categoryId == cat.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop(cat.id);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cat.color.withValues(alpha: 0.16)
                                  : AppColors.secondarySurface(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? cat.color
                                    : AppColors.border(ctx),
                                width:
                                    selected ? 1.4 : AppSpacing.hairlineBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HigIconSquircle(
                                  icon: cat.icon,
                                  color: cat.color,
                                  size: 26,
                                  iconSize: 14,
                                  radius: 7,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: const Icon(
            CupertinoIcons.back,
            color: AppColors.iosBlue,
          ),
        ),
        actions: [
          if (_candidates.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: _openPasteModal,
              child: const Icon(
                CupertinoIcons.doc_on_clipboard,
                size: 20,
                color: AppColors.iosBlue,
              ),
            ),
          if (_candidates.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.only(left: 4, right: 14),
              onPressed: _pickFile,
              child: const Icon(
                CupertinoIcons.folder,
                size: 20,
                color: AppColors.iosBlue,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Cabeçalho Translúcido de Destino (Conta Corrente vs Fatura de Cartão)
          _ImportDestinationHeader(
            destination: _destination,
            selectedCardId: _selectedCardId,
            selectedInvoiceMonth: _selectedInvoiceMonth,
            cards: cards,
            hasCandidates: _candidates.isNotEmpty,
            invertSigns: _invertSigns,
            onDestinationChanged: (val) {
              _updateGlobalDestination(
                val,
                cardId: _selectedCardId ??
                    (cards.isNotEmpty ? cards.first.id : null),
              );
            },
            onCardChanged: (cardId) {
              _updateGlobalDestination(
                ImportDestinationType.creditCard,
                cardId: cardId,
              );
            },
            onPrevMonth: () => _changeInvoiceMonth(-1),
            onNextMonth: () => _changeInvoiceMonth(1),
            onToggleInvertSigns: () {
              HapticFeedback.lightImpact();
              setState(() => _invertSigns = !_invertSigns);
              _reparseCurrentContent();
            },
            onToggleSelectAllValid: () {
              HapticFeedback.lightImpact();
              final anySelected = _candidates.any((c) => c.selected);
              setState(() {
                for (final c in _candidates) {
                  if (anySelected) {
                    c.selected = false;
                  } else if (!c.isDuplicate && c.ignoreReason == null) {
                    c.selected = true;
                  }
                }
              });
            },
          ),

          // 2. Estado Vazio vs Lista de Revisão de Lançamentos
          Expanded(
            child: _candidates.isEmpty
                ? _ImportEmptyState(
                    onPickFile: _pickFile,
                    onOpenPaste: _openPasteModal,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
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
                            HapticFeedback.lightImpact();
                            setState(() => c.selected = !c.selected);
                          },
                          onToggleSign: () {
                            HapticFeedback.lightImpact();
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
                            HapticFeedback.lightImpact();
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
                            HapticFeedback.lightImpact();
                            setState(() {
                              c.projectFutureInstallments =
                                  !c.projectFutureInstallments;
                            });
                          },
                          onToggleIgnored: () {
                            HapticFeedback.lightImpact();
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

      // 3. Barra Inferior Translúcida de Confirmação com tabularFigures
      bottomNavigationBar: _candidates.isEmpty
          ? null
          : _ImportBottomConfirmationBar(
              selectedCount: selectedCount,
              totalCount: _candidates.length,
              futureInstallmentsCount: futureInstallmentsCount,
              isCreditCardDestination:
                  _destination == ImportDestinationType.creditCard,
              netImpact: netImpact,
              onCommit: selectedCount > 0 ? _commitImport : null,
            ),
    );
  }
}

/// 1. Cabeçalho de Destino (Conta Corrente vs Fatura de Cartão) + Filtros de Revisão
class _ImportDestinationHeader extends StatelessWidget {
  final ImportDestinationType destination;
  final String? selectedCardId;
  final String selectedInvoiceMonth;
  final List<CreditCardItem> cards;
  final bool hasCandidates;
  final bool invertSigns;
  final ValueChanged<ImportDestinationType> onDestinationChanged;
  final ValueChanged<String> onCardChanged;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToggleInvertSigns;
  final VoidCallback onToggleSelectAllValid;

  const _ImportDestinationHeader({
    required this.destination,
    required this.selectedCardId,
    required this.selectedInvoiceMonth,
    required this.cards,
    required this.hasCandidates,
    required this.invertSigns,
    required this.onDestinationChanged,
    required this.onCardChanged,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToggleInvertSigns,
    required this.onToggleSelectAllValid,
  });

  @override
  Widget build(BuildContext context) {
    return HigFrostedSurface(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      border: Border(
        bottom: BorderSide(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESTINO DOS LANÇAMENTOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),

          // Dropdown Principal: Conta Corrente vs Fatura de Cartão
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface(context),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.border(context),
                width: AppSpacing.hairlineBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ImportDestinationType>(
                value: destination,
                isExpanded: true,
                borderRadius: BorderRadius.circular(13),
                items: const [
                  DropdownMenuItem(
                    value: ImportDestinationType.checking,
                    child: Row(
                      children: [
                        HigIconSquircle(
                          icon: CupertinoIcons.building_2_fill,
                          color: AppColors.iosBlue,
                          size: 28,
                          iconSize: 15,
                          radius: 8,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Conta Corrente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: ImportDestinationType.creditCard,
                    child: Row(
                      children: [
                        HigIconSquircle(
                          icon: CupertinoIcons.creditcard_fill,
                          color: AppColors.iosIndigo,
                          size: 28,
                          iconSize: 15,
                          radius: 8,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Fatura de Cartão',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) onDestinationChanged(val);
                },
              ),
            ),
          ),

          // Seleção do Cartão e do Mês da Fatura quando Fatura estiver ativa
          if (destination == ImportDestinationType.creditCard) ...[
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
                      color: AppColors.secondarySurface(context),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.border(context),
                        width: AppSpacing.hairlineBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: cards.any((c) => c.id == selectedCardId)
                            ? selectedCardId
                            : (cards.isNotEmpty ? cards.first.id : null),
                        isExpanded: true,
                        hint: const Text('Selecione o Cartão'),
                        borderRadius: BorderRadius.circular(13),
                        items: cards
                            .map(
                              (card) => DropdownMenuItem<String>(
                                value: card.id,
                                child: Row(
                                  children: [
                                    HigIconSquircle(
                                      icon: CupertinoIcons.creditcard_fill,
                                      color: card.color,
                                      size: 26,
                                      iconSize: 14,
                                      radius: 7,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        card.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (cardId) {
                          if (cardId != null) onCardChanged(cardId);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.iosIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onPrevMonth,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            CupertinoIcons.chevron_left,
                            size: 16,
                            color: AppColors.iosIndigo,
                          ),
                        ),
                      ),
                      Text(
                        AppFormatters.monthLabel(
                          selectedInvoiceMonth,
                          short: true,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.iosIndigo,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      GestureDetector(
                        onTap: onNextMonth,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppColors.iosIndigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Barra de Ferramentas da Revisão (quando há itens carregados)
          if (hasCandidates) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickReviewChip(
                    icon: CupertinoIcons.arrow_up_arrow_down,
                    label: invertSigns
                        ? 'Sinais Invertidos (+/-)'
                        : 'Inverter Sinais (+/-)',
                    color: AppColors.iosIndigo,
                    onTap: onToggleInvertSigns,
                  ),
                  const SizedBox(width: 8),
                  _QuickReviewChip(
                    icon: CupertinoIcons.checkmark_circle_fill,
                    label: 'Marcar / Desmarcar Válidos',
                    color: AppColors.iosBlue,
                    onTap: onToggleSelectAllValid,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickReviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickReviewChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondarySurface(context),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Estado Vazio Minimalista Apple HIG (Selecionar Arquivo ou Colar Texto)
class _ImportEmptyState extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onOpenPaste;

  const _ImportEmptyState({
    required this.onPickFile,
    required this.onOpenPaste,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        HigGroupedCard(
          borderRadius: AppSpacing.heroRadius,
          padding: const EdgeInsets.all(24),
          children: [
            const Center(
              child: HigIconSquircle(
                icon: CupertinoIcons.tray_arrow_down_fill,
                color: AppColors.iosBlue,
                size: 52,
                iconSize: 26,
                radius: 15,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Importador Unificado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Importe arquivos OFX ou CSV do seu banco, ou cole o texto copiado da fatura em PDF. Pagamentos antecipados abatem do saldo da fatura e cofrinhos/RDB são ignorados automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: AppColors.iosBlue,
                borderRadius: BorderRadius.circular(14),
                onPressed: onPickFile,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.folder_fill,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Selecionar Arquivo (.OFX ou .CSV)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: AppColors.secondarySurface(context),
                borderRadius: BorderRadius.circular(14),
                onPressed: onOpenPaste,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.doc_on_clipboard_fill,
                      size: 18,
                      color: AppColors.iosBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Colar Texto (Extrato / PDF)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 3. Barra Inferior Translúcida de Confirmação com `tabularFigures`
class _ImportBottomConfirmationBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final int futureInstallmentsCount;
  final bool isCreditCardDestination;
  final double netImpact;
  final VoidCallback? onCommit;

  const _ImportBottomConfirmationBar({
    required this.selectedCount,
    required this.totalCount,
    required this.futureInstallmentsCount,
    required this.isCreditCardDestination,
    required this.netImpact,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return HigFrostedSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      border: Border(
        top: BorderSide(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
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
                        : '$selectedCount de $totalCount selecionados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionTabular(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCreditCardDestination
                      ? 'Fatura: ${AppFormatters.currency(netImpact)}'
                      : 'Líquido: ${AppFormatters.currency(netImpact)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: AppColors.iosGreen,
                disabledColor: AppColors.iosGreen.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                onPressed: onCommit,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Importar $selectedCount ${selectedCount == 1 ? 'Lançamento' : 'Lançamentos'}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. Card de Lançamento Candidato Estilo Copilot Money / Apple Wallet
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
      opacity: candidate.selected ? 1.0 : 0.56,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: candidate.selected
                ? AppColors.border(context)
                : AppColors.border(context).withValues(alpha: 0.5),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onToggleSelected,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      candidate.selected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 22,
                      color: candidate.selected
                          ? AppColors.iosBlue
                          : AppColors.textSecondary(context),
                    ),
                  ),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCard
                            ? 'Compra em ${AppFormatters.shortDate(candidate.date)} • Fatura ${AppFormatters.monthLabel(selectedInvoiceMonth, short: true)}'
                            : 'Data: ${AppFormatters.shortDate(candidate.date)}',
                        style: AppTypography.captionTabular(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggleSign,
                  behavior: HitTestBehavior.opaque,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: amountColor,
                            fontFeatures: AppTypography.tabular,
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
                padding: const EdgeInsets.only(left: 32, top: 6, bottom: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (candidate.isInvoicePayment)
                      _StatusBadge(
                        icon: CupertinoIcons.checkmark_seal_fill,
                        text: 'Pagamento da Fatura (abate saldo a pagar)',
                        color: AppColors.success(context),
                      ),
                    if (candidate.ignoreReason != null)
                      _StatusBadge(
                        icon: CupertinoIcons.eye_slash_fill,
                        text: 'Ignorado: ${candidate.ignoreReason}',
                        color: AppColors.iosOrange,
                      ),
                    if (candidate.isDuplicate)
                      const _StatusBadge(
                        icon: CupertinoIcons.doc_on_doc_fill,
                        text: 'Já lançado neste mês',
                        color: AppColors.iosBlue,
                      ),
                  ],
                ),
              ),
            ],

            // Pílulas rápidas: Categoria, Destino, Ignorar e Projeção de Parcelas
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Categoria com Squircle 12%
                  GestureDetector(
                    onTap: onPickCategory,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
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
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Alternar Destino da linha (Conta vs Cartão)
                  GestureDetector(
                    onTap: onToggleDestination,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isCard
                                ? (card?.color ?? AppColors.iosIndigo)
                                : AppColors.iosBlue)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCard
                                ? CupertinoIcons.creditcard_fill
                                : CupertinoIcons.building_2_fill,
                            size: 13,
                            color: isCard
                                ? (card?.color ?? AppColors.iosIndigo)
                                : AppColors.iosBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCard
                                ? (card?.name ?? 'Cartão')
                                : 'Conta Corrente',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botão toggle ativo/inativo 'Ignorar' (oculto para Pagamento de Fatura)
                  if (!candidate.isInvoicePayment)
                    GestureDetector(
                      onTap: onToggleIgnored,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: candidate.isIgnored
                              ? AppColors.iosOrange
                              : AppColors.iosOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidate.isIgnored
                                ? AppColors.iosOrange
                                : AppColors.border(context),
                            width: AppSpacing.hairlineBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              candidate.isIgnored
                                  ? CupertinoIcons.eye_slash_fill
                                  : CupertinoIcons.eye_slash,
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
                                fontWeight: FontWeight.w600,
                                color: candidate.isIgnored
                                    ? Colors.white
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge de Parcela + Projeção Futura com tabularFigures
                  if (candidate.hasInstallments && isCard)
                    GestureDetector(
                      onTap: candidate.canProjectFuture
                          ? onToggleProjectFuture
                          : null,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: candidate.projectFutureInstallments
                              ? AppColors.iosGreen.withValues(alpha: 0.12)
                              : AppColors.secondarySurface(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              candidate.projectFutureInstallments
                                  ? CupertinoIcons.repeat
                                  : CupertinoIcons.number,
                              size: 12.5,
                              color: candidate.projectFutureInstallments
                                  ? AppColors.iosGreen
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
                                fontWeight: FontWeight.w600,
                                color: candidate.projectFutureInstallments
                                    ? AppColors.iosGreen
                                    : AppColors.textSecondary(context),
                                fontFeatures: AppTypography.tabular,
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
