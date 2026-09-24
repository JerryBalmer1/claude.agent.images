#Requires -Version 7.4
<#
.SYNOPSIS
    CI image cache: the key, the one build per run, and the load before the tests.

.DESCRIPTION
    Since I12 PR 4 the `pester` check builds both images (the Docker-tagged tests) and
    `incontainer` builds them again, and every build runs apt against archive.ubuntu.com. One run
    failed on DNS for it. ci.yml now has an `images` job, and this script is each of its steps:

      -Step Key    The cache key: sha256 over both images' Get-ImageInputHash, which covers each
                   Dockerfile, .dockerignore and every file their COPY lines read. Written to
                   GITHUB_OUTPUT as `key`. The same inputs on any commit give the same key.
      -Step Build  On a cache miss only: Invoke-Build Build.Image, then docker save of every image
                   carrying the org.leash.inputs label to output/image-cache/images.tar, which
                   actions/cache/save stores under the key.
      -Step Load   In `pester` and `incontainer`, after actions/cache/restore: docker load. Their
                   builds then go through Invoke-ImageBuild, find the label for these inputs, and
                   build nothing, so no job after `images` runs apt. With no tarball (the cache
                   entry was evicted or never saved) it says so, and the job builds for itself,
                   which is correct but touches the network again.

    Every step prints one `image-cache:` line, so a run log shows whether it hit or missed.

    No registry and no secret: actions/cache stores the tarball with the workflow's own runtime
    token.

.EXAMPLE
    pwsh -NoProfile -File scripts/ci/Invoke-ImageCache.ps1 -Step Key
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Key', 'Build', 'Load')]
    [string]$Step
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version 3.0

$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$CacheDir = Join-Path $RepoRoot 'output' 'image-cache'
$Tarball  = Join-Path $CacheDir 'images.tar'
Import-Module (Join-Path $RepoRoot 'build' 'Build.Helpers.psm1') -Force

switch ($Step) {
    'Key' {
        $leash = Get-ImageInputHash -ContextRoot $RepoRoot -Dockerfile (Join-Path $RepoRoot 'Dockerfile')
        $dev   = Get-ImageInputHash -ContextRoot $RepoRoot -Dockerfile (Join-Path $RepoRoot 'images' 'developer' 'Dockerfile')
        $key   = 'leash-images-' + (Get-StringSha256 -Text "leash $leash`ndeveloper $dev")
        Write-Host "image-cache: key $key (leash inputs $($leash.Substring(0, 12)), developer inputs $($dev.Substring(0, 12)))"
        if ($env:GITHUB_OUTPUT) { Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "key=$key" -Encoding utf8 }
    }

    'Build' {
        $config = Get-Content -LiteralPath (Join-Path $RepoRoot 'config' 'repo.json') -Raw | ConvertFrom-Json -Depth 20
        $pinned = $config.tooling.invokebuild
        if (-not (Get-Module -ListAvailable -Name InvokeBuild | Where-Object { $_.Version.ToString() -eq $pinned })) {
            Install-Module -Name InvokeBuild -RequiredVersion $pinned -Force -Scope CurrentUser -ErrorAction Stop
        }
        Import-Module InvokeBuild -RequiredVersion $pinned -Force -ErrorAction Stop

        Write-Host 'image-cache: MISS - building both images once for this run'
        Invoke-Build Build.Image -File (Join-Path $RepoRoot '.build.ps1')

        $tags = @(docker images --filter 'label=org.leash.inputs' --format '{{.Repository}}:{{.Tag}}' | Sort-Object -Unique)
        if ($tags.Count -ne 2) { throw "expected the two labelled images after Build.Image, found: $($tags -join ', ')" }
        $null = New-Item -ItemType Directory -Path $CacheDir -Force
        docker save -o $Tarball @tags
        Write-Host ("image-cache: saved {0} to {1} ({2:n0} MB)" -f ($tags -join ', '), $Tarball, ((Get-Item -LiteralPath $Tarball).Length / 1MB))
    }

    'Load' {
        if (-not (Test-Path -LiteralPath $Tarball)) {
            Write-Host 'image-cache: MISS - no saved images; this job builds its own, and apt runs'
            break
        }
        docker load -i $Tarball
        foreach ($t in @(docker images --filter 'label=org.leash.inputs' --format '{{.Repository}}:{{.Tag}}' | Sort-Object -Unique)) {
            $label = (docker image inspect --format '{{ index .Config.Labels "org.leash.inputs" }}' $t).Trim()
            Write-Host "image-cache: HIT - loaded $t (inputs $($label.Substring(0, 12)))"
        }
    }
}
exit 0
