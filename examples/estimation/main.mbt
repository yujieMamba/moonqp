///|
fn main {
  // Fit offset and slope to three observations, with a domain-specific slope
  // interval. P and q are the normal-equation terms for half the squared error.
  let problem = @moonqp.QpProblem::new(
    [[3.0, 3.0], [3.0, 5.0]],
    [-6.1, -7.8],
    [[0.0, 1.0]],
    [0.6],
    [1.2],
  )
  let settings = {
    ..@moonqp.SolverSettings::default(),
    absolute_tolerance: 1.0e-8,
    relative_tolerance: 1.0e-8,
  }
  let result = @moonqp.solve(problem, settings~)
  println("constrained linear least-squares estimate")
  println("status: " + status_label(result.status))
  println("offset: " + result.x[0].to_string())
  println("slope: " + result.x[1].to_string())
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
