import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/card.dart' as card_model;
import '../../services/card_service.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final _cardService = CardService();
  List<card_model.Card> _cards = [];
  Map<String, int> _statistics = {};
  bool _isLoading = true;
  String _filter = 'all'; // all, used, unused

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cards = await _cardService.getAllCards();
      final statistics = await _cardService.getCardStatistics();

      if (mounted) {
        setState(() {
          _cards = cards;
          _statistics = statistics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showCreateCardDialog() async {
    int? selectedAmount;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء بطاقة مالية جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر المبلغ:'),
              const SizedBox(height: 16),
              _buildAmountOption(5000, selectedAmount, (amount) {
                setDialogState(() {
                  selectedAmount = amount;
                });
              }),
              const SizedBox(height: 8),
              _buildAmountOption(10000, selectedAmount, (amount) {
                setDialogState(() {
                  selectedAmount = amount;
                });
              }),
              const SizedBox(height: 8),
              _buildAmountOption(25000, selectedAmount, (amount) {
                setDialogState(() {
                  selectedAmount = amount;
                });
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: selectedAmount == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _createCard(selectedAmount!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountOption(int amount, int? selected, Function(int) onTap) {
    final isSelected = selected == amount;
    return InkWell(
      onTap: () => onTap(amount),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} دينار',
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCard(int amount) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final card = await _cardService.createCard(amount);

      if (mounted) {
        Navigator.pop(context); // إغلاق loading

        if (card != null) {
          // حفظ card في متغير محلي لاستخدامه في closure
          final createdCard = card;
          // عرض الكود في dialog
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تم إنشاء البطاقة بنجاح'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الكود:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor),
                    ),
                    child: SelectableText(
                      createdCard.code,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المبلغ: ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} دينار',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: createdCard.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ الكود'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
                child: const Text('نسخ الكود'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );

          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // إغلاق loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(card_model.Card card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البطاقة'),
        content: Text('هل أنت متأكد من حذف البطاقة بالكود "${card.code}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _cardService.deleteCard(card.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف البطاقة بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل حذف البطاقة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  List<card_model.Card> get _filteredCards {
    switch (_filter) {
      case 'used':
        return _cards.where((card_model.Card card) => card.isUsed).toList();
      case 'unused':
        return _cards.where((card_model.Card card) => !card.isUsed).toList();
      default:
        return _cards;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('البطاقات المالية'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showCreateCardDialog,
              tooltip: 'إنشاء بطاقة جديدة',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Statistics
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'الإجمالي',
                            _statistics['total']?.toString() ?? '0',
                            Icons.credit_card,
                            AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'مستخدمة',
                            _statistics['used']?.toString() ?? '0',
                            Icons.check_circle,
                            AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'غير مستخدمة',
                            _statistics['unused']?.toString() ?? '0',
                            Icons.cancel,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filters
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('مستخدمة', 'used'),
                        const SizedBox(width: 8),
                        _buildFilterChip('غير مستخدمة', 'unused'),
                      ],
                    ),
                  ),
                  // List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: _filteredCards.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.credit_card_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد بطاقات',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredCards.length,
                              itemBuilder: (context, index) {
                                final card = _filteredCards[index];
                                return _buildCardItem(card);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCardItem(card_model.Card card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: card.isUsed
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    card.isUsed ? Icons.check_circle : Icons.credit_card,
                    color: card.isUsed ? AppTheme.successColor : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} دينار',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!card.isUsed)
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () => _handleDelete(card),
                    tooltip: 'حذف',
                  ),
              ],
            ),
            if (card.isUsed) ...[
              const Divider(),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'استخدمها: ${card.usedBy ?? "غير معروف"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(card.usedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'تاريخ الإنشاء: ${_formatDate(card.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

