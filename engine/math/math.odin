package okmath

import m "core:math"
import mb "core:math/bits"
import la "core:math/linalg"
import rnd "core:math/rand"
import "core:time"

K_PI :: m.PI
K_PI_2 :: 2.0 * K_PI
K_HAL_PI :: 0.5 * K_PI
K_QUARTER_PI :: 0.25 * K_PI
K_ONE_OVER_PI :: 1.0 / K_PI
K_ONE_OVER_TWO_PI :: 1.0 / K_PI_2
K_SQRT_TWO :: m.SQRT_TWO
K_SQRT_THREE :: m.SQRT_THREE
K_SQRT_ONE_OVER_TWO :: 0.70710678118654752440
K_SQRT_ONE_OVER_THREE :: 0.57735026918962576450
K_DEG2RAD_MULTIPLIER :: K_PI / 180.0
K_RAD2DEG_MULTIPLIER :: 180.0 / K_PI

// The multiplier to convert seconds to milliseconds.
K_SEC_TO_MS_MULTIPLIER :: 1000.0

// The multiplier to convert milliseconds to seconds.
K_MS_TO_SEC_MULTIPLIER :: 0.001

// A huge number that should be larger than any valid number used.
// K_INFINITY :: 1e30
K_INFINITY :: m.Float_Class.Inf

// Smallest positive number where 1.0 + FLOAT_EPSILON != 0
K_FLOAT_EPSILON :: m.F32_EPSILON

vec2 :: la.Vector2f32
vec3 :: la.Vector3f32
vec4 :: la.Vector4f32
mat4 :: la.Matrix4f32
quat :: la.Quaternionf32

@(private = "file")
rand_seeded : bool = false

ksin :: proc(x: f32) -> f32 {
    return m.sin_f32(x)
}

kcos :: proc(x: f32) -> f32 {
    return m.cos_f32(x)
}

ktan :: proc(x: f32) -> f32 {
    return m.tan_f32(x)
}

facos :: proc(x: f32) -> f32 {
    return m.cos_f32(x)
}

fsqrt :: proc(x: f32) -> f32 {
    return m.sqrt_f32(x)
}

kabs :: proc(x: f32) -> f32 {
    return m.abs(x)
}

krandom :: proc() -> i32 {
    if !rand_seeded {
		current_time:= time.now()
		rnd.set_global_seed(cast(u64)current_time._nsec)
        rand_seeded = true;
    }
    return cast(i32)rnd.uint32();
}

krandom_in_range :: proc(min: i32, max: i32) -> i32 {
    if !rand_seeded {
		current_time:= time.now()
		rnd.set_global_seed(cast(u64)current_time._nsec)
        rand_seeded = true;
    }
	return cast(i32)rnd.float32_range(cast(f32)min, cast(f32)max)
}

fkrandom :: proc() -> f32 {
    return rnd.float32();
}

fkrandom_in_range :: proc(min: f32, max: f32) -> f32 {
	return rnd.float32_range(min, max)
}

/**
 * Indicates if the value is a power of 2. 0 is considered _not_ a power of 2.
 * @param value The value to be interpreted.
 * @returns True if a power of 2, otherwise false.
 */
is_power_of_2 :: proc(value: u64) -> bool {
	return mb.is_power_of_two(value)
}

// ------------------------------------------
// Vector 2
// ------------------------------------------

/**
 * @brief Creates and returns a new 2-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @return A new 2-element vector.
 */
vec2_create :: #force_inline proc(x: f32, y: f32) -> vec2 {
	return vec2{x, y}
}

/**
 * @brief Creates and returns a 2-component vector with all components set to 0.0f.
 */
vec2_zero :: proc() -> vec2 {
	return vec2{}
}

/**
 * @brief Creates and returns a 2-component vector with all components set to 1.0f.
 */
vec2_one :: proc() -> vec2 {
	return vec2{0.0, 0.0}
}

/**
 * @brief Creates and returns a 2-component vector pointing up (0, 1).
 */
vec2_up :: proc() -> vec2 {
	return vec2{0.0, 1.0}
}

