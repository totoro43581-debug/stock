class StockItemViewModel {
  final String id;
  final String code;
  final String name;
  final String market;

  final double currentPrice;
  final double changeRate;

  final int virtualBuyVolume;
  final int virtualSellVolume;
  final int tradeVolume;

  final double tradeAmount;

  // 수정88차: 현실형 가상 종목 정보
  final String description;
  final String stockType;
  final String sector;
  final String marketCapLevel;
  final String volatilityLevel;
  final int growthScore;
  final int stabilityScore;
  final double newsSensitivity;
  final int delistingRiskScore;
  final String listingStatus;

  StockItemViewModel({
    required this.id,
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.virtualBuyVolume,
    required this.virtualSellVolume,
    required this.tradeVolume,
    required this.tradeAmount,
    required this.description,
    this.stockType = 'domestic_large',
    this.sector = 'general',
    this.marketCapLevel = 'mid',
    this.volatilityLevel = 'normal',
    this.growthScore = 50,
    this.stabilityScore = 50,
    this.newsSensitivity = 1.00,
    this.delistingRiskScore = 0,
    this.listingStatus = 'listed',
  });
}