import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/empty_state.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('عناويني'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const EmptyState(
          icon: Icons.location_on_outlined,
          title: 'لا توجد عناوين',
          message: 'لم تقم بإضافة أي عناوين بعد',
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // يمكن إضافة شاشة إضافة عنوان
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}









