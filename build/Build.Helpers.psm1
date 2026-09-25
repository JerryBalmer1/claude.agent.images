#Requires -Version 7.4

<#
.SYNOPSIS
    Shared helpers for the claude.agent.images build surface.

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

function Assert-SuiteClean {
    <#
    .SYNOPSIS
        Fail on any failed test, and on any skip that does not state its reason
        on the test object. Report the skips that do.

    .DESCRIPTION
        IT LIVES HERE SO MORE THAN ONE CALLER CAN REACH IT. It used to be a function
        inside build/tasks/Test.build.ps1, where it called Write-Build - an Invoke-Build
        command - so no plain pwsh script could call it. scripts/ci/Invoke-Tests.ps1, the
        `pester` required check, therefore had no skip gate at all: it exited 1 only on a
        failed test or an empty suite, and an unjustified skip went green in CI while the
        same tree failed Invoke-Build Test.Unit. A required check that passes what the
        build fails is not a floor.

        Nothing in this module depends on Invoke-Build, which is the same property that
        lets the container import it off the /work bind mount. Write-Host, not Write-Build,
        for exactly that reason.

    .PARAMETER ExcludeTag
        The tag filter THIS RUN CARRIED, or nothing if it carried none.

        Pester reports a test excluded by -ExcludeTag as NotRun, which is not a skip: it
        was never part of the run. Passing the filter in is what lets one implementation
        serve a run that excludes tags and a run that does not, instead of two that differ
        by accident - which is how the host and container gates came to disagree on NotRun
        in the first place. build/InContainer.Test.ps1 applies the same rule inline.

        Test.Unit passes nothing here because it excludes nothing, so every NotRun it sees
        really is unexplained and stays unjustified. Inconclusive gets no tag escape in
        either case: it means an assertion gave up part-way through, which is not a
        precondition anyone declared in advance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$Where,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$ExcludeTag
    )

    $excluded = @($ExcludeTag | Where-Object { $_ })

    # First, because a file that did not load has no tests in any count below: FailedCount,
    # the skip verdicts and PassedCount all read as if the file did not exist.
    $notLoaded = @(Get-SuiteLoadFailure -Result $Result)
    if ($notLoaded.Count -gt 0) {
        throw ("${Where}: $($notLoaded.Count) test file(s) failed to load; their tests did not run:`n  " +
            (@($notLoaded | ForEach-Object { "$($_.File)`n    $($_.Error)" }) -join "`n  "))
    }

    if ($Result.FailedCount -gt 0) {
        $names = @($Result.Tests | Where-Object Result -eq 'Failed' | ForEach-Object { $_.ExpandedPath })
        # ${Where} and not $Where: a colon straight after a variable name makes
        # PowerShell read it as a scope qualifier, the way $script: does, and
        # the file will not even parse.
        throw ("${Where}: $($Result.FailedCount) test(s) failed:`n  " + ($names -join "`n  "))
    }

    # The RULE for what counts as a justification is Get-SkipJustification, above. What
    # counts as needing one is decided here.
    $verdicts = @(
        $Result.Tests | ForEach-Object {
            if ($_.Result -notin @('Skipped', 'Inconclusive', 'NotRun')) { return }

            $tags = @($_.Tag)
            $block = $_.Block
            while ($block) { $tags += @($block.Tag); $block = $block.Parent }
            $tags = @($tags | Where-Object { $_ })

            # A test the filter excluded did not skip. It belongs in neither list.
            if ($_.Result -eq 'NotRun' -and @($tags | Where-Object { $excluded -contains $_ }).Count -gt 0) { return }

            $reason = if ($_.Result -eq 'Skipped') { Get-SkipJustification -Tag $tags } else { $null }

            [pscustomobject]@{
                Test   = $_.ExpandedPath
                Result = [string]$_.Result
                Reason = $reason
            }
        }
    )

    $unjustified = @($verdicts | Where-Object { -not $_.Reason })
    $justified   = @($verdicts | Where-Object { $_.Reason })

    # WHY, not just how many. A green log that says "skipped: 2" tells a reader
    # nothing they can act on; grouped by reason, it tells them what precondition
    # was unmet and therefore what would have to change for those tests to run.
    foreach ($group in ($justified | Group-Object -Property Reason | Sort-Object -Property Name)) {
        Write-Host ("${Where}: skipped - $($group.Name):") -ForegroundColor Yellow
        foreach ($t in $group.Group) { Write-Host "    $($t.Test)" -ForegroundColor DarkGray }
    }

    if ($unjustified.Count -gt 0) {
        throw ("${Where}: no justification tag (BLOCKER-n or SkipWhen:<reason>) on:`n  " +
            (@($unjustified | ForEach-Object { "$($_.Result.ToLowerInvariant()) - $($_.Test)" }) -join "`n  "))
    }

    if ($Result.PassedCount -eq 0) {
        throw "${Where}: no tests ran; that is a failure, not a pass"
    }
}

