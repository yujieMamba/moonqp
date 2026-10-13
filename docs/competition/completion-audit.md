# MoonQP completion audit

Audit date: 2026-10-13 (Asia/Shanghai). This document records the locally reproducible state before any GitHub remote write. GitHub ownership, public visibility, CI run, and Release remain pending the explicit account gate; update this audit after remote delivery.

## Project and identity

- Project: MoonQP, a dense-first MoonBit library for continuous convex quadratic programs.
- Participant/contact: 骆允泽 / LuoYunze06.
- Intended public repository: `https://github.com/yujieMamba/moonqp` (not yet created or verified).
- Repository-local Git identity: `LuoYunze06 <238675390+LuoYunze06@users.noreply.github.com>`; verified from `.git/config`. No global Git identity was changed.
- The 21 commits present before this audit entry all have the repository-local author and committer. For the participant-requested 20-commit threshold, the conservative inventory below excludes `b587fabe1b9fef387f8710ed1ab4a5559aa4a5b7`, which only adds `.gitattributes` line-ending policy. It is not counted as a functional deliverable. The other 20 listed commits are independently reviewable implementation, test, CI, or user documentation work; this audit entry is one additional substantive documentation commit.
- The inventory covers commits through `df3c15063567e1a126b063f7084b389515ebf842`; this audit itself is a separate documentation deliverable and is not included in that inventory.

## Effective commit inventory

| SHA | Theme | Change summary | Verification evidence |
|---|---|---|---|
| `9432b2d4daf8a79fa78efd0ceb66e6a2ed2fabf6` | Initial solver and dense algebra | Adds the ADMM convex-QP core and reusable dense numeric package. | Final wasm-gc/wasm/js test and build suites; 55 tests pass per test target. |
| `a130450dd4e0b35a8cb8798b552dad7d95d9b2c2` | Model ownership | Snapshots constructor arrays behind an opaque problem model. | Constructor mutation regression is included in the passing 55-test suite. |
| `83bd0823fc710c90f125e5eb78a24928fdf23796` | Candidate diagnostics | Adds objective and interval-violation evaluation. | Objective/feasibility tests and all three executable examples pass. |
| `1077d3e449074e72c137ada4f4111ab01fd98654` | Numerical failure reporting | Preserves completed iteration progress when arithmetic fails. | Numerical-overflow regression tests pass in each available test target. |
| `bfe1a39ff21a2c73640e5a7d69bb67fe9d40ff86` | Dual result API | Exposes row-ordered constraint multipliers. | Dual sign and result tests pass in the 55-test suite. |
| `d5de04707692d988c952e275c53924b49f8cbb24` | Primal warm starts | Adds validated initial decision vectors. | Warm-start behavior and malformed-input tests pass. |
| `6c4691e46e57a16c55433742d205356225e430e5` | Model dimensions | Exposes read-only variable and constraint counts. | Public interface refreshed by `moon info`; all target checks pass. |
| `3cc5ca5af136deb2ba7c140570b5f21f2d3b24dc` | Dense inverse API | Builds inverses from reusable LU factors. | Dense algebra tests pass across wasm-gc, wasm, and js. |
| `367cb321b99071610ef441b475cc8278e404b626` | One-shot dense solve | Adds a shape-checked matrix solve convenience operation. | Dense solve tests pass across wasm-gc, wasm, and js. |
| `9380fa8ef959f55efa1b7ff93e2d12ebc982bfee` | Bound tolerance fix | Prevents large inactive interval bounds from masking primal violations. | Large-bound feasibility regression passes in the final test suite. |
| `9bd8cd9ce7f14fabf1bf5db83b60bfb23f6ab840` | Target-matrix CI | Adds check/build/test CI coverage for configured MoonBit targets. | Workflow inspected locally; hosted CI result is pending repository creation. |
| `eed8198eb758ff9937f8439445242122b1f1bd29` | Executable example assertions | Makes examples assert solution status and independent feasibility. | MPC, estimation, and allocation examples all run successfully under wasm-gc. |
| `8f3793f44f72b6c3c7e2d2f3964a42c44500d299` | Dual warm starts | Accepts validated row-ordered initial multipliers. | Warm-start sign, equality, and invalid-input regressions pass. |
| `8b61647349f2d0910a6af4a02c9dbbc09e881b76` | Constraint evaluation | Adds detached `A x` evaluation in row order. | Constraint-value order, isolation, and overflow tests pass. |
| `e3efd316f2c16d3e761444cac8806ee0a12ef6a8` | Convexity threshold | Tightens rejection of materially negative curvature. | Scale and near-PSD boundary regressions pass. |
| `641eeb2f557ff8a2b0f5ae4b55624846f7d5513a` | Multiple dense right-hand sides | Reuses a factorization across matrix-column right-hand sides. | `solve_many` algebra tests pass across wasm-gc, wasm, and js. |
| `e983e3c2fca30527360e2886a7931a50f332914a` | Dual semantics tests | Verifies lower/upper/equality multiplier conventions for warm starts. | Dedicated multiplier semantic tests pass. |
| `30d1300ee8a25667501443ace3abd844d5245409` | Gradient and stationarity API | Adds checked detached `P x + q` and `P x + q + Aᵀy` evaluators with analytic, finite-difference, dimension, finiteness, and overflow tests. | `moon test` passes 55/55 for wasm-gc, wasm, and js; public interface refreshed. |
| `937dd6e7c1fb830520d8ed278fd1c2d90605b6ca` | Permutation regression | Verifies coupled variable/constraint permutations preserve solution, objective, feasibility, dual sign, and KKT residual. | Dedicated regression passes under wasm-gc; complete 55-test suites pass on wasm and js too. |
| `df3c15063567e1a126b063f7084b389515ebf842` | MPC warm-start example | Demonstrates a neighboring control QP using both prior primal and dual iterates. | Updated MPC example runs and checks both expected solutions. |

