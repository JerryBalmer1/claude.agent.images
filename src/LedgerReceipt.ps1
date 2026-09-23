#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Thin receipt rail for the leash hook. Does not replace the snake.
# Prefers Get-LedgerVerify from vendor/claude.build.ledger when loaded.
# Fallback is a prev/self SHA-256 JSONL at /ledger/sentinel.jsonl.

function Get-ReceiptSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Get-SentinelLedgerPath {
    $dir = if ($env:LEDGER_DIR) { $env:LEDGER_DIR } else { '/ledger' }
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return (Join-Path $dir 'sentinel.jsonl')
}

function Get-SentinelPrevHash {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '0' * 64 }
    $last = Get-Content -LiteralPath $Path -Tail 1 -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($last)) { return '0' * 64 }
    try {
        $obj = $last | ConvertFrom-Json
        if ($obj.self) { return [string]$obj.self }
    }
    catch { }
    return Get-ReceiptSha256 $last
}

function Add-SentinelReceipt {
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][string]$Decision,
        [string]$Raw = '',
        [string]$Reason = ''
    )
    $path = Get-SentinelLedgerPath
    $prev = Get-SentinelPrevHash -Path $path
    $record = [ordered]@{
        ts        = (Get-Date).ToString('o')
        principal = if ($env:LEDGER_PRINCIPAL) { $env:LEDGER_PRINCIPAL } else { 'unset' }
        tool      = $Tool
        decision  = $Decision
        reason    = $Reason
        armed     = $env:LEDGER_HOOK_ARM
        prev      = $prev
    }
    $canonical = ($record | ConvertTo-Json -Compress)
    $self = Get-ReceiptSha256 ($prev + $canonical)
    $record.self = $self
    $line = ($record | ConvertTo-Json -Compress)
    Add-Content -LiteralPath $path -Value $line -Encoding utf8
    return $record
}

function Test-SentinelChain {
    param([string]$Path = (Get-SentinelLedgerPath))
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Ok = $true; Count = 0; Path = $Path; Mode = 'empty' }
    }
    $lines = @(Get-Content -LiteralPath $Path)
    $expectedPrev = '0' * 64
    $i = 0
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $i++
        $obj = $line | ConvertFrom-Json
        if (-not $obj.prev -or -not $obj.self) {
            throw "Ledger chain break at line $i : missing prev/self"
        }
        if ([string]$obj.prev -ne $expectedPrev) {
            throw "Ledger chain break at line $i : prev mismatch"
        }
        $clone = [ordered]@{
            ts        = $obj.ts
            principal = $obj.principal
            tool      = $obj.tool
            decision  = $obj.decision
            reason    = $obj.reason
            armed     = $obj.armed
            prev      = $obj.prev
        }
        $canonical = ($clone | ConvertTo-Json -Compress)
        $recomputed = Get-ReceiptSha256 ($obj.prev + $canonical)
        if ([string]$obj.self -ne $recomputed) {
            throw "Ledger chain break at line $i : self hash mismatch"
        }
        $expectedPrev = [string]$obj.self
    }
    return [pscustomobject]@{ Ok = $true; Count = $i; Path = $Path; Tip = $expectedPrev; Mode = 'sentinel-jsonl' }
}

function Invoke-LedgerBootVerify {
    $snake = @(
        '/opt/leash/ledger/Ledger.psd1'
        '/opt/leash/vendor/claude.build.ledger/src/ledger/Ledger.psd1'
        (Join-Path $PSScriptRoot '..' 'vendor' 'claude.build.ledger' 'src' 'ledger' 'Ledger.psd1')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if ($snake) {
        Import-Module $snake -Force -ErrorAction Stop
        $path = Join-Path (if ($env:LEDGER_DIR) { $env:LEDGER_DIR } else { '/ledger' }) 'ledger.jsonl'
        if (Test-Path -LiteralPath $path) {
            $v = Get-LedgerVerify -LedgerPath $path
            if ($v -and ($v.PSObject.Properties.Name -contains 'Ok') -and -not $v.Ok) {
                throw "Get-LedgerVerify rejected $path"
            }
            return $v
        }
    }

    return Test-SentinelChain
}