/**
 * @brief Creates and returns a 2-component vector pointing down (0, -1).
 */
vec2_down :: proc() -> vec2 {
	return vec2{1.0, 0.0}
}

/**
 * @brief Creates and returns a 2-component vector pointing left (-1, 0).
 */
vec2_left :: proc() -> vec2 {
	return vec2{-1.0, 0.0}
}

/**
 * @brief Creates and returns a 2-component vector pointing right (1, 0).
 */
vec2_right :: proc() -> vec2 {
	return vec2{1.0, 0.0}
}

/**
 * @brief Adds vector_1 to vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec2_add :: proc(vector_0: vec2, vector_1: vec2) -> vec2 {
	return vector_0 + vector_1
}

/**
 * @brief Subtracts vector_1 from vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec2_sub :: proc(vector_0: vec2, vector_1: vec2) -> vec2 {
	return vector_0 - vector_1
}

/**
 * @brief Multiplies vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec2_mul :: proc(vector_0: vec2, vector_1: vec2) -> vec2 {
	return vector_0 * vector_1
}

/**
 * @brief Divides vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec2_div :: proc(vector_0: vec2, vector_1: vec2) -> vec2 {
	return vector_0 / vector_1
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
vec2_length_squared :: proc(vector: vec2) -> f32 {
	return la.vector_dot(vector, vector)
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
vec2_length :: proc(vector: vec2) -> f32 {
	return la.vector_length(vector)
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
vec2_normalize :: proc(vector: ^vec2) {
	v := la.vector_normalize(vector^)
	vector.x = v.x
	vector.y = v.y
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
vec2_normalized :: proc(vector: vec2) -> vec2 {
	return la.vector_normalize(vector)
}

/**
 * @brief Compares all elements of vector_0 and vector_1 and ensures the difference
 * is less than tolerance.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @param tolerance The difference tolerance. Typically K_FLOAT_EPSILON or similar.
 * @return True if within tolerance; otherwise false. 
 */
vec2_compare :: #force_inline proc(vector_0: vec2, vector_1: vec2, tolerance: f32) -> bool {
	if m.abs(vector_0.x - vector_1.x) > tolerance {
		return false
	}

	if m.abs(vector_0.y - vector_1.y) > tolerance {
		return false
	}

	return true
}

/**
 * @brief Returns the distance between vector_0 and vector_1.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The distance between vector_0 and vector_1.
 */
vec2_distance :: #force_inline proc(vector_0: vec2, vector_1: vec2) -> f32 {
	return la.distance(vector_0, vector_1)
}

// ------------------------------------------
// Vector 3
// ------------------------------------------

/**
 * @brief Creates and returns a new 3-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @param z The z value.
 * @return A new 3-element vector.
 */
vec3_create :: #force_inline proc (x: f32, y: f32, z: f32) -> vec3 {
    return vec3{x, y, z}
}

/**
 * @brief Returns a new vec3 containing the x, y and z components of the 
 * supplied vec4, essentially dropping the w component.
 * 
 * @param vector The 4-component vector to extract from.
 * @return A new vec3 
 */
vec3_from_vec4 :: #force_inline proc(vector: vec4) -> vec3 {
    return {vector.x, vector.y, vector.z}
}

/**
 * @brief Returns a new vec4 using vector as the x, y and z components and w for w.
 * 
 * @param vector The 3-component vector.
 * @param w The w component.
 * @return A new vec4 
 */
vec3_to_vec4 :: #force_inline proc(vector: vec3, w: f32) -> la.Vector4f32 {
    return la.Vector4f32{vector.x, vector.y, vector.z, w}
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 0.0f.
 */
vec3_zero :: #force_inline proc() -> vec3 {
    return vec3{0.0, 0.0, 0.0}
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 1.0f.
 */
