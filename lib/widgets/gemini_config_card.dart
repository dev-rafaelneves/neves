import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class GeminiConfigCard extends StatefulWidget {
  final AppState appState;

  const GeminiConfigCard({super.key, required this.appState});

  @override
  State<GeminiConfigCard> createState() => _GeminiConfigCardState();
}

class _GeminiConfigCardState extends State<GeminiConfigCard> {
  bool _isLoading = false;
  bool _isTesting = false;
  String? _currentKey;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    setState(() => _isLoading = true);
    final key = await GeminiService.getApiKey();
    if (mounted) {
      setState(() {
        _currentKey = key;
        _isLoading = false;
      });
    }
  }

  Future<void> _testCurrentKey() async {
    if (_currentKey == null || _currentKey!.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _isTesting = true);

    final res = await GeminiService.testConnection(_currentKey);

    if (mounted) {
      setState(() => _isTesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppColors.emerald : AppColors.rose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showConfigureDialog({bool isEditing = false}) async {
    HapticFeedback.selectionClick();
    final controller =
        TextEditingController(text: isEditing ? _currentKey : '');
    bool obscure = true;
    bool testingInDialog = false;
    String? dialogStatus;
    bool? isSuccess;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEditing
                        ? 'Alterar Chave Gemini'
                        : 'Configurar Chave Google Gemini (BYOK)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Armazenada exclusivamente no FlutterSecureStorage do seu aparelho.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Cole sua chave (ex: AIzaSy...)',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkBackground
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                            ),
                            onPressed: () =>
                                setModalState(() => obscure = !obscure),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 19,
                              color: AppColors.indigoPrimary,
                            ),
                            onPressed: () async {
                              final data =
                                  await Clipboard.getData('text/plain');
                              if (data?.text != null &&
                                  data!.text!.isNotEmpty) {
                                controller.text = data.text!.trim();
                                setModalState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (dialogStatus != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogStatus!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: (isSuccess ?? false)
                            ? AppColors.emerald
                            : AppColors.rose,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: testingInDialog
                              ? null
                              : () async {
                                  final key = controller.text.trim();
                                  if (key.isEmpty) return;
                                  setModalState(() {
                                    testingInDialog = true;
                                    dialogStatus = 'Testando conexão...';
                                  });
                                  final res =
                                      await GeminiService.testConnection(key);
                                  setModalState(() {
                                    testingInDialog = false;
                                    dialogStatus = res.message;
                                    isSuccess = res.success;
                                  });
                                },
                          child: const Text('Testar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final key = controller.text.trim();
                            if (key.isEmpty) return;
                            await widget.appState.saveGeminiApiKey(key);
                            await _loadKey();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.indigoPrimary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Salvar Chave'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasKey = _currentKey != null && _currentKey!.isNotEmpty;

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                        'Inteligência Artificial (Gemini)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        hasKey
                            ? GeminiService.maskApiKey(_currentKey)
                            : 'Chave própria (BYOK) • Desativada',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasKey) ...[
                  IconButton(
                    onPressed: _isTesting ? null : _testCurrentKey,
                    tooltip: 'Testar Conexão',
                    icon: const Icon(Icons.network_check_rounded, size: 20),
                  ),
                  IconButton(
                    onPressed: () async {
                      await widget.appState.removeGeminiApiKey();
                      await _loadKey();
                    },
                    tooltip: 'Remover Chave',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.danger(context),
                    ),
                  ),
                ],
              ],
            ),
            if (!_isLoading) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showConfigureDialog(isEditing: hasKey),
                  icon: const Icon(Icons.key_rounded, size: 17),
                  label: Text(
                    hasKey ? 'Alterar Chave da API' : 'Configurar Chave da API',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
