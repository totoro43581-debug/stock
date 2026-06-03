class AssetAccountTransactionModel {
  final String id;
  final String userId;

  /// deposit: 입금
  /// withdraw: 출금
  /// transfer: 이체
  final String type;

  /// point_to_asset: 포인트 → 자산계좌
  /// asset_to_deposit: 자산계좌 → 예금
  /// asset_to_savings: 자산계좌 → 적금
  /// asset_to_stock: 자산계좌 → 주식
  /// stock_to_asset: 주식 → 자산계좌
  final String reason;

  final double amount;
  final double balanceAfter;

  final String title;
  final String? memo;

  final DateTime createdAt;

  AssetAccountTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.title,
    this.memo,
    required this.createdAt,
  });

  factory AssetAccountTransactionModel.fromMap(Map<String, dynamic> map) {
    return AssetAccountTransactionModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      type: map['type'] ?? '',
      reason: map['reason'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceAfter: (map['balance_after'] ?? 0).toDouble(),
      title: map['title'] ?? '',
      memo: map['memo'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class AssetTransactionModel {
  final String id;
  final String userId;

  /// 거래 구분
  /// deposit: 입금
  /// withdraw: 출금
  /// stockBuy: 주식 매수
  /// stockSell: 주식 매도
  /// coinBuy: 코인 매수
  /// coinSell: 코인 매도
  /// pointTransfer: 포인트 전환
  /// savingDeposit: 예금/적금 입금
  /// savingWithdraw: 예금/적금 출금
  final String type;

  /// 화면 표시용 제목
  /// 예: 삼선전자 매수, 비트렉스 매도, 포인트 전환
  final String title;

  /// 연결 대상 코드
  /// 주식/코인 코드가 없으면 null
  final String? targetCode;

  /// 연결 대상 이름
  /// 주식명/코인명/예금명 등이 없으면 null
  final String? targetName;

  /// 금액
  final double amount;

  /// 수량
  /// 주식/코인 거래가 아니면 null
  final double? quantity;

  /// 체결 가격
  /// 주식/코인 거래가 아니면 null
  final double? price;

  /// 수수료
  final double fee;

  /// 거래 후 잔액
  final double balanceAfter;

  /// 메모
  final String memo;

  final DateTime createdAt;

  const AssetTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.targetCode,
    required this.targetName,
    required this.amount,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.balanceAfter,
    required this.memo,
    required this.createdAt,
  });

  factory AssetTransactionModel.fromMap(Map<String, dynamic> map) {
    return AssetTransactionModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      targetCode: map['target_code']?.toString(),
      targetName: map['target_name']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble(),
      price: (map['price'] as num?)?.toDouble(),
      fee: (map['fee'] as num?)?.toDouble() ?? 0,
      balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0,
      memo: map['memo']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'target_code': targetCode,
      'target_name': targetName,
      'amount': amount,
      'quantity': quantity,
      'price': price,
      'fee': fee,
      'balance_after': balanceAfter,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
    };
  }
}