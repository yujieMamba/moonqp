///|
/// Immutable-by-interface row-major dense matrix. Every constructor copies its
/// input; operations that can overflow or receive incompatible shapes return
/// `None` rather than publishing a non-finite result.
pub struct DenseMatrix {
  row_count : Int
  column_count : Int
  values : Array[Double]
}

///|
/// Immutable-by-interface finite vector used by the reusable dense kernels.
pub struct DenseVector {
  values : Array[Double]
}

///|
/// A reusable LU factorization with scaled partial pivoting.
pub struct DenseLuFactor {
  order : Int
  factors : Array[Array[Double]]
  permutation : Array[Int]
  pivot_threshold : Double
  determinant_sign : Double
}

///|
/// A reusable lower-triangular Cholesky factor for a symmetric positive
/// definite matrix.
pub struct CholeskyFactor {
  order : Int
  lower : Array[Array[Double]]
}

///|
/// Copy a rectangular finite row-major matrix. Empty input represents 0 by 0.
pub fn DenseMatrix::from_rows(rows : Array[Array[Double]]) -> DenseMatrix? {
  let row_count = rows.length()
  let column_count = if row_count == 0 { 0 } else { rows[0].length() }
  for i in 0..<row_count {
    if rows[i].length() != column_count {
      return None
    }
  }
  if row_count > 0 && column_count > 2147483647 / row_count {
    return None
  }
  let values = Array::make(row_count * column_count, 0.0)
  for i in 0..<row_count {
    for j in 0..<column_count {
      let value = rows[i][j]
      if !dense_finite(value) {
        return None
      }
      values[i * column_count + j] = value
    }
  }
  Some({ row_count, column_count, values, })
}

///|
/// Construct a finite matrix from a flat row-major buffer, copying the buffer.
pub fn DenseMatrix::from_flat(
  row_count : Int,
  column_count : Int,
  values : Array[Double],
) -> DenseMatrix? {
  if row_count < 0 || column_count < 0 {
    return None
  }
  if row_count > 0 && column_count > 2147483647 / row_count {
    return None
  }
  if values.length() != row_count * column_count {
    return None
  }
  let copied = Array::make(values.length(), 0.0)
  for i in 0..<values.length() {
    if !dense_finite(values[i]) {
      return None
    }
    copied[i] = values[i]
  }
  Some({ row_count, column_count, values: copied, })
}

///|
/// Construct a zero matrix. Negative or unrepresentably large shapes fail.
pub fn DenseMatrix::zeros(row_count : Int, column_count : Int) -> DenseMatrix? {
  if row_count < 0 || column_count < 0 {
    return None
  }
  if row_count > 0 && column_count > 2147483647 / row_count {
    return None
  }
  Some({
    row_count,
    column_count,
    values: Array::make(row_count * column_count, 0.0),
  })
}

///|
/// Construct an identity matrix of the requested order.
pub fn DenseMatrix::identity(order : Int) -> DenseMatrix? {
  if order < 0 {
    return None
  }
  let result = match DenseMatrix::zeros(order, order) {
    Some(matrix) => matrix
    None => return None
  }
  for i in 0..<order {
    result.values[i * order + i] = 1.0
  }
  Some(result)
}

///|
pub fn DenseMatrix::rows(self : DenseMatrix) -> Int {
  self.row_count
}

///|
pub fn DenseMatrix::columns(self : DenseMatrix) -> Int {
  self.column_count
}

///|
pub fn DenseMatrix::shape(self : DenseMatrix) -> (Int, Int) {
  (self.row_count, self.column_count)
}

///|
/// Return an element only when both indices are in range.
pub fn DenseMatrix::get(self : DenseMatrix, row : Int, column : Int) -> Double? {
  if row < 0 ||
    row >= self.row_count ||
    column < 0 ||
    column >= self.column_count {
    return None
  }
  Some(self.values[row * self.column_count + column])
}

///|
/// Return a copied row, or `None` for an invalid row index.
pub fn DenseMatrix::row(self : DenseMatrix, row : Int) -> Array[Double]? {
  if row < 0 || row >= self.row_count {
    return None
  }
  let result = Array::make(self.column_count, 0.0)
  for j in 0..<self.column_count {
    result[j] = self.values[row * self.column_count + j]
  }
  Some(result)
}

