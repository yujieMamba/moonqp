///|
fn dense_test_close(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Bool {
  (actual - expected).abs() <= tolerance
}

///|
fn dense_test_array_close(
  actual : Array[Double],
  expected : Array[Double],
  tolerance : Double,
) -> Bool {
  if actual.length() != expected.length() {
    return false
  }
  let mut close = true
  for i in 0..<actual.length() {
    if !dense_test_close(actual[i], expected[i], tolerance) {
      close = false
    }
  }
  close
}

///|
fn dense_test_matrix_close(
  actual : @moonqp.DenseMatrix,
  expected : Array[Array[Double]],
  tolerance : Double,
) -> Bool {
  if actual.rows() != expected.length() {
    return false
  }
  let mut close = true
  for i in 0..<expected.length() {
    if !dense_test_array_close(actual.row(i).unwrap(), expected[i], tolerance) {
      close = false
    }
  }
  close
}

///|
test "dense matrix constructors validate shape, finiteness, and copy input" {
  let source_rows = [[1.0, 2.0], [3.0, 4.0]]
  let from_rows = @moonqp.DenseMatrix::from_rows(source_rows).unwrap()
  source_rows[0][0] = 99.0
  assert_eq(from_rows.shape(), (2, 2))
  assert_true(dense_test_close(from_rows.get(0, 0).unwrap(), 1.0, 1.0e-12))

  let source_flat = [5.0, 6.0, 7.0, 8.0]
  let from_flat = @moonqp.DenseMatrix::from_flat(2, 2, source_flat).unwrap()
  source_flat[0] = -99.0
  assert_true(
    dense_test_array_close(from_flat.to_flat(), [5.0, 6.0, 7.0, 8.0], 1.0e-12),
  )

  let zeros = @moonqp.DenseMatrix::zeros(2, 3).unwrap()
  assert_eq(zeros.shape(), (2, 3))
  assert_true(
    dense_test_matrix_close(zeros, [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]], 0.0),
  )
  let identity = @moonqp.DenseMatrix::identity(3).unwrap()
  assert_true(
    dense_test_matrix_close(
      identity,
      [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
      0.0,
    ),
  )

  let infinity = 1.0 / 0.0
  let nan = infinity - infinity
  assert_true(@moonqp.DenseMatrix::from_rows([[1.0], [2.0, 3.0]]) is None)
  assert_true(@moonqp.DenseMatrix::from_rows([[nan]]) is None)
  assert_true(@moonqp.DenseMatrix::from_flat(-1, 1, []) is None)
  assert_true(@moonqp.DenseMatrix::from_flat(1, -1, []) is None)
  assert_true(@moonqp.DenseMatrix::from_flat(2, 2, [1.0]) is None)
  assert_true(@moonqp.DenseMatrix::from_flat(1, 1, [infinity]) is None)
  assert_true(@moonqp.DenseMatrix::zeros(-1, 2) is None)
  assert_true(@moonqp.DenseMatrix::zeros(50000, 50000) is None)
  assert_true(@moonqp.DenseMatrix::identity(-1) is None)
  assert_true(@moonqp.DenseMatrix::identity(50000) is None)
}

///|
test "dense matrix access exports copies and supports slices and selections" {
  let matrix = @moonqp.DenseMatrix::from_rows([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]).unwrap()
  assert_eq(matrix.rows(), 2)
  assert_eq(matrix.columns(), 3)
  assert_eq(matrix.shape(), (2, 3))
  assert_true(dense_test_close(matrix.get(1, 2).unwrap(), 6.0, 1.0e-12))
  assert_true(matrix.get(-1, 0) is None)
  assert_true(matrix.get(0, 3) is None)
  assert_true(matrix.row(-1) is None)
  assert_true(matrix.row(2) is None)
  assert_true(matrix.column(-1) is None)
  assert_true(matrix.column(3) is None)

  let exported_row = matrix.row(0).unwrap()
  let exported_column = matrix.column(1).unwrap()
  assert_true(dense_test_array_close(exported_row, [1.0, 2.0, 3.0], 1.0e-12))
  assert_true(dense_test_array_close(exported_column, [2.0, 5.0], 1.0e-12))
  exported_row[0] = 90.0
  exported_column[0] = 91.0
  assert_true(dense_test_close(matrix.get(0, 0).unwrap(), 1.0, 1.0e-12))

  let flat = matrix.to_flat()
  let rows = matrix.to_rows()
  flat[0] = 92.0
  rows[0][1] = 93.0
  assert_true(dense_test_close(matrix.get(0, 0).unwrap(), 1.0, 1.0e-12))
  assert_true(dense_test_close(matrix.get(0, 1).unwrap(), 2.0, 1.0e-12))

  let changed = matrix.with_entry(1, 2, -6.0).unwrap()
  assert_true(dense_test_close(changed.get(1, 2).unwrap(), -6.0, 1.0e-12))
  assert_true(dense_test_close(matrix.get(1, 2).unwrap(), 6.0, 1.0e-12))
  assert_true(matrix.with_entry(-1, 0, 0.0) is None)
  assert_true(matrix.with_entry(0, 0, 1.0 / 0.0) is None)
  let cloned = matrix.clone_matrix()
  assert_true(
    dense_test_matrix_close(cloned, [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], 1.0e-12),
  )
  assert_true(
    dense_test_matrix_close(
      matrix.transpose(),
      [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]],
      1.0e-12,
    ),
  )

  assert_true(
    dense_test_matrix_close(
      matrix.block(0, 2, 1, 3).unwrap(),
      [[2.0, 3.0], [5.0, 6.0]],
      1.0e-12,
    ),
  )
  assert_true(matrix.block(2, 1, 0, 1) is None)
  assert_true(matrix.block(0, 3, 0, 1) is None)
  assert_true(
    dense_test_matrix_close(
      matrix.select_rows([1, 0, 1]).unwrap(),
      [[4.0, 5.0, 6.0], [1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
      1.0e-12,
    ),
  )
  assert_true(matrix.select_rows([2]) is None)
  assert_true(
    dense_test_matrix_close(
      matrix.select_columns([2, 0]).unwrap(),
      [[3.0, 1.0], [6.0, 4.0]],
      1.0e-12,
    ),
  )
  assert_true(matrix.select_columns([-1]) is None)
}

///|
test "dense matrix arithmetic and products validate dimensions and overflow" {
  let left = @moonqp.DenseMatrix::from_rows([[1.0, -2.0], [3.0, 4.0]]).unwrap()
  let right = @moonqp.DenseMatrix::from_rows([[5.0, 6.0], [-1.0, 2.0]]).unwrap()
  assert_true(
    dense_test_matrix_close(
      left.add(right).unwrap(),
      [[6.0, 4.0], [2.0, 6.0]],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_matrix_close(
      left.subtract(right).unwrap(),
      [[-4.0, -8.0], [4.0, 2.0]],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_matrix_close(
      left.scale(2.0).unwrap(),
      [[2.0, -4.0], [6.0, 8.0]],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_matrix_close(
      left.hadamard(right).unwrap(),
      [[5.0, -12.0], [-3.0, 8.0]],
      1.0e-12,
    ),
  )
  assert_true(left.add(@moonqp.DenseMatrix::zeros(1, 2).unwrap()) is None)
  assert_true(left.subtract(@moonqp.DenseMatrix::zeros(2, 1).unwrap()) is None)
  assert_true(left.hadamard(@moonqp.DenseMatrix::zeros(1, 2).unwrap()) is None)
  assert_true(left.scale(1.0 / 0.0) is None)

  let a = @moonqp.DenseMatrix::from_rows([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]).unwrap()
  let b = @moonqp.DenseMatrix::from_rows([[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]]).unwrap()
  assert_true(
    dense_test_matrix_close(
      a.multiply(b).unwrap(),
      [[58.0, 64.0], [139.0, 154.0]],
      1.0e-12,
    ),
  )
  assert_true(a.multiply(@moonqp.DenseMatrix::identity(2).unwrap()) is None)

  let vector = @moonqp.DenseVector::from_array([1.0, 0.0, -1.0]).unwrap()
  assert_true(
    dense_test_array_close(
      a.multiply_vector(vector).unwrap().to_array(),
      [-2.0, -2.0],
      1.0e-12,
    ),
  )
  let row_vector = @moonqp.DenseVector::from_array([2.0, -1.0]).unwrap()
  assert_true(
    dense_test_array_close(
      a.transpose_multiply_vector(row_vector).unwrap().to_array(),
      [-2.0, -1.0, 0.0],
      1.0e-12,
    ),
  )
  assert_true(a.multiply_vector(row_vector) is None)
  assert_true(a.transpose_multiply_vector(vector) is None)

  let huge = @moonqp.DenseMatrix::from_rows([[1.0e308]]).unwrap()
  assert_true(huge.add(huge) is None)
  assert_true(huge.scale(2.0) is None)
  assert_true(huge.hadamard(huge) is None)
  assert_true(huge.multiply(huge) is None)
}

///|
test "dense matrix traces norms symmetry checks and symmetrization" {
  let matrix = @moonqp.DenseMatrix::from_rows([[1.0, -2.0], [3.0, 4.0]]).unwrap()
  assert_true(dense_test_close(matrix.trace().unwrap(), 5.0, 1.0e-12))
  assert_true(
    dense_test_array_close(matrix.diagonal().unwrap(), [1.0, 4.0], 1.0e-12),
  )
  assert_true(dense_test_close(matrix.infinity_norm().unwrap(), 7.0, 1.0e-12))
  assert_true(dense_test_close(matrix.one_norm().unwrap(), 6.0, 1.0e-12))
  assert_true(
    dense_test_close(matrix.frobenius_norm().unwrap(), 30.0.sqrt(), 1.0e-12),
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0]]).unwrap().trace() is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0]]).unwrap().diagonal() is None,
  )

  let almost_symmetric = @moonqp.DenseMatrix::from_rows([
    [4.0, 1.0005],
    [1.0, 3.0],
  ]).unwrap()
  assert_true(almost_symmetric.is_symmetric(0.001))
  assert_true(!almost_symmetric.is_symmetric(0.0001))
  assert_true(!almost_symmetric.is_symmetric(-1.0))
  assert_true(
    dense_test_matrix_close(
      almost_symmetric.symmetrize().unwrap(),
      [[4.0, 1.00025], [1.00025, 3.0]],
      1.0e-12,
    ),
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0, 3.0]]).unwrap().is_symmetric(0.0) ==
    false,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0]]).unwrap().symmetrize() is None,
  )

  let overflowing_norm = @moonqp.DenseMatrix::from_rows([[1.7e308, 1.7e308]]).unwrap()
  assert_true(overflowing_norm.infinity_norm() is None)
  assert_true(overflowing_norm.frobenius_norm() is None)
}

