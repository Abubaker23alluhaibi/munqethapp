import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_card.dart';
import '../services/card_service.dart';
import '../core/storage/secure_storage_service.dart';

enum PaymentMethod {
  wallet, // المحفظة
  card, // بطاقة
  cash, // نقدي
}

class PaymentMethodSelector extends StatefulWidget {
  final double totalAmount;
  final Function(PaymentMethod, String?) onPaymentMethodSelected;
  final PaymentMethod? initialMethod;

  const PaymentMethodSelector({
    super.key,
    required this.totalAmount,
    required this.onPaymentMethodSelected,
    this.initialMethod,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  final _cardService = CardService();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  String? _selectedCardId;
  List<UserCard> _userCards = [];
  int _walletBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMethod != null) {
      _selectedMethod = widget.initialMethod!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userPhone = await SecureStorageService.getString('user_phone');
      if (userPhone != null) {
        _userCards = await _cardService.getUserCards(userPhone);
        _walletBalance = await _cardService.getUserWalletBalance(userPhone);
      }
    } catch (e) {
      print('Error loading payment data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('طريقة الدفع'),
        const SizedBox(height: 16),
        // Wallet Option
        _buildPaymentOption(
          icon: Icons.account_balance_wallet,
          title: 'المحفظة',
          subtitle: 'الرصيد المتاح: ${_walletBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع',
          value: PaymentMethod.wallet,
          enabled: _walletBalance >= widget.totalAmount,
        ),
        const SizedBox(height: 12),
        // Cards Option
        if (_userCards.isNotEmpty) ...[
          _buildPaymentOption(
            icon: Icons.credit_card,
            title: 'بطاقة مالية',
            subtitle: '${_userCards.length} بطاقة متاحة',
            value: PaymentMethod.card,
            enabled: _hasCardWithEnoughBalance(),
          ),
          if (_selectedMethod == PaymentMethod.card) ...[
            const SizedBox(height: 12),
            _buildCardSelector(),
          ],
        ],
        const SizedBox(height: 12),
        // Cash Option
        _buildPaymentOption(
          icon: Icons.money,
          title: 'نقدي',
          subtitle: 'الدفع عند الاستلام',
          value: PaymentMethod.cash,
          enabled: true,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required PaymentMethod value,
    required bool enabled,
  }) {
    final isSelected = _selectedMethod == value;
    
    return InkWell(
      onTap: enabled ? () {
        setState(() {
          _selectedMethod = value;
          if (value != PaymentMethod.card) {
            _selectedCardId = null;
          } else if (_userCards.isNotEmpty && _selectedCardId == null) {
            // اختيار أول بطاقة متاحة تلقائياً
            _selectedCardId = _userCards.firstWhere(
              (card) => card.amount >= widget.totalAmount,
              orElse: () => _userCards.first,
            ).id;
          }
          widget.onPaymentMethodSelected(_selectedMethod, _selectedCardId);
        });
      } : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled
              ? (isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (enabled ? Colors.grey[300]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enabled
                    ? (isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.1))
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: enabled
                    ? (isSelected ? Colors.white : AppTheme.primaryColor)
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.black : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: enabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
            if (!enabled)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'غير متاح',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSelector() {
    final availableCards = _userCards.where((card) => card.amount >= widget.totalAmount).toList();
    
    if (availableCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'لا توجد بطاقة برصيد كافي',
                style: TextStyle(color: Colors.orange[900]),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر البطاقة:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...availableCards.map((card) => RadioListTile<String>(
            title: Text(
              '${card.code.substring(0, 4)}****${card.code.substring(card.code.length - 4)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الرصيد: ${card.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع',
            ),
            value: card.id,
            groupValue: _selectedCardId,
            onChanged: (value) {
              setState(() {
                _selectedCardId = value;
                widget.onPaymentMethodSelected(_selectedMethod, _selectedCardId);
              });
            },
            contentPadding: EdgeInsets.zero,
          )),
        ],
      ),
    );
  }

  bool _hasCardWithEnoughBalance() {
    return _userCards.any((card) => card.amount >= widget.totalAmount);
  }
}






