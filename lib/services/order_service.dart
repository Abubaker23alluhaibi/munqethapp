import '../models/order.dart';
import '../core/api/api_service_improved.dart';
import '../core/utils/app_logger.dart';
import 'card_service.dart';
import 'settings_service.dart';
import 'package:dio/dio.dart';

class OrderService {
  final ApiServiceImproved _apiService = ApiServiceImproved();

  // الحصول على جميع الطلبات
  Future<List<Order>> getAllOrders(String supermarketId) async {
    try {
      final response = await _apiService.get('/orders', queryParameters: {
        'supermarketId': supermarketId,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      AppLogger.w('getAllOrders: Response status ${response.statusCode} or null data');
      return [];
    } catch (e, stackTrace) {
      AppLogger.e('Error getting all orders for supermarket $supermarketId', e, stackTrace);
      // في release mode، نريد رؤية الأخطاء لكن نعيد قائمة فارغة لتجنب كسر UI
      return [];
    }
  }

  // الحصول على طلب بالـ ID
  Future<Order?> getOrderById(String id, String supermarketId) async {
    try {
      final response = await _apiService.get('/orders/$id');
      if (response.statusCode == 200 && response.data != null) {
        final order = Order.fromJson(response.data as Map<String, dynamic>);
        // إذا كان supermarketId فارغاً أو null، إرجاع الطلب مباشرة (للسائقين)
        if (supermarketId.isEmpty || supermarketId == '') {
          return order;
        }
        // التحقق من أن الطلب ينتمي إلى السوبر ماركت المطلوب (إذا كان نوعه delivery)
        if (order.supermarketId == supermarketId || order.type != 'delivery') {
          return order;
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error getting order by id', e);
      return null;
    }
  }

  // تحديث حالة الطلب
  Future<bool> updateOrderStatus(
      String orderId, OrderStatus status, String supermarketId) async {
    try {
      final response = await _apiService.put('/orders/$orderId/status', data: {
        'status': status.value,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Error updating order status', e);
      return false;
    }
  }

  // فلترة الطلبات حسب الحالة
  Future<List<Order>> getOrdersByStatus(
      OrderStatus status, String supermarketId) async {
    try {
      final response = await _apiService.get('/orders', queryParameters: {
        'supermarketId': supermarketId,
        'status': status.value,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting orders by status', e);
      return [];
    }
  }

  // الحصول على عدد الطلبات حسب الحالة
  Future<Map<OrderStatus, int>> getOrdersCountByStatus(
      String supermarketId) async {
    try {
      final orders = await getAllOrders(supermarketId);
      final counts = <OrderStatus, int>{};
      for (var status in OrderStatus.values) {
        counts[status] = orders.where((o) => o.status == status).length;
      }
      return counts;
    } catch (e) {
      AppLogger.e('Error getting orders count by status', e);
      return {};
    }
  }

  // الحصول على الطلبات الجديدة (pending)
  Future<List<Order>> getNewOrders(String supermarketId) async {
    return getOrdersByStatus(OrderStatus.pending, supermarketId);
  }

  // ترتيب الطلبات حسب التاريخ (الأحدث أولاً)
  Future<List<Order>> getAllOrdersSorted(String supermarketId) async {
    final orders = await getAllOrders(supermarketId);
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  // الحصول على جميع الطلبات (للسائقين - بدون فلترة بالسوبر ماركت)
  Future<List<Order>> getAllOrdersForDriver() async {
    try {
      final response = await _apiService.get('/orders');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      AppLogger.w('getAllOrdersForDriver: Response status ${response.statusCode} or null data');
      return [];
    } catch (e, stackTrace) {
      AppLogger.e('Error getting all orders for driver', e, stackTrace);
      // في release mode، نريد رؤية الأخطاء لكن نعيد قائمة فارغة لتجنب كسر UI
      return [];
    }
  }

  // Backward compatibility
  Future<List<Order>> getAllOrdersForDelivery() async {
    return getAllOrdersForDriver();
  }

  // الحصول على الطلبات المتاحة حسب نوع الخدمة
  Future<List<Order>> getAvailableOrdersForDriver(String serviceType) async {
    try {
      AppLogger.d('Getting available orders for driver, serviceType: $serviceType');
      final response = await _apiService.get('/orders', queryParameters: {
        'type': serviceType,
        'status': serviceType == 'delivery' ? 'ready' : 'pending',
      });
      
      AppLogger.d('Response status: ${response.statusCode}');
      AppLogger.d('Response data type: ${response.data.runtimeType}');
      AppLogger.d('Response data is null: ${response.data == null}');
      
      if (response.statusCode == 200 && response.data != null) {
        // التحقق من نوع البيانات
        List<dynamic> jsonList;
        if (response.data is List) {
          jsonList = response.data as List<dynamic>;
        } else if (response.data is Map) {
          // إذا كانت البيانات Map، قد تكون محاطة بكائن
          final dataMap = response.data as Map<String, dynamic>;
          if (dataMap.containsKey('orders')) {
            jsonList = dataMap['orders'] as List<dynamic>;
          } else if (dataMap.containsKey('data')) {
            jsonList = dataMap['data'] as List<dynamic>;
          } else {
            AppLogger.w('Response data is Map but no orders/data key found. Keys: ${dataMap.keys}');
            return [];
          }
        } else {
          AppLogger.w('Unexpected response data type: ${response.data.runtimeType}');
          return [];
        }
        
        AppLogger.d('Parsed ${jsonList.length} orders from response');
        
        final allOrders = jsonList
            .map((json) {
              try {
                return Order.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                AppLogger.e('Error parsing order JSON: $json', e);
                return null;
              }
            })
            .whereType<Order>() // إزالة null values
            .toList();
        
        AppLogger.d('Successfully parsed ${allOrders.length} orders');
        
        // وقت انتهاء صلاحية الطلب من إعدادات الأدمن (orderExpirationMinutes)
        final appSettings = await SettingsService().getAppSettings();
        final expirationMinutes = appSettings.orderExpirationMinutes.clamp(1, 60);
        final expirationTime = Duration(minutes: expirationMinutes);
        final now = DateTime.now();
        
        // فلترة الطلبات:
        // 1. التي لم يُقبل عليها سائق بعد
        // 2. غير ملغاة
        // 3. لم تنتهِ (أقل من 6 دقائق من وقت الإنشاء - buffer time)
        final filteredOrders = allOrders.where((order) {
          // يجب أن لا يكون لديه سائق
          if (order.driverId != null) {
            AppLogger.d('Order ${order.id} filtered: has driver ${order.driverId}');
            return false;
          }
          
          // يجب أن لا يكون ملغى
          if (order.status == OrderStatus.cancelled) {
            AppLogger.d('Order ${order.id} filtered: cancelled');
            return false;
          }
          
          // يجب أن يكون أقل من 6 دقائق من وقت الإنشاء (buffer time)
          // استخدام UTC لتجنب مشاكل فارق التوقيت
          final createdAtUtc = order.createdAt.toUtc();
          final nowUtc = now.toUtc();
          final elapsed = nowUtc.difference(createdAtUtc);
          
          // إذا كان elapsed سالباً (الطلب في المستقبل)، نعتبره صالحاً (مشكلة في التوقيت)
          if (elapsed.isNegative) {
            AppLogger.w('Order ${order.id} has negative elapsed time (timezone issue), keeping it');
            return true; // نعتبره صالحاً إذا كان في المستقبل (مشكلة توقيت)
          }
          
          // إذا كان أكثر من 6 دقائق، نزيله
          if (elapsed >= expirationTime) {
            AppLogger.d('Order ${order.id} filtered: expired (${elapsed.inMinutes} minutes old)');
            return false;
          }
          
          AppLogger.d('Order ${order.id} is valid (${elapsed.inSeconds} seconds old)');
          return true;
        }).toList();
        
        AppLogger.d('Filtered to ${filteredOrders.length} valid orders (after expiration check)');
        return filteredOrders;
      } else {
        AppLogger.w('getAvailableOrdersForDriver: Response status ${response.statusCode} or null data');
        if (response.statusCode != 200) {
          AppLogger.e('Non-200 status code: ${response.statusCode}, data: ${response.data}');
        }
        return [];
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error getting available orders for driver, serviceType: $serviceType', e, stackTrace);
      return [];
    }
  }

  // Backward compatibility
  Future<List<Order>> getAvailableOrdersForDelivery() async {
    return getAvailableOrdersForDriver('delivery');
  }

  // قبول طلب من قبل سائق
  Future<bool> acceptOrderByDriver(String orderId, String driverId, String serviceType) async {
    try {
      final response = await _apiService.post('/orders/$orderId/accept', data: {
        'driverId': driverId,
        'serviceType': serviceType,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Error accepting order by driver', e);
      return false;
    }
  }

  // Backward compatibility
  Future<bool> acceptOrderByDelivery(String orderId, String deliveryId) async {
    return acceptOrderByDriver(orderId, deliveryId, 'delivery');
  }

  // الحصول على طلبات سائق معين
  Future<List<Order>> getOrdersByDriver(String driverId) async {
    try {
      final response = await _apiService.get('/orders', queryParameters: {
        'driverId': driverId,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting orders by driver', e);
      return [];
    }
  }

  // Backward compatibility
  Future<List<Order>> getOrdersByDelivery(String deliveryId) async {
    return getOrdersByDriver(deliveryId);
  }

  // الحصول على طلبات سائق معين حسب الحالة
  Future<List<Order>> getOrdersByDriverAndStatus(
      String driverId, OrderStatus status) async {
    try {
      final response = await _apiService.get('/orders', queryParameters: {
        'driverId': driverId,
        'status': status.value,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        return jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('Error getting orders by driver and status', e);
      return [];
    }
  }

  // Backward compatibility
  Future<List<Order>> getOrdersByDeliveryAndStatus(
      String deliveryId, OrderStatus status) async {
    return getOrdersByDriverAndStatus(deliveryId, status);
  }

  // تحديث حالة طلب من قبل سائق
  Future<bool> updateOrderStatusByDriver(
      String orderId, OrderStatus status, String driverId) async {
    try {
      // أولاً، التحقق من أن السائق هو من قبل هذا الطلب
      // استخدام API مباشرة للحصول على الطلب بدون التحقق من supermarketId
      Order? order;
      AppLogger.d('Updating order status: $orderId -> ${status.value}');
      try {
        final response = await _apiService.get('/orders/$orderId');
        if (response.statusCode == 200 && response.data != null) {
          order = Order.fromJson(response.data as Map<String, dynamic>);
          AppLogger.d('Order found via direct API: ${order.id}, status: ${order.status.value}');
        }
      } catch (e) {
        AppLogger.w('Direct API call failed, trying getAllOrdersForDriver', e);
        // إذا فشل، البحث في جميع الطلبات
        final allOrders = await getAllOrdersForDriver();
        AppLogger.d('Searching in ${allOrders.length} orders');
        try {
          order = allOrders.firstWhere((o) => o.id == orderId);
          AppLogger.d('Order found in list: ${order.id}');
        } catch (e) {
          AppLogger.e('Order not found: $orderId');
          AppLogger.d('Available IDs: ${allOrders.map((o) => o.id).take(5).join(", ")}');
          order = null;
        }
      }
      
      if (order == null) {
        throw Exception('الطلب غير موجود');
      }
      if (order.driverId != driverId) {
        AppLogger.w('Driver mismatch: order.driverId=${order.driverId}, driverId=$driverId');
        throw Exception('ليس لديك صلاحية لتحديث حالة هذا الطلب');
      }
      
      AppLogger.d('Sending PUT request to /orders/$orderId/status with status: ${status.value}');
      final response = await _apiService.put('/orders/$orderId/status', data: {
        'status': status.value,
      });
      
      if (response.statusCode == 200) {
        // التحقق من أن الطلب تم تحديثه بنجاح
        AppLogger.i('Order status updated successfully: $orderId -> ${status.value}');
        AppLogger.d('Response data: ${response.data}');
        
        // التحقق من أن البيانات تم تحديثها في السيرفر
        if (response.data != null) {
          final updatedOrder = response.data as Map<String, dynamic>;
          final updatedStatus = updatedOrder['status'];
          if (updatedStatus == status.value) {
            AppLogger.d('Status confirmed in server response: $updatedStatus');
          } else {
            AppLogger.w('Status mismatch: expected ${status.value}, got $updatedStatus');
          }
        }
        
        return true;
      }
      
      // محاولة الحصول على رسالة الخطأ من السيرفر
      final errorData = response.data;
      if (errorData is Map && errorData.containsKey('error')) {
        throw Exception(errorData['error']);
      }
      
      throw Exception('فشل تحديث حالة الطلب');
    } on DioException catch (e) {
      AppLogger.e('DioException updating order status', e);
      // محاولة الحصول على رسالة الخطأ من السيرفر
      if (e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('error')) {
          throw Exception(errorData['error']);
        }
      }
      throw Exception('فشل تحديث حالة الطلب: ${e.message ?? "خطأ في الاتصال"}');
    } catch (e) {
      AppLogger.e('Error updating order status by driver', e);
      // إعادة رمي الخطأ إذا كان Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('فشل تحديث حالة الطلب: $e');
    }
  }

  // Backward compatibility
  Future<bool> updateOrderStatusByDelivery(
      String orderId, OrderStatus status, String deliveryId) async {
    return updateOrderStatusByDriver(orderId, status, deliveryId);
  }

  // إنشاء طلب جديد
  Future<Order?> createOrder(Order order) async {
    try {
      // إزالة id من البيانات المرسلة لأن السيرفر سينشئه
      final orderData = order.toJson();
      orderData.remove('id');
      
      final response = await _apiService.post('/orders', data: orderData);
      
      if (response.statusCode == 201 && response.data != null) {
        return Order.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error creating order', e);
      return null;
    }
  }

  // إلغاء طلب (للزبون أو السائق)
  // يمكن الإلغاء فقط قبل قبول السائق للطلب (قبل حالة accepted)
  // أو إذا كان السائق هو من قبل الطلب و الحالة accepted (قبل arrived)
  // أو إذا كان السائق وصل للموقع (arrived أو inProgress) - مع سبب الإلغاء
  Future<bool> cancelOrder(String orderId, {String? driverId, String? cancellationReason}) async {
    try {
      // التحقق من حالة الطلب أولاً - استخدام API مباشرة
      Order? order;
      AppLogger.d('Cancelling order: $orderId');
      try {
        final response = await _apiService.get('/orders/$orderId');
        if (response.statusCode == 200 && response.data != null) {
          order = Order.fromJson(response.data as Map<String, dynamic>);
          AppLogger.d('Order found via direct API: ${order.id}, status: ${order.status.value}');
        }
      } catch (e) {
        AppLogger.w('Direct API call failed, trying getAllOrdersForDriver', e);
        // إذا فشل، البحث في جميع الطلبات
        final allOrders = await getAllOrdersForDriver();
        AppLogger.d('Searching in ${allOrders.length} orders');
        try {
          order = allOrders.firstWhere((o) => o.id == orderId);
          AppLogger.d('Order found in list: ${order.id}');
        } catch (e) {
          AppLogger.e('Order not found: $orderId');
          AppLogger.d('Available IDs: ${allOrders.map((o) => o.id).take(5).join(", ")}');
          order = null;
        }
      }
      
      if (order == null) {
        throw Exception('الطلب غير موجود');
      }
      
      // إذا كان السائق يلغي، يجب أن يكون هو من قبل الطلب
      if (driverId != null && order.driverId != driverId) {
        return false;
      }
      
      // إذا كان السائق يلغي طلب قبل، يمكنه الإلغاء في جميع الحالات (حتى بعد الوصول) مع سبب
      if (driverId != null && order.driverId == driverId) {
        // السائق يمكنه الإلغاء حتى بعد الوصول (arrived, inProgress) إذا كان هناك سبب
        if (order.status == OrderStatus.delivered ||
            order.status == OrderStatus.completed) {
          return false; // لا يمكن الإلغاء بعد التسليم
        }
        // إذا كان السائق يلغي بعد الوصول، يجب أن يكون هناك سبب
        if ((order.status == OrderStatus.arrived || 
             order.status == OrderStatus.inProgress) && 
            (cancellationReason == null || cancellationReason.isEmpty)) {
          throw Exception('يرجى كتابة سبب الإلغاء');
        }
      } else {
        // للزبون: يمكن الإلغاء حتى بعد قبول السائق، لكن فقط قبل وصول السائق للموقع
        // أي يمكن الإلغاء في حالات: pending, preparing, ready, accepted
        // لا يمكن الإلغاء بعد: arrived, inProgress, delivered, completed
        if (order.status == OrderStatus.arrived ||
            order.status == OrderStatus.inProgress ||
            order.status == OrderStatus.delivered ||
            order.status == OrderStatus.completed) {
          throw Exception('لا يمكن إلغاء الطلب بعد وصول السائق للموقع');
        }
      }
      
      // تحديث حالة الطلب إلى ملغي
      try {
        final requestData = {
          'status': OrderStatus.cancelled.value,
        };
        // إضافة driverId إذا كان موجوداً
        if (driverId != null) {
          requestData['driverId'] = driverId;
        }
        // إضافة سبب الإلغاء إذا كان موجوداً
        if (cancellationReason != null && cancellationReason.isNotEmpty) {
          requestData['cancellationReason'] = cancellationReason;
        }
        final response = await _apiService.put('/orders/$orderId/status', data: requestData);
        
        if (response.statusCode == 200) {
          // استرجاع المبلغ إذا كان الدفع عبر الكارت أو المحفظة
          if (order.paymentMethod == 'wallet' || order.paymentMethod == 'card') {
            await _refundOrderPayment(order);
          }
          return true;
        }
        
        // إذا لم يكن statusCode 200، حاول الحصول على رسالة الخطأ
        final errorData = response.data;
        if (errorData is Map && errorData.containsKey('error')) {
          throw Exception(errorData['error']);
        }
        
        return false;
      } on DioException catch (e) {
        AppLogger.e('DioException cancelling order', e);
        // إرجاع رسالة الخطأ من السيرفر إذا كانت متوفرة
        if (e.response != null) {
          final errorData = e.response?.data;
          if (errorData is Map && errorData.containsKey('error')) {
            throw Exception(errorData['error']);
          }
        }
        throw Exception('فشل إلغاء الطلب: ${e.message}');
      }
    } catch (e) {
      AppLogger.e('Error cancelling order', e);
      // إعادة رمي الخطأ إذا كان Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('فشل إلغاء الطلب: $e');
    }
  }

  // استرجاع المبلغ المدفوع عند إلغاء الطلب
  Future<void> _refundOrderPayment(Order order) async {
    try {
      final cardService = CardService();
      
      // حساب المبلغ الكامل المستخدم في الدفع (يستخدم displayTotal الذي يحسب كل شيء)
      final orderAmount = order.displayTotal.toInt();
      
      if (orderAmount <= 0) {
        AppLogger.d('Order amount is 0, no refund needed');
        return;
      }
      
      // استرجاع المبلغ حسب طريقة الدفع
      if (order.paymentMethod == 'wallet') {
        // استرجاع للمحفظة
        final refunded = await cardService.refundToWallet(
          order.customerPhone,
          orderAmount,
        );
        if (refunded) {
          AppLogger.i('Refunded $orderAmount to wallet for order ${order.id}');
        } else {
          AppLogger.e('Failed to refund to wallet for order ${order.id}');
        }
      } else if (order.paymentMethod == 'card' && order.paymentCardId != null) {
        // استرجاع للبطاقة المحددة
        final refunded = await cardService.refundToCard(
          order.customerPhone,
          order.paymentCardId!,
          orderAmount,
        );
        if (refunded) {
          AppLogger.i('Refunded $orderAmount to card ${order.paymentCardId} for order ${order.id}');
        } else {
          AppLogger.e('Failed to refund to card for order ${order.id}');
        }
      }
    } catch (e) {
      AppLogger.e('Error refunding order payment', e);
      // لا نفشل عملية الإلغاء إذا فشل الاسترجاع
    }
  }

  // الحصول على طلبات المستخدم حسب رقم الهاتف
  Future<List<Order>> getOrdersByCustomerPhone(String customerPhone) async {
    try {
      AppLogger.d('Getting orders for customer phone: $customerPhone');
      
      // تطبيع رقم الهاتف (إزالة + ومسافات)
      String normalizedPhone = customerPhone.replaceAll(RegExp(r'[\s+]'), '');
      
      // إذا كان يبدأ بـ +964، أزل الـ +
      if (normalizedPhone.startsWith('+964')) {
        normalizedPhone = normalizedPhone.replaceFirst('+', '');
      }
      // إذا كان يبدأ بـ 964 فقط، اتركه كما هو
      // إذا كان يبدأ بـ 0، استبدله بـ 964
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '964' + normalizedPhone.substring(1);
      }
      // إذا كان يبدأ بـ 7 أو 7 بدون 964، أضف 964
      if (normalizedPhone.length == 10 && normalizedPhone.startsWith('7')) {
        normalizedPhone = '964' + normalizedPhone;
      }
      
      AppLogger.d('Normalized phone: $normalizedPhone');
      
      // استخدام API مباشر للبحث حسب رقم الهاتف
      final response = await _apiService.get('/orders', queryParameters: {
        'customerPhone': normalizedPhone,
      });
      
      AppLogger.d('Orders response status: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> jsonList = response.data;
        final orders = jsonList
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
        
        AppLogger.d('Found ${orders.length} orders for phone: $normalizedPhone');
        
        // فلترة إضافية للتأكد من المطابقة (في حالة وجود اختلافات في التنسيق)
        final filteredOrders = orders.where((order) {
          String orderPhone = order.customerPhone.replaceAll(RegExp(r'[\s+]'), '');
          
          // تطبيع رقم الهاتف من الطلب
          if (orderPhone.startsWith('+964')) {
            orderPhone = orderPhone.replaceFirst('+', '');
          }
          if (orderPhone.startsWith('0')) {
            orderPhone = '964' + orderPhone.substring(1);
          }
          if (orderPhone.length == 10 && orderPhone.startsWith('7')) {
            orderPhone = '964' + orderPhone;
          }
          
          // مقارنة الأرقام المطابقة
          final match = orderPhone == normalizedPhone;
          
          if (!match) {
            AppLogger.d('Phone mismatch: orderPhone=$orderPhone, normalizedPhone=$normalizedPhone');
          }
          
          return match;
        }).toList();
        
        AppLogger.d('Filtered to ${filteredOrders.length} matching orders');
        
        return filteredOrders;
      }
      AppLogger.w('getOrdersByCustomerPhone: Response status ${response.statusCode} or null data for phone: $normalizedPhone');
      return [];
    } catch (e, stackTrace) {
      AppLogger.e('Error getting orders by customer phone: $customerPhone', e, stackTrace);
      // في release mode، نريد رؤية الأخطاء لكن نعيد قائمة فارغة لتجنب كسر UI
      return [];
    }
  }
}