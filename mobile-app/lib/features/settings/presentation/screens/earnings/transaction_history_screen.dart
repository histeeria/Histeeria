import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/gradient_background.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _selectedFilter = 'All';
  
  final List<Map<String, dynamic>> _transactions = [
    {
      'type': 'Payout',
      'description': 'Monthly payout - November 2024',
      'amount': '+\$1,089.32',
      'date': 'Nov 15, 2024',
      'status': 'Completed',
      'icon': Icons.account_balance_wallet,
      'isPositive': true,
      'txHash': '0x7f9a...3b2c',
      'blockchain': 'Ethereum',
    },
    {
      'type': 'Job',
      'description': 'Web Development - TechCorp',
      'amount': '+\$485.00',
      'date': 'Nov 28, 2024',
      'status': 'Completed',
      'icon': Icons.work,
      'isPositive': true,
      'txHash': '0x4a8b...9d1e',
      'blockchain': 'Polygon',
    },
    {
      'type': 'Project',
      'description': 'Mobile App Collaboration',
      'amount': '+\$356.80',
      'date': 'Nov 25, 2024',
      'status': 'Pending',
      'icon': Icons.folder,
      'isPositive': true,
      'txHash': null,
      'blockchain': null,
    },
    {
      'type': 'Product',
      'description': 'Digital Course Sale',
      'amount': '+\$89.99',
      'date': 'Nov 22, 2024',
      'status': 'Completed',
      'icon': Icons.shopping_bag,
      'isPositive': true,
      'txHash': '0x2c5d...7f3a',
      'blockchain': 'BSC',
    },
    {
      'type': 'Earning',
      'description': 'Content monetization - Post views',
      'amount': '+\$112.40',
      'date': 'Nov 20, 2024',
      'status': 'Completed',
      'icon': Icons.monetization_on,
      'isPositive': true,
      'txHash': '0x9e1f...4c8b',
      'blockchain': 'Ethereum',
    },
    {
      'type': 'Crypto',
      'description': 'Bitcoin payment received',
      'amount': '+\$245.00',
      'date': 'Nov 18, 2024',
      'status': 'Completed',
      'icon': Icons.currency_bitcoin,
      'isPositive': true,
      'txHash': '0x5b3a...2d9f',
      'blockchain': 'Bitcoin',
    },
    {
      'type': 'NFT',
      'description': 'NFT Sale - Digital Art #142',
      'amount': '+\$500.00',
      'date': 'Nov 15, 2024',
      'status': 'Completed',
      'icon': Icons.image,
      'isPositive': true,
      'txHash': '0x8f2c...6a1b',
      'blockchain': 'Ethereum',
    },
    {
      'type': 'Fee',
      'description': 'Platform fee (10%)',
      'amount': '-\$65.40',
      'date': 'Nov 15, 2024',
      'status': 'Completed',
      'icon': Icons.remove_circle_outline,
      'isPositive': false,
      'txHash': '0x3d7e...5c4f',
      'blockchain': 'Ethereum',
    },
    {
      'type': 'Earning',
      'description': 'Tips from supporters',
      'amount': '+\$45.00',
      'date': 'Nov 10, 2024',
      'status': 'Completed',
      'icon': Icons.favorite,
      'isPositive': true,
      'txHash': '0x1a9c...8e2d',
      'blockchain': 'Polygon',
    },
    {
      'type': 'Job',
      'description': 'UI/UX Design - StartupXYZ',
      'amount': '+\$320.00',
      'date': 'Nov 5, 2024',
      'status': 'Completed',
      'icon': Icons.work,
      'isPositive': true,
      'txHash': '0x6d4b...3f7a',
      'blockchain': 'Ethereum',
    },
  ];

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') return _transactions;
    return _transactions.where((t) => t['type'] == _selectedFilter).toList();
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
                      'Transaction History',
                      style: AppTextStyles.headlineMedium(
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Tabs
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Job', 'Project', 'Product', 'Earning', 'Crypto', 'NFT', 'Payout', 'Fee'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.backgroundSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: AppTextStyles.bodySmall(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Transactions List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _filteredTransactions[index];
                    final isPositive = transaction['isPositive'] as bool;
                    final status = transaction['status'] as String;
                    final txHash = transaction['txHash'] as String?;
                    final blockchain = transaction['blockchain'] as String?;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showTransactionDetails(transaction),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isPositive
                                            ? AppColors.success.withOpacity(0.15)
                                            : AppColors.accentQuaternary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        transaction['icon'],
                                        color: isPositive
                                            ? AppColors.success
                                            : AppColors.accentQuaternary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transaction['description'],
                                            style: AppTextStyles.bodyMedium(
                                              weight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                transaction['date'],
                                                style: AppTextStyles.bodySmall(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'Completed'
                                                      ? AppColors.success.withOpacity(0.2)
                                                      : AppColors.textTertiary.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: AppTextStyles.bodySmall(
                                                    color: status == 'Completed'
                                                        ? AppColors.success
                                                        : AppColors.textTertiary,
                                                    weight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      transaction['amount'],
                                      style: AppTextStyles.bodyLarge(
                                        weight: FontWeight.w600,
                                        color: isPositive
                                            ? AppColors.success
                                            : AppColors.accentQuaternary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (txHash != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.link,
                                          size: 14,
                                          color: const Color(0xFF6366F1),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          blockchain ?? 'Blockchain',
                                          style: AppTextStyles.bodySmall(
                                            color: const Color(0xFF6366F1),
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            txHash,
                                            style: AppTextStyles.bodySmall(
                                              color: AppColors.textTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.open_in_new,
                                          size: 14,
                                          color: const Color(0xFF6366F1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Details',
                      style: AppTextStyles.headlineSmall(
                        weight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DetailRow(label: 'Type', value: transaction['type']),
                    _DetailRow(label: 'Description', value: transaction['description']),
                    _DetailRow(label: 'Amount', value: transaction['amount']),
                    _DetailRow(label: 'Date', value: transaction['date']),
                    _DetailRow(label: 'Status', value: transaction['status']),
                    if (transaction['txHash'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.currency_bitcoin,
                                  color: const Color(0xFF6366F1),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Blockchain Verification',
                                  style: AppTextStyles.bodyMedium(
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _DetailRow(
                              label: 'Network',
                              value: transaction['blockchain'] ?? 'N/A',
                            ),
                            _DetailRow(
                              label: 'Transaction Hash',
                              value: transaction['txHash'] ?? 'N/A',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  // TODO: Open blockchain explorer
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: BorderSide(
                                    color: const Color(0xFF6366F1),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'View on Blockchain Explorer',
                                      style: AppTextStyles.bodySmall(
                                        color: const Color(0xFF6366F1),
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.open_in_new,
                                      size: 14,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall(
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

