import 'package:stock/feature/stock/model/stock_pending_order_model.dart';

class StockPendingOrderService {
  bool hasSamePendingOrder({
    required List<StockPendingOrderModel> pendingOrders,
    required String stockCode,
    required String orderType,
    required double orderPrice,
  }) {
    return pendingOrders.any((order) {
      return order.stockCode == stockCode &&
          order.orderType == orderType &&
          order.orderPrice == orderPrice;
    });
  }

  double reservedBuyAmount({
    required List<StockPendingOrderModel> pendingOrders,
  }) {
    double total = 0;

    for (final order in pendingOrders) {
      if (order.orderType != 'buy') continue;
      total += order.orderPrice * order.quantity;
    }

    return total;
  }

  int reservedSellQuantity({
    required List<StockPendingOrderModel> pendingOrders,
    required String stockCode,
  }) {
    int total = 0;

    for (final order in pendingOrders) {
      if (order.orderType != 'sell') continue;
      if (order.stockCode != stockCode) continue;
      total += order.quantity;
    }

    return total;
  }
}