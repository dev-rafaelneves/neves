import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class AiInsightCard extends StatefulWidget {
  final AppState appState;

  const AiInsightCard({super.key, required this.appState});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _insightText;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedInsight();
  }

  @override
  void didUpdateWidget(covariant AiInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadCachedInsight();
  }

  Future<void> _loadCachedInsight() async {
    final ym = widget.appState.selectedYearMonth;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cached = await DatabaseService.getAiInsight(ym);
    if (mounted) {
      setState(() {
        _insightText = cached;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateInsight({bool forceRefresh = false}) async {
    final hasKey = await GeminiService.hasApiKey();
    if (!hasKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure sua chave gratuita do Google Gemini na aba Ajustes para ativar o Consultor IA.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final state = widget.appState;
      final ym = state.selectedYearMonth;
      final pillars = state.pillar503020Breakdown(ym);
      final breakdown = <String, double>{};
      for (final e in state.categoryExpenseBreakdown(ym).entries) {
        breakdown[e.key.name] = e.value;
      }

      final text = await GeminiService.generateMonthlyFinancialInsight(
        yearMonth: ym,
        totalIncome: state.totalIncomeForMonth(ym),
        totalExpense: state.totalExpenseForMonth(ym),
        projectedEndBalance: state.projectedEndOfMonthBalance(ym),
        netWorth: state.netWorth,
        essentialSpent: pillars[Pillar503020.essential] ?? 0,
        lifestyleSpent: pillars[Pillar503020.lifestyle] ?? 0,
        futureSaved: pillars[Pillar503020.future] ?? 0,
        categoryBreakdown: breakdown,
        futureInstallmentsTotal: state.totalCreditCardUnpaidDebt,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _insightText = text;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Bad state: ', '');
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigoPrimary, AppColors.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultor Financeiro IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Diagnóstico Gemini • Regra 50/30/20 & Faturas',
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
                if (_insightText != null && !_isGenerating) ...[
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _insightText!),
                      );
                      HapticFeedback.selectionClick();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Diagnóstico copiado!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    tooltip: 'Copiar Diagnóstico',
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.indigoPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _generateInsight(forceRefresh: true),
                    tooltip: 'Recalcular Diagnóstico',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppColors.indigoPrimary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading || _isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isGenerating
                          ? 'Analisando seu fluxo de caixa com o Gemini...'
                          : 'Carregando análise...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.rose,
                  ),
                ),
              )
            else if (_insightText != null && _insightText!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground.withValues(alpha: 0.6)
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _MarkdownFormattedView(
                  text: _insightText!,
                  isDark: isDark,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gere um parecer personalizado do mês com análise da regra 50/30/20, alerta de parcelas futuras no cartão e 3 recomendações práticas de economia.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _generateInsight(forceRefresh: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigoPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text(
                        'Gerar Diagnóstico do Mês',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Renderizador leve de Markdown para textos gerados pelo Gemini
class _MarkdownFormattedView extends StatelessWidget {
  final String text;
  final bool isDark;

  const _MarkdownFormattedView({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (line == '---' || line == '***' || line == '___') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('#### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 3),
            child: Text(
              _stripInlineMarkers(line.substring(5)),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              _stripInlineMarkers(line.substring(4)),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.indigoLight : AppColors.indigoPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              _stripInlineMarkers(line.substring(3)),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              _stripInlineMarkers(line.substring(2)),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('• ')) {
        final itemText = line.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.indigoLight
                        : AppColors.indigoPrimary,
                  ),
                ),
                Expanded(child: _buildRichLine(itemText)),
              ],
            ),
          ),
        );
      } else if (RegExp(r'^\d+\.\s+').hasMatch(line)) {
        final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(line)!;
        final prefix = match.group(1)!;
        final itemText = match.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefix ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.indigoLight
                        : AppColors.indigoPrimary,
                  ),
                ),
                Expanded(child: _buildRichLine(itemText)),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _buildRichLine(line),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _stripInlineMarkers(String input) {
    return input.replaceAll('**', '').replaceAll('__', '').trim();
  }

  Widget _buildRichLine(String line) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: isDark
              ? AppColors.darkTextSecondary
              : const Color(0xFF334155),
        ),
        children: spans,
      ),
    );
  }
}
