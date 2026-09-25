#Requires -Version 7.4

<#
.SYNOPSIS
    Image builds.

.DESCRIPTION
    Both images build from the REPOSITORY ROOT as context, with -f pointing at
    the Dockerfile. That is not a style preference: there is exactly one
    sentinel script and one vendored Ledger, both at the repo root, and both
    images copy them. A context of images/developer/ cannot see either.

    Images.Build.Agent is gone. It scaffolded a placeholder Dockerfile — on the
    deprecated MCR base, with a `# TODO: implement` in it — the first time
    anyone ran it, which is precisely the "no stub files, no TODO that ships"
    rule in AGENTS.md being broken by the build system itself. An agent image
    can be added when there is one to add.

    Both go through Invoke-ImageBuild (build/Build.Helpers.psm1), which skips the build when the
    tag already carries the label for these exact inputs. That is what lets CI load the images
    job's cached images and run no apt after it (I13 PR 3).

    The context is not the working tree. New-ImageContext exports HEAD, and the core submodule
    at its gitlink, into a temporary directory, and the build and its input hash both read that
    (F97). An untracked or uncommitted file is not in the image; commit it first.
#>

# Synopsis: Build the enforcing leash image.
task Build.Image.Leash {
    $ctx = New-ImageContext -RepositoryRoot $Build.RepositoryRoot
    try {
        $file = Join-Path $ctx 'Dockerfile'
        Write-Build Cyan "Building $($Build.LeashTag) from HEAD ..."
        $r = Invoke-ImageBuild -ContextRoot $ctx -Dockerfile $file -Tag $Build.LeashTag -NoCache:$Build.NoCache
        if ($r.ExitCode -ne 0) { throw "docker build failed for $($Build.LeashTag), exit $($r.ExitCode)" }
    }
    finally { Remove-ImageContext -Path $ctx }
    Write-Build Green "Built $($Build.LeashTag)"
}

# Synopsis: Build the observing developer image.
task Build.Image.Developer {
    $ctx = New-ImageContext -RepositoryRoot $Build.RepositoryRoot
    try {
        $file = Join-Path $ctx 'images' 'developer' 'Dockerfile'
        if (-not (Test-Path -LiteralPath $file)) {
            throw "Developer Dockerfile missing from HEAD: images/developer/Dockerfile"
        }
        Write-Build Cyan "Building $($Build.DeveloperTag) from HEAD ..."
        $r = Invoke-ImageBuild -ContextRoot $ctx -Dockerfile $file -Tag $Build.DeveloperTag -NoCache:$Build.NoCache
        if ($r.ExitCode -ne 0) { throw "docker build failed for $($Build.DeveloperTag), exit $($r.ExitCode)" }
    }
    finally { Remove-ImageContext -Path $ctx }
    Write-Build Green "Built $($Build.DeveloperTag)"
}

# Synopsis: Build every agent image.
task Build.Image Build.Image.Leash, Build.Image.Developer

# Synopsis: Backwards-compatible alias for Build.Image.
task Images.Build Build.Image
