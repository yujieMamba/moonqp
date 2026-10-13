///|
fn main {
  // Three users request [4, 3, 2] units, while total capacity is six.
  // Minimizing squared deviation gives the equal-cost projection [3, 2, 1].
  let problem = @moonqp.QpProblem::new(
    [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
    [-4.0, -3.0, -2.0],
    [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [1.0, 1.0, 1.0]],
    [0.0, 0.0, 0.0, 0.0],
    [10.0, 10.0, 10.0, 6.0],
  )
  let settings = {
    ..@moonqp.SolverSettings::default(),
    absolute_tolerance: 1.0e-8,
    relative_tolerance: 1.0e-8,
  }
  let result = @moonqp.solve(problem, settings~)
  println("capacity-limited allocation")
  println("status: " + status_label(result.status))
  println(
    "allocation: [" +
    result.x[0].to_string() +
    ", " +
    result.x[1].to_string() +
    ", " +
    result.x[2].to_string() +
    "]",
  )
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
