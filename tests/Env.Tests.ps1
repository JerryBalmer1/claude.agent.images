#Requires -Version 7.4
<#
    Tests for the credential path: .gitignore, .env.example, scripts/env.ps1, and the
    tree itself.

    NOTE ON FAKE TOKENS. This file must never contain a literal that the repo's own
    secret guard would match, or the guard fails on the file that proves it works.
    Every fake is assembled at runtime from fragments. Do not "tidy" them into one
    string literal — that is what would break it.

    NOTE ON GIT EXIT CODES. `git grep` and `git check-ignore` both exit 1 to mean
    "no match", which is the *passing* case here. The runner sets
    $PSNativeCommandUseErrorActionPreference, which turns that into a thrown
    exception, so a clean tree would fail the secret scan. Invoke-Git below suppresses
    it for the duration of the call and hands back the exit code as data. Caught by
    the fail-first run, which is what fail-first is for.
#>

BeforeAll {
    # Resolved from this file's location, not from `git rev-parse --show-toplevel` plus a check
    # that the path ends in the repository's name. That guard came from the develop lineage and
    # cannot hold in the container, where the repository is bind-mounted at /work: it threw
    # 'NOT IN IMAGE BUILDER' out of BeforeAll and took all 25 tests in this file down with it.
    # Get-RepoRoot exists for exactly this and says so in its own docstring - "whether that is
    # C:\... on the host or /work in the container".
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    $script:Loader = Join-Path $script:RepoRoot 'scripts/env.ps1'
    $script:Example = Join-Path $script:RepoRoot '.env.example'

    # Assembled, never written as one literal. See the note at the top of this file.
    $script:FakeToken = 'ghp' + '_' + 'planted' + '0123456789abcdef0123'
    $script:FakeMarker = 'planted'

    # The patterns the CI guard uses. Writing them here is safe: as text, none of them
    # matches itself — "ghp_[A-Za-z..." has a bracket where the guard wants alphanumerics.
    $script:SecretPatterns = @(
        'ghp_[A-Za-z0-9]{20,}'
        'github_pat_[A-Za-z0-9_]{20,}'
        '-----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----'
    )

    # Runs git in the repo and returns the exit code as data instead of throwing.
    # Preference variables are dynamically scoped, so the assignment here covers the call.
    #
    # Arguments go in as one array, never as loose positional words. A loose "-e"
    # is bound by PowerShell as an ambiguous abbreviation of -ErrorAction and never
    # reaches git. Found by this helper eating the grep pattern.
    function Invoke-Git {
        param([string[]] $Arg)
        $PSNativeCommandUseErrorActionPreference = $false
        $ErrorActionPreference = 'Continue'
        Push-Location $script:RepoRoot
        try {
            $out = & git @Arg 2>&1
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($out | Out-String) }
        }
        finally { Pop-Location }
    }

    function New-TempEnvFile {
        param([string[]] $Line)
        $p = Join-Path ([System.IO.Path]::GetTempPath()) ("env-test-{0}.local" -f [guid]::NewGuid())
        Set-Content -LiteralPath $p -Value $Line -Encoding utf8
        $p
    }
}

Describe '.gitignore keeps credentials out of the tree' {

    It '.env.local is ignored' {
        (Invoke-Git -Arg @('check-ignore','-q','.env.local')).ExitCode |
            Should -Be 0 -Because '.env.local holds the real token and must never be committable'
    }

    # The title must NOT read '.env.<name>.local'. Pester treats <word> in a test title as a
    # data-driven template placeholder and expands it from the -ForEach data; with no -ForEach
    # there is no $name, and under Set-StrictMode the expansion throws
    # "The variable '$name' cannot be retrieved because it has not been set" before the body
    # ever runs. The assertion below was never the problem and has always held.
    It '.env.ANYNAME.local is ignored' {
        (Invoke-Git -Arg @('check-ignore','-q','.env.production.local')).ExitCode | Should -Be 0
    }

    It 'terraform state and tfvars are ignored' {
        foreach ($f in 'secrets.tfvars', 'terraform.tfstate', 'terraform.tfstate.backup') {
            (Invoke-Git -Arg @('check-ignore','-q',$f)).ExitCode |
                Should -Be 0 -Because "$f can carry a credential in plain text"
        }
    }

    It 'private keys are ignored' {
        foreach ($f in 'deploy.pem', 'id_ed25519') {
            (Invoke-Git -Arg @('check-ignore','-q',$f)).ExitCode | Should -Be 0
        }
    }

    It 'keeps the pre-existing report rule' {
        (Invoke-Git -Arg @('check-ignore','-q','docs/plans/anything-report.md')).ExitCode |
            Should -Be 0 -Because 'this plan appends to .gitignore, it does not rewrite it'
    }

    It 'does not ignore .env.example' {
        (Invoke-Git -Arg @('check-ignore','-q','.env.example')).ExitCode |
            Should -Be 1 -Because '.env.example is the committed documentation; ignoring it would hide the contract'
    }
}

