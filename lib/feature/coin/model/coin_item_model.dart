class CoinItemModel {
  final String id;
  final String code;
  final String name;
  final String symbol;
  final double currentPrice;
  final double changeRate;
  final double tradeVolume;
  final String market;
  final bool isActive;

  const CoinItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    required this.currentPrice,
    required this.changeRate,
    required this.tradeVolume,
    required this.market,
    required this.isActive,
  });

  factory CoinItemModel.fromMap(Map<String, dynamic> map) {
    return CoinItemModel(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      symbol: map['symbol']?.toString() ?? '',
      currentPrice: _toDouble(map['current_price']),
      changeRate: _toDouble(map['change_rate']),
      tradeVolume: _toDouble(map['trade_volume']),
      market: map['market']?.toString() ?? 'KRW',
      isActive: map['is_active'] == true,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}