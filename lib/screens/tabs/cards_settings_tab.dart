import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neves_app_icon.dart';

class CardsSettingsTab extends StatelessWidget {
  final AppState appState;

  const CardsSettingsTab({super.key, required this.appState});

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final jsonStr = appState.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final dateTag =
          DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
      final file = File('${dir.path}/neves_backup_$dateTag.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Backup Neves Finanças',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar backup: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final content = await file.readAsString();
      await appState.importBackupJson(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo de backup inválido: $e')),
      );
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zerar todos os dados?'),
        content: const Text(
          'Todos os lançamentos serão apagados e os cartões e categorias voltarão para o padrão inicial. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.resetAllData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados reiniciados com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = appState.cards;
    final expCats = appState.categoriesByType(TransactionType.expense);
    final incCats = appState.categoriesByType(TransactionType.income);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Seção: Cartões de Crédito
        HigSectionHeader(
          title: 'Cartões de Crédito',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => showCardModal(context, appState),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Novo Cartão',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        HigGroupedCard(
          children: [
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Nenhum cartão cadastrado. Toque em "Novo Cartão" acima.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              )
            else
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  onTap: () =>
                      showCardModal(context, appState, existing: cards[i]),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cards[i].color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.credit_card_rounded,
                      color: cards[i].color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    cards[i].name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Fecha dia ${cards[i].closingDay} • Vence dia ${cards[i].dueDay}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () =>
                        showCardModal(context, appState, existing: cards[i]),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                  ),
                ),
              ],
          ],
        ),
        const SizedBox(height: 22),

        // Seção: Categorias
        HigSectionHeader(
          title: 'Categorias',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _showCategoryModal(context, appState),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Nova Categoria',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        HigGroupedCard(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Despesas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: expCats
                  .map(
                    (cat) => _CategoryEditChip(
                      cat: cat,
                      onTap: () =>
                          _showCategoryModal(context, appState, existing: cat),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Receitas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: incCats
                  .map(
                    (cat) => _CategoryEditChip(
                      cat: cat,
                      onTap: () =>
                          _showCategoryModal(context, appState, existing: cat),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Seção: Aparência
        const HigSectionHeader(title: 'Aparência'),
        HigGroupedCard(
          padding: const EdgeInsets.all(14),
          children: [
            CupertinoSlidingSegmentedControl<ThemeMode>(
              groupValue: appState.themeMode,
              onValueChanged: (mode) {
                if (mode != null) {
                  HapticFeedback.selectionClick();
                  appState.setThemeMode(mode);
                }
              },
              children: const {
                ThemeMode.system: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sistema'),
                ),
                ThemeMode.light: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Claro'),
                ),
                ThemeMode.dark: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Escuro'),
                ),
              },
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Seção: Dados e Backup
        const HigSectionHeader(title: 'Dados & Backup'),
        HigGroupedCard(
          children: [
            ListTile(
              onTap: () => _exportBackup(context),
              leading: const Icon(
                Icons.ios_share_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Exportar Backup (JSON)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Salve seus dados para trocar de aparelho',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              onTap: () => _importBackup(context),
              leading: const Icon(
                Icons.restore_page_rounded,
                color: AppColors.blue,
              ),
              title: const Text(
                'Restaurar Backup (JSON)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Importar arquivo salvo anteriormente',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              onTap: () => _confirmReset(context),
              leading: Icon(
                Icons.delete_forever_rounded,
                color: AppColors.danger(context),
              ),
              title: Text(
                'Apagar Todos os Dados',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger(context),
                ),
              ),
              subtitle: const Text(
                'Voltar o aplicativo para o estado inicial limpo',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Rodapé Sobre o MVP
        Center(
          child: Column(
            children: [
              const NevesAppIcon(size: 48),
              const SizedBox(height: 8),
              Text(
                'Neves Finanças • MVP v2.0',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                'Controle mensal enxuto e 100% offline',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> showCardModal(
    BuildContext context,
    AppState appState, {
    CreditCardItem? existing,
  }) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CardEditorSheet(
        appState: appState,
        existing: existing,
      ),
    );
  }

  static Future<void> _showCategoryModal(
    BuildContext context,
    AppState appState, {
    CategoryItem? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    TransactionType type = existing?.type ?? TransactionType.expense;
    String iconKey = existing?.iconKey ?? 'category';
    int colorVal =
        existing?.colorValue ?? AppColors.presetPalette.first.toARGB32();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existing == null
                                ? 'Nova Categoria'
                                : 'Editar Categoria',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (existing != null &&
                              appState.categoriesByType(existing.type).length >
                                  1)
                            IconButton(
                              onPressed: () async {
                                await appState.deleteCategory(existing.id);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger(context),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CupertinoSlidingSegmentedControl<TransactionType>(
                        groupValue: type,
                        onValueChanged: (v) {
                          if (v != null) setModalState(() => type = v);
                        },
                        children: const {
                          TransactionType.expense: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Despesa'),
                          ),
                          TransactionType.income: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Receita'),
                          ),
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        autofocus: existing == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Categoria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ícone',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppIconsCatalog.icons.entries.map((entry) {
                          final selected = iconKey == entry.key;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                setModalState(() => iconKey = entry.key),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Color(colorVal).withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Color(colorVal)
                                      : AppColors.border(context),
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                size: 20,
                                color: selected
                                    ? Color(colorVal)
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: AppColors.presetPalette.map((color) {
                          final val = color.toARGB32();
                          final selected = colorVal == val;
                          return GestureDetector(
                            onTap: () => setModalState(() => colorVal = val),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(
                                        color: AppColors.textPrimary(context),
                                        width: 2.5,
                                      )
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            await appState.saveCategory(
                              id: existing?.id,
                              name: name,
                              iconKey: iconKey,
                              colorValue: colorVal,
                              type: type,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Salvar Categoria',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryEditChip extends StatelessWidget {
  final CategoryItem cat;
  final VoidCallback onTap;

  const _CategoryEditChip({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: cat.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cat.color.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon, size: 15, color: cat.color),
            const SizedBox(width: 5),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 12.5,
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

class _CardEditorSheet extends StatefulWidget {
  final AppState appState;
  final CreditCardItem? existing;

  const _CardEditorSheet({
    required this.appState,
    this.existing,
  });

  @override
  State<_CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends State<_CardEditorSheet> {
  late final TextEditingController _nameCtrl;
  late int _closingDay;
  late int _dueDay;
  late int _colorVal;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _closingDay = ex?.closingDay ?? 25;
    _dueDay = ex?.dueDay ?? 5;
    _colorVal = ex?.colorValue ?? AppColors.presetPalette.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Digite o nome do cartão.');
      return;
    }
    await widget.appState.saveCard(
      id: widget.existing?.id,
      name: name,
      colorValue: _colorVal,
      closingDay: _closingDay,
      dueDay: _dueDay,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    await widget.appState.deleteCard(ex.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ex = widget.existing;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ex == null ? 'Novo Cartão' : 'Editar Cartão',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (ex != null)
                    IconButton(
                      tooltip: 'Excluir Cartão',
                      onPressed: _delete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger(context),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                autofocus: ex == null,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nome do Cartão (ex: Nubank, Itaú)',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DaySelectorBox(
                      label: 'Dia de Fechamento',
                      day: _closingDay,
                      onChanged: (d) => setState(() => _closingDay = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DaySelectorBox(
                      label: 'Dia de Vencimento',
                      day: _dueDay,
                      onChanged: (d) => setState(() => _dueDay = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Cor do Cartão',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.presetPalette.map((color) {
                  final val = color.toARGB32();
                  final selected = _colorVal == val;
                  return GestureDetector(
                    onTap: () => setState(() => _colorVal = val),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: AppColors.textPrimary(context),
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text(
                    'Salvar Cartão',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

class _DaySelectorBox extends StatelessWidget {
  final String label;
  final int day;
  final ValueChanged<int> onChanged;

  const _DaySelectorBox({
    required this.label,
    required this.day,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(day <= 1 ? 31 : day - 1);
                },
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              ),
              Text(
                'Dia $day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(day >= 31 ? 1 : day + 1);
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

