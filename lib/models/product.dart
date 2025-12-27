class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? image;
  final String category;
  final int stock;
  final bool isAvailable;
  final String supermarketId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    required this.category,
    this.stock = 0,
    this.isAvailable = true,
    required this.supermarketId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'category': category,
      'stock': stock,
      'isAvailable': isAvailable,
      'supermarketId': supermarketId,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB _id field
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    return Product(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
      category: json['category'] as String,
      stock: json['stock'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      supermarketId: json['supermarketId'] as String,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? image,
    String? category,
    int? stock,
    bool? isAvailable,
    String? supermarketId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      image: image ?? this.image,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      supermarketId: supermarketId ?? this.supermarketId,
    );
  }
}