///|
/// Return a copied column, or `None` for an invalid column index.
pub fn DenseMatrix::column(self : DenseMatrix, column : Int) -> Array[Double]? {
  if column < 0 || column >= self.column_count {
    return None
  }
  let result = Array::make(self.row_count, 0.0)
  for i in 0..<self.row_count {
    result[i] = self.values[i * self.column_count + column]
  }
  Some(result)
}

///|
/// Export independent row arrays; mutating the returned arrays cannot change
/// this matrix.
pub fn DenseMatrix::to_rows(self : DenseMatrix) -> Array[Array[Double]] {
  let result = Array::make(self.row_count, Array::make(0, 0.0))
  for i in 0..<self.row_count {
    let row = Array::make(self.column_count, 0.0)
    for j in 0..<self.column_count {
      row[j] = self.values[i * self.column_count + j]
    }
    result[i] = row
  }
  result
}

///|
/// Export a copied flat row-major buffer.
pub fn DenseMatrix::to_flat(self : DenseMatrix) -> Array[Double] {
  dense_copy_vector(self.values)
}

///|
/// Return a copy with one element replaced; invalid indices or non-finite
/// replacements return `None`.
pub fn DenseMatrix::with_entry(
  self : DenseMatrix,
  row : Int,
  column : Int,
  value : Double,
) -> DenseMatrix? {
  if row < 0 ||
    row >= self.row_count ||
    column < 0 ||
    column >= self.column_count ||
    !dense_finite(value) {
    return None
  }
  let result = self.clone_matrix()
  result.values[row * self.column_count + column] = value
  Some(result)
}

///|
/// Return a deep copy of this matrix.
pub fn DenseMatrix::clone_matrix(self : DenseMatrix) -> DenseMatrix {
  {
    row_count: self.row_count,
    column_count: self.column_count,
    values: dense_copy_vector(self.values),
  }
}

///|
/// Transpose the matrix without changing its values.
pub fn DenseMatrix::transpose(self : DenseMatrix) -> DenseMatrix {
  let result = DenseMatrix::zeros(self.column_count, self.row_count).unwrap()
  for i in 0..<self.row_count {
    for j in 0..<self.column_count {
      result.values[j * self.row_count + i] = self.values[i * self.column_count +
        j]
    }
  }
  result
}

///|
/// Return the requested half-open rectangular block, or `None` for an invalid
/// range.
pub fn DenseMatrix::block(
  self : DenseMatrix,
  row_start : Int,
  row_end : Int,
  column_start : Int,
  column_end : Int,
) -> DenseMatrix? {
  if row_start < 0 ||
    row_end < row_start ||
    row_end > self.row_count ||
    column_start < 0 ||
    column_end < column_start ||
    column_end > self.column_count {
    return None
  }
  let output_rows = row_end - row_start
  let output_columns = column_end - column_start
  let result = DenseMatrix::zeros(output_rows, output_columns).unwrap()
  for i in 0..<output_rows {
    for j in 0..<output_columns {
      result.values[i * output_columns + j] = self.values[(row_start + i) *
        self.column_count +
        column_start +
        j]
    }
  }
  Some(result)
}

///|
/// Select rows in the supplied order. Repeated indices intentionally repeat a
/// row; any out-of-range index fails the operation.
pub fn DenseMatrix::select_rows(
  self : DenseMatrix,
  indices : Array[Int],
) -> DenseMatrix? {
  let result = DenseMatrix::zeros(indices.length(), self.column_count).unwrap()
  for i in 0..<indices.length() {
    let source = indices[i]
    if source < 0 || source >= self.row_count {
      return None
    }
    for j in 0..<self.column_count {
      result.values[i * self.column_count + j] = self.values[source *
        self.column_count +
        j]
    }
  }
  Some(result)
}

///|
/// Select columns in the supplied order; repeated indices are allowed.
pub fn DenseMatrix::select_columns(
  self : DenseMatrix,
  indices : Array[Int],
) -> DenseMatrix? {
  let result = DenseMatrix::zeros(self.row_count, indices.length()).unwrap()
  for j in 0..<indices.length() {
    let source = indices[j]
    if source < 0 || source >= self.column_count {
      return None
    }
    for i in 0..<self.row_count {
      result.values[i * indices.length() + j] = self.values[i *
        self.column_count +
        source]
    }
  }
  Some(result)
}

