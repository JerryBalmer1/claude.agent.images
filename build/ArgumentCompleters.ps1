#Requires -Version 7.4
<#
.SYNOPSIS
    Argument completers for Invoke-Build in this repository.

.DESCRIPTION
    Registers tab completion for the Task parameter so that typing
        Invoke-Build <TAB>
    shows every task defined in .build.ps1 on first run.

    Load this in your profile, or dot-source it once per session:
        . ./build/ArgumentCompleters.ps1

    Adapted from nightroman/Invoke-Build Invoke-Build.ArgumentCompleters.ps1
    (https://github.com/nightroman/Invoke-Build/blob/main/Invoke-Build.ArgumentCompleters.ps1).
#>

Register-ArgumentCompleter -CommandName Invoke-Build -ParameterName Task -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

    $file = $boundParameters['File']
    if (-not $file) { $file = '.build.ps1' }
    if (-not (Test-Path $file)) { return }

    $tasks = Invoke-Build -Task ?? -File $file
    $tasks.Keys -like "$wordToComplete*" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName Invoke-Build -ParameterName File -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)

    Get-ChildItem -File -Name "$wordToComplete*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    Get-ChildItem -Directory -Name "$wordToComplete*" -ErrorAction SilentlyContinue | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ProviderContainer', $_)
    }
}
