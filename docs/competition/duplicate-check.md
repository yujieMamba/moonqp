# MoonQP duplicate-check

- Checked: 2026-10-13 (Asia/Shanghai)
- Decision: proceed to local implementation of a general continuous convex QP library, subject to the documented scale and numerical-verification limits.
- Project scope: a reusable MoonBit API accepting a symmetric positive-semidefinite quadratic objective and linear two-sided constraints, `minimize 1/2 xᵀPx + qᵀx` subject to `l ≤ Ax ≤ u`; dense-first, small-to-medium problems. The selected reference is OSQP v1.0.0 (`osqp/osqp`, Apache-2.0; inspected source revision `236713ce9a56c182ac3230d52108f952afce1523`). This is an independent MoonBit rewrite; no upstream source files are copied.
- Intended downstream workflows: model-predictive control with actuator/state limits; constrained parameter estimation; continuous capacity/resource allocation. Each consumes ordinary arrays/matrices and receives a solution plus residual/status diagnostics.
- Non-goals: mixed-integer optimization, nonconvex objectives, a modeling language, automatic differentiation, a high-performance sparse backend, or OSQP-scale performance claims.

## Recorded search scope

MoonCakes package search and `moon search --limit 100` covered quadratic programming/QP, OSQP, ADMM, KKT, optimization, linear algebra, bounded least squares, and model-predictive control. GitHub repository search covered MoonBit-tagged QP, quadratic programming, ADMM, and KKT terms. These indexes are bounded discovery tools, not exhaustive source-code searches. Search hits were inspected at fixed revisions where noted below; the permanent registry was read and semantically compared, including reserved, completed, rejected, and external-checked records. Core capability/API reverse-search terms were included; no absolute absence claim is made.

## Adjacent projects and capability comparison

| Project / inspected revision | Users, input and workflow | Overlap and boundary |
|---|---|---|
| `Freon793/moonopt@0.2.0`, `0632534ce6dc6ca96fd28d643c69fd77016035b0` | LP/MIP models with linear objective terms; simplex/revised simplex and integer workflow | Adjacent optimization API, but no general quadratic objective matrix `P`; not a direct QP substitute. |
| `Yuxiao-Bot/moonbit-kernel-svm@5c9d40c8c9c76cfe0a4b7fff3dee098dcf30042e` (Apache-2.0) | SVM dataset/config -> kernel Gram matrix -> binary/multiclass training; SMO pair updates and SVM-specific KKT diagnostics | A real QP-subclass overlap. Its objective, box/equality constraints and API are SVM-specific; no general `P/q/A/l/u`, generic warm-start/update, or general primal/dual infeasibility classification. |
| `hsy-bit/moonbit-circuit-solver@0.1.1`, `249fad4b2863a4a81cb13a6c7a4924b2e13fa2b0` (Apache-2.0) | Circuit netlist -> MNA linear system -> circuit solution; also exposes linear algebra/MINRES | Potential KKT linear-subsolver reuse, but no QP API. Reviewed MINRES tests did not verify residuals on indefinite KKT systems; a sparse Cholesky path densifies. It is not evidence of a complete QP workflow. |
| `ushironoko/nash-mbt@0.1.1`, repository `pkdxtools/nash-mbt`, `4917b4c026c15886e33c9b1c609ed16d5b7fe32d` (MIT) | Zero-sum matrix game -> LP/simplex, fictitious play and multiplicative weights -> equilibrium | Specialized game/LP workflow; not arbitrary convex QP. |
| `yyyt0807/curvefit@0.2.1`, `43d980b5429d9e5780adf7007fe7c278736104db` (Apache-2.0) | Residual-parameter problem -> dense projected/scaled Levenberg–Marquardt -> fitted parameters | Bounded nonlinear least-squares solver, not general coupled linear-constraint QP. |
| `lhw153766-ctrl/sparse-linalg@0.1.1`, `2da51fcea173fc91fc565605eb62796a9f3e5a41`; `Luna-Flow/linear-algebra@0.5.1`, `01696669d88faf16d073a8f0b78aa644ecb696b3` | Sparse or dense matrix/factorization primitives | Potential numerical backends, not optimization problem modeling, constraint projection, convergence diagnostics, or a QP solve workflow. |

| `MoonOT` (reserved 2026-10-13; finite-support entropic optimal transport) | Measures + pairwise costs + entropy/KL regularization -> transport coupling and marginal diagnostics | A domain-specific entropy-regularized transport objective, not a general quadratic objective with linear two-sided constraints. Kept out of MoonQP scope; do not add OT/Sinkhorn features. |
## Decision and verification boundary

Within the recorded search scope, **no mature direct substitute for a general continuous convex QP API was found**. This is not a claim of zero overlap: kernel SVM includes a specialized QP algorithm, and the circuit solver exposes a potentially reusable KKT linear-system component. The project proceeds only as a general dense-first library with its own end-to-end problem model, ADMM iterations, projection, stopping criteria, solution/status model and tests—not as a competing SVM, LP, circuit package, or standalone linear algebra package.

Numerical validation must independently check objective values, primal/dual residuals, bound handling, scaling/tolerance behavior, and termination states. Iteration exhaustion must never be reported as infeasibility. Any infeasibility certificate exposed publicly must have dedicated tests; otherwise the implementation will report an indeterminate/iteration-limit status. Sparse performance, large-problem guarantees and full OSQP behavioral compatibility remain unsupported unless later demonstrated by measured tests.

## Upstream and license boundary

OSQP v1.0.0 is the algorithm/reference project and is Apache-2.0. The MoonBit implementation is written independently from the published algorithm/API description; no C/Rust implementation source, generated code, or fixture corpus is copied. Any later reuse of upstream text, code, tests or data requires a fresh license/provenance review and explicit attribution before inclusion.