function Get-SuiteLoadFailure {
    <#
    .SYNOPSIS
        One object per test file that failed to load, with the file and the error.

    .DESCRIPTION
        A file that fails to parse, or throws while Pester discovers it, is a FAILED CONTAINER.
        Pester counts it in FailedContainersCount and leaves FailedCount at 0, and its tests
        appear in no count at all. Until 2026-09-24 every gate in this repository read only
        FailedCount - tests/run.ps1, Assert-SuiteClean, build/InContainer.Test.ps1 - so such a
        file was green by omission. Measured at 1f0c6d2: a file with a syntax error, runner
        exit 0. tests/RunnerTraps.Tests.ps1 holds each gate to this.

        Every caller asks this one function, so the gates cannot disagree about what "did not
        load" means.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Result)

    if (-not ($Result.PSObject.Properties.Name -contains 'FailedContainersCount')) { return }
    if ($Result.FailedContainersCount -le 0) { return }

    foreach ($c in @($Result.FailedContainers)) {
        [pscustomobject]@{
            File  = [string]$c.Item
            Error = (@($c.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join ' | ')
        }
    }
}

function Get-ImageCopySource {
    <#
    .SYNOPSIS
        The context-relative sources of every COPY line in a Dockerfile, in order.

    .DESCRIPTION
        Only the forms these Dockerfiles use: COPY [--flag ...] <src>... <dest> on one line. A
        COPY --from reads another stage, not the context, so it has no source here. A wildcard,
        or a COPY continued onto the next line, throws rather than being hashed wrongly: an input
        missed here is a stale image served from cache.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Dockerfile)

    foreach ($line in [System.IO.File]::ReadAllLines($Dockerfile)) {
        if ($line -notmatch '^\s*COPY\s+(.+)$') { continue }
        $rest = $Matches[1].Trim()
        if ($rest.EndsWith('\')) { throw "${Dockerfile}: a COPY continued onto the next line is not supported: $line" }
        if ($rest -match '--from=') { continue }
        $tokens = @($rest -split '\s+' | Where-Object { $_ -notlike '--*' })
        if ($tokens.Count -lt 2) { throw "${Dockerfile}: COPY with no source: $line" }
        foreach ($src in $tokens[0..($tokens.Count - 2)]) {
            if ($src -match '[\*\?\[]') { throw "${Dockerfile}: a wildcard COPY source is not supported: $src" }
            $src
        }
    }
}

function Get-ImageInputHash {
    <#
    .SYNOPSIS
        sha256 over everything an image build reads: the Dockerfile, .dockerignore, and every file
        under every COPY source, by context-relative path and content.

    .DESCRIPTION
        The key for reusing an image instead of rebuilding it (Invoke-ImageBuild) and for the CI
        image cache (scripts/ci/Invoke-ImageCache.ps1). It is the INPUTS, not the Dockerfile
        alone: keyed on the Dockerfile, a change to hooks/ would be served a stale image. Bytes
        are hashed as they are, because COPY copies them as they are.

        What it does not see: what the network returns at build time. The Dockerfile pins the base
        by digest and pwsh by sha256, but apt package versions and CLAUDE_CODE_VERSION=latest
        are resolved when the image is built, so a reused image keeps what they were then.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ContextRoot,
        [Parameter(Mandatory)][string]$Dockerfile
    )

    $root = (Resolve-Path -LiteralPath $ContextRoot).ProviderPath
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $entries = [System.Collections.Generic.List[string]]::new()
    $fileHash = { param($p) [Convert]::ToHexString($sha.ComputeHash([System.IO.File]::ReadAllBytes($p))).ToLowerInvariant() }

    $entries.Add("dockerfile $(& $fileHash $Dockerfile)")
    $ignore = Join-Path $root '.dockerignore'
    if (Test-Path -LiteralPath $ignore) { $entries.Add(".dockerignore $(& $fileHash $ignore)") }

    foreach ($src in @(Get-ImageCopySource -Dockerfile $Dockerfile)) {
        $path = Join-Path $root $src
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $entries.Add("copy $src $(& $fileHash $path)")
        }
        elseif (Test-Path -LiteralPath $path -PathType Container) {
            $files = @(Get-ChildItem -LiteralPath $path -Recurse -File -Force |
                ForEach-Object { [pscustomobject]@{ Rel = [System.IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/'); Full = $_.FullName } } |
                Sort-Object -Property Rel -Culture ([cultureinfo]::InvariantCulture) -CaseSensitive)
            $entries.Add("copy $src $($files.Count) file(s)")
            foreach ($f in $files) { $entries.Add("  $($f.Rel) $(& $fileHash $f.Full)") }
        }
        else {
            throw "COPY source '$src' in $Dockerfile does not exist under $root"
        }
    }

    $sha.Dispose()
    Get-StringSha256 -Text ($entries -join "`n")
}

function New-ImageContext {
    <#
    .SYNOPSIS
        A build context made from git's objects: HEAD's tree, and each submodule at the commit
        HEAD's gitlink names. Returns the path of a new directory; Remove-ImageContext removes it.

    .DESCRIPTION
        F97: the working tree is not a build input. Built from the repository root, the images
        took whatever sat on disk, and two untracked __pycache__/*.pyc files in the vendored
        Ledger changed one commit's input hash on one machine and, likely, shipped. An archive of
        HEAD cannot see an untracked, ignored or unstaged file, so neither the hash nor COPY can.

        git archive does not descend into submodules, so each gitlink in HEAD's tree is archived
        from its own repository at the commit HEAD records, under its own path. A submodule that
        is not checked out is a refusal, not a context with a hole in it.

        core.autocrlf=false: git archive applies checkout's conversions, so without it a Windows
        clone exports CRLF where CI exports LF (I14-F2). The eol attributes in .gitattributes still
        apply, and they apply the same way on every machine.

        Extraction is System.Formats.Tar, not tar: bsdtar and GNU tar read `C:\...` differently.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [string]$Revision = 'HEAD'
    )

    $root = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath
    $dest = Join-Path ([System.IO.Path]::GetTempPath()) ('leash-ctx-' + [guid]::NewGuid().ToString('n').Substring(0, 12))
    $tar = "$dest.tar"
    $conv = @('-c', 'core.autocrlf=false', '-c', 'core.eol=lf')
    $null = New-Item -ItemType Directory -Path $dest
    try {
        & git -C $root @conv archive --format=tar -o $tar $Revision
        [System.Formats.Tar.TarFile]::ExtractToDirectory($tar, $dest, $false)

        foreach ($line in @(& git -C $root ls-tree -r $Revision)) {
            if ($line -notmatch '^160000 commit ([0-9a-f]{40})\t(.+)$') { continue }
            $sha, $path = $Matches[1], $Matches[2]
            $sub = Join-Path $root $path
            $top = if (Test-Path -LiteralPath (Join-Path $sub '.git')) { (& git -C $sub rev-parse --show-toplevel).Trim() }
            if (-not $top -or [System.IO.Path]::GetFullPath($top) -ne [System.IO.Path]::GetFullPath($sub)) {
                throw "submodule $path is not checked out; run git submodule update --init"
            }
            & git -C $sub @conv archive --format=tar --prefix="$path/" -o $tar $sha
            [System.Formats.Tar.TarFile]::ExtractToDirectory($tar, $dest, $true)
        }
    }
    catch {
        Remove-ImageContext -Path $dest
        throw
    }
    finally {
        Remove-Item -LiteralPath $tar -Force -ErrorAction SilentlyContinue
    }
    $dest
}

function Remove-ImageContext {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) { [System.IO.Directory]::Delete($Path, $true) }
}

function Invoke-ImageBuild {
    <#
    .SYNOPSIS
        Build an image, or reuse the one already tagged if it was built from the same inputs.

    .DESCRIPTION
        The image is labelled org.leash.inputs=<Get-ImageInputHash>. If the tag already carries
        that label, nothing is built: the image was made from exactly these inputs. CI loads the
        images job's saved images before its tests, so on a cache hit neither the Docker-tagged
        tests nor Test.InContainer run apt. Any input change changes the hash, and the image is
        rebuilt.

        Returns Tag, Hash, Reused, ExitCode and Output. It does not throw on a failed build: the
        Build.Image tasks throw, and tests/Image.Tests.ps1 asserts on the exit code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ContextRoot,
        [Parameter(Mandatory)][string]$Dockerfile,
        [Parameter(Mandatory)][string]$Tag,
        [switch]$Quiet,
        # Cold: never reuse the tagged image, use no layer cache, and re-pull the base.
        [switch]$NoCache
    )

    $PSNativeCommandUseErrorActionPreference = $false
    $ErrorActionPreference = 'Continue'

    $hash = Get-ImageInputHash -ContextRoot $ContextRoot -Dockerfile $Dockerfile
    if (-not $NoCache) {
        $have = (& docker image inspect --format '{{ index .Config.Labels "org.leash.inputs" }}' $Tag 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $have -eq $hash) {
            Write-Host "image: $Tag is current (inputs $($hash.Substring(0, 12))), not rebuilt"
            return [pscustomobject]@{ Tag = $Tag; Hash = $hash; Reused = $true; ExitCode = 0; Output = '' }
        }
    }

    $coldArgs = if ($NoCache) { @('--no-cache', '--pull') } else { @() }
    Write-Host "image: building $Tag (inputs $($hash.Substring(0, 12)))$(if ($NoCache) { ', cold' })"
    $lines = [System.Collections.Generic.List[string]]::new()
    & docker build @coldArgs --label "org.leash.inputs=$hash" -f $Dockerfile -t $Tag $ContextRoot 2>&1 | ForEach-Object {
        $l = "$_"
        $lines.Add($l)
        if (-not $Quiet) { Write-Host $l }
    }
    [pscustomobject]@{ Tag = $Tag; Hash = $hash; Reused = $false; ExitCode = $LASTEXITCODE; Output = ($lines -join "`n") }
}

Export-ModuleMember -Function 'ConvertTo-CanonicalObject', 'ConvertTo-CanonicalJson',
    'Get-StringSha256', 'Get-CanonicalJsonSha256', 'Test-AssessmentHash',
    'Get-SkipJustification', 'Assert-SuiteClean', 'Get-SuiteLoadFailure',
    'Get-ImageCopySource', 'Get-ImageInputHash', 'New-ImageContext', 'Remove-ImageContext',
    'Invoke-ImageBuild'