vec3_one :: #force_inline proc() -> vec3 {
    return vec3{1.0, 1.0, 1.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing up vec3(0, 1, 0).
 */
vec3_up :: #force_inline proc() -> vec3 {
    return vec3{0.0, 1.0, 0.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing down vec3(0, -1, 0).
 */
vec3_down :: #force_inline proc() -> vec3 {
    return vec3{0.0, -1.0, 0.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing left vec3(-1, 0, 0).
 */
vec3_left :: #force_inline proc() -> vec3 {
    return vec3{-1.0, 0.0, 0.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing right vec3(1, 0, 0).
 */
vec3_right :: #force_inline proc() -> vec3 {
    return vec3{1.0, 0.0, 0.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing forward vec3(0, 0, -1).
 */
vec3_forward :: #force_inline proc() -> vec3 {
    return vec3{0.0, 0.0, -1.0}
}

/**
 * @brief Creates and returns a 3-component vector pointing backward vec3(0, 0, 1).
 */
vec3_back :: #force_inline proc() -> vec3 {
    return vec3{0.0, 0.0, 1.0}
}

/**
 * @brief Adds vector_1 to vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec3_add :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> vec3 {
    return vector_0 + vector_1
}

/**
 * @brief Subtracts vector_1 from vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec3_sub :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> vec3 {
    return vector_0 - vector_1
}

/**
 * @brief Multiplies vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec3_mul :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> vec3 {
	return vector_0 * vector_1
}

/**
 * @brief Multiplies all elements of vector_0 by scalar and returns a copy of the result.
 * 
 * @param vector_0 The vector to be multiplied.
 * @param scalar The scalar value.
 * @return A copy of the resulting vector.
 */
vec3_mul_scalar :: #force_inline proc(vector_0: vec3, scalar: f32) -> vec3 {
    return vector_0 * scalar
}

/**
 * @brief Divides vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec3_div :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> vec3 {
	return vector_0 / vector_1
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
vec3_length_squared :: #force_inline proc(vector: vec3) -> f32 {
	return la.dot(vector, vector)
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
vec3_length :: #force_inline proc(vector: vec3) -> f32{
  return la.length(vector)
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
vec3_normalize :: #force_inline proc(vector: ^vec3) {
	v := la.vector_normalize(vector^)
	vector.x = v.x
	vector.y = v.y
	vector.z = v.z
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
vec3_normalized :: #force_inline proc(vector: vec3) -> vec3 {
	return la.normalize(vector)
}

/**
 * @brief Returns the dot product between the provided vectors. Typically used
 * to calculate the difference in direction.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The dot product. 
 */
vec3_dot :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> f32 {
	return la.dot(vector_0, vector_1)
}

/**
 * @brief Calculates and returns the cross product of the supplied vectors.
 * The cross product is a new vector which is orthoganal to both provided vectors.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The cross product. 
 */
vec3_cross :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> vec3 {
	return la.cross(vector_0, vector_1)
}

/**
 * @brief Compares all elements of vector_0 and vector_1 and ensures the difference
 * is less than tolerance.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @param tolerance The difference tolerance. Typically K_FLOAT_EPSILON or similar.
 * @return True if within tolerance otherwise false. 
 */
vec3_compare :: #force_inline proc(vector_0: vec3, vector_1: vec3, tolerance: f32) -> bool {
	if m.abs(vector_0.x - vector_1.x) > tolerance {
		return false
	}

	if m.abs(vector_0.y - vector_1.y) > tolerance {
		return false
	}

	if m.abs(vector_0.z - vector_1.z) > tolerance {
		return false
	}

	return true
}

/**
 * @brief Returns the distance between vector_0 and vector_1.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The distance between vector_0 and vector_1.
 */
vec3_distance :: #force_inline proc(vector_0: vec3, vector_1: vec3) -> f32 {
	return la.distance(vector_0, vector_1)
}


// ------------------------------------------
// Vector 4
// ------------------------------------------

/**
 * @brief Creates and returns a new 4-element vector using the supplied values.
 * 
 * @param x The x value.
 * @param y The y value.
 * @param z The z value.
 * @param w The w value.
 * @return A new 4-element vector.
 * @TODO simd
 */
vec4_create :: #force_inline proc (x: f32, y: f32, z: f32, w: f32) -> vec4 {
    return vec4{x, y, z, w}
}

