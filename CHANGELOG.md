# Changelog

## Unreleased

- Add column-wise multi-right-hand-side solves to reusable LU and Cholesky factors without refactorization.
- Tighten the Jacobi PSD eigenvalue cutoff to `1e-14 * max_abs(P)`, rejecting material negative curvature while retaining roundoff tolerance for rank-deficient PSD inputs.
- Add `QpProblem::stationarity_at` for detached KKT stationarity-vector evaluation with row-ordered duals, documented multiplier signs, and checked inputs/overflow.
- Add `QpProblem::gradient_at` for detached decision-space `P x + q` evaluation with checked model symmetry, dimensions, finite inputs, and arithmetic overflow.
- Add `QpProblem::constraint_values_at` for detached, row-ordered `A x` evaluation with checked dimensions, finite inputs, and arithmetic overflow.
- Support optional finite, row-ordered dual warm starts for repeated nearby QP solves; omitted values preserve the zero-dual initialization.
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

