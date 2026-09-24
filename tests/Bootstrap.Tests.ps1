#Requires -Version 7.4

<#
    scripts/Bootstrap-Clean.ps1 and the pin it holds a fresh clone to (I14 PR 5).

    The full run clones from GitHub and builds both images, so it is evidence in the pull request,
    not a test here. What is held here is what a clean clone depends on: the pin in
    config/vendor.json is the gitlink the tree records and the URL .gitmodules names, so bumping one
    without the other is red; the script refuses to clone over anything or into the checkout it
    runs from; and it names nothing that exists only on one machine.
#>

BeforeDiscovery {
    $script:Pins = @((Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'config' 'vendor.json') -Raw | ConvertFrom-Json).submodules |
                     ForEach-Object { @{ path = $_.path; pin = $_.pin } })
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'TestHelpers.psm1') -Force
    $script:RepoRoot  = Get-RepoRoot
    $script:Bootstrap = Join-Path $script:RepoRoot 'scripts' 'Bootstrap-Clean.ps1'
    $script:Vendor    = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'config' 'vendor.json') -Raw | ConvertFrom-Json
}

Describe 'config/vendor.json is the submodule pin' {
    It 'names every submodule .gitmodules declares, at the same URL' {
        $declared = @(git -C $script:RepoRoot config --file .gitmodules --get-regexp '^submodule\..*\.path$' | ForEach-Object { ($_ -split '\s+', 2)[1] })
        @($script:Vendor.submodules.path) | Should -Be $declared
        foreach ($sm in @($script:Vendor.submodules)) {
            $name = (git -C $script:RepoRoot config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
                     Where-Object { $_ -like "* $($sm.path)" } | ForEach-Object { ($_ -split '\s+')[0] -replace '\.path$', '.url' })
            (git -C $script:RepoRoot config --file .gitmodules --get $name) | Should -BeExactly $sm.url
        }
    }

    It 'pins <path> to the gitlink the tree records' -ForEach $script:Pins {
        $pin | Should -Match '^[0-9a-f]{40}$'
        $gitlink = ((git -C $script:RepoRoot ls-tree HEAD -- $path | Out-String).Trim() -split '\s+')[2]
        $gitlink | Should -BeExactly $pin -Because 'a bump that moves the gitlink and not config/vendor.json, or the reverse, is a bootstrap that fails'
    }
}

Describe 'scripts/Bootstrap-Clean.ps1' {
    It 'refuses a -Path that already exists, before it clones anything' {
        $existing = New-LeashSandbox
        try {
            $r = Invoke-LeashScript -Path $script:Bootstrap -Arguments @('-Path', $existing.Root)
            $r.ExitCode | Should -Be 1
            $r.StdErr | Should -Match 'already exists'
        }
        finally { Remove-LeashSandbox -Root $existing.Root }
    }

    It 'refuses a -Path inside the checkout it runs from' {
        $r = Invoke-LeashScript -Path $script:Bootstrap -Arguments @('-Path', (Join-Path $script:RepoRoot 'output' 'never-created'))
        $r.ExitCode | Should -Be 1
        $r.StdErr | Should -Match 'inside the checkout'
    }

    It 'names no machine-specific path' {
        $text = Get-Content -LiteralPath $script:Bootstrap -Raw
        $text | Should -Not -Match '[A-Za-z]:\\'
        $text | Should -Not -Match '/(home|Users)/[A-Za-z]'
        $text | Should -Not -Match '\.\./claude\.'
    }
}