///|
/// Add shape-compatible matrices with compensated elementwise summation.
pub fn DenseMatrix::add(
  self : DenseMatrix,
  other : DenseMatrix,
) -> DenseMatrix? {
  if self.row_count != other.row_count ||
    self.column_count != other.column_count {
    return None
  }
  let result = DenseMatrix::zeros(self.row_count, self.column_count).unwrap()
  for i in 0..<self.values.length() {
    let value = self.values[i] + other.values[i]
    if !dense_finite(value) {
      return None
    }
    result.values[i] = value
  }
  Some(result)
}

///|
/// Subtract a shape-compatible matrix.
pub fn DenseMatrix::subtract(
  self : DenseMatrix,
  other : DenseMatrix,
) -> DenseMatrix? {
  if self.row_count != other.row_count ||
    self.column_count != other.column_count {
    return None
  }
  let result = DenseMatrix::zeros(self.row_count, self.column_count).unwrap()
  for i in 0..<self.values.length() {
    let value = self.values[i] - other.values[i]
    if !dense_finite(value) {
      return None
    }
    result.values[i] = value
  }
  Some(result)
}

///|
/// Scale every entry, rejecting a non-finite scalar or overflow.
pub fn DenseMatrix::scale(self : DenseMatrix, factor : Double) -> DenseMatrix? {
  if !dense_finite(factor) {
    return None
  }
  let result = DenseMatrix::zeros(self.row_count, self.column_count).unwrap()
  for i in 0..<self.values.length() {
    let value = self.values[i] * factor
    if !dense_finite(value) {
      return None
    }
    result.values[i] = value
  }
  Some(result)
}

///|
/// Elementwise product of shape-compatible matrices.
pub fn DenseMatrix::hadamard(
  self : DenseMatrix,
  other : DenseMatrix,
) -> DenseMatrix? {
  if self.row_count != other.row_count ||
    self.column_count != other.column_count {
    return None
  }
  let result = DenseMatrix::zeros(self.row_count, self.column_count).unwrap()
  for i in 0..<self.values.length() {
    let value = self.values[i] * other.values[i]
    if !dense_finite(value) {
      return None
    }
    result.values[i] = value
  }
  Some(result)
}

///|
/// Dense matrix product using compensated dot products.
pub fn DenseMatrix::multiply(
  self : DenseMatrix,
  other : DenseMatrix,
) -> DenseMatrix? {
  if self.column_count != other.row_count {
    return None
  }
  let result = DenseMatrix::zeros(self.row_count, other.column_count).unwrap()
  for i in 0..<self.row_count {
    for j in 0..<other.column_count {
      let mut sum = 0.0
      let mut compensation = 0.0
      for k in 0..<self.column_count {
        let product = self.values[i * self.column_count + k] *
          other.values[k * other.column_count + j]
        if !dense_finite(product) {
          return None
        }
        let corrected = product - compensation
        let next_sum = sum + corrected
        compensation = next_sum - sum - corrected
        sum = next_sum
      }
      if !dense_finite(sum) {
        return None
      }
      result.values[i * other.column_count + j] = sum
    }
  }
  Some(result)
}

///|
/// Multiply by a finite vector using compensated row dot products.
pub fn DenseMatrix::multiply_vector(
  self : DenseMatrix,
  vector : DenseVector,
) -> DenseVector? {
  if self.column_count != vector.values.length() {
    return None
  }
  let result = Array::make(self.row_count, 0.0)
  for i in 0..<self.row_count {
    let mut sum = 0.0
    let mut compensation = 0.0
    for j in 0..<self.column_count {
      let product = self.values[i * self.column_count + j] * vector.values[j]
      if !dense_finite(product) {
        return None
      }
      let corrected = product - compensation
      let next_sum = sum + corrected
      compensation = next_sum - sum - corrected
      sum = next_sum
    }
    if !dense_finite(sum) {
      return None
    }
    result[i] = sum
  }
  Some({ values: result, })
}

