#Requires -Version 7.4
<#
    SCRATCH. This file exists to be seen going red on the runner and is removed by the very
    next commit on this branch. It is committed rather than left untracked because a gate
    that has only ever been driven red on a developer desk has not been shown to work in the
    place it is supposed to guard.

    It carries one skip with no justification tag of either form. Before this branch the
    `pester` check would have reported it as a green run with "skipped=3".
#>

Describe 'scratch: falsifying the CI skip gate' {

    It 'skips with no BLOCKER-n and no SkipWhen tag' -Skip {
        $true | Should -BeTrue
    }
}
