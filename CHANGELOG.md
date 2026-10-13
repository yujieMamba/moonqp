# Changelog

## Unreleased

- Made `QpProblem` opaque and copy-safe so caller mutation cannot alter a constructed problem.
- Added a dense-first MoonBit solver for continuous convex quadratic programs with linear interval constraints.
- Added finite-checked dense matrix/vector arithmetic with pivoted LU and Cholesky factor APIs.
- Added typed termination and numerical diagnostics; iteration exhaustion is reported as `IterationLimit`, not infeasibility.
- Added runnable control, constrained-estimation, and capacity-allocation examples.
- No release has been published and no MoonCakes package is available yet.

