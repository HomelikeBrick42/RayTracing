package main

import "core:math/linalg/glsl"

Object :: union {
	Sphere,
	Plane,
}

Material :: struct {
	color:          glsl.dvec3,
	emission_color: glsl.dvec3,
	reflectiveness: f64,
	scatter:        f64,
}

Object_GetMaterial :: #force_inline proc(object: Object) -> Material {
	switch o in object {
	case Sphere:
		return o.material
	case Plane:
		return o.material
	case:
		return {}
	}
}

Sphere :: struct {
	material: Material,
	position: glsl.dvec3,
	radius:   f64,
}

Plane :: struct {
	material:   Material,
	y_position: f64,
}