///|
/// Multiply the transpose by a finite vector.
pub fn DenseMatrix::transpose_multiply_vector(
  self : DenseMatrix,
  vector : DenseVector,
) -> DenseVector? {
  if self.row_count != vector.values.length() {
    return None
  }
  let result = Array::make(self.column_count, 0.0)
  let compensation = Array::make(self.column_count, 0.0)
  for i in 0..<self.row_count {
    for j in 0..<self.column_count {
      let product = self.values[i * self.column_count + j] * vector.values[i]
      if !dense_finite(product) {
        return None
      }
      let corrected = product - compensation[j]
      let next_sum = result[j] + corrected
      compensation[j] = next_sum - result[j] - corrected
      result[j] = next_sum
    }
  }
  if !dense_array_finite(result) {
    return None
  }
  Some({ values: result, })
}

///|
/// Return the matrix trace for a square matrix.
pub fn DenseMatrix::trace(self : DenseMatrix) -> Double? {
  if self.row_count != self.column_count {
    return None
  }
  let mut result = 0.0
  for i in 0..<self.row_count {
    result = result + self.values[i * self.column_count + i]
    if !dense_finite(result) {
      return None
    }
  }
  Some(result)
}

///|
/// Return a copy of the diagonal of a square matrix.
pub fn DenseMatrix::diagonal(self : DenseMatrix) -> Array[Double]? {
  if self.row_count != self.column_count {
    return None
  }
  let result = Array::make(self.row_count, 0.0)
  for i in 0..<self.row_count {
    result[i] = self.values[i * self.column_count + i]
  }
  Some(result)
}

///|
/// Maximum absolute row sum, or `None` if the accumulated norm overflows.
pub fn DenseMatrix::infinity_norm(self : DenseMatrix) -> Double? {
  let mut maximum = 0.0
  for i in 0..<self.row_count {
    let mut sum = 0.0
    for j in 0..<self.column_count {
      sum = sum + self.values[i * self.column_count + j].abs()
      if !dense_finite(sum) {
        return None
      }
    }
    maximum = dense_max(maximum, sum)
  }
  Some(maximum)
}

///|
/// Maximum absolute column sum, or `None` if the accumulated norm overflows.
pub fn DenseMatrix::one_norm(self : DenseMatrix) -> Double? {
  let mut maximum = 0.0
  for j in 0..<self.column_count {
    let mut sum = 0.0
    for i in 0..<self.row_count {
      sum = sum + self.values[i * self.column_count + j].abs()
      if !dense_finite(sum) {
        return None
      }
    }
    maximum = dense_max(maximum, sum)
  }
  Some(maximum)
}

///|
/// Stable scaled sum-of-squares Frobenius norm.
pub fn DenseMatrix::frobenius_norm(self : DenseMatrix) -> Double? {
  dense_scaled_norm(self.values)
}

///|
/// Test symmetry with a finite non-negative absolute tolerance.
pub fn DenseMatrix::is_symmetric(
  self : DenseMatrix,
  tolerance : Double,
) -> Bool {
  if self.row_count != self.column_count ||
    !dense_finite(tolerance) ||
    tolerance < 0.0 {
    return false
  }
  for i in 0..<self.row_count {
    for j in 0..<i {
      if (self.values[i * self.column_count + j] -
        self.values[j * self.column_count + i]).abs() >
        tolerance {
        return false
      }
    }
  }
  true
}

///|
/// Average mirrored entries of an approximately symmetric matrix.
pub fn DenseMatrix::symmetrize(self : DenseMatrix) -> DenseMatrix? {
  if self.row_count != self.column_count {
    return None
  }
  let result = self.clone_matrix()
  for i in 0..<self.row_count {
    for j in 0..<i {
      let average = self.values[i * self.column_count + j] * 0.5 +
        self.values[j * self.column_count + i] * 0.5
      result.values[i * self.column_count + j] = average
      result.values[j * self.column_count + i] = average
    }
  }
  Some(result)
}

