package main

import "core:math/linalg/glsl"

Material :: struct {
	color:          glsl.dvec3,
	reflectiveness: f64,
	emission_color: glsl.dvec3,
	scatter:        f64,
}

Plane :: struct {
	material:   Material,
	y_position: f64,
}

Sphere :: struct {
	material: Material,
	position: glsl.dvec3,
	radius:   f64,
}
