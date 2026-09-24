#Requires -Version 7.4

<#
    CI builds the images once per run, from a cache keyed by the images' inputs, and apt retries.

    Since I12 PR 4 the `pester` check builds both images itself (the Docker-tagged tests), and
    `incontainer` builds them again. Every build runs apt-get against archive.ubuntu.com, and one
    run failed on DNS for it. Three changes, each held here:

      1. Both Dockerfiles wrap apt in a bounded retry: five attempts, growing sleeps, then a
         hard failure. `apt-get update --error-on=any`, because a plain update exits 0 when it
         cannot resolve the mirror and the failure only surfaces at install. Measured in the
         pinned base with --network none: five attempts, 96s, exit 1.
      2. Get-ImageInputHash hashes a Dockerfile, .dockerignore and every file its COPY lines
         read. Invoke-ImageBuild labels the image with it and skips the build when an image with
         that label already exists. The key is the images' INPUTS, not the Dockerfile alone: a
         cache keyed on the Dockerfile would serve a stale image after a change to hooks/.
      3. ci.yml: one `images` job builds on a cache miss and saves; `pester` and `incontainer`
         need it and load the saved images, so no job after it runs apt.

    No docker here. The Docker-tagged half (label present, second build reused) is in
    tests/Image.Tests.ps1.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot = Get-RepoRoot
    Import-Module (Join-Path $script:RepoRoot 'build' 'Build.Helpers.psm1') -Force
    $script:CiYaml = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.github' 'workflows' 'ci.yml') -Raw

    # One job's block of ci.yml: from its key to the next job key.
    function Get-JobBlock([string]$Name) {
        $m = [regex]::Match($script:CiYaml, "(?ms)^  $([regex]::Escape($Name)):\s*\r?\n(.*?)(?=^  [A-Za-z0-9][A-Za-z0-9_-]*:\s*\r?\n|\z)")
        if (-not $m.Success) { return $null }
        $m.Groups[1].Value
    }
}

Describe 'apt retries with a bounded backoff' {
    It '<File> wraps apt in five attempts, with growing sleeps, then fails' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $File) -Raw
        $text | Should -Not -Match 'RUN apt-get update &&' -Because 'a bare apt layer fails the build on one DNS miss'
        $text | Should -Match 'for attempt in 1 2 3 4 5; do'
        $text | Should -Match 'apt-get -o Acquire::Retries=3 update --error-on=any'
        $text | Should -Match 'sleep \$\(\(attempt \* attempt \* 2\)\)'
        $text | Should -Match 'if \[ "\$attempt" -eq 5 \]; then .* exit 1; fi'
    }
}

Describe 'Get-ImageInputHash' {
    BeforeAll {
        $script:Box = New-LeashSandbox
        $script:Ctx = $script:Box.Root
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Ctx 'a')
        [System.IO.File]::WriteAllText((Join-Path $script:Ctx 'a' 'one.txt'), "one`n")
        [System.IO.File]::WriteAllText((Join-Path $script:Ctx 'b.txt'), "b`n")
        [System.IO.File]::WriteAllText((Join-Path $script:Ctx 'unrelated.txt'), "u`n")
        $script:Df = Join-Path $script:Ctx 'Dockerfile'
        [System.IO.File]::WriteAllText($script:Df, "FROM scratch`nCOPY a/ /x/`nCOPY b.txt /y`n")
        $script:Base = Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df
    }

    AfterAll { Remove-Item -LiteralPath $script:Box.Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'is 64 hex characters and stable' {
        $script:Base | Should -Match '^[0-9a-f]{64}$'
        Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df | Should -Be $script:Base
    }

    It 'changes when a file under a copied folder changes, and changes back' {
        $f = Join-Path $script:Ctx 'a' 'one.txt'
        [System.IO.File]::WriteAllText($f, "one, changed`n")
        Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df | Should -Not -Be $script:Base
        [System.IO.File]::WriteAllText($f, "one`n")
        Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df | Should -Be $script:Base
    }

    It 'changes when a file is added to a copied folder' {
        $f = Join-Path $script:Ctx 'a' 'two.txt'
        [System.IO.File]::WriteAllText($f, "two`n")
        try { Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df | Should -Not -Be $script:Base }
        finally { Remove-Item -LiteralPath $f -Force }
    }

    It 'changes when the Dockerfile changes' {
        $other = Join-Path $script:Ctx 'Dockerfile.other'
        [System.IO.File]::WriteAllText($other, "FROM scratch`nCOPY a/ /x/`nCOPY b.txt /z`n")
        Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $other | Should -Not -Be $script:Base
    }

    It 'does not change when a file nothing copies changes' {
        [System.IO.File]::WriteAllText((Join-Path $script:Ctx 'unrelated.txt'), "u, changed`n")
        Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $script:Df | Should -Be $script:Base
    }

    It 'throws on a COPY source that does not exist' {
        $bad = Join-Path $script:Ctx 'Dockerfile.bad'
        [System.IO.File]::WriteAllText($bad, "FROM scratch`nCOPY missing/ /x/`n")
        { Get-ImageInputHash -ContextRoot $script:Ctx -Dockerfile $bad } | Should -Throw '*missing*'
    }

    It 'covers every COPY source of <File>' -ForEach @(
        @{ File = 'Dockerfile' }
        @{ File = 'images/developer/Dockerfile' }
    ) {
        $sources = @(Get-ImageCopySource -Dockerfile (Join-Path $script:RepoRoot $File))
        $sources | Should -Contain 'hooks/'
        $sources | Should -Contain 'src/'
        $sources | Should -Contain 'entrypoint.ps1'
        $sources | Should -Contain 'vendor/claude.agent.core/modules/ledger/python/'
        $sources | Should -Contain 'config/sentinel.json'
        $sources.Count | Should -Be 9
    }
}