/**
 * @brief Returns a new vec3 containing the x, y and z components of the 
 * supplied vec4, essentially dropping the w component.
 * 
	
}
 */
vec4_to_vec3 :: #force_inline proc(vector: vec4) -> la.Vector3f32 {
    return la.Vector3f32{vector.x, vector.y, vector.z}
}

/**
}
 * 
 * @param vector The 3-component vector.
 * @param w The w component.
 * @return A new vec4 
 */
vec4_from_vec3 :: #force_inline proc(vector: vec3, w: f32) -> vec4 {
	return vec4{vector.x, vector.y, vector.z, w}
}

/**
 * @brief Creates and returns a 3-component vector with all components set to 0.0f.
 */
vec4_zero :: #force_inline proc() -> vec4 {
    return vec4{0.0, 0.0, 0.0, 0.0}
}

/**
}
 */
vec4_one :: #force_inline proc() -> vec4 {
    return vec4{1.0, 1.0, 1.0, 1.0}
}

/**
 * @brief Adds vector_1 to vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
}
 */
vec4_add :: #force_inline proc(vector_0: vec4, vector_1: vec4) -> vec4 {
    return vector_0 + vector_1
}

/**
 * @brief Subtracts vector_1 from vector_0 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
}
 */
vec4_sub :: #force_inline proc(vector_0: vec4, vector_1: vec4) -> vec4 {
    return vector_0 - vector_1
}

/**
 * @brief Multiplies vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
}
 */
vec4_mul :: #force_inline proc(vector_0: vec4, vector_1: vec4) -> vec4 {
	return vector_0 * vector_1
}

/**
 * @brief Divides vector_0 by vector_1 and returns a copy of the result.
 * 
 * @param vector_0 The first vector.
 * @param vector_1 The second vector.
 * @return The resulting vector. 
 */
vec4_div :: #force_inline proc(vector_0: vec4, vector_1: vec4) -> vec4 {
	return vector_0 / vector_1
}

/**
 * @brief Returns the squared length of the provided vector.
 * 
 * @param vector The vector to retrieve the squared length of.
 * @return The squared length.
 */
vec4_length_squared :: #force_inline proc(vector: vec4) -> f32 {
	return la.dot(vector, vector)
}

/**
 * @brief Returns the length of the provided vector.
 * 
 * @param vector The vector to retrieve the length of.
 * @return The length.
 */
vec4_length :: #force_inline proc(vector: vec4) -> f32{
  return la.length(vector)
}

/**
 * @brief Normalizes the provided vector in place to a unit vector.
 * 
 * @param vector A pointer to the vector to be normalized.
 */
vec4_normalize :: #force_inline proc(vector: ^vec4) {
	v := la.normalize(vector^)
	vector.x = v.x
	vector.y = v.y
	vector.z = v.z
	vector.w = v.w
}

/**
 * @brief Returns a normalized copy of the supplied vector.
 * 
 * @param vector The vector to be normalized.
 * @return A normalized copy of the supplied vector 
 */
vec4_normalized :: #force_inline proc(vector: vec4) -> vec4 {
	return la.normalize(vector)
}

/**
 * @brief Creates and returns an identity matrix:
 * 
 * {
 *   {1, 0, 0, 0},
 *   {0, 1, 0, 0},
 *   {0, 0, 1, 0},
 *   {0, 0, 0, 1}
 * }
 * 
 * @return A new identity matrix 
 */
mat4_identity :: #force_inline proc() -> mat4 {
	return la.MATRIX4F32_IDENTITY
}

/**
 * @brief Returns the result of multiplying matrix_0 and matrix_1.
 * 
 * @param matrix_0 The first matrix to be multiplied.
 * @param matrix_1 The second matrix to be multiplied.
 * @return The result of the matrix multiplication.
 */
mat4_mul :: #force_inline proc(matrix_0: mat4, matrix_1: mat4) -> mat4 {
	return matrix_0 * matrix_1
}

/**
 * @brief Creates and returns an orthographic projection matrix. Typically used to
 * render flat or 2D scenes.
 * 
 * @param left The left side of the view frustum.
 * @param right The right side of the view frustum.
 * @param bottom The bottom side of the view frustum.
 * @param top The top side of the view frustum.
 * @param near_clip The near clipping plane distance.
 * @param far_clip The far clipping plane distance.
 * @return A new orthographic projection matrix. 
 */