///|
/// Factor a square matrix with scaled partial pivoting. `relative_tolerance`
/// is applied to the largest input coefficient to classify near-zero pivots.
pub fn DenseMatrix::lu(
  self : DenseMatrix,
  relative_tolerance? : Double = 1.0e-12,
) -> DenseLuFactor? {
  let n = self.row_count
  if n != self.column_count ||
    !dense_finite(relative_tolerance) ||
    relative_tolerance < 0.0 {
    return None
  }
  let factors = self.to_rows()
  let permutation = Array::make(n, 0)
  let row_scale = Array::make(n, 0.0)
  let mut matrix_scale = 0.0
  for i in 0..<n {
    permutation[i] = i
    for j in 0..<n {
      let magnitude = factors[i][j].abs()
      row_scale[i] = dense_max(row_scale[i], magnitude)
      matrix_scale = dense_max(matrix_scale, magnitude)
    }
  }
  if n > 0 && matrix_scale == 0.0 {
    return None
  }
  let threshold = relative_tolerance * matrix_scale
  let mut sign = 1.0
  for k in 0..<n {
    let mut pivot = k
    let mut pivot_score = -1.0
    for i in k..<n {
      let score = if row_scale[i] == 0.0 {
        0.0
      } else {
        factors[i][k].abs() / row_scale[i]
      }
      if score > pivot_score {
        pivot = i
        pivot_score = score
      }
    }
    if factors[pivot][k].abs() <= threshold {
      return None
    }
    if pivot != k {
      let saved_row = factors[k]
      factors[k] = factors[pivot]
      factors[pivot] = saved_row
      let saved_scale = row_scale[k]
      row_scale[k] = row_scale[pivot]
      row_scale[pivot] = saved_scale
      let saved_index = permutation[k]
      permutation[k] = permutation[pivot]
      permutation[pivot] = saved_index
      sign = -sign
    }
    for i in (k + 1)..<n {
      factors[i][k] = factors[i][k] / factors[k][k]
      if !dense_finite(factors[i][k]) {
        return None
      }
      for j in (k + 1)..<n {
        factors[i][j] = factors[i][j] - factors[i][k] * factors[k][j]
        if !dense_finite(factors[i][j]) {
          return None
        }
      }
    }
  }
  Some({
    order: n,
    factors,
    permutation,
    pivot_threshold: threshold,
    determinant_sign: sign,
  })
}

///|
/// Solve `A x = rhs` using the stored pivoted LU factors.
pub fn DenseLuFactor::solve(
  self : DenseLuFactor,
  rhs : Array[Double],
) -> Array[Double]? {
  if rhs.length() != self.order || !dense_array_finite(rhs) {
    return None
  }
  let result = Array::make(self.order, 0.0)
  for i in 0..<self.order {
    let mut value = rhs[self.permutation[i]]
    for j in 0..<i {
      value = value - self.factors[i][j] * result[j]
    }
    if !dense_finite(value) {
      return None
    }
    result[i] = value
  }
  for offset in 0..<self.order {
    let i = self.order - 1 - offset
    let mut value = result[i]
    for j in (i + 1)..<self.order {
      value = value - self.factors[i][j] * result[j]
    }
    let pivot = self.factors[i][i]
    if pivot.abs() <= self.pivot_threshold {
      return None
    }
    result[i] = value / pivot
    if !dense_finite(result[i]) {
      return None
    }
  }
  Some(result)
}

///|
/// Form the inverse by solving against each coordinate vector. Singular or
/// numerically overflowing results return `None`.
pub fn DenseLuFactor::inverse(self : DenseLuFactor) -> DenseMatrix? {
  let inverse = match DenseMatrix::zeros(self.order, self.order) {
    Some(value) => value
    None => return None
  }
  for j in 0..<self.order {
    let rhs = Array::make(self.order, 0.0)
    rhs[j] = 1.0
    let column = match self.solve(rhs) {
      Some(value) => value
      None => return None
    }
    for i in 0..<self.order {
      inverse.values[i * self.order + j] = column[i]
    }
  }
  Some(inverse)
}

///|
/// Compute the determinant from the factorization; overflow returns `None`.
pub fn DenseLuFactor::determinant(self : DenseLuFactor) -> Double? {
  let mut result = self.determinant_sign
  for i in 0..<self.order {
    result = result * self.factors[i][i]
    if !dense_finite(result) {
      return None
    }
  }
  Some(result)
}