///|
test "dense LU pivots rows solves and computes determinant" {
  let matrix = @moonqp.DenseMatrix::from_rows([[0.0, 2.0], [1.0, 3.0]]).unwrap()
  let factor = matrix.lu().unwrap()
  assert_eq(factor.order(), 2)
  assert_true(
    dense_test_array_close(
      factor.solve([4.0, 7.0]).unwrap(),
      [1.0, 2.0],
      1.0e-12,
    ),
  )
  let rhs = @moonqp.DenseVector::from_array([4.0, 7.0]).unwrap()
  assert_true(
    dense_test_array_close(
      matrix.solve(rhs).unwrap().to_array(),
      [1.0, 2.0],
      1.0e-12,
    ),
  )
  assert_true(
    matrix.solve(@moonqp.DenseVector::from_array([1.0]).unwrap()) is None,
  )
  assert_true(dense_test_close(factor.determinant().unwrap(), -2.0, 1.0e-12))
  let inverse = factor.inverse().unwrap()
  assert_true(
    dense_test_matrix_close(
      matrix.multiply(inverse).unwrap(),
      [[1.0, 0.0], [0.0, 1.0]],
      1.0e-12,
    ),
  )
  assert_true(factor.solve([1.0]) is None)
  assert_true(factor.solve([1.0, 1.0 / 0.0]) is None)

  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0], [2.0, 4.0]]).unwrap().lu()
    is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0]]).unwrap().lu() is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[0.0, 0.0], [0.0, 0.0]]).unwrap().lu()
    is None,
  )
}