mat4_orthographic :: #force_inline proc(left: f32, right: f32, bottom: f32, top: f32, near_clip: f32, far_clip: f32) -> mat4 {
	return la.matrix_ortho3d_f32(left, right, bottom, top, near_clip, far_clip)
}

/**
 * @brief Creates and returns a perspective matrix. Typically used to render 3d scenes.
 * 
 * @param fov_radians The field of view in radians.
 * @param aspect_ratio The aspect ratio.
 * @param near_clip The near clipping plane distance.
 * @param far_clip The far clipping plane distance.
 * @return A new perspective matrix. 
 */
mat4_perspective :: #force_inline proc(fov_radians: f32, aspect_ratio: f32, near_clip: f32, far_clip: f32) -> mat4 {
	return la.matrix4_perspective_f32(fov_radians, aspect_ratio, near_clip, far_clip)
}

/**
 * @brief Creates and returns a look-at matrix, or a matrix looking 
 * at target from the perspective of position.
 * 
 * @param position The position of the matrix.
 * @param target The position to "look at".
 * @param up The up vector.
 * @return A matrix looking at target from the perspective of position. 
 */
mat4_look_at :: #force_inline proc(position: vec3, target: vec3, up: vec3) -> mat4 {
	return la.matrix4_look_at_f32(position, target, up)
}

/**
 * @brief Returns a transposed copy of the provided matrix  :: #force_inline proc(rows->colums) -> mat4
 * 
 * @param matrix The matrix to be transposed.
 * @return A transposed copy of of the provided matrix.
 */
mat4_transposed :: #force_inline proc(m: mat4) -> mat4 {
	return la.transpose(m)
}

/**
 * @brief Creates and returns an inverse of the provided matrix.
 * 
 * @param matrix The matrix to be inverted.
 * @return A inverted copy of the provided matrix. 
 */
mat4_inverse :: #force_inline proc(m: mat4) -> mat4 {
	return la.inverse(m)
}

mat4_translation :: #force_inline proc(position: vec3) -> mat4 {
	return la.matrix4_translate(position)
}

/**
 * @brief Returns a scale matrix using the provided scale.
 * 
 * @param scale The 3-component scale.
 * @return A scale matrix.
 */
mat4_scale :: #force_inline proc(scale: f32) -> mat4 {
	return la.matrix4_scale_f32(scale)
}

mat4_euler_x :: #force_inline proc(angle_radians: f32) -> mat4 {
	return la.matrix4_from_euler_angle_x_f32(angle_radians)
}

mat4_euler_y :: #force_inline proc(angle_radians: f32) -> mat4 {
	return la.matrix4_from_euler_angle_y_f32(angle_radians)
}

mat4_euler_z :: #force_inline proc(angle_radians: f32) -> mat4 {
	return la.matrix4_from_euler_angle_z_f32(angle_radians)
}

mat4_euler_xyz :: #force_inline proc(x_radians: f32, y_radians: f32, z_radians: f32) -> mat4 {
	return la.matrix4_from_euler_angles_xyz(x_radians, y_radians, z_radians)
}

/**
 * @brief Returns a forward vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_forward :: #force_inline proc(m: mat4) -> vec3 {
}

/**
 * @brief Returns a backward vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_backward :: #force_inline proc(m: mat4) -> vec3 {
}

/**
 * @brief Returns a upward vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_up :: #force_inline proc(m: mat4) -> vec3 {
}

/**
 * @brief Returns a downward vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_down :: #force_inline proc(m: mat4) -> vec3 {
}

/**
 * @brief Returns a left vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_left :: #force_inline proc(m: mat4) -> vec3 {
}

/**
 * @brief Returns a right vector relative to the provided matrix.
 * 
 * @param matrix The matrix from which to base the vector.
 * @return A 3-component directional vector.
 */
mat4_right :: #force_inline proc(m: mat4) -> vec3 {
}

