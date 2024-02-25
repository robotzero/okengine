package okmath

import m "core:math"
import mb "core:math/bits"
import la "core:math/linalg"

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
quat :: la.Quaternionf32

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