Describe 'CI builds the images once per run, from the cache' {
    It 'has an images job that saves the images only on a cache miss' {
        $images = Get-JobBlock 'images'
        $images | Should -Not -BeNullOrEmpty
        $images | Should -Match 'scripts/ci/Invoke-ImageCache\.ps1 -Step Key'
        $images | Should -Match 'uses: actions/cache/restore@v4'
        $images | Should -Match 'lookup-only: true'
        $images | Should -Match 'scripts/ci/Invoke-ImageCache\.ps1 -Step Build'
        $images | Should -Match 'uses: actions/cache/save@v4'
        $images | Should -Match "if: steps\.cache\.outputs\.cache-hit != 'true'"
    }

    It '<Job> needs images and loads them before it runs' -ForEach @(
        @{ Job = 'pester'; Main = 'run: ./scripts/ci/Invoke-Tests.ps1' }
        @{ Job = 'incontainer'; Main = 'run: ./scripts/ci/Invoke-InContainer.ps1' }
    ) {
        $block = Get-JobBlock $Job
        $block | Should -Match 'needs: images'
        $block | Should -Match 'uses: actions/cache/restore@v4'
        $block | Should -Match 'key: \$\{\{ steps\.key\.outputs\.key \}\}'
        $block | Should -Match 'scripts/ci/Invoke-ImageCache\.ps1 -Step Load'
        $block.IndexOf('-Step Load') | Should -BeGreaterThan 0
        $block.IndexOf('-Step Load') | Should -BeLessThan $block.IndexOf($Main)
    }

    It 'uses no external registry and no secret but the workflow token' {
        $script:CiYaml | Should -Not -Match 'docker (login|push)'
        $script:CiYaml | Should -Not -Match 'type=registry'
        @([regex]::Matches($script:CiYaml, 'secrets\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) |
            Should -Be @('GITHUB_TOKEN')
    }
}

Describe 'Invoke-ImageBuild -NoCache builds cold' {
    # docker is shadowed by a GLOBAL function because Invoke-ImageBuild lives in a module, and a
    # module resolves a bare command name in its own scope and then the global one, never the
    # test's. The fake answers `image inspect` with the matching label, so without -NoCache the
    # image is reused, and with it the reuse must be skipped anyway.
    BeforeAll {
        $script:ColdBox = New-LeashSandbox
        $null = New-Item -ItemType Directory -Path (Join-Path $script:ColdBox.Root 'a')
        [System.IO.File]::WriteAllText((Join-Path $script:ColdBox.Root 'a' 'one.txt'), "one`n")
        $script:ColdDf = Join-Path $script:ColdBox.Root 'Dockerfile'
        [System.IO.File]::WriteAllText($script:ColdDf, "FROM scratch`nCOPY a/ /x/`n")
        $global:LeashColdCalls = [System.Collections.Generic.List[string]]::new()
        $global:LeashColdLabel = Get-ImageInputHash -ContextRoot $script:ColdBox.Root -Dockerfile $script:ColdDf
        function global:docker {
            $global:LeashColdCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'image') { $global:LeashColdLabel }
        }
    }
    AfterAll {
        Remove-Item -Path Function:\global:docker -ErrorAction SilentlyContinue
        Remove-Variable -Name LeashColdCalls, LeashColdLabel -Scope Global -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:ColdBox.Root -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reuses a tagged image whose label matches, without -NoCache' {
        $global:LeashColdCalls.Clear()
        $r = Invoke-ImageBuild -ContextRoot $script:ColdBox.Root -Dockerfile $script:ColdDf -Tag 't:1' -Quiet
        $r.Reused | Should -BeTrue
        @($global:LeashColdCalls | Where-Object { $_ -like 'build *' }).Count | Should -Be 0
    }

    It 'builds with --no-cache --pull and never asks about the tag, with -NoCache' {
        $global:LeashColdCalls.Clear()
        $r = Invoke-ImageBuild -ContextRoot $script:ColdBox.Root -Dockerfile $script:ColdDf -Tag 't:1' -Quiet -NoCache
        $r.Reused | Should -BeFalse
        @($global:LeashColdCalls | Where-Object { $_ -like 'image *' }).Count | Should -Be 0
        @($global:LeashColdCalls) | Should -HaveCount 1
        $global:LeashColdCalls[0] | Should -BeLike 'build --no-cache --pull --label org.leash.inputs=* -t t:1 *'
    }

    It '.build.ps1 carries -NoCache to both image tasks' {
        (Get-Content -LiteralPath (Join-Path $script:RepoRoot '.build.ps1') -Raw) | Should -Match 'NoCache\s*=\s*\[bool\]\$NoCache'
        $tasks = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'build' 'tasks' 'Images.build.ps1') -Raw
        ([regex]::Matches($tasks, '-NoCache:\$Build\.NoCache')).Count | Should -Be 2
    }
}
