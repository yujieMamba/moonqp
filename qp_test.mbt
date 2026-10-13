///|
test "unconstrained quadratic reaches its analytic minimizer" {
  let problem = @moonqp.QpProblem::new([[2.0]], [-4.0], [], [], [])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 2.0).abs() <= 1.0e-4)
  assert_true((result.objective.unwrap() + 4.0).abs() <= 1.0e-4)
  let independent_gradient = 2.0 * result.x[0] - 4.0
  assert_true(independent_gradient.abs() <= 1.0e-4)
  assert_true(result.stationarity_residual.unwrap() <= 2.0e-6)
}

///|
test "equality constraint is retained by interval projection" {
  let problem = @moonqp.QpProblem::new([[1.0]], [0.0], [[1.0]], [3.0], [3.0])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 3.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() - 4.5).abs() <= 1.0e-4)
  assert_true(result.primal_residual.unwrap() <= 5.0e-6)
}

///|
test "two-sided bound selects the constrained endpoint" {
  let problem = @moonqp.QpProblem::new([[1.0]], [-4.0], [[1.0]], [1.0], [2.0])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 2.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 6.0).abs() <= 1.0e-4)
}

///|
test "iteration exhaustion is not reported as infeasibility" {
  let problem = @moonqp.QpProblem::new([[2.0]], [-4.0], [], [], [])
  let settings = {
    ..@moonqp.SolverSettings::default(),
    max_iterations: 1,
    absolute_tolerance: 1.0e-14,
    relative_tolerance: 0.0,
  }
  let result = @moonqp.solve(problem, settings~)
  assert_true(result.status is IterationLimit)
  assert_eq(result.iterations, 1)
  assert_true(result.objective is Some(_))
}

///|
test "indefinite objective matrix is rejected" {
  let problem = @moonqp.QpProblem::new([[-1.0]], [0.0], [], [], [])
  let result = @moonqp.solve(problem)
  assert_true(result.status is InvalidProblem(_))
  assert_true(result.objective is None)
}

///|
test "asymmetric objective matrix is rejected" {
  let problem = @moonqp.QpProblem::new(
    [[1.0, 0.5], [0.0, 1.0]],
    [0.0, 0.0],
    [],
    [],
    [],
  )
  let result = @moonqp.solve(problem)
  assert_true(result.status is InvalidProblem(_))
}

///|
test "semidefinite flat unconstrained problem is supported" {
  let problem = @moonqp.QpProblem::new([[0.0]], [0.0], [], [], [])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_eq(result.objective.unwrap(), 0.0)
}

///|
test "contradictory interval is invalid input" {
  let problem = @moonqp.QpProblem::new([[1.0]], [0.0], [[1.0]], [2.0], [1.0])
  let result = @moonqp.solve(problem)
  assert_true(result.status is InvalidProblem(_))
}

///|
test "dense two-variable solve uses independent matrix rows" {
  let problem = @moonqp.QpProblem::new(
    [[4.0, 1.0], [1.0, 2.0]],
    [-1.0, -1.0],
    [],
    [],
    [],
  )
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 1.0 / 7.0).abs() <= 2.0e-5)
  assert_true((result.x[1] - 3.0 / 7.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 2.0 / 7.0).abs() <= 2.0e-5)
  let independent_g0 = 4.0 * result.x[0] + result.x[1] - 1.0
  let independent_g1 = result.x[0] + 2.0 * result.x[1] - 1.0
  assert_true(independent_g0.abs() <= 1.0e-4)
  assert_true(independent_g1.abs() <= 1.0e-4)
}

///|
test "wrong matrix dimensions are rejected before iteration" {
  let problem = @moonqp.QpProblem::new([[1.0, 0.0]], [0.0, 0.0], [], [], [])
  let result = @moonqp.solve(problem)
  assert_true(result.status is InvalidProblem(_))
  assert_eq(result.iterations, 0)
}

///|
test "rank-deficient positive semidefinite objective is accepted" {
  let problem = @moonqp.QpProblem::new(
    [[1.0, 1.0], [1.0, 1.0]],
    [-2.0, -2.0],
    [],
    [],
    [],
  )
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 1.0).abs() <= 2.0e-5)
  assert_true((result.x[1] - 1.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 2.0).abs() <= 2.0e-5)
}

///|
test "small-scale indefinite objective is not hidden by absolute tolerance" {
  let problem = @moonqp.QpProblem::new([[-1.0e-20]], [0.0], [], [], [])
  let result = @moonqp.solve(problem)
  assert_true(result.status is InvalidProblem(_))
}

