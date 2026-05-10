class StockItemViewModel {
  final String id;
  final String code;
  final String name;
  final String market;
  final double currentPrice;
  final double changeRate;
  final String description;

  StockItemViewModel({
    required this.id,
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.description,
  });
}