import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/advertisement.dart';
import '../../models/supermarket.dart';
import '../../services/advertisement_service.dart';
import '../../services/supermarket_service.dart';
import '../../services/image_service.dart';

class AddEditAdvertisementScreen extends StatefulWidget {
  final String? advertisementId;

  const AddEditAdvertisementScreen({
    super.key,
    this.advertisementId,
  });

  @override
  State<AddEditAdvertisementScreen> createState() => _AddEditAdvertisementScreenState();
}

class _AddEditAdvertisementScreenState extends State<AddEditAdvertisementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _advertisementService = AdvertisementService();
  final _supermarketService = SupermarketService();
  final _imageService = ImageService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<Supermarket> _supermarkets = [];
  String _selectedServiceType = 'all';
  String? _selectedSupermarketId;
  bool _hasDiscount = false;
  int _discountPercentage = 0;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = true;
  DateTime? _expiresAt;
  File? _selectedImageFile;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final supermarkets = await _supermarketService.getAllSupermarkets();

      // إذا كان تعديل إعلان موجود
      if (widget.advertisementId != null) {
        final advertisement = await _advertisementService.getAdvertisementById(
          widget.advertisementId!,
        );
        if (advertisement != null) {
          _titleController.text = advertisement.title;
          _descriptionController.text = advertisement.description ?? '';
          _imageUrlController.text = advertisement.imageUrl ?? '';
          _selectedServiceType = advertisement.serviceType;
          _selectedSupermarketId = advertisement.supermarketId;
          _hasDiscount = advertisement.hasDiscount;
          _discountPercentage = advertisement.discountPercentage;
          _isActive = advertisement.isActive;
          _expiresAt = advertisement.expiresAt;
        }
      }

      if (mounted) {
        setState(() {
          _supermarkets = supermarkets;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
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

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _expiresAt = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        // نسخ الصورة إلى مجلد التطبيق
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'advertisement_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
        final savedImage = await File(image.path).copy(path.join(imagesDir.path, fileName));
        
        setState(() {
          _selectedImageFile = savedImage;
          _selectedImagePath = savedImage.path;
          _imageUrlController.text = savedImage.path; // استخدام مسار الملف المحلي
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveAdvertisement() async {
    if (_formKey.currentState!.validate()) {
      if (_hasDiscount && _discountPercentage <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال نسبة تنزيل صحيحة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // رفع الصورة إذا كانت هناك صورة محلية جديدة
        String? imageUrl;
        if (_selectedImageFile != null) {
          // إذا كانت الصورة ملف محلي جديد، رفعها إلى السيرفر
          if (!_imageUrlController.text.startsWith('http')) {
            // عرض رسالة تقدم
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('جاري رفع الصورة...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            
            imageUrl = await _imageService.uploadImage(_selectedImageFile!);
            if (imageUrl == null) {
              throw 'فشل رفع الصورة. يرجى المحاولة مرة أخرى';
            }
          } else {
            // إذا كانت الصورة URL موجودة، استخدامها
            imageUrl = _imageUrlController.text.trim();
          }
        } else if (_imageUrlController.text.trim().isNotEmpty && 
                   _imageUrlController.text.startsWith('http')) {
          // إذا كان هناك URL موجود، استخدامه
          imageUrl = _imageUrlController.text.trim();
        }

        final advertisement = Advertisement(
          id: widget.advertisementId ??
              'ADV${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: imageUrl,
          serviceType: _selectedServiceType,
          supermarketId: _selectedSupermarketId,
          hasDiscount: _hasDiscount,
          discountPercentage: _discountPercentage,
          isActive: _isActive,
          createdAt: widget.advertisementId != null
              ? DateTime.now() // سيتم استبدالها بالقيمة الأصلية
              : DateTime.now(),
          expiresAt: _expiresAt,
        );

        if (widget.advertisementId != null) {
          // تحديث إعلان موجود
          final existing = await _advertisementService.getAdvertisementById(
            widget.advertisementId!,
          );
          if (existing != null) {
            final updated = advertisement.copyWith(createdAt: existing.createdAt);
            await _advertisementService.updateAdvertisement(updated);
          }
        } else {
          // إنشاء إعلان جديد
          await _advertisementService.createAdvertisement(advertisement);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.advertisementId != null
                  ? 'تم تحديث الإعلان بنجاح'
                  : 'تم إنشاء الإعلان بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.pop();
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(widget.advertisementId != null
              ? 'تعديل الإعلان'
              : 'إضافة إعلان جديد'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'عنوان الإعلان *',
                    hintText: 'أدخل عنوان الإعلان',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال عنوان الإعلان';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'وصف الإعلان',
                    hintText: 'أدخل وصف الإعلان (اختياري)',
                    prefixIcon: const Icon(Icons.description_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Image Selection
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          labelText: 'رابط الصورة',
                          hintText: 'أدخل رابط الصورة أو اختر صورة',
                          prefixIcon: const Icon(Icons.image_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('اختر صورة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                // Image Preview
                if (_selectedImageFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImageFile!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else if (_imageUrlController.text.isNotEmpty && _selectedImageFile == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _imageUrlController.text.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: _imageUrlController.text,
                              height: 200,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                            )
                          : Image.file(
                              File(_imageUrlController.text),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Service Type
                DropdownButtonFormField<String>(
                  value: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: 'نوع الخدمة *',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع الخدمات')),
                    DropdownMenuItem(value: 'delivery', child: Text('توصيل')),
                    DropdownMenuItem(value: 'taxi', child: Text('تكسي')),
                    DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedServiceType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Supermarket
                DropdownButtonFormField<String?>(
                  value: _selectedSupermarketId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'السوبر ماركت',
                    hintText: 'اختر سوبر ماركت (اختياري)',
                    prefixIcon: const Icon(Icons.store_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'عام (لجميع السوبر ماركتات)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._supermarkets.map((sm) => DropdownMenuItem<String?>(
                          value: sm.id,
                          child: Text(
                            sm.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  selectedItemBuilder: (context) {
                    return [
                      const Text(
                        'عام (لجميع السوبر ماركتات)',
                        overflow: TextOverflow.ellipsis,
                      ),
                      ..._supermarkets.map((sm) => Text(
                            sm.name,
                            overflow: TextOverflow.ellipsis,
                          )),
                    ];
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedSupermarketId = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Has Discount
                SwitchListTile(
                  title: const Text('يحتوي على تنزيل'),
                  subtitle: const Text('تفعيل خصم على هذا الإعلان'),
                  value: _hasDiscount,
                  onChanged: (value) {
                    setState(() {
                      _hasDiscount = value;
                      if (!value) {
                        _discountPercentage = 0;
                      }
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                // Discount Percentage
                if (_hasDiscount) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _discountPercentage.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'نسبة التنزيل (%) *',
                      hintText: 'أدخل نسبة التنزيل (0-100)',
                      prefixIcon: const Icon(Icons.percent_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _discountPercentage = int.tryParse(value) ?? 0;
                      });
                    },
                    validator: (value) {
                      if (_hasDiscount) {
                        final percentage = int.tryParse(value ?? '0') ?? 0;
                        if (percentage <= 0 || percentage > 100) {
                          return 'الرجاء إدخال نسبة صحيحة (1-100)';
                        }
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                // Is Active
                SwitchListTile(
                  title: const Text('نشط'),
                  subtitle: const Text('تفعيل/إلغاء تفعيل الإعلان'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeColor: AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                // Expiry Date
                ListTile(
                  title: const Text('تاريخ انتهاء الصلاحية'),
                  subtitle: Text(_expiresAt == null
                      ? 'لا يوجد تاريخ انتهاء'
                      : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today_rounded),
                    onPressed: _selectExpiryDate,
                  ),
                  onTap: _selectExpiryDate,
                ),
                if (_expiresAt != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _expiresAt = null;
                      });
                    },
                    child: const Text('إزالة تاريخ الانتهاء'),
                  ),
                const SizedBox(height: 32),
                // Save Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAdvertisement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.advertisementId != null ? 'تحديث' : 'حفظ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                // مسافة إضافية في الأسفل لتجنب تداخل الأزرار
                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