///|
pub fn DenseLuFactor::order(self : DenseLuFactor) -> Int {
  self.order
}

///|
/// Factor a square symmetric positive definite matrix by Cholesky's method.
pub fn DenseMatrix::cholesky(
  self : DenseMatrix,
  symmetry_tolerance? : Double = 1.0e-12,
) -> CholeskyFactor? {
  let n = self.row_count
  if n != self.column_count ||
    !dense_finite(symmetry_tolerance) ||
    symmetry_tolerance < 0.0 ||
    !self.is_symmetric(symmetry_tolerance) {
    return None
  }
  let lower = Array::make(n, Array::make(0, 0.0))
  for i in 0..<n {
    lower[i] = Array::make(n, 0.0)
  }
  for i in 0..<n {
    for j in 0..<=i {
      let mut value = self.values[i * n + j]
      for k in 0..<j {
        value = value - lower[i][k] * lower[j][k]
      }
      if !dense_finite(value) {
        return None
      }
      if i == j {
        if value <= 0.0 {
          return None
        }
        lower[i][j] = value.sqrt()
      } else {
        lower[i][j] = value / lower[j][j]
        if !dense_finite(lower[i][j]) {
          return None
        }
      }
    }
  }
  Some({ order: n, lower, })
}

///|
/// Solve `L L' x = rhs` from this Cholesky factorization.
pub fn CholeskyFactor::solve(
  self : CholeskyFactor,
  rhs : Array[Double],
) -> Array[Double]? {
  if rhs.length() != self.order || !dense_array_finite(rhs) {
    return None
  }
  let forward = Array::make(self.order, 0.0)
  for i in 0..<self.order {
    let mut value = rhs[i]
    for j in 0..<i {
      value = value - self.lower[i][j] * forward[j]
    }
    forward[i] = value / self.lower[i][i]
    if !dense_finite(forward[i]) {
      return None
    }
  }
  let result = Array::make(self.order, 0.0)
  for offset in 0..<self.order {
    let i = self.order - 1 - offset
    let mut value = forward[i]
    for j in (i + 1)..<self.order {
      value = value - self.lower[j][i] * result[j]
    }
    result[i] = value / self.lower[i][i]
    if !dense_finite(result[i]) {
      return None
    }
  }
  Some(result)
}

///|
/// Solve against each coordinate vector and return the symmetric inverse.
pub fn CholeskyFactor::inverse(self : CholeskyFactor) -> DenseMatrix? {
  let inverse = DenseMatrix::zeros(self.order, self.order).unwrap()
  for j in 0..<self.order {
    let rhs = Array::make(self.order, 0.0)
    rhs[j] = 1.0
    let column = match self.solve(rhs) {
      Some(value) => value
      None => return None
    }
    for i in 0..<self.order {
      inverse.values[i * self.order + j] = column[i]
    }
  }
  inverse.symmetrize()
}

///|
pub fn CholeskyFactor::order(self : CholeskyFactor) -> Int {
  self.order
}

///|
/// Construct a vector from a finite array, copying the input.
pub fn DenseVector::from_array(values : Array[Double]) -> DenseVector? {
  if !dense_array_finite(values) {
    return None
  }
  Some({ values: dense_copy_vector(values), })
}

///|
/// Construct a zero vector of non-negative length.
pub fn DenseVector::zeros(length : Int) -> DenseVector? {
  if length < 0 {
    return None
  }
  Some({ values: Array::make(length, 0.0), })
}

///|
pub fn DenseVector::length(self : DenseVector) -> Int {
  self.values.length()
}

///|
pub fn DenseVector::get(self : DenseVector, index : Int) -> Double? {
  if index < 0 || index >= self.values.length() {
    return None
  }
  Some(self.values[index])
}

///|
pub fn DenseVector::to_array(self : DenseVector) -> Array[Double] {
  dense_copy_vector(self.values)
}

///|
pub fn DenseVector::with_value(
  self : DenseVector,
  index : Int,
  value : Double,
) -> DenseVector? {
  if index < 0 || index >= self.values.length() || !dense_finite(value) {
    return None
  }
  let values = dense_copy_vector(self.values)
  values[index] = value
  Some({ values, })
}

