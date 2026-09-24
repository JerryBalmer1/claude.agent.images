# END_GOAL

The st te of this repository, recorded by the run th t ch nged it.

jGo l.Upd tej is the l st t sk in the def ult ch in  nd it f ils the build
unless the newest run h s   section here. See jAGENTS.mdj for the required
fields. The jTestedj tot ls  re cross-checked  g inst
joutput/incont iner.jsonj, so   green summ ry of   run th t did not h ppen
f ils the build r ther th n being believed.

---

## 2026-09-23 c7b2dee run-01

I12 PR 4, `feature/docker-tests-in-ci`: the 21 Docker-tagged tests run in CI, and the in-container
suite's wall time is shown.

**Changed:**

- `scripts/ci/Invoke-Tests.ps1` excludes no tag. The `pester` required check on the ubuntu runner
  builds both images and runs the Docker-tagged tests. A hard gate fails the check on any NotRun.
- `Test.InContainer` and the `incontainer` job print `wall=<s>s`, from the `duration_s` the in-container
  run already wrote.
- `tests/CiCoverage.Tests.ps1`: red before the fix (0 passed, 4 failed), green after.

**Tested:** passed=169 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. **In-container suite wall time: 33.5s** (`Test.InContainer` at `c7b2dee`;
the task took 39.3s with container start). `scripts/ci/Invoke-Tests.ps1` locally, as CI runs it:
total=196 passed=193 failed=0 skipped=3 **notrun=0**, 90s. The Docker-tagged tests needed no new skip.

**Failed:** none.

**Missing:**

- The Docker-tagged tests still cannot run inside the image: there is no docker daemon there. They run
  in the `pester` check instead, which is where the packet asked for them.
- `src/LedgerReceipt.ps1` still ships with no caller (I12 PR 5).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before any edit at seq 36 (`docker-tests-in-ci`). `Goal.Update` appends its
own `verification` record.

## 2026-09-23 f470895 run-01

I12 PR 3, `feature/ci-on-main`: after a merge into main, automerge dispatches `ci.yml` on main.

**Changed:**

- `Invoke-CiDispatchOnMain` in `scripts/AutoMerge.Lib.ps1`, called by `Invoke-AutoMerge.ps1` after the
  merge. `automerge.yml` gets `actions: write`. `ci.yml` gets `workflow_dispatch` and `actions: read`.
- `AGENTS.md` claim: the commit at main's tip has a completed, successful ci run.
- `tests/CiOnMain.Tests.ps1`: the dispatch decision with `gh` shadowed, the checker on fixed commits
  (`6b8943a` has 0 ci runs, measured, kept as the red case; `74c1db2` has one), and the live claim.
  Red before the fix: 4 failed.

**Tested:** passed=165 failed=0 skipped=6 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. The three new skips are `no-gh-cli`.

**Failed:** none.

**Missing:**

- **The live claim cannot run yet.** Automerge's `workflow_run` runs `main`'s copy of itself, so the
  promotion that brings the dispatch to `main` is merged by the pre-dispatch copy. The packet's
  "confirm PR 3's dispatch produced a ci run on the new main tip" rests on a false premise for that
  promotion. The first automerge dispatch comes one promotion later.
- Automerged merges into `develop` get no push CI either. Their trees are the checked pull request
  heads. This is recorded at seq 34 and not changed.
- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before any edit at seq 34 (`ci-on-main`), naming the false premise.
`Goal.Update` appends its own `verification` record.

## 2026-09-23 24e8812 run-01

I12 PR 2, `feature/merge-settings`: the repository enforces merge commits only, and a test reads that live.

**Changed:**

- GitHub setting, by `gh repo edit --enable-squash-merge=false --enable-rebase-merge=false` after the
  test was red in CI: squash `true` -> `false`, rebase `true` -> `false`, merge commit `true`. Branch
  protection was not attempted.
- `AGENTS.md` claim, and `tests/MergeSettings.Tests.ps1` reading the three settings through
  `gh api graphql`. No answer is a failure. Without `gh` - inside the images - it skips as
  `SkipWhen:no-gh-cli`. `ci.yml` gives the `pester` step `GH_TOKEN` from the workflow's `GITHUB_TOKEN`.
- Red before the change: host, and CI run 35953595780 (`pester`: squash reported `true`).

**Tested:** passed=161 failed=0 skipped=3 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. The third skip is `no-gh-cli`, justified on the test object.

**Failed:** none.

**Missing:**

- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(shape checked, not value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by `Bootstrap`.

**Forensic chain:** decision before the change at seq 32 (`merge-commits-only`). `Goal.Update` appends
its own `verification` record.

## 2026-09-23 23b1db9 run-01

I12 PR 1, `feature/public-hygiene`: the repository is public, so it now carries a licence and keeps
private names and addresses out of tracked files.

**Changed:**

- `LICENSE`, MIT, JerryBalmer1, 2026, stated in one line of `README.md`.
- Scan of every tracked file at `e195e49`: 0 local user paths, 0 tokens or keys, 1 email address
  (the line below at `:291` in the 2026-09-23 0c0f714 section), and 45 occurrences of the private
  origin repository's name, 35 of them in live files. All live hits are edited.
- `tests/PublicHygiene.Tests.ps1` fails on any of the four in a tracked file outside `.continuity/`.
  Red at `e195e49`: host, and CI run 35952853389 (`pester` 2 failed, on email and name).
- `DECISIONS.md` created. It lists the forensic records that carry a hit and are not edited.

**Tested:** passed=161 failed=0 skipped=2 - in-container, `pwsh 7.6.6`, Pester 6.1.0, uid 1001,
`unjustified_skips` empty. Five tests added.

**Failed:** none.

**Missing:**

- Personal author addresses in git commit metadata and in older blobs of this file. They can only be
  cleared by a history rewrite, which is not done here and never is. See `DECISIONS.md`.
- The Docker-tagged tests still run nowhere in CI (I12 PR 4).

**Blockers:**

- **No signing key.** Not touched. Identity is operator-asserted.
- **Command-hook timeout fails open.** Not touched. 15s PreToolUse, Claude Code semantics.
- The receipt-append export blocker was struck on 2026-09-23 at seq 9 and is not relisted.

**Ledger head hash:** `33a77e42c7a9f230735561fdbcd3abe28df294abb4d92671b0bffde536bd123a`
(receipts at `output/ledger/ledger.jsonl`; `Goal.Update` checks its shape, not its value.)

**Assessment hash:** `798b10ee3ca2d64b28bc779611484ddc0565448c6468ae2ddaf54a53a98030a3`
- canonical sha256 of `prompts/assessment.2026-09-21.json`, unchanged and re-verified by
`Bootstrap`.

**Forensic chain:** decision before any edit at seq 29 (`public-hygiene`), the finding for
records left unedited at seq 30 (`public-hygiene-records-not-edited`). `Goal.Update` appends its
own `verification` record.

## 2026-09-23 439e2c4 run-01

I11 PR B, jfe ture/drop-directory-gu rdj: jtests/run.ps1j no longer refuses on its folder n me. The
cl ude. gent.tools T0 inspector found the gu rd.

**Ch nged:**

- **The gu rd is gone.** jtests/run.ps1j threw jNOT IN CLAUDE.AGENT.IMAGESj unless the c ller's git
  toplevel ended in this repository's n me. The root is now the folder the script lives in,  s in
  cl ude. gent.tools' copy.
- **Pester is pinned from jconfig/repo.jsonj** (6.1.0), not the 5.x r nge. The im ges ship only
  6.1.0, so this runner h d never been  ble to run in the cont iner on either count.
- **jtests/RunnerFolder.Tests.ps1j.** It clones the committed HEAD into   folder n med with   r ndom
  guid, then runs the clone's runner on   probe test from inside the clone. It w s red  t j3921c4bj,
  on the host  nd in CI run 35950457428 (jpesterj  nd jincont inerj, e ch refusing with
  jNOT IN CLAUDE.AGENT.IMAGESj),  nd green from j439e2c4j.

**Tested:** p ssed=156 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0, uid 1001,
junjustified_skipsj empty. Host jtests/run.ps1j, now on Pester 6.1.0: 177 p ssed, 0 f iled, 2
skipped. Two tests  dded.

**F iled:** none.

**Missing:**

- The 21 Docker-t gged tests still run nowhere in CI; in-cont iner timing is unme sured here. Both  re
  out of scope for I11.
- jsrc/LedgerReceipt.ps1j still h s no c ller (see the section below).

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not relisted.

**Ledger he d h sh:** jd4e578b 8988229c2738b4 c8f3 3e2478f622c 8 745c0712d e4e29b11b3e0j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified by
jBootstr pj.

**Forensic ch in:** decision recorded BEFORE  ny edit  t seq 26, jkind=decisionj,
jsubject=drop-directory-gu rdj, jprev 2cd6 c5dj, jself 9933bcf7j. It pl ces the Pester import  t
j:31j; it w s  t j:33j, corrected in j439e2c4j's mess ge, record unch nged. jGo l.Upd tej  ppends its
own jverific tionj record.

## 2026-09-23 6232e03 run-01

I11 PR A, jfe ture/ledger-receipt-p thj: jsrc/LedgerReceipt.ps1j finds cl ude. gent.core's ledger
module, found by the cl ude. gent.tools T0 inspector.

**Ch nged:**

- **jInvoke-LedgerBootVerifyj looks where the module is.** C ndid tes  re
  j/opt/le sh/ledger/Ledger.psd1j, where both Dockerfiles COPY core's jmodules/ledger/ledger.psd1j,
   nd jvendor/cl ude. gent.core/modules/ledger/ledger.psd1j on the host. The two entries n ming the
  retired ledger repository's vendor p th  re gone. Th t repository w s never   submodule here:
  j.gitmodulesj decl res jvendor/cl ude. gent.corej  lone.
- **jJoin-P th (if ...)j bec me jJoin-P th $(if ...)j.** In PowerShell 7 the first form is   runtime
  error. The p cket did not n me it; it sits on the line the p th fix m kes re ch ble,  nd PR #13's
  first CI run showed it f iling inside the im ge.
- **jtests/LedgerP th.Tests.ps1j.** A sweep for the old repository n me in  ny form  cross jsrc/j,
  jhooks/j, jscripts/j, jentrypoint.ps1j  nd both Dockerfiles, plus   Ledger-t gged test th t
  Invoke-LedgerBootVerify  nswers from core's jGet-LedgerVerifyj on   re l ch in. Both were red  t
  j050e3d8j: host 0 p ssed, 2 f iled; CI run 35949377012 red on jpesterj  nd jincont inerj with
  ex ctly these two tests.

**Tested:** p ssed=154 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0, uid 1001,
junjustified_skipsj empty. Host jtests/run.ps1j: 175 p ssed, 0 f iled, 2 skipped. Two tests  dded.
The jInvoke-Build Test.InCont inerj log h s 415 lines,  nd none cont ins the old repository n me.

**F iled:** none.

**Missing:**

- jsrc/LedgerReceipt.ps1j h s no c ller: nothing dot-sources it or c lls jInvoke-LedgerBootVerifyj,
   nd both im ges still COPY it through jsrc/j. Whether it should be wired or deleted is not decided
  here.
- The 21 Docker-t gged tests still run nowhere in CI; in-cont iner timing is unme sured here. Both  re
  out of scope for I11  nd belong to their own p cket.

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not relisted.

**Ledger he d h sh:** jd4e578b 8988229c2738b4 c8f3 3e2478f622c 8 745c0712d e4e29b11b3e0j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified by
jBootstr pj.

**Forensic ch in:** decision recorded BEFORE  ny edit  t seq 24, jkind=decisionj,
jsubject=ledger-receipt-p th-to-corej, jprev f83f3 16j, jself 69 d2087j. It pl ces the
if-in-p rentheses  t j:105j; it w s  t j:109j, corrected in j6232e03j's mess ge, record unch nged.
jGo l.Upd tej  ppends its own jverific tionj record.

## 2026-09-23 67cbfd1 run-01

I10 PR B, jfe ture/ci-incont inerj: CI runs the suite inside the im ge,  nd FINDING-M17 is
retired with the me surement th t killed it.

**Ch nged:**

- **A required jincont inerj job.** It builds both im ges on the runner  nd runs
  jInvoke-Build Test.InCont inerj through jscripts/ci/Invoke-InCont iner.ps1j, uplo ding
  joutput/incont iner.jsonj  s  n  rtif ct. InvokeBuild pinned  t jtooling.invokebuildj
  5.14.23. The runner me sured 1m57s for the whole job, with im ges built cold in 67.4s -
  under the 10-minute threshold fixed  t seq 21 before me suring - so it g tes pull requests
   nd is in jrequired_checksj. jPOLICY.mdj  nd the PR templ te regener ted.
- **FINDING-M17 retired.** core is public; PR #9's jpesterj job checked the submodule out
  with no token  nd r n  ll 43 Ledger-t gged tests. The entry itself lives only in
  jcl ude.pwsh.im ge.builderj, so it is retired on this ch in  t seq 21, not copied here.
- **jscripts/ci/Invoke-Tests.ps1j:   missing Ledger now f ils the check** inste d of
  excluding the t g. The exclusion existed only for the PAT nobody h d; without th t re son
  it w s  n ungu rded green.
- **Three old END_GOAL records  nnot ted, not rewritten** - d ted notes under the sentences
  th t  sserted M17's priv te premise, origin l words kept.
- **One runner-only defect found  nd fixed:** jInvoke-Build -Result ibj f iled on the runner
  with "v ri ble h s been optimized"  fter p ssing loc lly; j-Resultj now t kes   h sht ble.

**Tested:** p ssed=152 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0, uid
1001, tot l 175, NotRun 21 ( ll Docker-t gged), junjustified_skipsj empty. The s me numbers
on the runner, inside the im ge, in the jincont inerj job. Runner jpesterj: 152 / 0 / 2,
NotRun 21, Docker only. No test  dded or removed this run.

**F iled:** none.

**Missing:**

- The Docker-t gged tests (21) still run nowhere in CI. There is no docker d emon inside the
  im ge,  nd the runner-host jpesterj job excludes them by design (M13). jdocs/pl ns/2026-09-21-cle nup/FINDINGS.mdj,
  which M13 cites, is not in this tree.
- jincont inerj is required from the NEXT pull request into develop:  utomerge re ds
  jrequired_checksj from the b se br nch.

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not relisted.

**Ledger he d h sh:** j4cd5b9348323773 72b5 949873bf3cc021f041ee46bef15 d1d563e2939e9d3j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified by
jBootstr pj.

**Forensic ch in:** decision recorded BEFORE  ny edit  t seq 21, jkind=decisionj,
jsubject=ci-incont iner-m17-retiredj, jprev c95 d544j, jself 6334f210j. jGo l.Upd tej
 ppends its own jverific tionj record.

**F lsified in the pl ce it gu rds.** Scr tch commit j90dfc59j put one unt gged j-Skipj on  
test inside   Ledger-t gged Describe. Run 35943528887 went red on jpesterj  nd on
jincont inerj, e ch n ming ex ctly th t test. j67cbfd1j removed it with   new commit. Before
PR #9 the s me line w s excluded on the runner  nd would h ve been toler ted green.

## 2026-09-23 ff 9341 run-01

I10 PR A, jfe ture/st le-premisesj: five st le premises, one commit e ch, one decision
record first.

**Ch nged:**

- **The repository c lls itself jcl ude. gent.im gesj.** jconfig/repo.json:3j,
  jschem s/repo.schem .json:3j, j.build.ps1:5j, jbuild/Build.Helpers.psm1:5j,
  jscripts/env.ps1:75j, jdocs/GITFLOW.md:1j, jFLOW.md:35j. jdocs/POLICY.md:9j is the
  rendered jrepoj field, so it w s regener ted by jscripts/Gener te-Policy.ps1j, not edited.
  jscripts/env.ps1:67j describes the OLD gu rd  nd st ys   sentence  bout it.
- **The jpesterj check t kes the submodule.** jci.yml:60-80j n med
  jvendor/cl ude.build.ledgerj  s   priv te submodule needing   PAT. The submodule is
  jvendor/cl ude. gent.corej  nd core is public. There w s no token plumbing to drop - no
  jtoken:j or jsubmodules:j key in  ny of the three workflows. The comment is rewritten  nd
  jsubmodules: recursivej  dded, so the 43 Ledger-t gged tests run in th t required check
  for the first time.
- **jdocs/pl ns/BACKLOG.mdj: 04 is no longer blocked on Pro.** The 403 w s priv te-only;
  the repository is public; 404 me ns  v il ble  nd unset; protection on jm inj is on by
  decision. The Pro row is checked off with the re son, not deleted.
- **jscripts/ci/Test-PushGu rd.ps1:19-25j**, comment only: the protection premise rewritten
  to wh t w s me sured - jm inj protected without  dmin enforcement, jdevelopj 404
  unprotected, rulesets j[]j. The tripwire's g p is n rrower, not closed.
- **One test, two hooks, recorded  s   recurrence.** A one-element JSON  rr y piped through
  jhooks/sentinel.ps1j (f ils closed, exit 2)  nd j.cl ude/hooks/Deny-Heredoc.ps1j (f ils
  open, exit 0), with   control proving the unwr pped object is denied. The prior p cket's
  "both now c rry j-NoEnumer tej" w s f lse: only Deny-Heredoc does; the sentinel defends
  with   r w-text check.

**Tested:** p ssed=152 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0,
uid 1001, tot l 175, NotRun 21 ( ll Docker-t gged), junjustified_skipsj empty. Host
jTest.Unitj: p ssed=173 f iled=0 skipped=2. Host jtests/run.ps1j: 173 p ssed, 0 f iled,
2 skipped, 0 NotRun - b seline w s 172,  nd the one  dded test is the whole delt .
jscripts/ci/Invoke-Tests.ps1j loc lly: tot l=175 p ssed=152 skipped=2 NotRun=21, PASS -
wh t the runner now runs, Ledger included. The new test w s f lsified both w ys: without
j-NoEnumer tej it goes red on   330-byte deny; without the St rtsWith check it goes red on
stderr, while the exit code STAYED 2 for  n unrel ted re son.

**F iled:** none.

**Missing:**

- FINDING-M17, the PAT premise, is still  sserted in jscripts/ci/Invoke-Tests.ps1:71-96j
   nd j:128j. Th t is PR B.
- CI still does not run the in-cont iner suite. Th t is PR B.
- jdocs/pl ns/2026-09-21-cle nup/FINDINGS.mdj, cited for M13  nd M17, is not in this tree.
  It exists only in jcl ude.pwsh.im ge.builderj, left behind  t birth.

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not relisted.

**Ledger he d h sh:** j537 1e40fb567f41 ec 05857591 f 26975c7698f0155de5e4041519 86b8c3j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified by
jBootstr pj.

**Forensic ch in:** decision recorded BEFORE  ny edit  t seq 19, jkind=decisionj,
jsubject=st le-premises-five-itemsj, jprev 941 794bj, jself eff4c8 9j. jGo l.Upd tej
 ppends its own jverific tionj record.

## 2026-09-23 0c0f714 run-01

The repository is public by decision. The rule th t forb de it is retired, not broken.

**Ch nged:**

- **jAGENTS.md:56j stops being   prohibition  nd becomes the f ct.** "Never m ke this
  repo public" held from birth; the repository is public - GitHub API jpriv te: F lsej
  -  nd Jerry h s decided it st ys th t w y. The Do-not bullet now st tes the f ct,  nd
  s ys wh t repl ces the rule: nothing enters this tree th t   str nger should not re d.
  Core's jdocs/pl ns/2026-09-22-public-rele se/j is NAMED  s the  uthority on wh t st ys
  out of   public tree, not copied - this repository does not vendor th t pl n.
- **Dis greement t ble row 8** records the prior rule, the d te it stopped holding,  nd
  the sequence th t is the  ctu l finding: the rule w s being broken while jst te.ps1j
  refused to run  nd therefore could not s y so; it bec me s y ble the moment th t gu rd
  w s fixed (seq 12, item 5); it w s retired one p cket l ter once someone decided.
- **jscripts/st te.ps1j reports visibility inste d of judging it.** The jpriv te:j line
  st ys; the jWARNING: repository is PUBLIC - it must not bej is gone. A report th t
  judges by   retired rule is worse th n one th t does not judge, bec use   re der c nnot
  tell which of its w rnings still me n  nything. The merge-commit w rning beside it is
  untouched - th t rule is live.
- **The promotion of j994 df8j fin lly h s   forensic record**,  t seq 17, c rrying  ll
  three DoD cl use me surements  s t ken  t j c6f167j. PR #7 l nded without one.
- **A PreToolUse hook th t refuses heredocs.** j.cl ude/settings.jsonj plus
  j.cl ude/hooks/Deny-Heredoc.ps1j:   B sh c ll whose comm nd cont ins j<<j is denied with
  "PowerShell only - see AGENTS.md". Exit 0 with   decision body, not exit 2 - the sh pe
  jhooks/sentinel.ps1j  lre dy h d to be rep ired into. F ils open on   m lformed p ylo d;
  this gu rds the h nds of  n  gent trying to comply, not  n  dvers ry.

**Tested:** p ssed=151 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0,
uid 1001, tot l 174, junjustified_skipsj empty. Host jTest.Unitj: p ssed=172 f iled=0
skipped=2 NotRun=0 Inconclusive=0. No test w s  dded or removed: **zero tests  sserted
the repository w s priv te**, me sured before the rule w s touched, so retiring it
removed nothing. jrequires-he derj 39 files checked, 0 missing, with the new hook script
tr cked.

**F iled:** none.

**Missing:**

- **The hook did not  rm in the session th t wrote it.** Cl ude Code sn pshots hooks  t
  session st rt  nd w tches only directories th t  lre dy held   settings file; this
  repository h d no j.cl ude/j  t  ll. A heredoc pushed through the B sh tool minutes
   fter the file w s written r n norm lly. The script itself w s f lsified directly -
  five p ylo ds, five correct verdicts - so this is   timing property, not   broken
  sh pe. Open j/hooksj once, or st rt   new session.
- **Commit met d t  c rries   person l em il  nd c nnot be fixed.** jgit log -- llj shows
  jjerry.infr @gm il.comj  s the  uthor of every hum n commit  nd the committer of every
  commit in the repository,  nd it is now world-re d ble. No history rewrite - not now,
  not ever. jgit config user.em ilj in this clone is still th t  ddress, so every future
  commit  dds it  g in; stopping the forw rd le k is   one-line identity ch nge plus
  GitHub's keep-my-em il-priv te setting,  nd both  re Jerry's to m ke.
- **Br nch protection is no longer 403 on this repository.** jdocs/pl ns/BACKLOG.md:45-50j
  blocks b cklog item 04 on   GitHub Pro upgr de, me sured 2026-09-21  s 403 "Upgr de to
  GitHub Pro **or m ke this repository public**". Re-probed tod y: j/rulesetsj returns
  j[]j exit 0  nd j/br nches/m in/protectionj returns 404 "Br nch not protected". The
  Free-tier limit  pplies to priv te repositories only. Th t  lso m kes the premise  t
  jscripts/ci/Test-PushGu rd.ps1:19-25j st le for this repository. Nothing is configured
  here: turning protection on ch nges how every merge l nds  nd is Jerry's c ll.
- **jcl ude. gent.corej is itself public**, me sured. FINDING-M17 s ys CI c nnot clone the
  submodule bec use core is priv te  nd needs   PAT p ssed to j ctions/checkoutj  s
  jtoken:j. Th t premise is de d:   public submodule clones without   secret, so the 43
  Ledger-t gged tests could run in CI. The M17 PAT w s explicitly out of scope for this
  run, so it is me sured  nd reported r ther th n  cted on. Sep r tely,
  j.github/workflows/ci.yml:60-80j still n mes jvendor/cl ude.build.ledgerj  nd
  jcl ude.build.ledgerj  s the priv te submodule; the submodule is jvendor/cl ude. gent.corej.
  Doubly st le, not edited here.
  *Annot ted 2026-09-23, origin l words kept  bove:  cted on. PR #9 rewrote the jci.ymlj
  comment  nd  dded jsubmodules: recursivej (seq 19); its pester job r n the 43 tests with
  no token. M17 is retired  t seq 21.*
- jconfig/repo.json -> repoj  nd jschem s/repo.schem .json:3j both still n me
  jcl ude.pwsh.im ge.builderj.
- The README still c rries pre-birth wreck ge:   jTest.F ilFirstj row for   deleted t sk,
    jdocker runj ex mple p ssing jLEDGER_HOOK_ARM=1j th t the l w forbids,  nd  
  j. gents/BREADCRUMBS.mdj th t never existed in this repository.

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not relisted.

**Ledger he d h sh:** je35e9 f6c478b126373491953d885f560b5e30fe473167e67 1e97 82d0 0530j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified by
jBootstr pj.

**Forensic ch in:** decision recorded BEFORE  ny edit  t seq 16, jkind=decisionj,
jsubject=repo-public-by-decisionj, jprev 8ecffe0cj, jself b 6def bj. The overdue promotion
record follows  t seq 17, jkind=verific tionj,
jsubject=promotion-develop-to-m in-994 df8j. jGo l.Upd tej  ppends its own, so this run
 dds three records.

**Exposure, me sured bec use the tree is visible.** Live tree: **zero** loc l p ths  nd
**zero** em il  ddresses, jgit grepj over everything but jvendor/j. The only jC:j strings
 re the pl ceholder jC:\...j illustr tions in comments  t jtests/Env.Tests.ps1:25j  nd
jtests/TestHelpers.psm1:213j. History p tch content, jgit log -- ll -pj: **zero** m tches.
The exposure th t does exist is commit met d t , listed under Missing  bove,  nd it is not
fix ble without   rewrite this repository will not do.

## 2026-09-23 531b2e0 run-01

I7: the skip-justific tion g te becomes   required check, on the host h lf.

**Ch nged:**

- **jscripts/ci/Invoke-Tests.ps1j now runs jAssert-SuiteCle nj.** The jpesterj
  required check exited 1 on ex ctly two conditions - zero tests,  nd   f iled test.
  An unjustified skip went green there  nd red under jInvoke-Build Test.Unitj, so CI
  p ssed wh t Full f ils.
- **jAssert-SuiteCle nj moved to jbuild/Build.Helpers.psm1j  nd is exported.** It h d
  to move: it c lled jWrite-Buildj,  n Invoke-Build comm nd, so no pl in pwsh script
  could c ll it where it lived. Th t module  lre dy documents itself  s
  Invoke-Build-free, which is why the cont iner imports it off the bind mount.
  jWrite-Buildj bec me jWrite-Hostj with the s me colours. It is the SAME function
  both c llers run, not   port.
- **One beh viour ch nge, p r meterised r ther th n forked: j-ExcludeT gj.** Pester
  reports   t g-excluded test  s jNotRunj, which is not   skip. A jNotRunj whose
  inherited t gs include one of the excluded v lues is toler ted; every other
  jNotRunj,  nd every jInconclusivej, st ys unjustified. jTest.Unitj p sses nothing
   nd excludes nothing, so its verdict is unch nged. This is the rule
  jbuild/InCont iner.Test.ps1:159-164j  lre dy  pplies, so the host  nd cont iner
  g tes now differ on jNotRunj by  rgument inste d of by  ccident.
- **jconfig/repo.json -> required_checksj untouched.** jpesterj is  lre dy in it;
  this ch nges wh t th t check me sures, not which checks exist, so
  jgener ted-m tch-configj st ys green without editing the config.

**Tested:** p ssed=151 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0,
uid 1001, tot l 174, junjustified_skipsj empty. Host jTest.Unitj: p ssed=172 f iled=0
skipped=2 NotRun=0 Inconclusive=0, reporting both skips  s
jno-exempt-commit-in-r ngej ex ctly  s before the move. jscripts/ci/Invoke-Tests.ps1j
run loc lly: exit 0, tot l=174 p ssed=151 skipped=2 NotRun=21, the s me
justified/unjustified split joutput/incont iner.jsonj records. No test w s  dded or
removed this run.

**F iled:** none.

**Missing:**

- **CI still c nnot run the in-cont iner suite.** jvendor/cl ude. gent.corej is  
  priv te submodule  nd j ctions/checkoutj needs   PAT p ssed  s jtoken:j -
  FINDING-M17, Jerry to cre te. All **43** Ledger-t gged tests st y jNotRunj on the
  runner, toler ted by the very j-ExcludeT gj this run  dds. The host g te stops CI
  p ssing wh t Full f ils; it does not m ke CI prove wh t Full proves. Floor, not
  ceiling.
  *Annot ted 2026-09-23, origin l words kept  bove: the priv te premise w s f lse by then -
  core w s public. No PAT w s ever needed. The Ledger-t gged tests h ve run in the pester
  check since PR #9,  nd  n  bsent submodule now f ils it r ther th n excluding them. M17 is
  retired  t seq 21.*
- The 21 Docker-t gged tests  re still excluded in CI by design (FINDING-M13), so  
  pull request th t bre ks the Dockerfile still goes green there.
- jbuild/InCont iner.Test.ps1j still implements the g te inline r ther th n c lling
  the sh red function. Deliber te: it writes joutput/incont iner.jsonj  nd its
  reporting medium differs. Two implement tions of one sh red rule, now with two
  c llers on the host side.
- jconfig/repo.json -> repoj still re ds jJerryB lmer1/cl ude.pwsh.im ge.builderj.
- **The repository is PUBLIC**,  g inst jAGENTS.mdj. jst te.ps1j w rns on every run.
- The README still c rries pre-birth wreck ge -   jTest.F ilFirstj row,  
  jLEDGER_HOOK_ARM=1j ex mple the l w forbids,   j. gents/BREADCRUMBS.mdj th t does
  not exist.

**Blockers:**

- **No signing key.** Not touched. Identity is oper tor- sserted.
- **Comm nd-hook timeout f ils open.** Not touched. 15s PreToolUse, Cl ude Code
  sem ntics.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not
  relisted.

**Ledger he d h sh:** j3951b581642 cf5de6c9d81d818e91323 212941b686b72e93f27b0fc 60ded6j
(receipts  t joutput/ledger/ledger.jsonlj. It moves on every jTest.InCont inerj, so
jGo l.Upd tej checks its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged  nd re-verified
by jBootstr pj.

**Forensic ch in:** decision recorded BEFORE the edit  t seq 14, jkind=decisionj,
jsubject=ci-pester-runs- ssert-suite-cle nj, jprev 28e12c75j, jself d531447dj.
jGo l.Upd tej  ppends its own jverific tionj record, so this run  dds two.

**F lsified in the pl ce it gu rds, not only on this desk.** A scr tch commit
c rrying one j-Skipj with no t g w s pushed to jfe ture/ci-suite-cle nj  nd drove the
jpesterj check RED on the runner; the run URL is in the pull request body. A second
commit removed it - not   force-push, jAGENTS.mdj forbids one -  nd the check went
green. Loc lly the s me probe g ve jscripts/ci/Invoke-Tests.ps1j exit 1 n ming the
test, with the two re l skips still reported  s justified.

## 2026-09-23 d6c54cb run-01

Six govern nce items every p cket since #1 h d w lked p st, decided r ther th n
deferred  g in. One decision record, seq 12, covering  ll six.

**Ch nged:**

- **jdocs/pl ns/ACTIVE.mdj retired; the st le-pl n STOP reinst ted with   re ding.**
  The file h d been in the tree since the birth commit jf1 eb60j, n ming
  jfe ture/env-loc lj from two fe tures  go. jAGENTS.mdj row 2 suspended the STOP
  bec use "ACTIVE.md does not exist here" - f lse from birth. The row now re ds: no
  jACTIVE.mdj me ns no  ctive pl n,   leg l st te,  nd the STOP fires only when the
  file exists  nd n mes   br nch other th n the current one. It n mes the four pull
  requests th t w lked p st it - #1 jb03  76j, #2 j66 78d6j, #3 j3e47c9ej,
  #4 jbcd8f 4j. jscripts/st te.ps1j printed the opposite re ding  nd is corrected;
  jAGENTS.md:24-31j  nd jFLOW.md:187-188j  re deliber tely not edited, bec use the
  dis greement t ble is where   re ding lives.
- **The frozen-pl ns justific tion retired; the rule in force given   test.**
  jtests/Repo.Tests.ps1j excluded jdocs/pl ns/j  s FROZEN RECORDS "covered by  
  HASHES.txt". No HASHES.txt is tr cked in this repository  t  ll; the only one
  re ch ble is in jvendor/cl ude. gent.corej  t pin j 68664ej  nd covers nine
   rtef cts belonging to core. Nor  re pl ns frozen here - je221ddbj edited four
  pl n sites. The rule  ctu lly in force is now  sserted r ther th n  sserted- bout:
    pl n m y be  nnot ted in p st tense with   d te, origin l me surements
  preserved. Eight recorded me surements  re pinned;   ch nged number f ils,   d ted
   nnot tion does not. The j^docs/pl ns/j exclusion itself st ys, bec use
  jASSESSMENT.md:406j c rries the pre-move p th.
- **The D7 jAdd-LedgerReceiptj objection: open in core, closed in im ges.** Me sured
   t pin j 68664e6b9938773478d967348b590f487fe2443j: the n me exists in neither tree
   nd core exports the r w jAdd-LedgerRecordj  t jledger.psd1:9j. A wr pper over  
  Ledger export is Ledger API; this repository consumes core  nd  dds none, so the
  objection stops re ding  s  n unmet oblig tion of this tree. No wr pper written,
  core untouched.
- **Cl use (b) of promotion written into the README.** It is the exit code of
  jInvoke-Build Test.InCont inerj, not the suite t lly inside it:  t j3e47c9ej the
  cont iner reported jp ssed=150 f iled=0 skipped=2j  nd the t sk still exited 1.
  The README h d no definition of done  t  ll, so the section w s cre ted to hold
  the rule.
- **jscripts/st te.ps1j runs here.** The gu rd pinned the origin to
  jcl ude.pwsh.im ge.builderj  nd exited 1 in this repository, which is why every
  st te block since birth w s h nd- ssembled. No n me list repl ces it: the origin
  is re d  nd printed,  nd wh t is  sserted is th t the work tree being reported on
  is the work tree this copy of the script lives in. F lsified from  nother clone:
  exit 1, both p ths n med.
- **jscripts/ci/Test-PushGu rd.ps1:44j** n med jconfig/tr iler-gr ndf ther.txtj; the
  file is  t j.continuity/tr iler-gr ndf ther.txtj. Comment only. The proven nce
  he der three lines up cl imed byte-identic l- t-copy-time, which th t edit
  f lsifies, so it moves to  d pted=YES  nd s ys wh t the difference is.

**Tested:** p ssed=151 f iled=0 skipped=2 - in-cont iner, jpwsh 7.6.6j, Pester 6.1.0,
uid 1001, tot l 174, 34.76s, junjustified_skipsj empty  nd both re l skips reported
 s jno-exempt-commit-in-r ngej. Host jTest.Unitj: p ssed=172 f iled=0 skipped=2
NotRun=0 Inconclusive=0. Host jtests/run.ps1j (Pester 5.7.1): 172 p ssed, 0 f iled,
2 skipped. One test  dded this run - the pl n- nnot tion rule - which is the whole
of the 171 to 172  nd 150 to 151 movement.

**F iled:** none.

**Missing:**

- The skip-justific tion g te is still not in the CI required set. Th t is I7, the
  next pull request on this br nch line,  nd jconfig/repo.json -> required_checksj
  is untouched here.
- CI still c nnot run the in-cont iner suite. jvendor/cl ude. gent.corej is   priv te
  submodule  nd j ctions/checkoutj needs   PAT p ssed  s jtoken:j - FINDING-M17,
  Jerry to cre te. The Ledger-t gged tests st y jNotRunj on the runner.
  *Annot ted 2026-09-23, origin l words kept  bove: the priv te premise w s f lse - core
  is public  nd needs no PAT. M17 is retired  t seq 21; see the newer sections.*
- jconfig/repo.json -> repoj still re ds jJerryB lmer1/cl ude.pwsh.im ge.builderj.
  St le in the s me w y jst te.ps1j w s,  nd not fixed here: it is  n input to the
  jgener ted-m tch-configj check  nd ch nging it is its own decision. Listed.
- **The repository is PUBLIC.** jAGENTS.mdj s ys "Never m ke this repo public".
  jst te.ps1j prints the w rning on every run now th t it runs  t  ll. Not  n  gent
  decision to reverse; listed loudly.
- The README still c rries pre-birth wreck ge the cl use-(b) section sits beside:  
  jTest.F ilFirstj row for   t sk th t w s deleted,   jdocker runj ex mple p ssing
  jLEDGER_HOOK_ARM=1j th t jAGENTS.mdj forbids (dis greement row 4),  nd  
  j. gents/BREADCRUMBS.mdj th t does not exist. Row 4  lre dy s ys the README is
  wrong; this run  dded   section r ther th n rebuilding the file.

**Blockers:**

- **No signing key.** Not touched. j ctorj  nd jLEDGER_PRINCIPALj  re
  oper tor- sserted  nd  re pl ces to be c ught lying, not sign tures.
- **Comm nd-hook timeout f ils open.** Not touched. The 15s PreToolUse timeout is
  Cl ude Code sem ntics;   sentinel th t h ngs is   sentinel th t is not consulted.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is not
  relisted; see the 2026-09-21 section for its history.

**Ledger he d h sh:** j841c9dd4 2968 4 e7851bdf74 7c0c083ffe174 5fe9fd 00728 685fec8742j
(receipts  t joutput/ledger/ledger.jsonlj, written by the sentinel b ked into the
im ge. It moves on every jTest.InCont inerj, so jGo l.Upd tej checks its sh pe, not
its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
- c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged by this run  nd
re-verified by jBootstr pj.

**Forensic ch in:** the decision w s recorded BEFORE  ny edit,  t seq 12,
jkind=decisionj, jsubject=tidy-before-promotion-six-itemsj, jprev 41  feb2j,
jself  0 3ce9ej. jGo l.Upd tej  ppends its own jverific tionj record  t the end of
this run, so this run  dds two records.

**F lsified, not  sserted.** The new pl n- nnot tion test w s driven both w ys with
scr tch edits to jdocs/pl ns/2026-09-21-oneshot/END_GOAL.DRAFT.mdj, e ch reverted  nd
the tree verified cle n: jp ssed=109j rewritten to jp ssed=110j g ve exit 1 n ming the
file  nd the v lue,  nd   d ted p st-tense  nnot tion  ppended to the s me file g ve
exit 0. The rewritten jst te.ps1j gu rd w s driven red from  nother clone.

## 2026-09-23 5d48942 run-01

The skip-justific tion g te  nd the condition l skip stop colliding.

**Ch nged:**

- **A second justified form on the g te.** jbuild/InCont iner.Test.ps1j  nd
  jAssert-SuiteCle nj in jbuild/t sks/Test.build.ps1j toler ted   skipped test
  only if it c rried   jBLOCKER-nj t g. They now  lso  ccept
  jSkipWhen:<keb b-re son>j, m tched by
  j^SkipWhen:(?<re son>[ -z0-9]+(-[ -z0-9]+)*)$j. Both forms  re re d off the
  Pester test object — its own t gs plus every p rent block's — so the
  justific tion is   thing the g te me sures r ther th n   comment nobody
  executes.
- **Why not jBLOCKER-nj.** A blocker is   defect someone intends to rep ir  nd
  strike,  nd this repository is retiring them (seq 9, jblocker-1-retiredj).
  "No exempt commit in r nge" is not   defect. It is   st te this tree is in on
  most d ys  nd will re-enter whenever the pull-request r nge holds no
  gr ndf thered commit, so filing it  s   blocker would me n c rrying it on the
  st nding list forever for something nobody pl ns to le ve.
- **The two tests  re t gged, not excused.** jtests/Tr ilers.Tests.ps1j — the
  Co-Authored-By f lsific tion  nd the empty-exemption-list f lsific tion —
  e ch c rry j-T g 'SkipWhen:no-exempt-commit-in-r nge'j beside the existing
  j-Skip:$NothingToF lsifyj from j47e2031j. The t g is on the two jItjs  nd not
  on the jDescribej, bec use the sibling "p sses, using the exemption" does not
  skip  nd must not inherit   justific tion it never needed.
- **The g tes now report WHY.** Both print justified skips grouped by re son.
  joutput/incont iner.jsonj g ins jjustified_skips[]j, e ch entry c rrying
  jtestj, jresultj  nd jre sonj; junjustified_skipsj keeps its me ning  nd is
  now empty. A green log th t s ys "skipped: 2" tells   re der nothing they c n
   ct on.
- **The rule is written once.** jGet-SkipJustific tionj lives in
  jbuild/Build.Helpers.psm1j — pl in PowerShell, no Invoke-Build dependency,
  which is why the cont iner c n import it from the j/workj bind mount. The two
  g tes rem in two implement tions  nd still differ on jNotRunj: the cont iner
  run c rries  n jExcludeT gj filter  nd the host run does not. They no longer
  differ on wh t   justific tion *is*.

**Tested:** p ssed=150 f iled=0 skipped=2 — in-cont iner, jpwsh 7.6.6j,
Pester 6.1.0, uid 1001, 21 Docker-t gged tests jNotRunj by design  nd excluded
from both skip lists. Host jTest.Unitj: p ssed=171 f iled=0 skipped=2
NotRun=0 Inconclusive=0. Before this ch nge both runs were exit 1 on those s me
numbers; only the verdict on the two skips moved.

**F iled:** none.

**Missing:**

- The g te is still not in the CI required set. Th t is I7, explicitly out of
  scope here, so jconfig/repo.json -> required_checksj is untouched.
- jscripts/st te.ps1j still refuses to run in this repository — it  sserts the
  origin is jcl ude.pwsh.im ge.builderj  nd exits 1. Every st te block in this
  run, including the one in the pull request, is h nd- ssembled. Listed, not
  fixed.
- jscripts/ci/Test-PushGu rd.ps1:44j n mes jconfig/tr iler-gr ndf ther.txtj in
  its doc comment; the file is  t j.continuity/tr iler-gr ndf ther.txtj. A
  st le p th in prose, no beh viour  tt ched. Listed, not fixed.
- jdocs/pl ns/ACTIVE.mdj still describes jfe ture/env-loc lj from 2026-09-21,
  two fe tures  go. jAGENTS.mdj's st le-pl n STOP is recorded  s SUSPENDED in
  the dis greement t ble on the grounds th t the file does not exist; it does
  exist. Listed, not fixed — deciding it is not this run's job.

**Blockers:**

- **No signing key.** Not touched. Nothing signs  nything; j ctorj  nd
  jLEDGER_PRINCIPALj  re oper tor- sserted  nd  re pl ces to be c ught lying,
  not sign tures.
- **Comm nd-hook timeout f ils open.** Not touched. The 15s PreToolUse timeout
  is Cl ude Code sem ntics;   sentinel th t h ngs is   sentinel th t is not
  consulted.
- The receipt- ppend export blocker w s struck on 2026-09-23  t seq 9  nd is
  not relisted; see the 2026-09-21 section for its history.

**Ledger he d h sh:** j de4061216bd49047c169c95b23 e0eb4b508114c19180 e1 622d5204f6b3e j
(3 receipts  t joutput/ledger/ledger.jsonlj, written by the sentinel b ked into
the im ge  nd verified by jGet-LedgerVerifyj. It moves on every
jTest.InCont inerj — receipts  ccumul te by design — so jGo l.Upd tej checks
its sh pe, not its v lue.)

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
— c nonic l sh 256 of jprompts/ ssessment.2026-09-21.jsonj, unch nged by this
run  nd re-verified by jBootstr pj.

**Forensic ch in:** the decision w s recorded *before* the edit,  t seq 10,
jkind=decisionj, jsubject=skip-justific tion-formj, jprev f05b175dj,
jself f88886e6j. jGo l.Upd tej  ppends its own jverific tionj record  t the end
of this run, so this run  dds two records, not one.

**F lsified, bec use   g te th t only ever s ys yes is the honour system with
extr  steps.** A scr tch untr cked jtests/Scr tch.F lsify.Tests.ps1j c rrying
one skip with no t g  nd one t gged jSkipWhen:NotAKeb bRe sonj —   spelling the
p ttern rejects — drove both g tes red: jTest.Unitj exit 1  nd
jTest.InCont inerj exit 1, e ch n ming both scr tch skips while still reporting
the two re l ones  s justified. skipped=4 in both runs. The scr tch w s then
removed  nd the tree verified cle n.

## 2026-09-21 06e738d run-01

Getting the im ge from "  hook exists" to "the hook is proven".

**Ch nged:**

- **B se im ge.** jmcr.microsoft.com/powershell:7.4-ubuntu-22.04j is gone from
  both im ges — deprec ted, l st published 2025-02, no 7.6 t g to move to.
  Both now pin jubuntu:24.04@sh 256:008173c2…j by digest  nd inst ll
  PowerShell 7.6.6 from the GitHub rele se t rb ll, with jsh 256sum -cj run
  **before** jt r -xzfj. The three pins  re identic l  cross both Dockerfiles
   nd   test  sserts they h ve not drifted.
- **Sentinel.** Rewritten to the current PreToolUse contr ct. A deny is now
  jhookSpecificOutput.permissionDecisionj on stdout with **exit 0**; the old
  version emitted   deny body  nd then exited 2, so the body w s disc rded
  every time  nd the re son never re ched  nyone. Intern l f ilures  re
  stderr + exit 2 with empty stdout — f il closed. One script, one j-Modej
  switch, both im ges; the developer im ge's second  lw ys- llow copy is
  deleted.
- **Receipts.** Every decision,  llow  nd deny  like,  ppends one Ledger
  record before the decision is returned. A f iled  ppend is exit 2. Schem  v1
  is untouched  t eight keys; the sentinel expresses itself in the existing
  fields  nd h shes the r w stdin p ylo d, so   receipt proves wh t the
  sentinel s w r ther th n wh t it l ter s id  bout it.
- **Ledger vendored.** Both im ges copy jvendor/cl ude.build.ledger/src/ledgerj
  to j/opt/le sh/ledgerj, root:root 0555, from the build context.
- **Entrypoint.** jentrypoint.shj deleted, repl ced by jentrypoint.ps1j. The
  j# TODO: c ll Get-LedgerVerifyj is now  n  ctu l c ll. Policy v lid tion is  
  JSON-structure check, not three greps th t would p ss on   settings file
  merely *mentioning* jPreToolUsej in   comment. Seven distinct exit codes
  (10–15) with one line of re son e ch.
- **M n ged settings.** jpermissions.denyj lists jB shj, jShell(*)j, jEdit(*)j,
  jWrite(*)j. jpermissions. llowj is **empty in both im ges** — the developer
  im ge's old j["B sh(pwsh *)", "B sh(python *)", "B sh(git *)"]j would h ve
  silently defe ted its own sentinel under cl ude-code#18312. The entrypoint
  refuses to boot (exit 11) if   g ted tool ever re ppe rs there.
- **Tests.** jtests/pl n.f ilfirst.ps1j deleted  nd repl ced by five Pester
  suites, 130 tests. jsrc/Pl nV lid tor.ps1j implements the pl n contr ct for
  re l, driven by the schem  file.
- **Build.** Def ult ch in is jBootstr p → Build.Im ge → Test.InCont iner →
  Go l.Upd tej. jTest.F ilFirstj  nd the stub-sc ffolding jIm ges.Build.Agentj
   re deleted; no t sk cre tes the file it is checking  ny more.
- **Continuity.** jscripts/forensic.ps1j is   byte-identic l copy of
  jcl ude.build.ledgerj's (sh 256 j d16 85b355e0090…j), so both repos' ch ins
  sh re   form t  nd   verifier.

**Tested:** p ssed=109 f iled=0 skipped=0 — in-cont iner, jpwsh 7.6.6j,
jPester 6.1.0j, uid 1001, non-root. 21 further tests  re t gged jDockerj  nd
excluded in-cont iner (no d emon in there); they run on the host vi 
jTest.Unitj  nd cover both built im ges. Host run: 109 p ssed, 0 f iled,
0 skipped with the s me exclusion. jInvoke-Build Bootstr p, Build.Im ge,
Test.InCont inerj → jBuild succeeded. 5 t sks, 0 errors, 0 w rningsj.

**F iled:** none.

**Missing:**

- No  gent im ge. jIm ges.Build.Agentj w s deleted r ther th n kept, bec use it
  sc ffolded   pl ceholder Dockerfile on the deprec ted b se with  
  j# TODO: implementj in it the first time  nyone r n it. There is nothing to
  build yet; when there is, it gets built properly.
- jTest.Unitj is not in the def ult ch in, per the run order. The def ult ch in
  re ches the host-only Docker-t gged  ssertions through jInvoke-Build Fullj.
- jpl ns/j cont ins no pl ns, so jPl n.Checkj v lid tes the schem   nd the
  v lid tor but h s nothing to run them  g inst.
- Cl ude Code is inst lled from jhttps://cl ude. i/inst ll.shj, which is
  fetched  t build time  nd not pinned by h sh. The version is pinned by ARG;
  the inst ller script itself is not. Not in scope for run-01, but it is the
  one unverified downlo d left in the im ge.

**Blockers:**

- **The receipt- ppend export — RETIRED 2026-09-23,  nd listed here  s history.**
  At the time of this run the Ledger exported no receipt- ppend function:
  jAdd-LedgerRecordj existed  t jLedger.psm1:298j but w s  bsent from
  jExport-ModuleMemberj  t jLedger.psm1:1121j, so the sentinel re ched it
  through the module's own session st te —   coupling to   priv te n me.
  jGet-LedgerVerifyj *w s* exported even then, so the entrypoint's ch in check
  w s live  nd needed no j-Wh tIfj gu rd. The fix l nded upstre m:  t vendor pin
  j 68664ej the n me is exported by both jledger.psd1:9j  nd
  jledger.psm1:1121-1122j, jhooks/sentinel.ps1j c lls it pl inly,  nd
  jtests/Sentinel.Tests.ps1j  sserts the export r ther th n the work round.
  Retirement recorded on the forensic ch in  t seq 9, jblocker-1-retiredj.
- **No signing key.** Not touched, per the run order. Nothing signs  nything.
- **Comm nd-hook timeout f ils open.** Not touched, per the run order. The 15s
  PreToolUse timeout is Cl ude Code sem ntics;   sentinel th t h ngs is  
  sentinel th t is not consulted.
- **Identity is oper tor- sserted.** Not touched, per the run order.
  jLEDGER_PRINCIPALj is wh tever jdocker run -ej s ys it is. It is not  
  sign ture; it is   pl ce to be c ught lying.

**Ledger he d h sh:** j7e7604105df9555bb93bff22c ec 213cb3f554b4604e20c318003f7d8c3822cj
(3 receipts  t joutput/ledger/ledger.jsonlj, written by the sentinel b ked into
the im ge, ch in verified by jGet-LedgerVerifyj. This is the he d the forensic
record for this run n mes, so the two  gree. It moves on every
jTest.InCont inerj — receipts  ccumul te by design — so jGo l.Upd tej checks
its sh pe, not its v lue; pinning it would m ke the ch in red for the next
person to run it.)

**Forensic  nchor:** jrecords=1 git=06e738d tip= 476fdfdfd48f655 f413d2057e8ff4f58966  7f653f64963500f724706 140j
— j.continuity/forensic.jsonlj, ch in OK. T mper-evident, not t mper-proof:
keep this line somewhere off the tree.

**Assessment h sh:** j798b10ee3c 2d64b28bc779611484ddc0565448c6468 e2dd f54 53 98030 3j
— c nonic l sh 256 (keys sorted ordin l, no whitesp ce) of
jprompts/ ssessment.2026-09-21.jsonj. Th t file did not exist in the repo; it
w s written from the bytes c rried inline in the run order, in c nonic l form,
so the file on disk **is** the bytes th t h sh  nd jsh 256sumj  lone verifies
it. The g te w s f lsified on purpose before being trusted.

### Defects found by running things, not by re ding them

1. jinst ll.shj follows j$HOMEj, so Cl ude Code inst lled into j/root/.loc lj
   (mode 0700). The build w s green; jcl ude --versionj f iled  t run time for
   the non-root user with "not found",  nd jCMDj is j["cl ude"]j.
2. jentrypoint.ps1j h d   jp r m()j block, so PowerShell bound the *comm nd's*
   fl gs to the script: jdocker run <img> pwsh -NoProfile -c 'exit 0'j died
   with "A p r meter c nnot be found th t m tches p r meter n me 'NoProfile'".
3. j$p ylo d = $r w | ConvertFrom-Jsonj in the sentinel — the pipeline unrolls,
   so j[{"tool_n me":"B sh"}]j w s  ccepted  s   v lid p ylo d while  
   two-element  rr y w s correctly rejected. Beh viour th t depended on the
   length of the thing being rejected.
4. The s me enumer tion tr p twice more in jsrc/Pl nV lid tor.ps1j: jreturnj
   from   scriptblock,  nd  n jifj used  s  n expression.
5. My own skip-gu rd counted Pester's jNotRunj (t g-excluded)  s  n
   undocumented skip, which would h ve f iled the ch in over the 21 Docker
   tests th t  re excluded on purpose.

## Merged from docs/END_GOAL.md (Grok, b0232b8)

BLOCKER-11: this repository c rried two files n med jEND_GOAL.mdj. The root one is
lo d-be ring - jInvoke-Build Go l.Upd tej re ds it  nd f ils the build without   section
for the run. The second w s cre ted on joriginj by Grok  nd never merged.

The content below is Grok's, moved VERBATIM  nd not edited. jdocs/END_GOAL.mdj is deleted
in the s me commit. Nothing is lost; it ch nges  ddress  nd s ys whose it is.

Note   cl im in it th t l ter p sses settled: "jAdd-LedgerRecordj not in
jFunctionsToExportj. Fix in jcl ude.build.ledgerj, then pin bump." It w s true when Grok
wrote it  nd it is history now -  t vendor pin j 68664ej the n me IS in jFunctionsToExportj
(jledger.psd1:9j)  nd the pin bump h s l nded. Grok's words  bove  re left ex ctly  s
written; this note is where the correction lives, bec use editing  n  ttributed section to
 gree with   l ter f ct is how   record stops being one.

One objection th t tr velled with th t cl im is NOT settled upstre m,  nd is not quietly
dropped here. The e rlier text cited "the compli nce pl n's D7" for it: exporting the
function r w me ns   receipt c n be  ppended with no v lid ted output behind it, so the
decision w s jAdd-LedgerReceiptj,   constr ined wr pper, r ther th n the r w function.
**Th t pl n file is not in this tree** - jdocs/pl ns/j w s pruned to code-n med files  t
birth (forensic seq 1),  nd jgit grepj finds no D7 here - so the cit tion is c rried, not
verifi ble from this repository. Wh t IS me sur ble, re-me sured 2026-09-23  t vendor pin
j 68664e6b9938773478d967348b590f487fe2443j: jAdd-LedgerReceiptj exists in neither this tree
nor jvendor/cl ude. gent.corej - jgit grepj returns nothing in core,  nd here it returns
only the two prose lines in this note - while core exports the r w jAdd-LedgerRecordj  s one
of five n mes  t jmodules/ledger/ledger.psd1:9j.

**Where it st nds, decided 2026-09-23: OPEN IN CORE, CLOSED IN IMAGES.** A wr pper over  
Ledger export is Ledger API,  nd this repository consumes core r ther th n  dding to it -
there is no pl ce here to put  n jAdd-LedgerReceiptj th t would not immedi tely belong to
core. So the objection stops being c rried  s  n unmet oblig tion of THIS tree, which is how
the line  bove used to re d,  nd is c rried inste d  s  n open objection  g inst core  t the
pin n med. No wr pper is written here  nd core is not touched. Wh t this repository did ch nge
is sm ller  nd is not offered  s meeting the objection: the sentinel depends on   public n me
inste d of   priv te one. Forensic ch in seq 12, jtidy-before-promotion-six-itemsj.

## 2026-09-21 — Grok review of oneshot (this file cre ted on origin)

- Agent: Grok
- Remote m in  t write: j397f631j
- Remote develop  t write: j57637 ej
- PR #5 develop→m in: still open; do not merge until split is rep ired without force-push
- F ble oneshot: ch in cl imed jCOMBINED 34c940 b…j / tip j052d2db7…j / git jeb32496j. Dump not visible on origin/m in  t review time — tre t  s loc l until pushed.
- Ledger: not UNWIRED. jpending-exportsj = jAdd-LedgerRecordj not in FunctionsToExport. Fix in jcl ude.build.ledgerj, then pin bump.
- P th to m in: fe ture → m in while develop CI rejects run-01. L ter merge m in *into* develop. No reb se of run-01.
- Blockers: submodule export line; oneshot  rtif cts not on remote; ArgumentCompleters j#Requiresj; j*.logj vs TRANSCRIPT.log; PR #5 st le body.
