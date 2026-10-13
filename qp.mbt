///|
/// A dense continuous convex quadratic program:
/// minimize 0.5 * x' * P * x + q' * x subject to lower <= A * x <= upper.
/// An immutable-by-API problem snapshot. The constructor copies all supplied
/// arrays so later caller-side mutation cannot change a problem being solved.
pub struct QpProblem {
  p : Array[Array[Double]]
  q : Array[Double]
  a : Array[Array[Double]]
  lower : Array[Double]
  upper : Array[Double]
}

///|
/// Construct a problem from dense row-major matrices. Convexity, dimensions,
/// finite coefficients, and interval bounds are checked by `solve`.
pub fn QpProblem::new(
  p : Array[Array[Double]],
  q : Array[Double],
  a : Array[Array[Double]],
  lower : Array[Double],
  upper : Array[Double],
) -> QpProblem {
  {
    p: copy_matrix(p),
    q: copy_vector(q),
    a: copy_matrix(a),
    lower: copy_vector(lower),
    upper: copy_vector(upper),
  }
}

///|
/// Return `(decision_variable_count, constraint_row_count)` without exposing
/// the model's mutable backing arrays.
pub fn QpProblem::dimensions(self : QpProblem) -> (Int, Int) {
  (self.q.length(), self.a.length())
}

///|
/// Evaluate the quadratic objective at a candidate vector. Invalid model
/// data, a wrong vector length, non-finite values, or arithmetic overflow
/// return `None`.
pub fn QpProblem::objective_at(self : QpProblem, x : Array[Double]) -> Double? {
  match validate_problem(self) {
    Some(_) => return None
    None => ()
  }
  if x.length() != self.q.length() || !all_finite(x) {
    return None
  }
  let value = evaluate_objective(self.p, self.q, x)
  if is_finite(value) {
    Some(value)
  } else {
    None
  }
}

///|
/// Return the maximum non-negative violation of `lower <= A * x <= upper`.
/// A feasible point returns zero; malformed data and arithmetic overflow
/// return `None`.
pub fn QpProblem::max_constraint_violation(
  self : QpProblem,
  x : Array[Double],
) -> Double? {
  match validate_problem(self) {
    Some(_) => return None
    None => ()
  }
  if x.length() != self.q.length() || !all_finite(x) {
    return None
  }
  let ax = mat_vec(self.a, x)
  if !all_finite(ax) {
    return None
  }
  let mut maximum = 0.0
  for row in 0..<ax.length() {
    let lower_violation = if self.lower[row].is_neg_inf() {
      0.0
    } else {
      (self.lower[row] - ax[row]).max(0.0)
    }
    let upper_violation = if self.upper[row].is_pos_inf() {
      0.0
    } else {
      (ax[row] - self.upper[row]).max(0.0)
    }
    if !is_finite(lower_violation) || !is_finite(upper_violation) {
      return None
    }
    maximum = max_double(maximum, lower_violation)
    maximum = max_double(maximum, upper_violation)
  }
  Some(maximum)
}

///|
/// ADMM and termination settings. `sigma` is the positive proximal
/// regularization used to keep each dense x-update positive definite.
pub(all) struct SolverSettings {
  rho : Double
  sigma : Double
  absolute_tolerance : Double
  relative_tolerance : Double
  max_iterations : Int
  initial_x : Array[Double]?
  initial_y : Array[Double]?
}

///|
pub fn SolverSettings::default() -> SolverSettings {
  {
    rho: 1.0,
    sigma: 1.0e-6,
    absolute_tolerance: 1.0e-6,
    relative_tolerance: 1.0e-6,
    max_iterations: 10000,
    initial_x: None,
    initial_y: None,
  }
}

///|
/// The solver reports iteration exhaustion separately; it is not an
/// infeasibility certificate.
pub(all) enum SolveStatus {
  Solved
  IterationLimit
  InvalidProblem(String)
  NumericalError(String)
}

///|
/// A solution and independently useful KKT/ADMM residual diagnostics.
/// `constraint_dual` uses negative multipliers at active lower bounds and
/// positive multipliers at active upper bounds; equality-row multipliers are
/// unrestricted. Solution fields are absent when they are unavailable.
pub(all) struct SolveResult {
  x : Array[Double]
  objective : Double?
  constraint_dual : Array[Double]?
  iterations : Int
  primal_residual : Double?
  dual_residual : Double?
  stationarity_residual : Double?
  status : SolveStatus
}

