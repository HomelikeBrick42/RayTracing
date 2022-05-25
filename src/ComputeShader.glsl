#version 440 core

layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;
layout(rgba32f, binding = 0) uniform image2D u_Texture;

const double MaxDistance = 1000.0;
const double MinDistance = 0.01;
const uint MaxBounces = 500;

struct Camera {
	dvec3 position;
	dvec3 forward;
	dvec3 right;
	dvec3 up;
	double v_fov;
};

uniform Camera u_Camera;
uniform float u_Time;

struct Ray {
	dvec3 origin;
	dvec3 direction;
};

struct Material {
	dvec3 color;
	double reflectiveness;
	dvec3 emission_color;
	double scatter;
};

struct Plane {
	Material material;
	double y_position;
};

struct Sphere {
	Material material;
	dvec3 position;
	double radius;
};

uniform uint u_PlaneCount;
layout(std430, binding = 1) buffer l_Planes
{
	Plane planes[];
};

uniform uint u_SphereCount;
layout(std430, binding = 2) buffer l_Spheres
{
	Sphere spheres[];
};

// From: https://stackoverflow.com/a/17479300
uint hash(uint x) {
    x += (x << 10u);
    x ^= (x >>  6u);
    x += (x <<  3u);
    x ^= (x >> 11u);
    x += (x << 15u);
    return x;
}

uint hash(uvec2 v) { return hash(v.x ^ hash(v.y)); }
uint hash(uvec3 v) { return hash(v.x ^ hash(v.y) ^ hash(v.z)); }
uint hash(uvec4 v) { return hash(v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w)); }

float floatConstruct(uint m) {
    const uint ieeeMantissa = 0x007FFFFFu; // binary32 mantissa bitmask
    const uint ieeeOne      = 0x3F800000u; // 1.0 in IEEE binary32

    m &= ieeeMantissa;                     // Keep only mantissa bits (fractional part)
    m |= ieeeOne;                          // Add fractional part to 1.0

    float  f = uintBitsToFloat(m);       // Range [1:2]
    return f - 1.0;                        // Range [0:1]
}

float random(float x) { return floatConstruct(hash(floatBitsToUint(x))); }
float random(vec2 v) { return floatConstruct(hash(floatBitsToUint(v))); }
float random(vec3 v) { return floatConstruct(hash(floatBitsToUint(v))); }
float random(vec4 v) { return floatConstruct(hash(floatBitsToUint(v))); }

vec3 state;

float random_range(float lo, float hi) {
    float value = (hi - lo) * random(state);
    state.x = random(state);
    state.y = random(state);
    state.z = random(state);
    return value;
}

double GetClosestDistance(dvec3 point) {
	double dist = MaxDistance * 2.0;
	for (uint i = 0; i < u_PlaneCount; i++) {
		dist = min(dist, abs(point.y - planes[i].y_position));
	}
	for (uint i = 0; i < u_SphereCount; i++) {
		dist = min(dist, length(point - spheres[i].position) - spheres[i].radius);
	}
	return dist;
}

Material GetClosestMaterial(dvec3 point) {
	Material material;
	double dist = MaxDistance * 2.0;
	for (uint i = 0; i < u_PlaneCount; i++) {
		double new_dist = abs(point.y - planes[i].y_position);
		if (new_dist < dist) {
			dist = new_dist;
			material = planes[i].material;
		}
	}
	for (uint i = 0; i < u_SphereCount; i++) {
		double new_dist = length(point - spheres[i].position) - spheres[i].radius;
		if (new_dist < dist) {
			dist = new_dist;
			material = spheres[i].material;
		}
	}
	return material;
}

dvec3 RandomInHemisphere(dvec3 normal) {
    for (uint i = 0; i < 100; i++) {
        dvec3 value = dvec3(
            double(random_range(-1.0, 1.0)),
            double(random_range(-1.0, 1.0)),
            double(random_range(-1.0, 1.0))
        );
        if (dot(value, value) > 1.0) continue;
        if (dot(value, normal) < 0.0) continue;
        return value;
    }
    return normal;
}

dvec3 RayMarch(Ray ray) {
	double total_distance = 0.0;

    Material materials[MaxBounces];

	uint bounce = 0;
	for (uint i = 0; i < 1000; i++) {
		dvec3 point = ray.origin + ray.direction * total_distance;
		double dist = GetClosestDistance(point);
		total_distance += dist;
		if (abs(total_distance) > MaxDistance) break;
		if (abs(dist) < MinDistance) {
			dvec3 XDir = dvec3(MinDistance, 0.0, 0.0);
			dvec3 YDir = dvec3(0.0, MinDistance, 0.0);
			dvec3 ZDir = dvec3(0.0, 0.0, MinDistance);
			dvec3 normal = normalize(
				dvec3(
					GetClosestDistance(point + XDir) - GetClosestDistance(point - XDir),
					GetClosestDistance(point + YDir) - GetClosestDistance(point - YDir),
					GetClosestDistance(point + ZDir) - GetClosestDistance(point - ZDir)
				)
			);
			
			materials[bounce] = GetClosestMaterial(point);

			ray.origin = point + normal * MinDistance,
			ray.direction = mix(
				reflect(ray.direction, normal),
				normalize(RandomInHemisphere(normal)),
				materials[bounce].scatter
			);

			total_distance = 0.0;
			bounce++;
			if (bounce > MaxBounces) return dvec3(0.0);
		}
	}

    dvec3 color = dvec3(0.0);
    for (int i = int(bounce) - 1; i >= 0; i--) {
        color *= mix(
            materials[i].color,
            dvec3(1.0),
            materials[i].reflectiveness
        );
        color += materials[i].emission_color;
    }
	return color;
}

void main() {
	ivec2 image_size = imageSize(u_Texture);
	ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
	dvec2 uv = dvec2(pixel_coord) / dvec2(image_size) * 2.0 - 1.0;
	if (image_size.x > image_size.y) {
		uv.x *= double(image_size.x) / double(image_size.y);
	} else {
		uv.y *= double(image_size.y) / double(image_size.x);
	}
	uv *= double(tan(radians(float(u_Camera.v_fov)) * 0.5) * 2.0); // TODO: why is there no overload of `radians` for `double`?

    state = vec3(vec2(pixel_coord), u_Time);

	Ray ray;
	ray.origin = u_Camera.position;
	ray.direction = normalize(
		u_Camera.forward +
		u_Camera.right * uv.x +
		u_Camera.up * uv.y
	);

	dvec3 color = RayMarch(ray);
	imageStore(u_Texture, pixel_coord, imageLoad(u_Texture, pixel_coord) + vec4(vec3(color), 1.0));
}
