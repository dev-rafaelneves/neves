import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'neves_app_icon.dart';

class AppLockGate extends StatefulWidget {
  final AppState appState;
  final Widget child;

  const AppLockGate({
    super.key,
    required this.appState,
    required this.child,
  });

  static Future<void> showConfigurePinDialog(
    BuildContext context,
    AppState appState,
  ) async {
    final pinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                appState.hasPinLock
                    ? 'Alterar ou Desativar PIN'
                    : 'Configurar PIN de 4 Dígitos',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proteja seu patrimônio, cartões e extratos com uma senha criptografada de 4 números (SHA-256) ao abrir o aplicativo.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Novo PIN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      onChanged: (_) {
                        if (errorMsg != null) {
                          setDialogState(() => errorMsg = null);
                        }
                      },
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBackground
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Confirme o PIN',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmPinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      onChanged: (_) {
                        if (errorMsg != null) {
                          setDialogState(() => errorMsg = null);
                        }
                      },
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 10,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBackground
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.danger(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (appState.hasPinLock)
                  TextButton(
                    onPressed: () async {
                      await appState.setAppPin(null);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bloqueio por PIN desativado.'),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Desativar PIN',
                      style: TextStyle(color: AppColors.danger(context)),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = pinCtrl.text.trim();
                    final confirmText = confirmPinCtrl.text.trim();
                    if (text.length != 4) {
                      HapticFeedback.heavyImpact();
                      setDialogState(
                        () => errorMsg = 'Digite exatamente 4 números.',
                      );
                      return;
                    }
                    if (text != confirmText) {
                      HapticFeedback.heavyImpact();
                      setDialogState(
                        () => errorMsg =
                            'Os dois PINs não coincidem. Confira e tente novamente.',
                      );
                      return;
                    }
                    await appState.setAppPin(text);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PIN de segurança ativado com sucesso!'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Salvar PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinCtrl.dispose();
    confirmPinCtrl.dispose();
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _inBackground = false;
  String _typedPin = '';
  bool _hasError = false;
  bool _isVerifying = false;
  Timer? _lockoutTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockoutTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.appState.isLocked && !widget.appState.isLockedOut) {
        _tryBiometrics();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkLockoutTimer();
  }

  void _checkLockoutTimer() {
    if (widget.appState.isLockedOut) {
      _remainingSeconds = widget.appState.remainingLockoutSeconds;
      _lockoutTimer?.cancel();
      _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final rem = widget.appState.remainingLockoutSeconds;
        setState(() => _remainingSeconds = rem);
        if (rem <= 0) {
          timer.cancel();
          setState(() => _hasError = false);
        }
      });
    } else {
      _lockoutTimer?.cancel();
      _remainingSeconds = 0;
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.appState.hasPinLock && !widget.appState.discreetMode) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      setState(() => _inBackground = true);
      if (state == AppLifecycleState.paused && widget.appState.hasPinLock) {
        widget.appState.lockSession();
      }
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _inBackground = false);
      if (widget.appState.isLocked && !widget.appState.isLockedOut) {
        _tryBiometrics();
      }
    }
  }

  Future<void> _tryBiometrics() async {
    if (!widget.appState.useBiometrics || widget.appState.isLockedOut) return;
    final ok = await widget.appState.unlockWithBiometrics();
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _typedPin = '';
        _hasError = false;
      });
    }
  }

  Future<void> _onDigitTap(String digit) async {
    if (_isVerifying || widget.appState.isLockedOut || _typedPin.length >= 4) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _typedPin += digit;
    });

    if (_typedPin.length == 4) {
      setState(() => _isVerifying = true);
      final ok = await widget.appState.unlockSession(_typedPin);
      if (!mounted) return;

      setState(() => _isVerifying = false);
      if (!ok) {
        HapticFeedback.heavyImpact();
        setState(() {
          _hasError = true;
          _typedPin = '';
        });
        _checkLockoutTimer();
      } else {
        HapticFeedback.mediumImpact();
        setState(() => _typedPin = '');
      }
    }
  }

  void _onBackspace() {
    if (_isVerifying || widget.appState.isLockedOut || _typedPin.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _hasError = false;
      _typedPin = _typedPin.substring(0, _typedPin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLockedOut = widget.appState.isLockedOut;

    if (widget.appState.isLocked) {
      String subtitleText;
      if (isLockedOut) {
        subtitleText =
            'Muitas tentativas incorretas.\nAguarde ${_remainingSeconds}s para tentar novamente.';
      } else if (_hasError) {
        subtitleText = 'PIN incorreto. Tente novamente.';
      } else {
        subtitleText = 'Digite seu PIN de 4 dígitos para acessar suas finanças';
      }

      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.backspace ||
                key == LogicalKeyboardKey.delete) {
              _onBackspace();
              return KeyEventResult.handled;
            }
            final ch = event.character;
            if (ch != null && ch.length == 1 && RegExp(r'^[0-9]$').hasMatch(ch)) {
              _onDigitTap(ch);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const NevesAppIcon(size: 72),
                    const SizedBox(height: 18),
                    Text(
                      'Neves Protegido',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: (_hasError || isLockedOut)
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: (_hasError || isLockedOut)
                            ? AppColors.rose
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (idx) {
                        final filled = idx < _typedPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: (_hasError || isLockedOut)
                                  ? AppColors.rose
                                  : (filled
                                      ? AppColors.primary
                                      : const Color(0xFF94A3B8)),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: isLockedOut ? 0.35 : 1.0,
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final d in [
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6',
                            '7',
                            '8',
                            '9'
                          ])
                            _PinKeyButton(
                              label: d,
                              enabled: !isLockedOut,
                              onTap: () => _onDigitTap(d),
                            ),
                          if (widget.appState.useBiometrics)
                            Semantics(
                              button: true,
                              label: 'Desbloquear com biometria',
                              child: Material(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : Colors.white,
                                shape: CircleBorder(
                                  side: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: isLockedOut ? null : _tryBiometrics,
                                  customBorder: const CircleBorder(),
                                  child: const SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: Center(
                                      child: Icon(
                                        Icons.fingerprint_rounded,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 68, height: 68),
                          _PinKeyButton(
                            label: '0',
                            enabled: !isLockedOut,
                            onTap: () => _onDigitTap('0'),
                          ),
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: Semantics(
                              button: true,
                              label: 'Apagar dígito',
                              child: IconButton(
                                tooltip: 'Apagar dígito',
                                onPressed: isLockedOut ? null : _onBackspace,
                                icon: const Icon(Icons.backspace_outlined),
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
          ),
        ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_inBackground)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: (isDark ? AppColors.darkBackground : Colors.white)
                  .withValues(alpha: 0.7),
              alignment: Alignment.center,
              child: const NevesAppIcon(size: 80),
            ),
          ),
      ],
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PinKeyButton({
    required this.label,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: CircleBorder(
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 68,
          height: 68,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