// ------------------------------------------
// Quaternion
// ------------------------------------------

// KINLINE quat quat_identity :: #force_inline proc() -> mat4 {
//     return (quat) -> mat4{0, 0, 0, 1.0f};
// }

// KINLINE f32 quat_normal(quat q) {
//     return ksqrt(
//         q.x * q.x +
//         q.y * q.y +
//         q.z * q.z +
//         q.w * q.w);
// }

// KINLINE quat quat_normalize(quat q) {
//     f32 normal = quat_normal(q);
//     return (quat){
//         q.x / normal,
//         q.y / normal,
//         q.z / normal,
//         q.w / normal};
// }

// KINLINE quat quat_conjugate(quat q) {
//     return (quat){
//         -q.x,
//         -q.y,
//         -q.z,
//         q.w};
// }

// KINLINE quat quat_inverse(quat q) {
//     return quat_normalize(quat_conjugate(q));
// }

// KINLINE quat quat_mul(quat q_0, quat q_1) {
//     quat out_quaternion;

//     out_quaternion.x = q_0.x * q_1.w +
//                        q_0.y * q_1.z -
//                        q_0.z * q_1.y +
//                        q_0.w * q_1.x;

//     out_quaternion.y = -q_0.x * q_1.z +
//                        q_0.y * q_1.w +
//                        q_0.z * q_1.x +
//                        q_0.w * q_1.y;

//     out_quaternion.z = q_0.x * q_1.y -
//                        q_0.y * q_1.x +
//                        q_0.z * q_1.w +
//                        q_0.w * q_1.z;

//     out_quaternion.w = -q_0.x * q_1.x -
//                        q_0.y * q_1.y -
//                        q_0.z * q_1.z +
//                        q_0.w * q_1.w;

//     return out_quaternion;
// }

// KINLINE f32 quat_dot(quat q_0, quat q_1) {
//     return q_0.x * q_1.x +
//            q_0.y * q_1.y +
//            q_0.z * q_1.z +
//            q_0.w * q_1.w;
// }

// KINLINE mat4 quat_to_mat4(quat q) {
//     mat4 out_matrix = mat4_identity();

//     // https://stackoverflow.com/questions/1556260/convert-quaternion-rotation-to-rotation-matrix

//     quat n = quat_normalize(q);

//     out_matrix.data[0] = 1.0f - 2.0f * n.y * n.y - 2.0f * n.z * n.z;
//     out_matrix.data[1] = 2.0f * n.x * n.y - 2.0f * n.z * n.w;
//     out_matrix.data[2] = 2.0f * n.x * n.z + 2.0f * n.y * n.w;

//     out_matrix.data[4] = 2.0f * n.x * n.y + 2.0f * n.z * n.w;
//     out_matrix.data[5] = 1.0f - 2.0f * n.x * n.x - 2.0f * n.z * n.z;
//     out_matrix.data[6] = 2.0f * n.y * n.z - 2.0f * n.x * n.w;

//     out_matrix.data[8] = 2.0f * n.x * n.z - 2.0f * n.y * n.w;
//     out_matrix.data[9] = 2.0f * n.y * n.z + 2.0f * n.x * n.w;
//     out_matrix.data[10] = 1.0f - 2.0f * n.x * n.x - 2.0f * n.y * n.y;

//     return out_matrix;
// }

// // Calculates a rotation matrix based on the quaternion and the passed in center point.
// KINLINE mat4 quat_to_rotation_matrix(quat q, vec3 center) {
//     mat4 out_matrix;

//     f32* o = out_matrix.data;
//     o[0] = (q.x * q.x) - (q.y * q.y) - (q.z * q.z) + (q.w * q.w);
//     o[1] = 2.0f * ((q.x * q.y) + (q.z * q.w));
//     o[2] = 2.0f * ((q.x * q.z) - (q.y * q.w));
//     o[3] = center.x - center.x * o[0] - center.y * o[1] - center.z * o[2];

