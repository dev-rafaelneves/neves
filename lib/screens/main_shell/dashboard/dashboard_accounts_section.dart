import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/app_state.dart';
import '../../../theme/app_theme.dart';

class DashboardAccountsSection extends StatelessWidget {
  final AppState appState;
  final bool isWide;
  final VoidCallback onCreateAccount;
  final ValueChanged<Account> onEditAccount;

  const DashboardAccountsSection({
    super.key,
    required this.appState,
    required this.isWide,
    required this.onCreateAccount,
    required this.onEditAccount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discreet = appState.discreetMode;

    final liquidAccs = appState.accounts
        .where((a) => a.type != AccountType.investment)
        .toList();
    final investAccs = appState.accounts
        .where((a) => a.type == AccountType.investment)
        .toList();

    final liquidColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'CONTAS CORRENTES & CARTEIRA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova Conta'),
            ),
          ],
        ),
        ...liquidAccs.map(
          (acc) => _AccountTile(
            account: acc,
            isDark: isDark,
            discreet: discreet,
            onTap: () => onEditAccount(acc),
          ),
        ),
      ],
    );

    final investColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'INVESTIMENTOS & PATRIMÔNIO LÍQUIDO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.success(context),
            ),
          ),
        ),
        ...investAccs.map(
          (acc) => _InvestmentTile(
            account: acc,
            isDark: isDark,
            discreet: discreet,
            onTap: () => onEditAccount(acc),
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: liquidColumn),
          const SizedBox(width: 16),
          Expanded(child: investColumn),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        liquidColumn,
        const SizedBox(height: 14),
        investColumn,
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  final bool isDark;
  final bool discreet;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.isDark,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: account.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(account.icon, color: account.color, size: 22),
          ),
          title: Text(
            account.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            account.type.label,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            AppFormatters.currency(account.currentBalance, discreet: discreet),
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: account.currentBalance >= 0
                  ? (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary)
                  : AppColors.danger(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvestmentTile extends StatelessWidget {
  final Account account;
  final bool isDark;
  final bool discreet;
  final VoidCallback onTap;

  const _InvestmentTile({
    required this.account,
    required this.isDark,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: AppColors.success(context),
              size: 22,
            ),
          ),
          title: Text(
            account.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: const Text(
            'Toque para atualizar saldo da carteira',
            style: TextStyle(fontSize: 12),
          ),
          trailing: Text(
            AppFormatters.currency(account.currentBalance, discreet: discreet),
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.success(context),
            ),
          ),
        ),
      ),
    );
  }
}
