import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  final List<Map<String, dynamic>> _payoutMethods = [
    {
      'type': 'Bank Account',
      'name': 'Chase Bank ****1234',
      'isPrimary': true,
      'icon': Icons.account_balance,
      'isBlockchain': false,
    },
    {
      'type': 'Ethereum Wallet',
      'name': '0x742d...35Bd',
      'isPrimary': false,
      'icon': Icons.currency_bitcoin,
      'isBlockchain': true,
      'network': 'Ethereum',
    },
    {
      'type': 'PayPal',
      'name': 'john.doe@example.com',
      'isPrimary': false,
      'icon': Icons.payment,
      'isBlockchain': false,
    },
  ];

  Future<void> _setPrimary(int index) async {
    setState(() {
      for (var i = 0; i < _payoutMethods.length; i++) {
        _payoutMethods[i]['isPrimary'] = i == index;
      }
    });

    _showMessage('Primary payout method updated');
  }

  Future<void> _removeMethod(int index) async {
    final method = _payoutMethods[index];
    
    if (method['isPrimary']) {
      _showMessage('Cannot remove primary payout method');
      return;
    }

    final confirm = await _showRemoveDialog(method['name']);
    if (confirm != true) return;

    setState(() {
      _payoutMethods.removeAt(index);
    });

    _showMessage('Payout method removed');
  }

  void _showAddMethodDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add Payout Method',
                  style: AppTextStyles.headlineSmall(
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.account_balance, color: AppColors.textPrimary),
                title: Text('Bank Account', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('Bank account setup - Coming soon');
                },
              ),
              ListTile(
                leading: Icon(Icons.payment, color: AppColors.textPrimary),
                title: Text('PayPal', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('PayPal setup - Coming soon');
                },
              ),
              ListTile(
                leading: Icon(Icons.credit_card, color: AppColors.textPrimary),
                title: Text('Debit Card', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('Debit card setup - Coming soon');
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Cryptocurrency Wallets',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.textTertiary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.currency_bitcoin, color: const Color(0xFF6366F1)),
                title: Text('Ethereum Wallet', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('Ethereum wallet setup - Coming soon');
                },
              ),
              ListTile(
                leading: Icon(Icons.currency_bitcoin, color: const Color(0xFFF7931A)),
                title: Text('Bitcoin Wallet', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('Bitcoin wallet setup - Coming soon');
                },
              ),
              ListTile(
                leading: Icon(Icons.currency_bitcoin, color: const Color(0xFF8247E5)),
                title: Text('Polygon Wallet', style: AppTextStyles.bodyMedium()),
                trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () {
                  Navigator.pop(context);
                  _showMessage('Polygon wallet setup - Coming soon');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showRemoveDialog(String methodName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Remove Payout Method?',
          style: AppTextStyles.headlineSmall(weight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove $methodName?',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: AppTextStyles.bodyMedium(
                color: AppColors.accentQuaternary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: AppColors.gradientWarm,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Payout Methods',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.accentPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add and manage your payout methods. Payments are processed on the 15th of each month.',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.accentPrimary,
                              ).copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Payout Methods List
                    ..._payoutMethods.asMap().entries.map((entry) {
                      final index = entry.key;
                      final method = entry.value;
                      final isPrimary = method['isPrimary'] as bool;
                      final isBlockchain = method['isBlockchain'] as bool? ?? false;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? AppColors.accentPrimary.withOpacity(0.1)
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPrimary
                                ? AppColors.accentPrimary.withOpacity(0.5)
                                : isBlockchain
                                    ? const Color(0xFF6366F1).withOpacity(0.3)
                                    : AppColors.glassBorder.withOpacity(0.2),
                            width: isPrimary ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isBlockchain
                                        ? const Color(0xFF6366F1).withOpacity(0.15)
                                        : AppColors.accentPrimary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    method['icon'],
                                    color: isBlockchain
                                        ? const Color(0xFF6366F1)
                                        : AppColors.accentPrimary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              method['type'],
                                              style: AppTextStyles.bodyMedium(
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isPrimary) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Primary',
                                                style: AppTextStyles.bodySmall(
                                                  color: AppColors.success,
                                                  weight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (isBlockchain) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Blockchain',
                                                style: AppTextStyles.bodySmall(
                                                  color: const Color(0xFF6366F1),
                                                  weight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        method['name'],
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (isBlockchain && method['network'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Network: ${method['network']}',
                                          style: AppTextStyles.bodySmall(
                                            color: const Color(0xFF6366F1),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!isPrimary) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _setPrimary(index),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(
                                          color: AppColors.accentPrimary,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Set as Primary',
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.accentPrimary,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _removeMethod(index),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: BorderSide(
                                          color: AppColors.accentQuaternary,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Remove',
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.accentQuaternary,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 16),
                    
                    // Add New Method Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showAddMethodDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: AppColors.accentPrimary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              color: AppColors.accentPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Payout Method',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.accentPrimary,
                                weight: FontWeight.w600,
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

