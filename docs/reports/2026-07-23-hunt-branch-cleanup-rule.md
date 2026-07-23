---
proposal: docs/proposals/2026-07-23-branch-cleanup-rule.md
---

# Hunt record — branch-cleanup-rule

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the rule's own text ("when merged directly without a PR, after the branch lands") describes a case where the branch has no remote counterpart, but the mandated step ("delete on both local and remote") assumes one always exists.
Kind: design-error
Seed: proposal adds one sentence to dispatch/hooks/directive.sh's merge/landing section: after a merge/landing, delete the merged source branch locally (`git branch -d`) and on remote (`git push origin --delete`), scoped to never touch main and never an unmerged branch. Proposal text itself carves out the no-PR direct-landing case ("when merged directly without a PR, after the branch lands on the target").

### Reproduce
```
cd /home/jwjung/claude-plugins
git checkout -b local-only-test-branch
git commit --allow-empty -m "test commit"
git checkout main
git merge --no-edit local-only-test-branch   # this is a "landing" per the proposal's own no-PR case
git push origin --delete local-only-test-branch
```

### Observed
```
error: 'local-only-test-branch'를 삭제할 수 없습니다; 리모트 참조가 존재하지 않습니다
error: 레퍼런스를 'github.com:tokenmaxxxer/claude-plugins.git'에 푸시하는데 실패했습니다
```
(git push origin --delete fails with exit 1 because the branch was never pushed — there is no remote ref to delete. Nothing in dispatch/hooks/directive.sh or elsewhere tracks whether a given "landed" branch was ever pushed to origin, so the mandatory "both local and remote" step has no state to consult before running the remote half, and the rule as written cannot be satisfied for its own named case.)

### Expected
The rule should either omit the remote-delete step for branches with no upstream, or the sentence should say so — as written it prescribes an unconditional two-part action (`git branch -d` + `git push origin --delete`) for a case (direct/no-PR landing) that the proposal's own text acknowledges may have no remote branch to delete, with no state anywhere recording push-status to gate that step.

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: FINDING — the proposal restricts edits to `dispatch/hooks/directive.sh` only, but `dispatch/README.md` mirrors the directive's rule list bullet-for-bullet (as `warrant/README.md` mirrors `warrant/hooks/directive.sh`'s ON LANDING wording), so landing the new branch-cleanup rule into directive.sh without touching README.md leaves the README's "What it does" list stale/incomplete — the same class of drift commit 18cdbfe just fixed for a different README claim.
Kind: design-error
Seed: docs/proposals/2026-07-23-branch-cleanup-rule.md — "Edit only dispatch/hooks/directive.sh; a single short rule sentence added to the ... area — no restructuring."

### Reproduce
```
grep -n "MERGE ONLY\|Merge only on explicit" dispatch/hooks/directive.sh dispatch/README.md
```

### Observed
Both files currently list the same bullets 1:1 (issue, PR, feedback-as-comment, progress, merge-on-approval). After the proposed edit, `dispatch/hooks/directive.sh` gains a new "delete the merged branch" rule sentence in the MERGE ONLY area, while `dispatch/README.md`'s "What it does" list (which the repo's own convention — see `warrant/README.md` mirroring `warrant/hooks/directive.sh`'s ON LANDING clause — treats as required to track the directive) is left unchanged and silently omits the new behavior. The write set given in the proposal (`files: - dispatch/hooks/directive.sh`) does not include `dispatch/README.md`, so nothing in the plan carries this update.

### Expected
The write set should include `dispatch/README.md` (or the proposal should explicitly note the README is intentionally left out of sync), consistent with how the repo has previously required README to stay a faithful mirror of directive.sh (commit 18cdbfe: "fix README convergence claim").
