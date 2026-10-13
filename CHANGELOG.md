# Changelog

## Unreleased

- Add a one-shot dense matrix solve convenience API while retaining reusable LU factors.
- Add inverse construction from reusable pivoted LU factors.
- Add read-only QP model dimension introspection.
- Support validated primal warm starts for repeated nearby QP solves.
- Expose row-constraint Lagrange multipliers with a documented lower/upper sign convention.
- Preserve completed iteration counts when a later numerical calculation fails.
- Added candidate objective and maximum interval-violation evaluators on `QpProblem`.
- Made `QpProblem` opaque and copy-safe so caller mutation cannot alter a constructed problem.
- Added a dense-first MoonBit solver for continuous convex quadratic programs with linear interval constraints.
- Added finite-checked dense matrix/vector arithmetic with pivoted LU and Cholesky factor APIs.
- Added typed termination and numerical diagnostics; iteration exhaustion is reported as `IterationLimit`, not infeasibility.
- Added runnable control, constrained-estimation, and capacity-allocation examples.
- No release has been published and no MoonCakes package is available yet.

