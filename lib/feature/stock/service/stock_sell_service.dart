import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';
import 'package:stock/feature/stock/model/stock_pending_order_model.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';
import 'package:stock/feature/stock/service/stock_pending_order_service.dart';

class StockSellService {
  final StockPendingOrderService _pendingOrderService =
  StockPendingOrderService();

  int availableSellQuantity({
    required StockHoldingModel? holding,
    required List<StockPendingOrderModel> pendingOrders,
    required String stockCode,
  }) {
    final reservedSellQuantity =
    _pendingOrderService.reservedSellQuantity(
      pendingOrders: pendingOrders,
      stockCode: stockCode,
    );

    return (holding?.quantity ?? 0) - reservedSellQuantity;
  }

  Future<String> sell({
    required StockTradeRepository tradeRepository,
    required String userId,
    required StockItemViewModel item,
    required StockHoldingModel? holding,
    required double orderPrice,
    required int quantity,
    required bool isMarketOrder,
    required List<StockPendingOrderModel> pendingOrders,
  }) async {
    final currentAvailableSellQuantity = availableSellQuantity(
      holding: holding,
      pendingOrders: pendingOrders,
      stockCode: item.code,
    );

    if (currentAvailableSellQuantity < quantity) {
      throw Exception('미체결 매도 주문을 포함하면 보유수량이 부족합니다.');
    }

    if (isMarketOrder) {
      await tradeRepository.sellStock(
        userId: userId,
        stockCode: item.code,
        stockName: item.name,
        price: orderPrice,
        quantity: quantity,
      );

      return '시장가 매도 완료: ${item.name} ${quantity}주';
    }

    // 수정76차: 지정가 주문가가 현재가와 같으면 즉시 체결
    final bool isSameAsCurrentPrice = orderPrice == item.currentPrice;

    if (isSameAsCurrentPrice) {
      await tradeRepository.sellStock(
        userId: userId,
        stockCode: item.code,
        stockName: item.name,
        price: orderPrice,
        quantity: quantity,
      );

      return '지정가 매도 체결: ${item.name} ${quantity}주';
    }

    final hasSameOrder = _pendingOrderService.hasSamePendingOrder(
      pendingOrders: pendingOrders,
      stockCode: item.code,
      orderType: 'sell',
      orderPrice: orderPrice,
    );

    if (hasSameOrder) {
      throw Exception('이미 같은 가격의 매도 주문이 있습니다.');
    }

    await tradeRepository.createPendingOrder(
      userId: userId,
      stockCode: item.code,
      stockName: item.name,
      orderType: 'sell',
      orderPrice: orderPrice,
      quantity: quantity,
    );

    return '지정가 매도 주문 등록: ${item.name} ${quantity}주';
  }
}