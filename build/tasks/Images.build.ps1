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
#>

# Synopsis: Build the enforcing leash image.
task Build.Image.Leash {
    $root = $Build.RepositoryRoot
    $file = Join-Path $root 'Dockerfile'
    Write-Build Cyan "Building $($Build.LeashTag) ..."
    exec { docker build -f $file -t $Build.LeashTag $root }
    Write-Build Green "Built $($Build.LeashTag)"
}

# Synopsis: Build the observing developer image.
task Build.Image.Developer {
    $root = $Build.RepositoryRoot
    $file = Join-Path $root 'images' 'developer' 'Dockerfile'
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Developer Dockerfile missing: $file"
    }
    Write-Build Cyan "Building $($Build.DeveloperTag) ..."
    exec { docker build -f $file -t $Build.DeveloperTag $root }
    Write-Build Green "Built $($Build.DeveloperTag)"
}

# Synopsis: Build every agent image.
task Build.Image Build.Image.Leash, Build.Image.Developer

# Synopsis: Backwards-compatible alias for Build.Image.
task Images.Build Build.Image
