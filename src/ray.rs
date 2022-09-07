use std::fmt::Debug;

use crate::Vector3;

pub type Rayf32 = Ray<f32>;
pub type Rayf64 = Ray<f64>;

pub struct Ray<T> {
    pub origin: Vector3<T>,
    pub direction: Vector3<T>,
}

impl<T: Default> Default for Ray<T> {
    fn default() -> Ray<T> {
        Ray {
            origin: Vector3::default(),
            direction: Vector3::default(),
        }
    }
}

impl<T: Clone> Clone for Ray<T> {
    fn clone(&self) -> Ray<T> {
        Ray {
            origin: self.origin.clone(),
            direction: self.direction.clone(),
        }
    }
}

impl<T: Copy> Copy for Ray<T> {}

impl<T: PartialEq> PartialEq for Ray<T> {
    fn eq(&self, other: &Ray<T>) -> bool {
        self.origin == other.origin && self.direction == other.direction
    }
}

impl<T: Eq> Eq for Ray<T> {}

impl<T: Debug> Debug for Ray<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Ray")
            .field("origin", &self.origin)
            .field("direction", &self.direction)
            .finish()
    }
}
