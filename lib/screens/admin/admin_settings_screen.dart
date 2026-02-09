import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/app_settings.dart';
import '../../services/admin_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // --- نفس التعريفات والمنطق البرمجي بدون أي تغيير ---
  final _adminService = AdminService();
  final _commissionController = TextEditingController();
  final _orderExpirationController = TextEditingController();

  final _taxiMaxKmController = TextEditingController();
  final _taxiNightStartController = TextEditingController();
  final _taxiNightEndController = TextEditingController();
  final _taxiPeakMStartController = TextEditingController();
  final _taxiPeakMEndController = TextEditingController();
  final _taxiPeakEStartController = TextEditingController();
  final _taxiPeakEEndController = TextEditingController();
  final _taxiNightMinController = TextEditingController();
  final _taxiNightMaxController = TextEditingController();
  final _taxiPeakMinController = TextEditingController();
  final _taxiPeakMaxController = TextEditingController();

  final _craneMaxKmController = TextEditingController();
  final _marketMaxKmController = TextEditingController();
  final _marketPerKmController = TextEditingController();
  final _fuelMaxKmController = TextEditingController();
  final _carEmergencyMaxKmController = TextEditingController();
  final _carWashMaxKmController = TextEditingController();
  final _carWashSmallController = TextEditingController();
  final _carWashLargeController = TextEditingController();
  final _maidMaxKmController = TextEditingController();
  final _maidPriceController = TextEditingController();

  bool _taxiEnabled = true;
  bool _craneEnabled = true;
  bool _marketEnabled = true;
  bool _fuelEnabled = true;
  bool _carEmergencyEnabled = true;
  bool _carWashEnabled = true;
  bool _maidEnabled = true;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
    _loadSettings();
  }

  // --- دوال الربط والمنطق (لم يتم تغييرها لضمان الأداء) ---
  Future<void> _checkPermission() async {
    final admin = await _adminService.getCurrentAdmin();
    if (admin != null && !admin.permissions.canAccessSettings && !admin.isSuperAdmin) {
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية الدخول لهذه الصفحة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commissionController.dispose();
    _orderExpirationController.dispose();
    _taxiMaxKmController.dispose();
    _taxiNightStartController.dispose();
    _taxiNightEndController.dispose();
    _taxiPeakMStartController.dispose();
    _taxiPeakMEndController.dispose();
    _taxiPeakEStartController.dispose();
    _taxiPeakEEndController.dispose();
    _taxiNightMinController.dispose();
    _taxiNightMaxController.dispose();
    _taxiPeakMinController.dispose();
    _taxiPeakMaxController.dispose();
    _craneMaxKmController.dispose();
    _marketMaxKmController.dispose();
    _marketPerKmController.dispose();
    _fuelMaxKmController.dispose();
    _carEmergencyMaxKmController.dispose();
    _carWashMaxKmController.dispose();
    _carWashSmallController.dispose();
    _carWashLargeController.dispose();
    _maidMaxKmController.dispose();
    _maidPriceController.dispose();
    super.dispose();
  }

  void _applySettings(AppSettings s) {
    _commissionController.text = s.commissionPercentage.toStringAsFixed(0);
    _orderExpirationController.text = s.orderExpirationMinutes.toString();
    _taxiEnabled = s.taxi.enabled;
    _taxiMaxKmController.text = s.taxi.maxDistanceKm.toStringAsFixed(0);
    _taxiNightStartController.text = s.taxi.nightStart;
    _taxiNightEndController.text = s.taxi.nightEnd;
    _taxiPeakMStartController.text = s.taxi.peakMorningStart;
    _taxiPeakMEndController.text = s.taxi.peakMorningEnd;
    _taxiPeakEStartController.text = s.taxi.peakEveningStart;
    _taxiPeakEEndController.text = s.taxi.peakEveningEnd;
    _taxiNightMinController.text = s.taxi.nightMinFare.toString();
    _taxiNightMaxController.text = s.taxi.nightMaxFare.toString();
    _taxiPeakMinController.text = s.taxi.peakMinFare.toString();
    _taxiPeakMaxController.text = s.taxi.peakMaxFare.toString();
    _craneEnabled = s.crane.enabled;
    _craneMaxKmController.text = s.crane.maxDistanceKm.toStringAsFixed(0);
    _marketEnabled = s.market.enabled;
    _marketMaxKmController.text = s.market.maxDistanceKm.toStringAsFixed(0);
    _marketPerKmController.text = s.market.deliveryFeePerKmOverMax.toString();
    _fuelEnabled = s.fuel.enabled;
    _fuelMaxKmController.text = s.fuel.maxDistanceKm.toStringAsFixed(0);
    _carEmergencyEnabled = s.carEmergency.enabled;
    _carEmergencyMaxKmController.text = s.carEmergency.maxDistanceKm.toStringAsFixed(0);
    _carWashEnabled = s.carWash.enabled;
    _carWashMaxKmController.text = s.carWash.maxDistanceKm.toStringAsFixed(0);
    _carWashSmallController.text = s.carWash.smallPrice.toString();
    _carWashLargeController.text = s.carWash.largePrice.toString();
    _maidEnabled = s.maid.enabled;
    _maidMaxKmController.text = s.maid.maxDistanceKm.toStringAsFixed(0);
    _maidPriceController.text = s.maid.defaultPrice.toString();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _adminService.getSettings();
      final appSettings = AppSettings.fromJson(Map<String, dynamic>.from(settings));
      if (mounted) {
        _applySettings(appSettings);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _applySettings(AppSettings.defaults);
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'commissionPercentage': double.tryParse(_commissionController.text.trim()) ?? 10,
      'orderExpirationMinutes': int.tryParse(_orderExpirationController.text.trim()) ?? 6,
      'taxi': {
        'enabled': _taxiEnabled,
        'maxDistanceKm': double.tryParse(_taxiMaxKmController.text.trim()) ?? 3,
        'nightStart': _taxiNightStartController.text.trim().isEmpty ? '20:30' : _taxiNightStartController.text.trim(),
        'nightEnd': _taxiNightEndController.text.trim().isEmpty ? '06:00' : _taxiNightEndController.text.trim(),
        'peakMorningStart': _taxiPeakMStartController.text.trim().isEmpty ? '07:00' : _taxiPeakMStartController.text.trim(),
        'peakMorningEnd': _taxiPeakMEndController.text.trim().isEmpty ? '09:00' : _taxiPeakMEndController.text.trim(),
        'peakEveningStart': _taxiPeakEStartController.text.trim().isEmpty ? '17:00' : _taxiPeakEStartController.text.trim(),
        'peakEveningEnd': _taxiPeakEEndController.text.trim().isEmpty ? '19:00' : _taxiPeakEEndController.text.trim(),
        'nightMinFare': int.tryParse(_taxiNightMinController.text.trim()) ?? 10000,
        'nightMaxFare': int.tryParse(_taxiNightMaxController.text.trim()) ?? 20000,
        'peakMinFare': int.tryParse(_taxiPeakMinController.text.trim()) ?? 10000,
        'peakMaxFare': int.tryParse(_taxiPeakMaxController.text.trim()) ?? 20000,
      },
      'crane': {
        'enabled': _craneEnabled,
        'maxDistanceKm': double.tryParse(_craneMaxKmController.text.trim()) ?? 15,
      },
      'market': {
        'enabled': _marketEnabled,
        'maxDistanceKm': double.tryParse(_marketMaxKmController.text.trim()) ?? 5,
        'deliveryFeePerKmOverMax': int.tryParse(_marketPerKmController.text.trim()) ?? 500,
      },
      'fuel': {
        'enabled': _fuelEnabled,
        'maxDistanceKm': double.tryParse(_fuelMaxKmController.text.trim()) ?? 15,
      },
      'carEmergency': {
        'enabled': _carEmergencyEnabled,
        'maxDistanceKm': double.tryParse(_carEmergencyMaxKmController.text.trim()) ?? 15,
      },
      'carWash': {
        'enabled': _carWashEnabled,
        'maxDistanceKm': double.tryParse(_carWashMaxKmController.text.trim()) ?? 15,
        'smallPrice': int.tryParse(_carWashSmallController.text.trim()) ?? 10000,
        'largePrice': int.tryParse(_carWashLargeController.text.trim()) ?? 15000,
      },
      'maid': {
        'enabled': _maidEnabled,
        'maxDistanceKm': double.tryParse(_maidMaxKmController.text.trim()) ?? 15,
        'defaultPrice': int.tryParse(_maidPriceController.text.trim()) ?? 55000,
      },
    };
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _adminService.updateSettingsFull(_buildPayload());
      SettingsService().invalidateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- دوال مساعدة للتصميم المطور ---

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool? isEnabled,
    ValueChanged<bool>? onToggle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: title == 'عام',
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          trailing: onToggle != null
              ? Switch.adaptive(
                  value: isEnabled ?? false,
                  onChanged: onToggle,
                  activeColor: AppTheme.primaryColor,
                )
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CustomTextField(
        label: label,
        hint: hint,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        prefixIcon: Icons.numbers_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // لون خلفية هادئ
        appBar: AppBar(
          title: const Text('إعدادات النظام', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // القسم العام
                          _buildSectionCard(
                            title: 'إعدادات عامة',
                            icon: Icons.settings_applications,
                            children: [
                              CustomTextField(
                                label: 'نسبة العمولة (%)',
                                hint: '10',
                                controller: _commissionController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                prefixIcon: Icons.percent_rounded,
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                label: 'وقت المتاح للطلبات (دقائق)',
                                hint: '6',
                                controller: _orderExpirationController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                prefixIcon: Icons.timer_outlined,
                              ),
                            ],
                          ),

                          // قسم التكسي
                          _buildSectionCard(
                            title: 'خدمة التكسي',
                            icon: Icons.local_taxi,
                            isEnabled: _taxiEnabled,
                            onToggle: (v) => setState(() => _taxiEnabled = v),
                            children: [
                              _numberField(_taxiMaxKmController, 'أقصى مسافة بحث (كم)', '3'),
                              const Divider(height: 32),
                              const Text('أوقات العمل والذروة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: CustomTextField(label: 'بداية الليل', controller: _taxiNightStartController, hint: '20:30')),
                                  const SizedBox(width: 8),
                                  Expanded(child: CustomTextField(label: 'نهاية الليل', controller: _taxiNightEndController, hint: '06:00')),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: CustomTextField(label: 'ذروة الصباح (من)', controller: _taxiPeakMStartController, hint: '07:00')),
                                  const SizedBox(width: 8),
                                  Expanded(child: CustomTextField(label: 'ذروة الصباح (إلى)', controller: _taxiPeakMEndController, hint: '09:00')),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: CustomTextField(label: 'ذروة المساء (من)', controller: _taxiPeakEStartController, hint: '17:00')),
                                  const SizedBox(width: 8),
                                  Expanded(child: CustomTextField(label: 'ذروة المساء (إلى)', controller: _taxiPeakEEndController, hint: '19:00')),
                                ],
                              ),
                              const Divider(height: 32),
                              const Text('تعرفة الأسعار (د.ع)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              _numberField(_taxiNightMinController, 'أدنى سعر ليل', '10000'),
                              _numberField(_taxiNightMaxController, 'أقصى سعر ليل', '20000'),
                              _numberField(_taxiPeakMinController, 'أدنى سعر ذروة', '10000'),
                              _numberField(_taxiPeakMaxController, 'أقصى سعر ذروة', '20000'),
                            ],
                          ),

                          // قسم الماركت
                          _buildSectionCard(
                            title: 'الماركت (التسوق)',
                            icon: Icons.shopping_bag_outlined,
                            isEnabled: _marketEnabled,
                            onToggle: (v) => setState(() => _marketEnabled = v),
                            children: [
                              _numberField(_marketMaxKmController, 'أقصى مسافة توصيل (كم)', '5'),
                              _numberField(_marketPerKmController, 'رسوم إضافية لكل كم إضافي', '500'),
                            ],
                          ),

                          // قسم غسيل السيارات
                          _buildSectionCard(
                            title: 'غسيل السيارات',
                            icon: Icons.local_car_wash,
                            isEnabled: _carWashEnabled,
                            onToggle: (v) => setState(() => _carWashEnabled = v),
                            children: [
                              _numberField(_carWashMaxKmController, 'أقصى مسافة (كم)', '15'),
                              _numberField(_carWashSmallController, 'سعر السيارة الصغيرة', '10000'),
                              _numberField(_carWashLargeController, 'سعر السيارة الكبيرة', '15000'),
                            ],
                          ),

                          // أقسام أخرى مختصرة
                          _buildSectionCard(
                            title: 'الكرين والطوارئ',
                            icon: Icons.build_circle_outlined,
                            children: [
                              _numberField(_craneMaxKmController, 'أقصى مسافة للكرين (كم)', '15'),
                              _numberField(_carEmergencyMaxKmController, 'أقصى مسافة للطوارئ (كم)', '15'),
                            ],
                          ),

                          _buildSectionCard(
                            title: 'خدمة البنزين والعاملة',
                            icon: Icons.cleaning_services,
                            children: [
                              _numberField(_fuelMaxKmController, 'أقصى مسافة بنزين (كم)', '15'),
                              const Divider(),
                              _numberField(_maidMaxKmController, 'أقصى مسافة للعاملة (كم)', '15'),
                              _numberField(_maidPriceController, 'السعر الافتراضي للعاملة', '55000'),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // زر الحفظ ثابت في الأسفل
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: CustomButton(
                      text: 'حفظ التغييرات',
                      onPressed: _isSaving ? null : _save,
                      isLoading: _isSaving,
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}