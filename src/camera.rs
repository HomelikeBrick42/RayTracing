use std::fmt::Debug;

use num::traits::real::Real;

use crate::{Ray, Vector3};

pub struct Camera<T> {
    pub position: Vector3<T>,
    pub forward: Vector3<T>,
    pub right: Vector3<T>,
    pub up: Vector3<T>,
    pub aspect: T,
}

impl<T> Camera<T> {
    pub fn get_ray(&self, x: T, y: T) -> Ray<T>
    where
        T: Real,
    {
        Ray {
            origin: self.position.clone(),
            direction: (self.right * x.into() * self.aspect.into())
                + (self.up * y.into())
                + self.forward,
        }
    }
}

impl<T: Clone> Clone for Camera<T> {
    fn clone(&self) -> Camera<T> {
        Camera {
            position: self.position.clone(),
            forward: self.forward.clone(),
            right: self.right.clone(),
            up: self.up.clone(),
            aspect: self.aspect.clone(),
        }
    }
}

impl<T: Copy> Copy for Camera<T> {}

impl<T: PartialEq> PartialEq for Camera<T> {
    fn eq(&self, other: &Camera<T>) -> bool {
        self.position == other.position
            && self.forward == other.forward
            && self.right == other.right
            && self.up == other.up
            && self.aspect == other.aspect
    }
}

impl<T: Eq> Eq for Camera<T> {}

impl<T: Debug> Debug for Camera<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Camera")
            .field("position", &self.position)
            .field("forward", &self.forward)
            .field("right", &self.right)
            .field("up", &self.up)
            .field("aspect", &self.aspect)
            .finish()
    }
}
