import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/supermarket_service.dart';
import '../../services/driver_service.dart';
import '../../services/product_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/payment_method_selector.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/errors/error_handler.dart';
import '../../services/card_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../utils/delivery_fee_calculator.dart';
import '../../core/utils/distance_calculator.dart';

class ShoppingOrderScreen extends StatefulWidget {
  const ShoppingOrderScreen({super.key});

  @override
  State<ShoppingOrderScreen> createState() => _ShoppingOrderScreenState();
}

class _ShoppingOrderScreenState extends State<ShoppingOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supermarketService = SupermarketService();
  final _driverService = DriverService();
  final _productService = ProductService();
  final _cardService = CardService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  List<Product> _availableProducts = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;
  
  // Location
  double? _customerLat;
  double? _customerLng;
  
  // Payment
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedCardId;
  
  // Delivery
  int? _deliveryFee;
  double? _distanceToSupermarket;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadProducts();
  }

  Future<void> _loadUserInfo() async {
    // جلب بيانات المستخدم من AuthProvider (الذي يجلبها من السيرفر)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadCurrentUser();
    
    final user = authProvider.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      if (user.address != null && user.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }
    } else {
      // إذا لم يكن المستخدم مسجل دخول، جرب جلب رقم الهاتف المحفوظ
      final userPhone = await SecureStorageService.getString('user_phone');
      if (userPhone != null && userPhone.isNotEmpty) {
        _phoneController.text = userPhone;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      // الحصول على جميع المنتجات من جميع السوبر ماركتات
      final products = await _productService.getAllProductsFromAllSupermarkets();
      
      if (mounted) {
        setState(() {
          _availableProducts = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _calculateDeliveryFee() async {
    if (_customerLat == null || _customerLng == null) {
      // إذا لم يكن الموقع محدداً، استخدم قيمة افتراضية
      if (mounted) {
        setState(() {
          _deliveryFee = 1000; // قيمة افتراضية
          _distanceToSupermarket = null;
        });
      }
      return;
    }

    try {
      final nearestSupermarket = await _supermarketService.findNearestSupermarket(
        _customerLat!,
        _customerLng!,
      );

      if (nearestSupermarket != null) {
        double? distance;
        
        // استخدام الموقع الأقرب من مواقع السوبر ماركت (إذا كان هناك مواقع متعددة)
        if (nearestSupermarket.locations != null && nearestSupermarket.locations!.isNotEmpty) {
          final nearestLocation = nearestSupermarket.getNearestLocation(_customerLat!, _customerLng!);
          if (nearestLocation != null) {
            distance = DistanceCalculator.calculateDistance(
              nearestLocation.latitude,
              nearestLocation.longitude,
              _customerLat!,
              _customerLng!,
            );
          }
        } else if (nearestSupermarket.latitude != null && nearestSupermarket.longitude != null) {
          // استخدام الموقع القديم (latitude, longitude) للتوافق مع الكود القديم
          distance = DistanceCalculator.calculateDistance(
            nearestSupermarket.latitude!,
            nearestSupermarket.longitude!,
            _customerLat!,
            _customerLng!,
          );
          // التحقق من أن المسافة صحيحة
          if (distance != null && !distance.isFinite) {
            distance = null;
          }
        }

        if (mounted) {
          setState(() {
            _distanceToSupermarket = distance;
            _deliveryFee = distance != null 
                ? DeliveryFeeCalculator.calculateDeliveryFee(distance)
                : 1000;
            // التأكد من أن deliveryFee على الأقل 1000
            if (_deliveryFee != null && _deliveryFee! < 1000) {
              _deliveryFee = 1000;
            }
          });
        }
      } else {
        // إذا لم يوجد سوبر ماركت، استخدم قيمة افتراضية
        if (mounted) {
          setState(() {
            _deliveryFee = 1000;
            _distanceToSupermarket = null;
          });
        }
      }
    } catch (e) {
      // في حالة الخطأ، استخدم قيمة افتراضية
      if (mounted) {
        setState(() {
          _deliveryFee = 1000;
          _distanceToSupermarket = null;
        });
      }
    }
  }


  Future<void> _submitOrder() async {
    if (_formKey.currentState!.validate()) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      if (cartProvider.isEmpty) {
        ErrorHandler.showErrorSnackBar(
          context,
          null,
          customMessage: 'الرجاء اختيار منتج واحد على الأقل',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Validate location
        if (_customerLat == null || _customerLng == null) {
          ErrorHandler.showErrorSnackBar(
            context,
            null,
            customMessage: 'الرجاء تحديد موقعك على الخريطة',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Show loading dialog with supermarket image
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SupermarketLoadingWidget(),
                      const SizedBox(height: 20),
                      const Text(
                        'جاري البحث عن أقرب سوبر ماركت',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        
        // Give time for dialog to render
        await Future.delayed(const Duration(milliseconds: 300));

        // Generate order ID
        final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

        // Get customer location from map
        final customerLat = _customerLat!;
        final customerLng = _customerLng!;

        // Find nearest supermarket
        final nearestSupermarket = await _supermarketService.findNearestSupermarket(
          customerLat,
          customerLng,
        );

        if (nearestSupermarket == null) {
          // Close loading dialog
          if (mounted) {
            Navigator.of(context).pop();
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ErrorHandler.showErrorSnackBar(
              context,
              null,
              customMessage: 'لا يوجد سوبر ماركت متاح حالياً. الرجاء المحاولة لاحقاً',
            );
          }
          return;
        }

        // Calculate distance and delivery fee (إذا لم تكن محسوبة مسبقاً)
        if (_deliveryFee == null || _distanceToSupermarket == null) {
          double? calculatedDistance;
          
          // استخدام الموقع الأقرب من مواقع السوبر ماركت (إذا كان هناك مواقع متعددة)
          if (nearestSupermarket.locations != null && nearestSupermarket.locations!.isNotEmpty) {
            // استخدام الموقع الأقرب من مواقع السوبر ماركت
            final nearestLocation = nearestSupermarket.getNearestLocation(customerLat, customerLng);
            if (nearestLocation != null) {
              calculatedDistance = DistanceCalculator.calculateDistance(
                nearestLocation.latitude,
                nearestLocation.longitude,
                customerLat,
                customerLng,
              );
            }
          } 
          // استخدام الموقع القديم (latitude, longitude) للتوافق مع الكود القديم
          else if (nearestSupermarket.latitude != null && nearestSupermarket.longitude != null) {
            calculatedDistance = DistanceCalculator.calculateDistance(
              nearestSupermarket.latitude!,
              nearestSupermarket.longitude!,
              customerLat,
              customerLng,
            );
          }

          if (calculatedDistance != null && calculatedDistance.isFinite) {
            _distanceToSupermarket = calculatedDistance;
            _deliveryFee = DeliveryFeeCalculator.calculateDeliveryFee(_distanceToSupermarket!);
          } else {
            _distanceToSupermarket = null;
            _deliveryFee = 1000; // Default minimum fee
          }
        }
        
        // Check if supermarket is within 5 km
        if (_distanceToSupermarket == null || _distanceToSupermarket! > 5.0) {
          // Close loading dialog
          if (mounted) {
            Navigator.of(context).pop();
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ErrorHandler.showErrorSnackBar(
              context,
              null,
              customMessage: 'لا يوجد سوبر ماركت متاح ضمن مسافة 5 كيلومتر. الرجاء المحاولة لاحقاً',
            );
          }
          return;
        }
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // التأكد من أن deliveryFee ليس null أو أقل من 1000
        if (_deliveryFee == null || _deliveryFee! < 1000) {
          _deliveryFee = 1000; // ضمان أن المبلغ على الأقل 1000
        }
 
        // Find nearest delivery driver
        final nearestDriver = await _driverService.findNearestDriver(
          customerLat,
          customerLng,
          'delivery',
        );

        // Build order items from cart
        final orderItems = <OrderItem>[];
        for (var product in cartProvider.cartProducts) {
          final quantity = cartProvider.getQuantity(product.id);
          orderItems.add(OrderItem(
            productId: product.id,
            productName: product.name,
            price: product.price,
            quantity: quantity,
            productImage: product.image,
          ));
        }
        
        if (orderItems.isEmpty) {
          ErrorHandler.showErrorSnackBar(
            context,
            null,
            customMessage: 'الرجاء اختيار منتج واحد على الأقل',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // معالجة الدفع
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userPhone = authProvider.currentUser?.phone ?? _phoneController.text.trim();
        bool paymentProcessed = false;

        // Calculate total with delivery fee
        final totalWithDelivery = cartProvider.total + (_deliveryFee ?? 0);

        if (_paymentMethod == PaymentMethod.wallet) {
          // خصم من المحفظة
          paymentProcessed = await _cardService.deductFromWallet(userPhone, totalWithDelivery.toInt());
          if (!paymentProcessed) {
            ErrorHandler.showErrorSnackBar(
              context,
              null,
              customMessage: 'الرصيد في المحفظة غير كافي',
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else if (_paymentMethod == PaymentMethod.card && _selectedCardId != null) {
          // خصم من البطاقة
          paymentProcessed = await _cardService.useCardForPayment(userPhone, _selectedCardId!, totalWithDelivery.toInt());
          if (!paymentProcessed) {
            ErrorHandler.showErrorSnackBar(
              context,
              null,
              customMessage: 'فشل استخدام البطاقة للدفع',
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // Create order with ready status so drivers can see it immediately
        final order = Order(
          id: orderId,
          type: 'delivery',
          supermarketId: nearestSupermarket.id,
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          customerAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          customerLatitude: customerLat,
          customerLongitude: customerLng,
          items: orderItems,
          status: OrderStatus.ready, // Changed to ready so drivers can see it immediately
          total: cartProvider.total,
          deliveryFee: _deliveryFee,
          createdAt: DateTime.now(),
          paymentMethod: _paymentMethod.name,
          paymentCardId: _selectedCardId,
        );

        // Save order using Provider
        final success = await orderProvider.createOrder(order);
        
        if (success) {
          // مسح السلة بعد إنشاء الطلب
          cartProvider.clearCart();
        }

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم إرسال الطلب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم إرسال طلبك بنجاح',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'رقم الطلب: $orderId',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'السوبر ماركت: ${nearestSupermarket.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'في انتظار الموافقة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                  // إعادة توجيه المستخدم لصفحة الطلبات
                  context.push('/orders/history');
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) {
          // Close loading dialog if still open
          try {
            Navigator.of(context).pop();
          } catch (_) {
            // Dialog might not be open, ignore
          }
          setState(() {
            _isLoading = false;
          });
          ErrorHandler.handleError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('طلب من السوبر ماركت'),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: _isLoadingProducts
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Customer Info Section
                      _buildSectionTitle('معلومات العميل'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'الاسم *',
                          hintText: 'أدخل اسمك',
                          prefixIcon: const Icon(Icons.person_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال الاسم';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف *',
                          hintText: 'أدخل رقم الهاتف',
                          prefixIcon: const Icon(Icons.phone_rounded, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال رقم الهاتف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'العنوان (اختياري)',
                          hintText: 'أدخل عنوانك',
                          prefixIcon: const Icon(Icons.location_on_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      // Location Picker
                      LocationPickerWidget(
                        label: 'حدد موقعك على الخريطة *',
                        initialLatitude: _customerLat,
                        initialLongitude: _customerLng,
                        onLocationSelected: (lat, lng) async {
                          setState(() {
                            _customerLat = lat;
                            _customerLng = lng;
                          });
                          // Calculate delivery fee when location is selected
                          await _calculateDeliveryFee();
                        },
                      ),
                      const SizedBox(height: 32),
                      // Selected Products Section
                      _buildSectionTitle('المنتجات المختارة'),
                      const SizedBox(height: 16),
                      Consumer<CartProvider>(
                        builder: (context, cartProvider, child) {
                          if (cartProvider.isEmpty) {
                            return const EmptyState(
                              icon: Icons.shopping_cart_outlined,
                              title: 'لا توجد منتجات مختارة',
                              message: 'ارجع إلى صفحة التسوق واختر المنتجات',
                            );
                          }
                          
                          return Column(
                            children: [
                              // عرض المنتجات المختارة فقط
                              ...cartProvider.cartProducts.map((product) => _buildProductCard(product, cartProvider)),
                              const SizedBox(height: 24),
                              // Delivery Fee Section
                              if (_deliveryFee != null && _distanceToSupermarket != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.local_shipping, color: Colors.blue[700], size: 20),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'سعر التوصيل',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue[900],
                                                ),
                                              ),
                                              Text(
                                                'المسافة: ${DistanceCalculator.formatDistance(_distanceToSupermarket)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${_deliveryFee!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // Total Section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'مجموع المنتجات',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          '${cartProvider.total.toStringAsFixed(0)} د.ع',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                    if (_deliveryFee != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'سعر التوصيل',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                          Text(
                                            '${_deliveryFee!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'المجموع الكلي',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          '${(cartProvider.total + (_deliveryFee ?? 0)).toStringAsFixed(0)} د.ع',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Payment Method Selector
                              PaymentMethodSelector(
                                totalAmount: cartProvider.total + (_deliveryFee ?? 1000),
                                onPaymentMethodSelected: (method, cardId) {
                                  setState(() {
                                    _paymentMethod = method;
                                    _selectedCardId = cardId;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),
                              // Submit Button
                              ElevatedButton(
                                onPressed: (_isLoading || _customerLat == null || _customerLng == null) 
                                    ? null 
                                    : () {
                                        // التأكد من أن رسوم التوصيل محسوبة قبل الإرسال
                                        if (_deliveryFee == null) {
                                          _calculateDeliveryFee().then((_) {
                                            if (_deliveryFee != null) {
                                              _submitOrder();
                                            }
                                          });
                                        } else {
                                          _submitOrder();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
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
                                    : const Text(
                                        'موافق وإرسال الطلب',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildProductCard(Product product, CartProvider cartProvider) {
    final quantity = cartProvider.getQuantity(product.id);
    final isSelected = cartProvider.isInCart(product.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.image != null
                  ? Image.network(
                      product.image!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image),
                    ),
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(0)} د.ع',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Quantity Controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: quantity > 0 ? () => cartProvider.removeFromCart(product.id) : null,
                  color: AppTheme.primaryColor,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    quantity.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => cartProvider.addToCart(product),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget تحميل خاص للسوبر ماركت
class _SupermarketLoadingWidget extends StatefulWidget {
  const _SupermarketLoadingWidget();

  @override
  State<_SupermarketLoadingWidget> createState() => _SupermarketLoadingWidgetState();
}

class _SupermarketLoadingWidgetState extends State<_SupermarketLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _sparkleController;
  late Animation<double> _animation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Animation للنجوم/اللمعان (تظهر وتختفي)
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    _sparkleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الصورة المتحركة
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animation.value * 20, math.sin(_controller.value * 2 * math.pi) * 5),
                child: Transform.rotate(
                  angle: _animation.value * 0.1,
                  child: Image.asset(
                    'assets/images/supermaketloud.jpg',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          
          // نجوم/لمعان متحركة (تظهر حول الصورة)
          ...List.generate(4, (index) {
            final delay = index * 0.25;
            final angle = (index * 90) * (math.pi / 180);
            return Positioned(
              top: 40 + (math.sin(angle) * 40),
              left: 40 + (math.cos(angle) * 40),
              child: AnimatedBuilder(
                animation: _sparkleAnimation,
                builder: (context, child) {
                  final adjustedValue = (_sparkleAnimation.value + delay) % 1.0;
                  final opacity = adjustedValue < 0.5 
                      ? (adjustedValue * 2) 
                      : (2 - adjustedValue * 2);
                  
                  return Opacity(
                    opacity: opacity,
                    child: const Icon(
                      Icons.shopping_basket,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

