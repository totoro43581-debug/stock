class CoinHoldingModel {
  final String id;
  final String userId;
  final String coinCode;
  final String coinName;
  final double quantity;
  final double averagePrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoinHoldingModel({
    required this.id,
    required this.userId,
    required this.coinCode,
    required this.coinName,
    required this.quantity,
    required this.averagePrice,
    required this.createdAt,
    required this.updatedAt,
  });

  double get evaluationAmount => quantity * averagePrice;

  factory CoinHoldingModel.fromMap(Map<String, dynamic> map) {
    return CoinHoldingModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      coinCode: map['coin_code']?.toString() ?? '',
      coinName: map['coin_name']?.toString() ?? '',
      quantity: _toDouble(map['quantity']),
      averagePrice: _toDouble(map['average_price']),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}