///|
/// Solve a dense convex QP with a proximal ADMM iteration. No infeasibility
/// claim is made when the iteration limit is reached.
pub fn solve(
  problem : QpProblem,
  settings? : SolverSettings = SolverSettings::default(),
) -> SolveResult {
  let n = problem.q.length()
  let empty_x = Array::make(n, 0.0)
  match validate_settings(settings) {
    Some(message) => return failure(empty_x, InvalidProblem(message))
    None => ()
  }
  match validate_problem(problem) {
    Some(message) => return failure(empty_x, InvalidProblem(message))
    None => ()
  }
  let m = problem.a.length()
  match settings.initial_y {
    Some(initial_y) =>
      if initial_y.length() != m || !all_finite(initial_y) {
        return failure(
          empty_x,
          InvalidProblem("initial_y must be finite and match A row count"),
        )
      }
    None => ()
  }

  let p = symmetric_copy(problem.p)
  if !is_positive_semidefinite(p) {
    return failure(
      empty_x,
      InvalidProblem("P must be numerically positive semidefinite"),
    )
  }
  let n = problem.q.length()
  let rho = settings.rho
  let sigma = settings.sigma
  let system = zero_matrix(n, n)
  for i in 0..<n {
    for j in 0..<n {
      let mut value = p[i][j]
      for row in 0..<m {
        value = value + rho * problem.a[row][i] * problem.a[row][j]
      }
      if i == j {
        value = value + sigma
      }
      if !is_finite(value) {
        return failure(
          empty_x,
          NumericalError("dense normal matrix overflowed"),
        )
      }
      system[i][j] = value
    }
  }
  let factor = match cholesky(system) {
    Some(value) => value
    None =>
      return failure(
        empty_x,
        NumericalError(
          "dense normal matrix was not numerically positive definite",
        ),
      )
  }

  let mut x = match settings.initial_x {
    Some(initial_x) => {
      if initial_x.length() != n || !all_finite(initial_x) {
        return failure(
          empty_x,
          InvalidProblem("initial_x must be finite and match q.length"),
        )
      }
      copy_vector(initial_x)
    }
    None => Array::make(n, 0.0)
  }
  let y = match settings.initial_y {
    Some(initial_y) => copy_vector(initial_y)
    None => Array::make(m, 0.0)
  }
  let mut z = match settings.initial_y {
    Some(_) => {
      let initial_ax = mat_vec(problem.a, x)
      let projected_input = Array::make(m, 0.0)
      for row in 0..<m {
        projected_input[row] = initial_ax[row] + y[row] / rho
      }
      if !all_finite(projected_input) {
        return failure(
          empty_x,
          NumericalError("initial dual projection became non-finite"),
        )
      }
      project(problem, projected_input)
    }
    None => project(problem, mat_vec(problem.a, x))
  }
  let mut iteration = 0
  let mut last_primal = 0.0
  let mut last_dual = 0.0
  let mut last_stationarity = 0.0
  let mut status = IterationLimit
  let mut finished = false
  while iteration < settings.max_iterations && !finished {
    let z_old = copy_vector(z)
    let ax_old = mat_vec(problem.a, x)
    if !all_finite(ax_old) {
      return failure_after(
        x,
        NumericalError("constraint product became non-finite"),
        iteration,
      )
    }
    let rhs = Array::make(n, 0.0)
    for i in 0..<n {
      let mut value = sigma * x[i] - problem.q[i]
      for row in 0..<m {
        value = value + problem.a[row][i] * (rho * z[row] - y[row])
      }
      rhs[i] = value
    }
    let next_x = match cholesky_solve(factor, rhs) {
      Some(value) => value
      None =>
        return failure_after(
          x,
          NumericalError("dense linear solve became non-finite"),
          iteration,
        )
    }
    x = next_x
    let ax = mat_vec(problem.a, x)
    if !all_finite(ax) {
      return failure_after(
        x,
        NumericalError("constraint product became non-finite"),
        iteration,
      )
    }
    let projected_input = Array::make(m, 0.0)
    for row in 0..<m {
      projected_input[row] = ax[row] + y[row] / rho
    }
    if !all_finite(projected_input) {
      return failure_after(
        x,
        NumericalError("interval projection input became non-finite"),
        iteration,
      )
    }
    z = project(problem, projected_input)
    for row in 0..<m {
      y[row] = y[row] + rho * (ax[row] - z[row])
    }
    if !all_finite(y) {
      return failure_after(
        x,
        NumericalError("dual iterate became non-finite"),
        iteration,
      )
    }

    let mut primal = 0.0
    let mut primal_scale = 0.0
    for row in 0..<m {
      primal = max_double(primal, (ax[row] - z[row]).abs())
      primal_scale = max_double(primal_scale, ax[row].abs())
      primal_scale = max_double(primal_scale, z[row].abs())
      if !problem.lower[row].is_neg_inf() {
        primal = max_double(
          primal,
          max_double(0.0, problem.lower[row] - ax[row]),
        )
      }
      if !problem.upper[row].is_pos_inf() {
        primal = max_double(
          primal,
          max_double(0.0, ax[row] - problem.upper[row]),
        )
      }
    }
    let px = mat_vec(p, x)
    let aty = transpose_mat_vec(problem.a, y, n)
    let stationarity = Array::make(n, 0.0)
    let mut dual_scale = 0.0
    for i in 0..<n {
      stationarity[i] = px[i] + problem.q[i] + aty[i]
      dual_scale = max_double(dual_scale, px[i].abs())
      dual_scale = max_double(dual_scale, problem.q[i].abs())
      dual_scale = max_double(dual_scale, aty[i].abs())
    }
    let dual_vector = transpose_mat_vec(
      problem.a,
      vector_difference(z, z_old),
      n,
    )
    let dual = max_abs(dual_vector) * rho
    last_primal = primal
    last_dual = dual
    last_stationarity = max_abs(stationarity)
    if !all_finite(px) ||
      !all_finite(aty) ||
      !all_finite(stationarity) ||
      !is_finite(last_dual) ||
      !is_finite(primal_scale) ||
      !is_finite(dual_scale) {
      return failure_after(
        x,
        NumericalError("residual calculation became non-finite"),
        iteration,
      )
    }

    let primal_limit = settings.absolute_tolerance +
      settings.relative_tolerance * primal_scale
    let dual_limit = settings.absolute_tolerance +
      settings.relative_tolerance * dual_scale
    iteration = iteration + 1
    if primal <= primal_limit && last_stationarity <= dual_limit {
      status = Solved
      finished = true
    }
  }

  let objective = evaluate_objective(p, problem.q, x)
  if !is_finite(objective) {
    return failure_after(
      x,
      NumericalError("objective became non-finite"),
      iteration,
    )
  }
  {
    x,
    objective: Some(objective),
    constraint_dual: Some(copy_vector(y)),
    iterations: iteration,
    primal_residual: Some(last_primal),
    dual_residual: Some(last_dual),
    stationarity_residual: Some(last_stationarity),
    status,
  }
}

