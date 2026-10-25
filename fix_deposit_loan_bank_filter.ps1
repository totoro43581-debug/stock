$ErrorActionPreference = 'Stop'
$target = Join-Path (Get-Location) 'lib\feature\bank\view\widget\deposit_secured_loan_section.dart'
if (-not (Test-Path -LiteralPath $target)) {
    throw "Could not find the Dart file. Run this script from F:\stock. Target: $target"
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$code = [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8)
$originalCRLF = $code.Contains("`r`n")
$code = $code.Replace("`r`n","`n")
$old1 = "'id,product_name,annual_rate,min_amount,'"
$new1 = "'id,bank_id,product_name,annual_rate,min_amount,'"
$old2 = "'id,product_name_snapshot,principal_amount,maturity_at'"
$new2 = "'id,product_name_snapshot,principal_amount,maturity_at,bank_products!inner(bank_id)'"
$old3 = @'
      final fetchedDeposits =
      List<Map<String, dynamic>>.from(results[1] as List);
'@
$new3 = @'
      final loanBankId = products.isEmpty
          ? null
          : products.first['bank_id']?.toString();

      final fetchedDeposits =
          List<Map<String, dynamic>>.from(results[1] as List)
              .where((item) {
                final linkedProduct = item['bank_products'];
                return loanBankId != null &&
                    linkedProduct is Map &&
                    linkedProduct['bank_id']?.toString() == loanBankId;
              }).toList();
'@
$old3 = $old3.Replace("`r`n", "`n")
$new3 = $new3.Replace("`r`n", "`n")
$old4 = "'담보로 사용할 활성 예금이 없습니다.'"
$new4 = "'해당 은행에 담보로 사용할 활성 예금이 없습니다.'"

if ($code.Contains($new3)) {
    Write-Host 'Already patched. No files changed.' -ForegroundColor Green
    exit 0
}
foreach ($text in @($old1, $old2, $old3, $old4)) {
    if (-not $code.Contains($text)) {
        throw "Source code is different from the GitHub version. No files were changed. Missing: $text"
    }
    if ($code.Split([string[]]@($text),[System.StringSplitOptions]::None).Count -ne 2) {
        throw "Expected exactly one match. No files were changed. Search for: $text"
    }
}

$changed = $code.Replace($old1,$new1).Replace($old2,$new2).Replace($old3,$new3).Replace($old4,$new4)
if ($changed -eq $code -or (-not $changed.Contains($new3))) {
    throw 'Safety check failed. No files were changed.'
}

$backup = "$target.before_bank_filter_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
Copy-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
if ($originalCRLF) { $changed = $changed.Replace("`n", "`r`n") }
[System.IO.File]::WriteAllText($target,$changed,$utf8)
Write-Host 'SUCCESS: Same-bank collateral filter installed.' -ForegroundColor Green
Write-Host "Changed: $target"
Write-Host "Backup: $backup"
Write-Host 'Restart Flutter or hot-restart, then open Hanbit deposit secured loan again.'
