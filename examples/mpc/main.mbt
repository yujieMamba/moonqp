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