Describe '.env.example documents without leaking' {

    It 'exists' {
        Test-Path -LiteralPath $script:Example | Should -BeTrue
    }

    It 'names every variable the loader requires by default' {
        $required = & $script:Loader -ListRequired
        $required | Should -Not -BeNullOrEmpty -Because 'the loader must publish its own contract'

        $names = Get-Content -LiteralPath $script:Example |
            ForEach-Object { if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=') { $Matches[1] } }

        foreach ($r in $required) {
            $names | Should -Contain $r -Because "$r is required but undocumented in .env.example"
        }
    }

    It 'carries no token-shaped value' {
        $text = Get-Content -LiteralPath $script:Example -Raw
        foreach ($pattern in $script:SecretPatterns) {
            $text | Should -Not -Match $pattern -Because '.env.example is committed; only .env.local holds real values'
        }
    }

    It 'comments every variable it declares' {
        $lines = Get-Content -LiteralPath $script:Example
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=') {
                $name = $Matches[1]
                $above = if ($i -gt 0) { $lines[$i - 1] } else { '' }
                $above | Should -Match '^\s*#' -Because "$name needs a comment saying what it is and who reads it"
            }
        }
    }
}

Describe 'scripts/env.ps1 loads without leaking' {

    AfterEach {
        foreach ($n in 'TEST_ALPHA', 'TEST_BETA', 'TEST_QUOTED', 'TEST_TILDE', 'TEST_CHECK_ONLY', 'GITHUB_TOKEN_TEST') {
            if (Test-Path "env:$n") { Remove-Item "env:$n" }
        }
    }

    It 'exists and parses' {
        Test-Path -LiteralPath $script:Loader | Should -BeTrue
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script:Loader, [ref]$null, [ref]$errs)
        $errs | Should -BeNullOrEmpty
    }

    It 'sets variables, skipping blanks and comments' {
        $f = New-TempEnvFile @(
            '# a comment line'
            ''
            'TEST_ALPHA=one'
            '   '
            '# TEST_BETA=not-this'
            'TEST_BETA=two'
        )
        try {
            & $script:Loader -Path $f | Out-Null
            $env:TEST_ALPHA | Should -Be 'one'
            $env:TEST_BETA | Should -Be 'two' -Because 'a commented-out duplicate must not win'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It 'strips matching quotes' {
        $f = New-TempEnvFile @('TEST_QUOTED="quoted value"')
        try {
            & $script:Loader -Path $f | Out-Null
            $env:TEST_QUOTED | Should -Be 'quoted value'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It 'expands a leading tilde' {
        $f = New-TempEnvFile @('TEST_TILDE=~/.ssh/claude.build')
        try {
            & $script:Loader -Path $f | Out-Null
            $env:TEST_TILDE | Should -Not -Match '^~' -Because 'a literal ~ is not a path any tool can open'
            $env:TEST_TILDE | Should -BeLike "$HOME*"
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It 'never prints a value' {
        $f = New-TempEnvFile @("GITHUB_TOKEN_TEST=$($script:FakeToken)")
        try {
            $out = & $script:Loader -Path $f *>&1 | Out-String
            $out | Should -Not -Match $script:FakeMarker -Because 'the loader reports names and lengths, never values'
            $out | Should -Match 'GITHUB_TOKEN_TEST' -Because 'it must still say the variable was seen'
            $out | Should -Match 'len\s*\d+' -Because 'length is how you tell a pasted token from a truncated one'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It 'reports an empty variable as EMPTY' {
        $f = New-TempEnvFile @('TEST_ALPHA=')
        try {
            $out = & $script:Loader -Path $f *>&1 | Out-String
            $out | Should -Match 'EMPTY'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Require throws naming the missing variable' {
        $f = New-TempEnvFile @('TEST_ALPHA=one')
        try {
            { & $script:Loader -Path $f -Require 'TEST_ALPHA', 'TEST_MISSING_VAR' } |
                Should -Throw -ExpectedMessage '*TEST_MISSING_VAR*'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Require passes when everything it names is present' {
        $f = New-TempEnvFile @('TEST_ALPHA=one', 'TEST_BETA=two')
        try {
            { & $script:Loader -Path $f -Require 'TEST_ALPHA', 'TEST_BETA' } | Should -Not -Throw
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Require treats an empty value as missing' {
        $f = New-TempEnvFile @('TEST_ALPHA=')
        try {
            { & $script:Loader -Path $f -Require 'TEST_ALPHA' } | Should -Throw -ExpectedMessage '*TEST_ALPHA*'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Require does not leak the value of a variable that is present' {
        $f = New-TempEnvFile @("GITHUB_TOKEN_TEST=$($script:FakeToken)")
        try {
            $err = $null
            try { & $script:Loader -Path $f -Require 'GITHUB_TOKEN_TEST', 'TEST_MISSING_VAR' }
            catch { $err = $_ | Out-String }
            $err | Should -Not -BeNullOrEmpty
            $err | Should -Not -Match $script:FakeMarker -Because 'an error message is the easiest place to leak a token'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Check sets nothing' {
        $f = New-TempEnvFile @('TEST_CHECK_ONLY=value')
        try {
            $env:TEST_CHECK_ONLY | Should -BeNullOrEmpty
            $out = & $script:Loader -Path $f -Check *>&1 | Out-String
            $env:TEST_CHECK_ONLY | Should -BeNullOrEmpty -Because '-Check reports, it does not load'
            $out | Should -Match 'TEST_CHECK_ONLY'
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It '-Check still refuses to print a value' {
        $f = New-TempEnvFile @("GITHUB_TOKEN_TEST=$($script:FakeToken)")
        try {
            $out = & $script:Loader -Path $f -Check *>&1 | Out-String
            $out | Should -Not -Match $script:FakeMarker
        }
        finally { Remove-Item -LiteralPath $f -Force }
    }
}

Describe 'the tracked tree carries no secret' {

    It 'git grep finds no token pattern in any tracked file' {
        foreach ($pattern in $script:SecretPatterns) {
            # -e is mandatory, not style. The private-key pattern starts with "-----",
            # which git reads as options: without -e it exits 129 (usage error) and the
            # scan silently never runs. Found by this test going red.
            $r = Invoke-Git -Arg @('grep','-nE','-e',$pattern,'--','.')
            $r.ExitCode | Should -Not -Be 129 -Because 'exit 129 is a git usage error, not a clean scan'
            $r.ExitCode | Should -Be 1 -Because "a tracked file matches $pattern`n$($r.Output)"
        }
    }

    It 'the guard would catch a planted token' -Tag 'PlantedTwin' {
        # Proves the scan can go red. Done in a throwaway clone so the real tree is
        # never mutated — a probe that edits the repo in place leaves it broken the
        # first time it throws.
        $clone = Join-Path ([System.IO.Path]::GetTempPath()) ("env-twin-{0}" -f [guid]::NewGuid())
        try {
            $PSNativeCommandUseErrorActionPreference = $false
            git clone --quiet --no-hardlinks --depth 1 $script:RepoRoot $clone 2>&1 | Out-Null
            Set-Content -LiteralPath (Join-Path $clone 'planted.txt') -Value "TOKEN=$($script:FakeToken)" -Encoding utf8
            Push-Location $clone
            try {
                git add planted.txt 2>&1 | Out-Null
                $null = git grep -nE 'ghp_[A-Za-z0-9]{20,}' -- .
                $LASTEXITCODE | Should -Be 0 -Because 'the scan must FIND a planted token, or it is decoration'
            }
            finally { Pop-Location }
        }
        finally {
            if (Test-Path -LiteralPath $clone) { Remove-Item -LiteralPath $clone -Recurse -Force }
        }
    }
}
