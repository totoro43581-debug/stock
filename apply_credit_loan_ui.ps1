# Stock loan UI one-step integration. Places BasicCreditLoanSection and makes
# surgical edits to loan_catalog_section.dart. Creates a timestamped backup.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = Join-Path $root 'basic_credit_loan_section.dart'
$target = Join-Path $root 'lib\feature\bank\view\widget\loan_catalog_section.dart'
$dest = Join-Path $root 'lib\feature\bank\view\widget\basic_credit_loan_section.dart'

if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
  throw '이 파일과 basic_credit_loan_section.dart를 Stock 프로젝트 루트(F:\stock)에 둔 뒤 실행해주세요.'
}
if (-not (Test-Path $source)) { throw 'basic_credit_loan_section.dart 파일이 프로젝트 루트에 없습니다.' }
if (-not (Test-Path $target)) { throw 'loan_catalog_section.dart 파일을 찾지 못했습니다.' }
if (Test-Path $dest) {
  $newHash = (Get-FileHash -Algorithm SHA256 $source).Hash
  $oldHash = (Get-FileHash -Algorithm SHA256 $dest).Hash
  if ($newHash -ne $oldHash) {
    throw '기존 basic_credit_loan_section.dart가 다릅니다. 덮어쓰지 않았습니다. 기존 파일을 확인해주세요.'
  }
}

$code = [System.IO.File]::ReadAllText($target)
$base = $code

function Apply-One([string]$pattern,[string]$replacement,[string]$label) {
  $regex = [System.Text.RegularExpressions.Regex]::new($pattern,[System.Text.RegularExpressions.RegexOptions]::Singleline)
  $matches = $regex.Matches($script:code)
  if ($matches.Count -ne 1) {
    throw "$label 수정 위치가 정확히 하나가 아닙니다($($matches.Count)개). 기존 파일은 수정하지 않았습니다."
  }
  $script:code = $regex.Replace($script:code,$replacement,1)
}

$import = "import 'package:stock/feature/bank/view/widget/basic_credit_loan_section.dart';"
if (-not $code.Contains($import)) {
  Apply-One "import 'package:stock/feature/bank/view/widget/deposit_secured_loan_section\.dart';" `
      "import 'package:stock/feature/bank/view/widget/deposit_secured_loan_section.dart';`n$import" 'import'
}

$detailsCondition = @'
final isCreditLoan = offer['product_code'] == 'LOAN_CREDIT_BASIC';
    final canApply = (isDepositLoan || isCreditLoan) &&
        offer['is_active'] == true;
'@
Apply-One "final canApply\s*=\s*isDepositLoan\s*&&\s*offer\['is_active'\]\s*==\s*true;" $detailsCondition '상품 상세 신청 조건'

Apply-One "showApplication\s*\?\s*'예금담보대출 신청·상환'" `
"showApplication`n                                    ? (isDepositLoan ? '예금담보대출 신청·상환' : '생활 신용대출 신청·상환')" '상세 팝업 제목'

$nested = @'
child: showApplication
    ? (isDepositLoan
        ? DepositSecuredLoanSection(
            onChanged: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                _load();
                widget.onChanged?.call();
              }
            },
          )
        : BasicCreditLoanSection(
            productId: offer['id'].toString(),
            onChanged: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                _load();
                widget.onChanged?.call();
              }
            },
          ))
    : Column(
'@
Apply-One 'child:\s*showApplication\s*\?\s*DepositSecuredLoanSection\(\s*onChanged:\s*\(\)\s*\{.*?\}\s*,\s*\)\s*:\s*Column\(' $nested '상세 팝업 신청 위젯'

$cardCondition = @'
final canApply = (type == 'deposit_secured' ||
        offer['product_code'] == 'LOAN_CREDIT_BASIC') &&
        offer['is_active'] == true;
'@
Apply-One "final canApply\s*=\s*type\s*==\s*'deposit_secured'\s*&&\s*offer\['is_active'\]\s*==\s*true;" $cardCondition '상품 카드 신청 상태'

if ($code -notmatch "case 'credit_cooldown':") {
  $extraStatuses = @'
case 'credit_cooldown':
        return '신용대출 재신청까지 30게임일 대기 필요';
      case 'existing_credit_loan':
        return '이용 중인 신용대출이 있습니다';
      case 'delinquent':
        return '연체 또는 부도 이력으로 신규 대출 제한';
      case 'income_not_verified':
'@
  Apply-One "case 'income_not_verified':" $extraStatuses '추가 가심사 상태 안내'
}

if ($code -eq $base) { throw '변경 내용이 없습니다. 이미 적용됐는지 확인해주세요.' }
$backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
[System.IO.File]::Copy($target,$backup)
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target,$code,$utf8)
if (-not (Test-Path $dest)) { [System.IO.File]::Copy($source,$dest) }
Write-Host '신용대출 화면 연결 완료' -ForegroundColor Green
Write-Host "기존 파일 백업: $backup"
Write-Host '다음: flutter analyze (작업 단위 완료 후 1회)'
