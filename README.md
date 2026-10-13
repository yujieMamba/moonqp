# MoonQP

MoonQP is an independent MoonBit library for solving **dense continuous convex quadratic programs** with linear interval constraints.

It solves

```text
minimize    1/2 xᵀ P x + qᵀ x
subject to  lower ≤ A x ≤ upper
```

where `P` must be finite, symmetric, and numerically positive semidefinite. Bounds can be one-sided unbounded by using negative infinity in `lower` or positive infinity in `upper`; NaN and opposite-signed infinities are rejected. The current implementation uses a dense ADMM splitting with interval projection and a Cholesky factorization of the per-solve normal matrix. It is intended as a reusable solver core for small-to-medium control, estimation, and resource-allocation models—not as a sparse or large-scale solver.

## Scope and status semantics

- The QP API accepts row-major dense arrays and checks dimensions, finite coefficients, matrix symmetry and numerical convexity, and bound ordering before iteration.
- `SolverSettings` exposes `rho`, proximal `sigma`, absolute/relative tolerances, and an iteration limit.
- A result contains the candidate vector, objective, iteration count, residual diagnostics, and a typed status.
- `IterationLimit` means only that the configured budget ended. It is **not** an infeasibility certificate.
- Mixed-integer and nonconvex models, sparse matrices, warm starts, in-place model updates, adaptive penalty updates, scaling, and infeasibility certificates are outside the current supported contract. No OSQP performance or behavioral parity is claimed.

## Reusable dense numeric primitives

The same package also exposes finite-valued `DenseMatrix` and `DenseVector` types with copy-safe construction/access, shape-checked arithmetic and products, and norm helpers. `DenseMatrix::lu()` provides a scaled-partial-pivoting factor for general nonsingular square matrices; `DenseMatrix::cholesky()` provides a factor for symmetric positive-definite matrices, with solve and inverse operations. Invalid shapes, non-finite inputs, singular factors, and arithmetic overflow are returned as `None` rather than silently publishing non-finite results. These routines are dense numerical foundations; sparse storage and sparse factorization are not included.
## Examples

Each example is an executable MoonBit package:

```sh
moon run --target wasm-gc examples/mpc
moon run --target wasm-gc examples/estimation
moon run --target wasm-gc examples/allocation
```

They show a bounded two-step control decision, a constrained linear least-squares estimate expressed as a QP, and a capacity-limited allocation. These are illustrative workflows; they do not imply specialized MPC, statistical-estimation, or scheduling APIs.

## Use from MoonBit

The central API is `QpProblem::new(...)`, `SolverSettings::default()`, and `solve(problem, settings?)`. See the executable examples for complete model construction and result handling. The module name is `LuoYunze06/moonqp`. MoonQP has not been published to MoonCakes; these repository-local examples are the currently verified consumer integration. A registry installation path is not available yet.

## Development checks

```sh
moon info
moon fmt --check
moon check --deny-warn
moon test --target wasm-gc
```

The CI workflow additionally checks the configured compiler targets and runs executable examples. A native target is only considered locally verified when the required native toolchain is present and the command succeeds.

## Reference and license

MoonQP is independently implemented in MoonBit. OSQP v1.0.0 is documented as an algorithm/API reference in [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md); no OSQP implementation source or fixture corpus is bundled. MoonQP is licensed under Apache-2.0; see [`LICENSE`](LICENSE).