///|
test "dense Cholesky factors SPD matrices solves and forms inverse" {
  let matrix = @moonqp.DenseMatrix::from_rows([[4.0, 2.0], [2.0, 3.0]]).unwrap()
  let factor = matrix.cholesky().unwrap()
  assert_eq(factor.order(), 2)
  assert_true(
    dense_test_array_close(
      factor.solve([6.0, 5.0]).unwrap(),
      [1.0, 1.0],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_matrix_close(
      factor.inverse().unwrap(),
      [[0.375, -0.25], [-0.25, 0.5]],
      1.0e-12,
    ),
  )
  assert_true(factor.solve([1.0]) is None)
  assert_true(factor.solve([1.0, 1.0 / 0.0]) is None)

  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 0.5], [0.0, 1.0]]).unwrap().cholesky()
    is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0], [2.0, 1.0]]).unwrap().cholesky()
    is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 1.0], [1.0, 1.0]]).unwrap().cholesky()
    is None,
  )
  assert_true(
    @moonqp.DenseMatrix::from_rows([[1.0, 2.0]]).unwrap().cholesky() is None,
  )
}

///|
test "dense vectors copy input and support arithmetic and norms" {
  let source = [3.0, 4.0]
  let vector = @moonqp.DenseVector::from_array(source).unwrap()
  source[0] = 90.0
  assert_eq(vector.length(), 2)
  assert_true(dense_test_close(vector.get(0).unwrap(), 3.0, 1.0e-12))
  assert_true(vector.get(-1) is None)
  assert_true(vector.get(2) is None)
  assert_true(dense_test_array_close(vector.to_array(), [3.0, 4.0], 1.0e-12))
  let zeros = @moonqp.DenseVector::zeros(2).unwrap()
  assert_true(dense_test_array_close(zeros.to_array(), [0.0, 0.0], 0.0))
  assert_true(@moonqp.DenseVector::zeros(-1) is None)

  let changed = vector.with_value(1, -4.0).unwrap()
  assert_true(dense_test_array_close(changed.to_array(), [3.0, -4.0], 1.0e-12))
  assert_true(dense_test_array_close(vector.to_array(), [3.0, 4.0], 1.0e-12))
  assert_true(vector.with_value(-1, 0.0) is None)
  assert_true(vector.with_value(0, 1.0 / 0.0) is None)

  let other = @moonqp.DenseVector::from_array([1.0, -2.0]).unwrap()
  assert_true(
    dense_test_array_close(
      vector.add(other).unwrap().to_array(),
      [4.0, 2.0],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_array_close(
      vector.subtract(other).unwrap().to_array(),
      [2.0, 6.0],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_array_close(
      vector.scale(2.0).unwrap().to_array(),
      [6.0, 8.0],
      1.0e-12,
    ),
  )
  assert_true(dense_test_close(vector.dot(other).unwrap(), -5.0, 1.0e-12))
  assert_true(dense_test_close(vector.norm().unwrap(), 5.0, 1.0e-12))
  assert_true(dense_test_close(vector.infinity_norm(), 4.0, 1.0e-12))
  assert_true(
    dense_test_array_close(
      vector.axpy(2.0, other).unwrap().to_array(),
      [7.0, 6.0],
      1.0e-12,
    ),
  )
  assert_true(
    dense_test_close(vector.distance(other).unwrap(), 40.0.sqrt(), 1.0e-12),
  )

  let mismatch = @moonqp.DenseVector::from_array([1.0]).unwrap()
  assert_true(vector.add(mismatch) is None)
  assert_true(vector.subtract(mismatch) is None)
  assert_true(vector.dot(mismatch) is None)
  assert_true(vector.axpy(1.0, mismatch) is None)
  assert_true(vector.distance(mismatch) is None)
  assert_true(vector.scale(1.0 / 0.0) is None)
  assert_true(@moonqp.DenseVector::from_array([1.0 / 0.0]) is None)
  assert_true(@moonqp.DenseVector::from_array([1.0 / 0.0 - 1.0 / 0.0]) is None)

  let huge = @moonqp.DenseVector::from_array([1.0e308]).unwrap()
  assert_true(huge.add(huge) is None)
  assert_true(huge.scale(2.0) is None)
  assert_true(huge.dot(huge) is None)
  assert_true(huge.axpy(2.0, huge) is None)
}