## Local verification

- `moon info`, `moon fmt`, `moon fmt --check`: passed.
- `moon check --deny-warn --target wasm-gc|wasm|js|native`: passed for all four targets.
- `moon test --deny-warn --target wasm-gc`: 55/55 passed; `moon test --target wasm|js`: 55/55 passed on each target.
- `moon build --target wasm-gc|wasm|js`: passed.
- `moon test --target native`: not locally runnable because this Windows environment has no `cc`, `gcc`, or `clang`; this is not reported as a pass. The CI workflow includes native build and test on Ubuntu.
- `moon run --target wasm-gc examples/mpc`, `examples/estimation`, and `examples/allocation`: all passed with expected output and feasibility checks.
- `git diff --check`: passed.
- Library source size: 2,052 physical lines in root non-test `dense.mbt` and `qp.mbt` (1,171 + 881); tests and generated interfaces are excluded from this count.
- License: root Apache-2.0 `LICENSE`. `THIRD-PARTY-NOTICES.md` identifies OSQP v1.0.0 (Apache-2.0) as an algorithm/API reference only; no upstream implementation source or fixtures are bundled.

## Remote handoff still required

No remote has been added, and no repository creation, push, tag, Release, or other remote write has occurred. Immediately before the first remote write, run both `gh auth status` and `gh api user`; proceed only if the active account is exactly `yujieMamba`. If it differs, stop and request web authorization; do not switch accounts. After push, verify public visibility, default branch, commit attribution, permissions, and a green CI run, then create a GitHub Release and update this section with its verified links. MoonCakes publication is deliberately not performed here and remains a participant action.

## Remote delivery verification — 2026-10-13 (Asia/Shanghai)

This append-only addendum supersedes the earlier pending-remote statements for the delivery state recorded here; the pre-remote local test inventory above remains a historical record.

- Public repository: https://github.com/yujieMamba/moonqp. GitHub API verified `visibility=public`, `default_branch=main`, and administrator/push permission for the verified account. The pushed `main` update was a fast-forward from `bf47765c3cc2b72622517e781443544ba7de4ea7` to `33d97f9d2cb2c6a06ad02f5f747af0a73eece805`.
- Account isolation: before the push, a short-lived process selected the saved `yujieMamba` credential without switching the GitHub CLI active account. `gh auth status` identified `yujieMamba (GH_TOKEN)` and `gh api user` returned the exact login. Git HTTPS used a command-scoped `gh auth git-credential` helper; no token was printed or stored, and no global Git identity or persistent credential-helper setting was changed.
- At commit `33d97f9`, all 24 raw commits had author and committer `LuoYunze06 <238675390+LuoYunze06@users.noreply.github.com>`. The conservative inventory above already identifies 20 independently reviewable commits meeting the participant's threshold and excludes `b587fabe1b9fef387f8710ed1ab4a5559aa4a5b7` from that count; the later MoonBit compatibility and CI fixes are not needed to reach the minimum.
- Hosted CI for `33d97f9` passed in full: https://github.com/yujieMamba/moonqp/actions/runs/38400239871 . The `wasm-gc`, `wasm`, `js`, `native`, and format/interface/examples jobs all concluded `success`. Native was verified by Ubuntu CI, not claimed as a local Windows test.
- The outside-Git Chinese application is `C:/Users/42673/Desktop/工作区/MoonQP-申报书.md`; `scripts/check_submission.py --strict` passed (33 lines, 1,446 characters). It remains outside the repository.
- Release gate: this audit addendum is a real repository documentation change, so it must be committed and pushed, and its resulting `main` SHA must receive a complete green CI run before it can be the `v0.1.0` source Release target. Planned Release page: https://github.com/yujieMamba/moonqp/releases/tag/v0.1.0. At the time this addendum was written, that tag and Release had not yet been created.
- MoonCakes publication: not performed; it remains a separate manual participant action.