///|
pub fn DenseVector::add(
  self : DenseVector,
  other : DenseVector,
) -> DenseVector? {
  if self.values.length() != other.values.length() {
    return None
  }
  let values = Array::make(self.values.length(), 0.0)
  for i in 0..<values.length() {
    values[i] = self.values[i] + other.values[i]
    if !dense_finite(values[i]) {
      return None
    }
  }
  Some({ values, })
}

///|
pub fn DenseVector::subtract(
  self : DenseVector,
  other : DenseVector,
) -> DenseVector? {
  if self.values.length() != other.values.length() {
    return None
  }
  let values = Array::make(self.values.length(), 0.0)
  for i in 0..<values.length() {
    values[i] = self.values[i] - other.values[i]
    if !dense_finite(values[i]) {
      return None
    }
  }
  Some({ values, })
}

///|
pub fn DenseVector::scale(self : DenseVector, factor : Double) -> DenseVector? {
  if !dense_finite(factor) {
    return None
  }
  let values = Array::make(self.values.length(), 0.0)
  for i in 0..<values.length() {
    values[i] = self.values[i] * factor
    if !dense_finite(values[i]) {
      return None
    }
  }
  Some({ values, })
}

///|
/// Compensated Euclidean inner product; incompatible lengths return `None`.
pub fn DenseVector::dot(self : DenseVector, other : DenseVector) -> Double? {
  if self.values.length() != other.values.length() {
    return None
  }
  let mut sum = 0.0
  let mut compensation = 0.0
  for i in 0..<self.values.length() {
    let product = self.values[i] * other.values[i]
    if !dense_finite(product) {
      return None
    }
    let corrected = product - compensation
    let next_sum = sum + corrected
    compensation = next_sum - sum - corrected
    sum = next_sum
  }
  if dense_finite(sum) {
    Some(sum)
  } else {
    None
  }
}

///|
pub fn DenseVector::norm(self : DenseVector) -> Double? {
  dense_scaled_norm(self.values)
}

///|
pub fn DenseVector::infinity_norm(self : DenseVector) -> Double {
  dense_max_abs(self.values)
}

///|
/// Return `alpha * x + y` without mutating either input.
pub fn DenseVector::axpy(
  self : DenseVector,
  alpha : Double,
  y : DenseVector,
) -> DenseVector? {
  if self.values.length() != y.values.length() || !dense_finite(alpha) {
    return None
  }
  let result = Array::make(self.values.length(), 0.0)
  for i in 0..<result.length() {
    result[i] = alpha * self.values[i] + y.values[i]
    if !dense_finite(result[i]) {
      return None
    }
  }
  Some({ values: result, })
}

///|
pub fn DenseVector::distance(
  self : DenseVector,
  other : DenseVector,
) -> Double? {
  match self.subtract(other) {
    Some(difference) => difference.norm()
    None => None
  }
}

///|
fn dense_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn dense_array_finite(values : Array[Double]) -> Bool {
  for value in values {
    if !dense_finite(value) {
      return false
    }
  }
  true
}

///|
fn dense_copy_vector(values : Array[Double]) -> Array[Double] {
  let result = Array::make(values.length(), 0.0)
  for i in 0..<values.length() {
    result[i] = values[i]
  }
  result
}

///|
fn dense_scaled_norm(values : Array[Double]) -> Double? {
  let mut scale = 0.0
  let mut sum_squares = 1.0
  for value in values {
    let magnitude = value.abs()
    if magnitude != 0.0 {
      if scale < magnitude {
        let ratio = scale / magnitude
        sum_squares = 1.0 + sum_squares * ratio * ratio
        scale = magnitude
      } else {
        let ratio = magnitude / scale
        sum_squares = sum_squares + ratio * ratio
      }
    }
  }
  let norm = scale * sum_squares.sqrt()
  if dense_finite(norm) {
    Some(norm)
  } else {
    None
  }
}

///|
fn dense_max_abs(values : Array[Double]) -> Double {
  let mut maximum = 0.0
  for value in values {
    maximum = dense_max(maximum, value.abs())
  }
  maximum
}

///|
fn dense_max(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}
