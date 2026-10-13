///|
fn main {
  // Two-step actuator plan: track a modest first setpoint and a higher second
  // setpoint while penalizing abrupt changes. Both controls are capped at 0.8.
  let problem = @moonqp.QpProblem::new(
    [[1.5, -0.5], [-0.5, 1.5]],
    [-0.3, -1.4],
    [[1.0, 0.0], [0.0, 1.0]],
    [0.0, 0.0],
    [0.8, 0.8],
  )
  let settings = {
    ..@moonqp.SolverSettings::default(),
    absolute_tolerance: 1.0e-8,
    relative_tolerance: 1.0e-8,
  }
  let result = @moonqp.solve(problem, settings~)
  require_example_solution(problem, result, [0.4666666667, 0.8], "MPC")
  println("two-step bounded control plan")
  println("status: " + status_label(result.status))
  println("u[0]: " + result.x[0].to_string())
  println("u[1]: " + result.x[1].to_string())
  println("objective: " + result.objective.unwrap().to_string())
}

///|
fn status_label(status : @moonqp.SolveStatus) -> String {
  match status {
    @moonqp.Solved => "solved"
    @moonqp.IterationLimit => "iteration limit"
    @moonqp.InvalidProblem(_) => "invalid problem"
    @moonqp.NumericalError(_) => "numerical error"
  }
}

///|
fn require_example_solution(
  problem : @moonqp.QpProblem,
  result : @moonqp.SolveResult,
  expected : Array[Double],
  label : String,
) -> Unit {
  match result.status {
    @moonqp.Solved => ()
    status => abort(label + " did not solve: " + status_label(status))
  }
  if result.x.length() != expected.length() {
    abort(label + " returned an unexpected decision-vector length")
  }
  for i in 0..<expected.length() {
    if (result.x[i] - expected[i]).abs() > 2.0e-5 {
      abort(label + " returned an unexpected decision value")
    }
  }
  let violation = problem.max_constraint_violation(result.x).unwrap()
  if violation > 2.0e-5 {
    abort(label + " returned a candidate outside its constraint intervals")
  }
}
