use std::fmt::Debug;

use num::traits::real::Real;

use crate::{Intersectable, Material, Ray, RayHit, Vector3};

pub struct Sphere<T, C> {
    pub position: Vector3<T>,
    pub radius: T,
    pub material: Material<T, C>,
}

impl<T, C> Intersectable<T, C> for Sphere<T, C>
where
    T: Real,
    C: Clone,
{
    fn intersect(&self, ray: &Ray<T>) -> Option<RayHit<T, C>> {
        let oc = ray.origin - self.position;
        let a = ray.direction.length_sqr();
        let half_b = oc.dot(ray.direction);
        let c = oc.length_sqr() - self.radius * self.radius;
        let discriminant = half_b * half_b - a * c;
        if discriminant >= T::zero() {
            let mut distance = (-half_b - discriminant.sqrt()) / a;
            let (position, normal) = if distance >= T::zero() {
                let position = ray.origin + ray.direction * distance.into();
                let normal = (position - self.position) / self.radius.into();
                (position, normal)
            } else {
                distance = (-half_b + discriminant.sqrt()) / a;
                let position = ray.origin + ray.direction * distance.into();
                let normal = -(position - self.position) / self.radius.into();
                (position, normal)
            };
            Some(RayHit {
                position,
                normal,
                distance,
                material: self.material.clone(),
            })
        } else {
            None
        }
    }
}

impl<T: Clone, C: Clone> Clone for Sphere<T, C> {
    fn clone(&self) -> Sphere<T, C> {
        Sphere {
            position: self.position.clone(),
            radius: self.radius.clone(),
            material: self.material.clone(),
        }
    }
}

impl<T: Copy, C: Copy> Copy for Sphere<T, C> {}

impl<T: PartialEq, C: PartialEq> PartialEq for Sphere<T, C> {
    fn eq(&self, other: &Sphere<T, C>) -> bool {
        self.position == other.position
            && self.radius == other.radius
            && self.material == other.material
    }
}

impl<T: Eq, C: Eq> Eq for Sphere<T, C> {}

impl<T: Debug, C: Debug> Debug for Sphere<T, C> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Sphere")
            .field("position", &self.position)
            .field("radius", &self.radius)
            .field("material", &self.material)
            .finish()
    }
}