//     o[4] = 2.0f * ((q.x * q.y) - (q.z * q.w));
//     o[5] = -(q.x * q.x) + (q.y * q.y) - (q.z * q.z) + (q.w * q.w);
//     o[6] = 2.0f * ((q.y * q.z) + (q.x * q.w));
//     o[7] = center.y - center.x * o[4] - center.y * o[5] - center.z * o[6];

//     o[8] = 2.0f * ((q.x * q.z) + (q.y * q.w));
//     o[9] = 2.0f * ((q.y * q.z) - (q.x * q.w));
//     o[10] = -(q.x * q.x) - (q.y * q.y) + (q.z * q.z) + (q.w * q.w);
//     o[11] = center.z - center.x * o[8] - center.y * o[9] - center.z * o[10];

//     o[12] = 0.0f;
//     o[13] = 0.0f;
//     o[14] = 0.0f;
//     o[15] = 1.0f;
//     return out_matrix;
// }

// KINLINE quat quat_from_axis_angle(vec3 axis, f32 angle, b8 normalize) {
//     const f32 half_angle = 0.5f * angle;
//     f32 s = ksin(half_angle);
//     f32 c = kcos(half_angle);

//     quat q = (quat){s * axis.x, s * axis.y, s * axis.z, c};
//     if (normalize) {
//         return quat_normalize(q);
//     }
//     return q;
// }

// KINLINE quat quat_slerp(quat q_0, quat q_1, f32 percentage) {
//     quat out_quaternion;
//     // Source: https://en.wikipedia.org/wiki/Slerp
//     // Only unit quaternions are valid rotations.
//     // Normalize to avoid undefined behavior.
//     quat v0 = quat_normalize(q_0);
//     quat v1 = quat_normalize(q_1);

//     // Compute the cosine of the angle between the two vectors.
//     f32 dot = quat_dot(v0, v1);

//     // If the dot product is negative, slerp won't take
//     // the shorter path. Note that v1 and -v1 are equivalent when
//     // the negation is applied to all four components. Fix by
//     // reversing one quaternion.
//     if (dot < 0.0f) {
//         v1.x = -v1.x;
//         v1.y = -v1.y;
//         v1.z = -v1.z;
//         v1.w = -v1.w;
//         dot = -dot;
//     }

//     const f32 DOT_THRESHOLD = 0.9995f;
//     if (dot > DOT_THRESHOLD) {
//         // If the inputs are too close for comfort, linearly interpolate
//         // and normalize the result.
//         out_quaternion = (quat){
//             v0.x + ((v1.x - v0.x) * percentage),
//             v0.y + ((v1.y - v0.y) * percentage),
//             v0.z + ((v1.z - v0.z) * percentage),
//             v0.w + ((v1.w - v0.w) * percentage)};

//         return quat_normalize(out_quaternion);
//     }

//     // Since dot is in range [0, DOT_THRESHOLD], acos is safe
//     f32 theta_0 = kacos(dot);          // theta_0 = angle between input vectors
//     f32 theta = theta_0 * percentage;  // theta = angle between v0 and result
//     f32 sin_theta = ksin(theta);       // compute this value only once
//     f32 sin_theta_0 = ksin(theta_0);   // compute this value only once

//     f32 s0 = kcos(theta) - dot * sin_theta / sin_theta_0;  // == sin(theta_0 - theta) / sin(theta_0)
//     f32 s1 = sin_theta / sin_theta_0;

//     return (quat){
//         (v0.x * s0) + (v1.x * s1),
//         (v0.y * s0) + (v1.y * s1),
//         (v0.z * s0) + (v1.z * s1),
//         (v0.w * s0) + (v1.w * s1)};
// }

// /**
//  * @brief Converts provided degrees to radians.
//  * 
//  * @param degrees The degrees to be converted.
//  * @return The amount in radians.
//  */
// KINLINE f32 deg_to_rad(f32 degrees) {
//     return degrees * K_DEG2RAD_MULTIPLIER;
// }

// /**
//  * @brief Converts provided radians to degrees.
//  * 
//  * @param radians The radians to be converted.
//  * @return The amount in degrees.
//  */
// KINLINE f32 rad_to_deg(f32 radians) {
//     return radians * K_RAD2DEG_MULTIPLIER;
// }
