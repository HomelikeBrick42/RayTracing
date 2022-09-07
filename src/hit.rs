use std::fmt::Debug;

use crate::{Material, Ray, Vector3};

pub trait Intersectable<T, C> {
    fn intersect(&self, ray: &Ray<T>) -> Option<RayHit<T, C>>;
}

pub struct RayHit<T, C> {
    pub position: Vector3<T>,
    pub normal: Vector3<T>,
    pub distance: T,
    pub material: Material<T, C>,
}

impl<T: Default, C: Default> Default for RayHit<T, C> {
    fn default() -> RayHit<T, C> {
        RayHit {
            position: Default::default(),
            normal: Default::default(),
            distance: Default::default(),
            material: Default::default(),
        }
    }
}

impl<T: Clone, C: Clone> Clone for RayHit<T, C> {
    fn clone(&self) -> RayHit<T, C> {
        RayHit {
            position: self.position.clone(),
            normal: self.normal.clone(),
            distance: self.distance.clone(),
            material: self.material.clone(),
        }
    }
}

impl<T: Copy, C: Copy> Copy for RayHit<T, C> {}

impl<T: PartialEq, C: PartialEq> PartialEq for RayHit<T, C> {
    fn eq(&self, other: &Self) -> bool {
        self.position == other.position
            && self.normal == other.normal
            && self.distance == other.distance
            && self.material == other.material
    }
}

impl<T: Eq, C: Eq> Eq for RayHit<T, C> {}

impl<T: Debug, C: Debug> Debug for RayHit<T, C> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("RayHit")
            .field("position", &self.position)
            .field("normal", &self.normal)
            .field("distance", &self.distance)
            .field("material", &self.material)
            .finish()
    }
}
