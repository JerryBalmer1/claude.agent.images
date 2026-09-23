#Requires -Version 7.4

<#
.SYNOPSIS
    Shared helpers for the claude.pwsh.image.builder build surface.

.DESCRIPTION
    Task bodies in build/tasks/*.build.ps1 orchestrate and render. The work
    lives here so it can be unit-tested on the host without Invoke-Build.

    Canonical JSON is the load-bearing piece: run-01's preflight gate hashes
    prompts/assessment.2026-09-21.json and refuses to proceed on a mismatch.
    "Canonical" means recursively key-sorted (ordinal) and whitespace-free, so
    the hash is a property of the *values*, not of how someone formatted them.
    This must agree byte-for-byte with Python's
    json.dumps(obj, sort_keys=True, separators=(',', ':')).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function ConvertTo-CanonicalObject {
    <#
    .SYNOPSIS
        Rebuild an object graph with every mapping's keys in ordinal order.

    .DESCRIPTION
        Ordinal, not culture-aware: Sort-Object would order keys by the current
        culture's collation, which is a different order on a different machine.
        A canonicalizer that depends on the locale is not a canonicalizer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) { return $null }

    # Strings are IEnumerable; check before the sequence branch or they become char arrays.
    if ($Value -is [string] -or $Value -is [bool] -or $Value.GetType().IsPrimitive -or
        $Value -is [decimal] -or $Value -is [datetime]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [Array]::Sort($keys, [System.StringComparer]::Ordinal)
        $sorted = [ordered]@{}
        foreach ($k in $keys) { $sorted[$k] = ConvertTo-CanonicalObject -Value $Value[$k] }
        return $sorted
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $keys = [string[]]@($Value.PSObject.Properties.Name)
        [Array]::Sort($keys, [System.StringComparer]::Ordinal)
        $sorted = [ordered]@{}
        foreach ($k in $keys) { $sorted[$k] = ConvertTo-CanonicalObject -Value $Value.$k }
        return $sorted
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        # Unary comma: a one-element result must stay an array through the return.
        $items = @(foreach ($item in $Value) { , (ConvertTo-CanonicalObject -Value $item) })
        return , $items
    }

    return $Value
}

function ConvertTo-CanonicalJson {
    <#
    .SYNOPSIS
        The exact bytes that get hashed. Key-sorted, compressed, no BOM.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        $InputObject
    )

    $canonical = ConvertTo-CanonicalObject -Value $InputObject
    return (ConvertTo-Json -InputObject $canonical -Compress -Depth 100)
}

function Get-StringSha256 {
    <#
    .SYNOPSIS
        Lowercase hex sha256 over a string's UTF-8 bytes.

    .DESCRIPTION
        Same convention as Ledger's Get-LedgerSha256Hex and Python's
        hashlib.sha256(s.encode('utf-8')).hexdigest().
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-CanonicalJsonSha256 {
    <#
    .SYNOPSIS
        Canonical sha256 of a JSON document on disk.

    .EXAMPLE
        Get-CanonicalJsonSha256 -Path ./prompts/assessment.2026-09-21.json
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Canonical hash requested for a file that does not exist: $Path"
    }

    Write-Verbose "[helpers] canonicalizing $Path"
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $obj = $raw | ConvertFrom-Json -Depth 100
    $canonical = ConvertTo-CanonicalJson -InputObject $obj
    Write-Debug "[helpers] canonical bytes: $canonical"
    return (Get-StringSha256 -Text $canonical)
}

function Test-AssessmentHash {
    <#
    .SYNOPSIS
        run-01 preflight gate. Throws on mismatch; returns the hash on success.

    .DESCRIPTION
        The gate exists because the run order carries the assessment inline and
        the repo carries it on disk. If those two ever disagree, every later
        step is being taken against a document nobody agreed to.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedSha256
    )

    $actual = Get-CanonicalJsonSha256 -Path $Path
    if ($actual -ne $ExpectedSha256) {
        throw ("Assessment hash mismatch for {0}`n  expected: {1}`n  actual:   {2}" -f $Path, $ExpectedSha256, $actual)
    }
    Write-Verbose "[helpers] assessment hash verified: $actual"
    return $actual
}

function Get-SkipJustification {
    <#
    .SYNOPSIS
        The stated reason a skipped test is allowed to be skipped, or $null for none.

    .DESCRIPTION
        Two forms, and both are read off the TEST OBJECT — its own tags, plus every
        parent block's — never out of a comment sitting beside the test. A comment is
        not a measurement: nothing reads it, so nothing goes red when it stops being
        true, which is the honour system this gate exists to replace.

            BLOCKER-n                 a skip waiting on a numbered blocker.
            SkipWhen:<kebab-reason>   a precondition that is legitimately unmet today.

        The second form exists because BLOCKER-n is the wrong token for the trailer
        falsification tests. Blockers are being retired, and "no exempt commit in range"
        is not a blocker — it is a state this repository is simply in on most days, and
        will drop back into whenever a grandfathered commit enters the range again. A
        blocker gets fixed and struck; this does not.

        It returns the REASON rather than a boolean so a gate can report WHY a test did
        not run, not merely that it did not. For BLOCKER-n the reason is the token
        itself; for SkipWhen it is the text after the colon, pulled from the pattern's
        own named group so the pattern and the extraction cannot drift apart.

        THE HOME FOR THIS IS DELIBERATE. build/tasks/Test.build.ps1 (host) and
        build/InContainer.Test.ps1 (container) are two independent implementations of
        the same gate, and they already differ on NotRun. Writing this rule a third and
        fourth time would guarantee they eventually disagree about what a justification
        even is. The container reaches this module at /work/build, which is bind-mounted;
        nothing here depends on Invoke-Build.

    .EXAMPLE
        Get-SkipJustification -Tag @('SkipWhen:no-exempt-commit-in-range')
        no-exempt-commit-in-range
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Tag,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BlockerPattern = '^BLOCKER-\d+$',

        # The 'reason' group is load-bearing: it is the string the gates print. A
        # replacement pattern that omits it falls back to the whole tag rather than
        # reporting an empty reason, which would read as a justification that justifies
        # nothing.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SkipWhenPattern = '^SkipWhen:(?<reason>[a-z0-9]+(-[a-z0-9]+)*)$'
    )

    $tags = @($Tag | Where-Object { $_ })

    # Blockers first: if a test carries both, the blocker is the more serious claim and
    # is the one worth surfacing.
    foreach ($t in $tags) {
        if ($t -cmatch $BlockerPattern) { return $t }
    }

    foreach ($t in $tags) {
        $m = [regex]::Match($t, $SkipWhenPattern)
        if ($m.Success) {
            $reason = $m.Groups['reason'].Value
            if ($reason) { return $reason }
            return $t
        }
    }

    return $null
}

Export-ModuleMember -Function 'ConvertTo-CanonicalObject', 'ConvertTo-CanonicalJson',
    'Get-StringSha256', 'Get-CanonicalJsonSha256', 'Test-AssessmentHash',
    'Get-SkipJustification'
