# Solver design and supported semantics

## Problem contract

A problem consists of a finite symmetric numerically positive-semidefinite matrix `P`, vector `q`, finite matrix `A`, and one lower/upper bound pair per row. It minimizes `0.5 * xᵀ P x + qᵀx` subject to `lower ≤ Ax ≤ upper`. Bounds may be unbounded on one side using negative infinity in `lower` or positive infinity in `upper`; NaN and the opposite-signed infinities are invalid. Dimension, finite-value, symmetry, convexity and bound-order checks happen before iteration. Equality constraints use identical finite lower and upper bounds.

## Dense numeric value API

`DenseMatrix` and `DenseVector` constructors copy and validate finite inputs. Their read methods return values or copies, and arithmetic methods return new values rather than mutating operands. Shape mismatch, invalid indices, non-finite input, or non-finite arithmetic is reported as `None` where an operation can fail. LU uses scaled partial pivoting with a caller-configurable relative pivot threshold; Cholesky accepts only numerically symmetric positive-definite matrices. These general dense kernels are independently exposed from the QP model API and have no sparse backend.
## Solver approach

The dense ADMM splitting uses `z = Ax` and projects each row onto its permitted interval. For each call, the solver forms and Cholesky-factorizes `P + rho AᵀA + sigma I`, then reuses that factor within the iteration. `sigma` must be positive, so the x-update remains positive definite even when `P` is singular positive semidefinite.

The solver checks interval feasibility and KKT stationarity using absolute-plus-relative tolerances. The relative primal tolerance is scaled by the largest absolute component of `Ax` or its interval projection `z`, not by the bound values; a very large but loose finite bound therefore cannot mask a violation of the opposite bound. With no constraint rows, the primal scale and residual are zero. It exposes the objective, row-constraint dual multipliers (negative at active lower bounds, positive at active upper bounds), primal feasibility residual, ADMM dual residual, stationarity residual, iteration count and typed status. The status `IterationLimit` means the configured budget expired; it does not prove infeasibility. Callers may provide a finite primal initial vector for repeated nearby solves; dual warm starts, model updates and infeasibility certificates are not provided.

## Numerical acceptance

Tests cover analytically solvable unconstrained, equality, interval, one-sided-bound and singular-PSD cases, zero constraint rows, malformed dimensions, nonsymmetric/indefinite `P`, invalid bounds and budget exhaustion. Tests independently recompute representative objective, feasibility and stationarity values instead of relying only on solver diagnostics. Tolerance behavior and ill-conditioning remain explicit limitations; no sparse-scale or OSQP-performance guarantee is made.




