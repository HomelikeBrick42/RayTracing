package main

import "core:math/rand"
import "core:math/linalg/glsl"

RandomDirectionInUnitCircle :: proc(r: ^rand.Rand) -> glsl.dvec2 {
	for {
		direction := glsl.dvec2{
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
		}
		if glsl.dot(direction, direction) > 1.0 do continue
		return direction
	}
}

RandomDirectionInUnitSphere :: proc(r: ^rand.Rand) -> glsl.dvec3 {
	for {
		direction := glsl.dvec3{
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
		}
		if glsl.dot(direction, direction) > 1.0 do continue
		return direction
	}
}

RandomInHemisphere :: proc(normal: glsl.dvec3, r: ^rand.Rand) -> glsl.dvec3 {
	in_unit_sphere := RandomDirectionInUnitSphere(r)
	if (glsl.dot(in_unit_sphere, normal) > 0.0) {
		return in_unit_sphere
	} else {
		return -in_unit_sphere
	}
}