///|
fn failure(x : Array[Double], status : SolveStatus) -> SolveResult {
  failure_after(x, status, 0)
}

///|
fn failure_after(
  x : Array[Double],
  status : SolveStatus,
  iterations : Int,
) -> SolveResult {
  {
    x,
    objective: None,
    constraint_dual: None,
    iterations,
    primal_residual: None,
    dual_residual: None,
    stationarity_residual: None,
    status,
  }
}

///|
fn validate_settings(settings : SolverSettings) -> String? {
  if !is_finite(settings.rho) || settings.rho <= 0.0 {
    return Some("rho must be positive and finite")
  }
  if !is_finite(settings.sigma) || settings.sigma <= 0.0 {
    return Some("sigma must be positive and finite")
  }
  if !is_finite(settings.absolute_tolerance) ||
    settings.absolute_tolerance <= 0.0 {
    return Some("absolute_tolerance must be positive and finite")
  }
  if !is_finite(settings.relative_tolerance) ||
    settings.relative_tolerance < 0.0 {
    return Some("relative_tolerance must be non-negative and finite")
  }
  if settings.max_iterations <= 0 {
    return Some("max_iterations must be positive")
  }
  None
}

///|
fn validate_problem(problem : QpProblem) -> String? {
  let n = problem.q.length()
  let m = problem.a.length()
  if n == 0 {
    return Some("the decision vector must have positive length")
  }
  if problem.p.length() != n {
    return Some("P must be square with dimension equal to q.length")
  }
  for row in 0..<n {
    if problem.p[row].length() != n {
      return Some("P must be square with dimension equal to q.length")
    }
    for col in 0..<n {
      if !is_finite(problem.p[row][col]) {
        return Some("P entries must be finite")
      }
    }
  }
  for i in 0..<n {
    if !is_finite(problem.q[i]) {
      return Some("q entries must be finite")
    }
  }
  if problem.lower.length() != m || problem.upper.length() != m {
    return Some("A, lower, and upper must have the same row count")
  }
  for row in 0..<m {
    if problem.a[row].length() != n {
      return Some("each row of A must have q.length columns")
    }
    for col in 0..<n {
      if !is_finite(problem.a[row][col]) {
        return Some("A entries must be finite")
      }
    }
    let lower = problem.lower[row]
    let upper = problem.upper[row]
    if lower.is_nan() || lower.is_pos_inf() {
      return Some("lower bounds may be finite or negative infinity")
    }
    if upper.is_nan() || upper.is_neg_inf() {
      return Some("upper bounds may be finite or positive infinity")
    }
    if lower > upper {
      return Some("each lower bound must not exceed its upper bound")
    }
  }
  let scale = max_abs_matrix(problem.p)
  let symmetry_tolerance = 1.0e-10 * scale
  for i in 0..<n {
    for j in 0..<i {
      if (problem.p[i][j] - problem.p[j][i]).abs() > symmetry_tolerance {
        return Some("P must be symmetric")
      }
    }
  }
  None
}

