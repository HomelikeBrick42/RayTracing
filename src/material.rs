use std::fmt::Debug;

use crate::Vector3;

pub struct Material<T, C> {
    pub diffuse_color: Vector3<C>,
    pub emissive_color: Vector3<C>,
    pub smoothness: T,
}

impl<T: Default, C: Default> Default for Material<T, C> {
    fn default() -> Material<T, C> {
        Material {
            diffuse_color: Default::default(),
            emissive_color: Default::default(),
            smoothness: Default::default(),
        }
    }
}

impl<T: Clone, C: Clone> Clone for Material<T, C> {
    fn clone(&self) -> Material<T, C> {
        Material {
            diffuse_color: self.diffuse_color.clone(),
            emissive_color: self.emissive_color.clone(),
            smoothness: self.smoothness.clone(),
        }
    }
}

impl<T: Copy, C: Copy> Copy for Material<T, C> {}

impl<T: PartialEq, C: PartialEq> PartialEq for Material<T, C> {
    fn eq(&self, other: &Material<T, C>) -> bool {
        self.diffuse_color == other.diffuse_color
            && self.emissive_color == other.emissive_color
            && self.smoothness == other.smoothness
    }
}

impl<T: Eq, C: Eq> Eq for Material<T, C> {}

impl<T: Debug, C: Debug> Debug for Material<T, C> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Material")
            .field("diffuse_color", &self.diffuse_color)
            .field("emissive_color", &self.emissive_color)
            .field("smoothness", &self.smoothness)
            .finish()
    }
}
