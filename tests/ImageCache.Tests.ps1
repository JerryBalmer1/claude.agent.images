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
        $sources | Should -Contain 'config/vendor.json'
        $sources.Count | Should -Be 10
    }
}

Describe 'New-ImageContext builds from git, not the working tree (F97)' {
    # A sandbox repository with a real submodule, so the gitlink path is the one exercised: F97's
    # two .pyc files were untracked in the VENDORED folder, which git archive of the superproject
    # never reaches. core.autocrlf=true in the outer clone, as on this Windows machine (I14-F2).
    BeforeAll {
        $script:FBox = New-LeashSandbox
        $git = @('-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'protocol.file.allow=always', '-c', 'init.defaultBranch=main')
        $sub = Join-Path $script:FBox.Root 'sub'
        $script:Outer = Join-Path $script:FBox.Root 'outer'
        $null = New-Item -ItemType Directory -Path (Join-Path $sub 'py'), $script:Outer
        $null = git -C $sub @git init -q 2>&1
        [System.IO.File]::WriteAllText((Join-Path $sub 'py' 'one.py'), "x = 1`n")
        [System.IO.File]::WriteAllText((Join-Path $sub '.gitignore'), "__pycache__/`n")
        $null = git -C $sub @git add -A 2>&1
        $null = git -C $sub @git commit -q -m sub 2>&1
        $null = git -C $script:Outer @git init -q 2>&1
        $null = git -C $script:Outer config core.autocrlf true
        [System.IO.File]::WriteAllText((Join-Path $script:Outer 'a.txt'), "a`n")
        [System.IO.File]::WriteAllText((Join-Path $script:Outer 'Dockerfile'), "FROM scratch`nCOPY vendor/sub/py/ /x/`nCOPY a.txt /y`n")
        $null = git -C $script:Outer @git submodule add -q $sub vendor/sub 2>&1
        $null = git -C $script:Outer @git add -A 2>&1
        $null = git -C $script:Outer @git commit -q -m outer 2>&1
        # checkout rewrites only a file that is missing, so a.txt goes first and comes back CRLF.
        Remove-Item -LiteralPath (Join-Path $script:Outer 'a.txt')
        $null = git -C $script:Outer @git checkout -q -- a.txt 2>&1

        $script:HashOf = {
            $c = New-ImageContext -RepositoryRoot $script:Outer
            try { [pscustomobject]@{ Hash = Get-ImageInputHash -ContextRoot $c -Dockerfile (Join-Path $c 'Dockerfile')
                                     Files = @(Get-ChildItem -LiteralPath $c -Recurse -File -Force | ForEach-Object { [System.IO.Path]::GetRelativePath($c, $_.FullName).Replace('\', '/') } | Sort-Object -CaseSensitive)
                                     A = [System.IO.File]::ReadAllBytes((Join-Path $c 'a.txt')) } }
            finally { Remove-ImageContext -Path $c }
        }
        $script:Clean = & $script:HashOf
    }

    AfterAll { Remove-Item -LiteralPath $script:FBox.Root -Recurse -Force -ErrorAction SilentlyContinue }

    It 'exports HEAD and the submodule at its gitlink, and nothing else' {
        $script:Clean.Files | Should -Be @('.gitmodules', 'a.txt', 'Dockerfile', 'vendor/sub/.gitignore', 'vendor/sub/py/one.py')
    }

    It 'exports LF where the clone checked out CRLF' {
        [System.IO.File]::ReadAllBytes((Join-Path $script:Outer 'a.txt')) | Should -Be @(0x61, 0x0D, 0x0A) -Because 'the precondition: this clone is autocrlf'
        $script:Clean.A | Should -Be @(0x61, 0x0A)
    }

    It 'does not see an untracked or ignored file in the vendored folder, nor an uncommitted edit; the hash is unchanged' {
        $pyc = Join-Path $script:Outer 'vendor' 'sub' 'py' '__pycache__'
        $null = New-Item -ItemType Directory -Path $pyc
        [System.IO.File]::WriteAllText((Join-Path $pyc 'one.cpython-310.pyc'), 'ignored')
        [System.IO.File]::WriteAllText((Join-Path $script:Outer 'vendor' 'sub' 'py' 'stray.py'), 'untracked')
        [System.IO.File]::WriteAllText((Join-Path $script:Outer 'a.txt'), "edited, not committed`n")
        try {
            # The precondition: the working-tree hash does see them. Without this the test passes on a no-op.
            Get-ImageInputHash -ContextRoot $script:Outer -Dockerfile (Join-Path $script:Outer 'Dockerfile') |
                Should -Not -Be $script:Clean.Hash
            $after = & $script:HashOf
            $after.Files | Should -Be $script:Clean.Files
            $after.Hash | Should -Be $script:Clean.Hash
        }
        finally {
            Remove-Item -LiteralPath $pyc, (Join-Path $script:Outer 'vendor' 'sub' 'py' 'stray.py') -Recurse -Force
            $null = git -C $script:Outer checkout -q -- a.txt 2>&1
        }
    }

    It 'refuses a submodule that is not checked out' {
        $null = git -C $script:Outer submodule deinit -q -f vendor/sub 2>&1
        try { { New-ImageContext -RepositoryRoot $script:Outer } | Should -Throw '*vendor/sub is not checked out*' }
        finally { $null = git -C $script:Outer -c protocol.file.allow=always submodule update -q --init 2>&1 }
    }

    It 'is what Build.Image and the CI cache key build and hash from' {
        $tasks = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'build' 'tasks' 'Images.build.ps1') -Raw
        ([regex]::Matches($tasks, 'New-ImageContext -RepositoryRoot \$Build\.RepositoryRoot')).Count | Should -Be 2
        $tasks | Should -Not -Match '-ContextRoot \$(root|Build\.RepositoryRoot)'
        $cache = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'scripts' 'ci' 'Invoke-ImageCache.ps1') -Raw
        $cache | Should -Match 'New-ImageContext -RepositoryRoot \$RepoRoot'
        $cache | Should -Not -Match '-ContextRoot \$RepoRoot'
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