///|
fn symmetric_copy(matrix : Array[Array[Double]]) -> Array[Array[Double]] {
  let n = matrix.length()
  let result = zero_matrix(n, n)
  for i in 0..<n {
    for j in 0..<n {
      result[i][j] = matrix[i][j] * 0.5 + matrix[j][i] * 0.5
    }
  }
  result
}

///|
fn is_positive_semidefinite(matrix : Array[Array[Double]]) -> Bool {
  let n = matrix.length()
  let work = symmetric_copy(matrix)
  let tolerance = 1.0e-10 * max_abs_matrix(work)
  let rotation_tolerance = 1.0e-15 * max_abs_matrix(work)
  let mut sweep = 0
  let mut converged = false
  while sweep < 64 && !converged {
    let mut changed = false
    for p in 0..<n {
      for q in (p + 1)..<n {
        let apq = work[p][q]
        if apq.abs() > rotation_tolerance {
          changed = true
          let tau = (work[q][q] - work[p][p]) / (2.0 * apq)
          let t = if tau >= 0.0 {
            1.0 / (tau + (1.0 + tau * tau).sqrt())
          } else {
            -1.0 / (-tau + (1.0 + tau * tau).sqrt())
          }
          let cosine = 1.0 / (1.0 + t * t).sqrt()
          let sine = t * cosine
          let app = work[p][p]
          let aqq = work[q][q]
          for k in 0..<n {
            if k != p && k != q {
              let akp = work[k][p]
              let akq = work[k][q]
              let next_kp = cosine * akp - sine * akq
              let next_kq = sine * akp + cosine * akq
              work[k][p] = next_kp
              work[p][k] = next_kp
              work[k][q] = next_kq
              work[q][k] = next_kq
            }
          }
          work[p][p] = app - t * apq
          work[q][q] = aqq + t * apq
          work[p][q] = 0.0
          work[q][p] = 0.0
        }
      }
    }
    converged = !changed
    sweep = sweep + 1
  }
  if !converged {
    let mut largest = 0.0
    for i in 0..<n {
      for j in 0..<n {
        if i != j {
          largest = max_double(largest, work[i][j].abs())
        }
      }
    }
    converged = largest <= tolerance
  }
  if !converged {
    return false
  }
  for i in 0..<n {
    if !is_finite(work[i][i]) || work[i][i] < -tolerance {
      return false
    }
  }
  true
}