///|
test "one-sided upper bound clamps an otherwise larger minimizer" {
  let plus_inf = 1.0 / 0.0
  let problem = @moonqp.QpProblem::new([[1.0]], [-2.0], [[1.0]], [-plus_inf], [
    1.0,
  ])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 1.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 1.5).abs() <= 2.0e-5)
  let independently_measured_violation = (result.x[0] - 1.0).max(0.0)
  assert_true(independently_measured_violation <= 2.0e-5)
}

///|
test "one-sided lower bound clamps an otherwise smaller minimizer" {
  let plus_inf = 1.0 / 0.0
  let problem = @moonqp.QpProblem::new([[1.0]], [2.0], [[1.0]], [-1.0], [
    plus_inf,
  ])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] + 1.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 1.5).abs() <= 2.0e-5)
  let independently_measured_violation = (-1.0 - result.x[0]).max(0.0)
  assert_true(independently_measured_violation <= 2.0e-5)
}

///|
test "fully unbounded row preserves the unconstrained minimizer" {
  let plus_inf = 1.0 / 0.0
  let problem = @moonqp.QpProblem::new([[2.0]], [-6.0], [[3.0]], [-plus_inf], [
    plus_inf,
  ])
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 3.0).abs() <= 2.0e-5)
  assert_true((result.objective.unwrap() + 9.0).abs() <= 2.0e-5)
}

///|
test "opposite-signed and NaN bounds are rejected" {
  let plus_inf = 1.0 / 0.0
  let nan = plus_inf - plus_inf
  let invalid_lower = @moonqp.QpProblem::new(
    [[1.0]],
    [0.0],
    [[1.0]],
    [plus_inf],
    [plus_inf],
  )
  let invalid_upper = @moonqp.QpProblem::new(
    [[1.0]],
    [0.0],
    [[1.0]],
    [-plus_inf],
    [-plus_inf],
  )
  let invalid_nan = @moonqp.QpProblem::new([[1.0]], [0.0], [[1.0]], [nan], [1.0])
  assert_true(@moonqp.solve(invalid_lower).status is InvalidProblem(_))
  assert_true(@moonqp.solve(invalid_upper).status is InvalidProblem(_))
  assert_true(@moonqp.solve(invalid_nan).status is InvalidProblem(_))
}

///|
test "non-finite objective and constraint coefficients are rejected" {
  let plus_inf = 1.0 / 0.0
  let nan = plus_inf - plus_inf
  let bad_p = @moonqp.QpProblem::new([[nan]], [0.0], [], [], [])
  let bad_q = @moonqp.QpProblem::new([[1.0]], [plus_inf], [], [], [])
  let bad_a = @moonqp.QpProblem::new([[1.0]], [0.0], [[nan]], [0.0], [1.0])
  assert_true(@moonqp.solve(bad_p).status is InvalidProblem(_))
  assert_true(@moonqp.solve(bad_q).status is InvalidProblem(_))
  assert_true(@moonqp.solve(bad_a).status is InvalidProblem(_))
}

///|
test "invalid solver settings are rejected before iteration" {
  let problem = @moonqp.QpProblem::new([[1.0]], [0.0], [], [], [])
  let bad_rho = { ..@moonqp.SolverSettings::default(), rho: 0.0, }
  let bad_sigma = { ..@moonqp.SolverSettings::default(), sigma: -1.0, }
  let bad_tolerance = {
    ..@moonqp.SolverSettings::default(),
    relative_tolerance: -0.1,
  }
  let bad_iteration_limit = {
    ..@moonqp.SolverSettings::default(),
    max_iterations: 0,
  }
  for settings in [bad_rho, bad_sigma, bad_tolerance, bad_iteration_limit] {
    let result = @moonqp.solve(problem, settings~)
    assert_true(result.status is InvalidProblem(_))
    assert_eq(result.iterations, 0)
    assert_true(result.objective is None)
  }
}

///|
test "empty constraint set solves a rank-deficient convex objective" {
  let problem = @moonqp.QpProblem::new(
    [[1.0, 1.0], [1.0, 1.0]],
    [-2.0, -2.0],
    [],
    [],
    [],
  )
  let result = @moonqp.solve(problem)
  assert_true(result.status is Solved)
  assert_true((result.x[0] - 1.0).abs() <= 2.0e-5)
  assert_true((result.x[1] - 1.0).abs() <= 2.0e-5)
  // Recompute the objective from P, q, and x instead of trusting diagnostics.
  let x0 = result.x[0]
  let x1 = result.x[1]
  let objective = 0.5 * (x0 + x1) * (x0 + x1) - 2.0 * x0 - 2.0 * x1
  assert_true((objective + 2.0).abs() <= 2.0e-5)
}
