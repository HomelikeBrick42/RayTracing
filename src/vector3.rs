use std::{
    fmt::{Debug, Display},
    ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign},
};

use num::{traits::real::Real, One, Zero};

pub type Vector3f32 = Vector3<f32>;
pub type Vector3f64 = Vector3<f64>;

pub struct Vector3<T> {
    pub x: T,
    pub y: T,
    pub z: T,
}

impl<T> Vector3<T> {
    pub fn zero() -> Vector3<T>
    where
        T: Zero,
    {
        Vector3 {
            x: T::zero(),
            y: T::zero(),
            z: T::zero(),
        }
    }

    pub fn one() -> Vector3<T>
    where
        T: One,
    {
        Vector3 {
            x: T::one(),
            y: T::one(),
            z: T::one(),
        }
    }

    pub fn dot(self, other: Vector3<T>) -> T
    where
        T: Add<Output = T> + Mul<Output = T>,
    {
        self.x * other.x + self.y * other.y + self.z * other.z
    }

    pub fn length_sqr(self) -> T
    where
        T: Clone + Add<Output = T> + Mul<Output = T>,
    {
        self.clone().dot(self)
    }

    pub fn length(self) -> T
    where
        T: Real,
    {
        self.length_sqr().sqrt()
    }

    pub fn normalized(self) -> Vector3<T>
    where
        T: Real + Zero,
    {
        let length = self.length();
        if length.is_zero() {
            Vector3::zero()
        } else {
            Vector3 {
                x: self.x / length,
                y: self.y / length,
                z: self.z / length,
            }
        }
    }

    pub fn reflect(self, normal: Vector3<T>) -> Vector3<T>
    where
        T: Real + From<f64>,
    {
        self - (normal * self.dot(normal).into() * <T as From<f64>>::from(2.0).into()).into()
    }

    pub fn lerp(self, other: Vector3<T>, t: T) -> Vector3<T>
    where
        T: Real + From<f64>,
    {
        Vector3 {
            x: self.x * (<T as From<f64>>::from(1.0) - t).into() + other.x * t.into(),
            y: self.y * (<T as From<f64>>::from(1.0) - t).into() + other.y * t.into(),
            z: self.z * (<T as From<f64>>::from(1.0) - t).into() + other.z * t.into(),
        }
    }
}

impl<T> Add for Vector3<T>
where
    T: Add<Output = T>,
{
    type Output = Vector3<T>;

    fn add(self, other: Vector3<T>) -> Vector3<T> {
        Vector3 {
            x: self.x + other.x,
            y: self.y + other.y,
            z: self.z + other.z,
        }
    }
}

impl<T> AddAssign for Vector3<T>
where
    T: AddAssign,
{
    fn add_assign(&mut self, other: Vector3<T>) {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }
}

impl<T> Sub for Vector3<T>
where
    T: Sub<Output = T>,
{
    type Output = Vector3<T>;

    fn sub(self, other: Vector3<T>) -> Vector3<T> {
        Vector3 {
            x: self.x - other.x,
            y: self.y - other.y,
            z: self.z - other.z,
        }
    }
}

impl<T> SubAssign for Vector3<T>
where
    T: SubAssign,
{
    fn sub_assign(&mut self, other: Vector3<T>) {
        self.x -= other.x;
        self.y -= other.y;
        self.z -= other.z;
    }
}

impl<T> Mul for Vector3<T>
where
    T: Mul<Output = T>,
{
    type Output = Vector3<T>;

    fn mul(self, other: Vector3<T>) -> Vector3<T> {
        Vector3 {
            x: self.x * other.x,
            y: self.y * other.y,
            z: self.z * other.z,
        }
    }
}

impl<T> MulAssign for Vector3<T>
where
    T: MulAssign,
{
    fn mul_assign(&mut self, other: Vector3<T>) {
        self.x *= other.x;
        self.y *= other.y;
        self.z *= other.z;
    }
}

impl<T> Div for Vector3<T>
where
    T: Div<Output = T>,
{
    type Output = Vector3<T>;

    fn div(self, other: Vector3<T>) -> Vector3<T> {
        Vector3 {
            x: self.x / other.x,
            y: self.y / other.y,
            z: self.z / other.z,
        }
    }
}

impl<T> DivAssign for Vector3<T>
where
    T: DivAssign,
{
    fn div_assign(&mut self, other: Vector3<T>) {
        self.x /= other.x;
        self.y /= other.y;
        self.z /= other.z;
    }
}

impl<T: Neg<Output = T>> Neg for Vector3<T> {
    type Output = Vector3<T>;

    fn neg(self) -> Vector3<T> {
        Vector3 {
            x: -self.x,
            y: -self.y,
            z: -self.z,
        }
    }
}

impl<T: Default> Default for Vector3<T> {
    fn default() -> Vector3<T> {
        Vector3 {
            x: T::default(),
            y: T::default(),
            z: T::default(),
        }
    }
}

impl<T: Clone> From<T> for Vector3<T> {
    fn from(value: T) -> Vector3<T> {
        Vector3 {
            x: value.clone(),
            y: value.clone(),
            z: value,
        }
    }
}

impl<T: Clone> Clone for Vector3<T> {
    fn clone(&self) -> Vector3<T> {
        Vector3 {
            x: self.x.clone(),
            y: self.y.clone(),
            z: self.z.clone(),
        }
    }
}

impl<T: Copy> Copy for Vector3<T> {}

impl<T: PartialEq> PartialEq for Vector3<T> {
    fn eq(&self, other: &Vector3<T>) -> bool {
        self.x == other.x && self.y == other.y && self.z == other.z
    }
}

impl<T: Eq> Eq for Vector3<T> {}

impl<T: Debug> Debug for Vector3<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Vector2")
            .field("x", &self.x)
            .field("y", &self.y)
            .field("z", &self.z)
            .finish()
    }
}

impl<T: Display> Display for Vector3<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "({}, {}, {})", self.x, self.y, self.z)
    }
}