///|
fn cholesky(matrix : Array[Array[Double]]) -> Array[Array[Double]]? {
  let n = matrix.length()
  let lower = zero_matrix(n, n)
  for i in 0..<n {
    for j in 0..<=i {
      let mut value = matrix[i][j]
      for k in 0..<j {
        value = value - lower[i][k] * lower[j][k]
      }
      if i == j {
        if !is_finite(value) || value <= 0.0 {
          return None
        }
        lower[i][j] = value.sqrt()
      } else {
        lower[i][j] = value / lower[j][j]
        if !is_finite(lower[i][j]) {
          return None
        }
      }
    }
  }
  Some(lower)
}

///|
fn cholesky_solve(
  lower : Array[Array[Double]],
  rhs : Array[Double],
) -> Array[Double]? {
  let n = rhs.length()
  let forward = Array::make(n, 0.0)
  for i in 0..<n {
    let mut value = rhs[i]
    for j in 0..<i {
      value = value - lower[i][j] * forward[j]
    }
    forward[i] = value / lower[i][i]
    if !is_finite(forward[i]) {
      return None
    }
  }
  let result = Array::make(n, 0.0)
  for offset in 0..<n {
    let i = n - 1 - offset
    let mut value = forward[i]
    for j in (i + 1)..<n {
      value = value - lower[j][i] * result[j]
    }
    result[i] = value / lower[i][i]
    if !is_finite(result[i]) {
      return None
    }
  }
  Some(result)
}

///|
fn project(problem : QpProblem, values : Array[Double]) -> Array[Double] {
  let result = Array::make(values.length(), 0.0)
  for i in 0..<values.length() {
    if values[i] < problem.lower[i] {
      result[i] = problem.lower[i]
    } else if values[i] > problem.upper[i] {
      result[i] = problem.upper[i]
    } else {
      result[i] = values[i]
    }
  }
  result
}

///|
fn mat_vec(
  matrix : Array[Array[Double]],
  vector : Array[Double],
) -> Array[Double] {
  let result = Array::make(matrix.length(), 0.0)
  for i in 0..<matrix.length() {
    let mut sum = 0.0
    for j in 0..<vector.length() {
      sum = sum + matrix[i][j] * vector[j]
    }
    result[i] = sum
  }
  result
}

///|
fn transpose_mat_vec(
  matrix : Array[Array[Double]],
  vector : Array[Double],
  n : Int,
) -> Array[Double] {
  let result = Array::make(n, 0.0)
  for i in 0..<matrix.length() {
    for j in 0..<n {
      result[j] = result[j] + matrix[i][j] * vector[i]
    }
  }
  result
}

///|
fn vector_difference(
  left : Array[Double],
  right : Array[Double],
) -> Array[Double] {
  let result = Array::make(left.length(), 0.0)
  for i in 0..<left.length() {
    result[i] = left[i] - right[i]
  }
  result
}

///|
fn evaluate_objective(
  p : Array[Array[Double]],
  q : Array[Double],
  x : Array[Double],
) -> Double {
  let px = mat_vec(p, x)
  let mut value = 0.0
  for i in 0..<x.length() {
    value = value + 0.5 * x[i] * px[i] + q[i] * x[i]
  }
  value
}

///|
fn max_abs(values : Array[Double]) -> Double {
  let mut result = 0.0
  for value in values {
    result = max_double(result, value.abs())
  }
  result
}

///|
fn max_abs_matrix(matrix : Array[Array[Double]]) -> Double {
  let mut result = 0.0
  for row in matrix {
    result = max_double(result, max_abs(row))
  }
  result
}

///|
fn all_finite(values : Array[Double]) -> Bool {
  for value in values {
    if !is_finite(value) {
      return false
    }
  }
  true
}

///|
fn is_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn copy_vector(values : Array[Double]) -> Array[Double] {
  let result = Array::make(values.length(), 0.0)
  for i in 0..<values.length() {
    result[i] = values[i]
  }
  result
}

///|
fn copy_matrix(values : Array[Array[Double]]) -> Array[Array[Double]] {
  let result = Array::make(values.length(), [])
  for i in 0..<values.length() {
    result[i] = copy_vector(values[i])
  }
  result
}

///|
fn max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn zero_matrix(rows : Int, columns : Int) -> Array[Array[Double]] {
  let result = Array::make(rows, Array::make(0, 0.0))
  for i in 0..<rows {
    result[i] = Array::make(columns, 0.0)
  }
  result
}
