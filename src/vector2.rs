use std::{
    fmt::{Debug, Display},
    ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign},
};

use num::{traits::real::Real, One, Zero};

pub type Vector2f22 = Vector2<f32>;
pub type Vector2f64 = Vector2<f64>;

pub struct Vector2<T> {
    pub x: T,
    pub y: T,
}

impl<T> Vector2<T> {
    pub fn zero() -> Vector2<T>
    where
        T: Zero,
    {
        Vector2 {
            x: T::zero(),
            y: T::zero(),
        }
    }

    pub fn one() -> Vector2<T>
    where
        T: One,
    {
        Vector2 {
            x: T::one(),
            y: T::one(),
        }
    }

    pub fn dot(self, other: Vector2<T>) -> T
    where
        T: Add<Output = T> + Mul<Output = T>,
    {
        self.x * other.x + self.y * other.y
    }

    pub fn length_sqr(self) -> T
    where
        T: Clone + Add<Output = T> + Mul<Output = T>,
    {
        self.clone().dot(self)
    }

    pub fn length(self) -> T
    where
        T: Clone + Real,
    {
        self.length_sqr().sqrt()
    }

    pub fn normalized(self) -> Vector2<T>
    where
        T: Real + Zero,
    {
        let length = self.length();
        if length.is_zero() {
            Vector2::zero()
        } else {
            Vector2 {
                x: self.x / length,
                y: self.y / length,
            }
        }
    }
}

impl<T> Add for Vector2<T>
where
    T: Add<Output = T>,
{
    type Output = Vector2<T>;

    fn add(self, other: Vector2<T>) -> Vector2<T> {
        Vector2 {
            x: self.x + other.x,
            y: self.y + other.y,
        }
    }
}

impl<T> AddAssign for Vector2<T>
where
    T: AddAssign,
{
    fn add_assign(&mut self, other: Vector2<T>) {
        self.x += other.x;
        self.y += other.y;
    }
}

impl<T> Sub for Vector2<T>
where
    T: Sub<Output = T>,
{
    type Output = Vector2<T>;

    fn sub(self, other: Vector2<T>) -> Vector2<T> {
        Vector2 {
            x: self.x - other.x,
            y: self.y - other.y,
        }
    }
}

impl<T> SubAssign for Vector2<T>
where
    T: SubAssign,
{
    fn sub_assign(&mut self, other: Vector2<T>) {
        self.x -= other.x;
        self.y -= other.y;
    }
}

impl<T> Mul for Vector2<T>
where
    T: Mul<Output = T>,
{
    type Output = Vector2<T>;

    fn mul(self, other: Vector2<T>) -> Vector2<T> {
        Vector2 {
            x: self.x * other.x,
            y: self.y * other.y,
        }
    }
}

impl<T> MulAssign for Vector2<T>
where
    T: MulAssign,
{
    fn mul_assign(&mut self, other: Vector2<T>) {
        self.x *= other.x;
        self.y *= other.y;
    }
}

impl<T> Div for Vector2<T>
where
    T: Div<Output = T>,
{
    type Output = Vector2<T>;

    fn div(self, other: Vector2<T>) -> Vector2<T> {
        Vector2 {
            x: self.x / other.x,
            y: self.y / other.y,
        }
    }
}

impl<T> DivAssign for Vector2<T>
where
    T: DivAssign,
{
    fn div_assign(&mut self, other: Vector2<T>) {
        self.x /= other.x;
        self.y /= other.y;
    }
}

impl<T: Neg<Output = T>> Neg for Vector2<T> {
    type Output = Vector2<T>;

    fn neg(self) -> Vector2<T> {
        Vector2 {
            x: -self.x,
            y: -self.y,
        }
    }
}

impl<T: Default> Default for Vector2<T> {
    fn default() -> Vector2<T> {
        Vector2 {
            x: T::default(),
            y: T::default(),
        }
    }
}

impl<T: Clone> From<T> for Vector2<T> {
    fn from(value: T) -> Vector2<T> {
        Vector2 {
            x: value.clone(),
            y: value,
        }
    }
}

impl<T: Clone> Clone for Vector2<T> {
    fn clone(&self) -> Vector2<T> {
        Vector2 {
            x: self.x.clone(),
            y: self.y.clone(),
        }
    }
}

impl<T: Copy> Copy for Vector2<T> {}

impl<T: PartialEq> PartialEq for Vector2<T> {
    fn eq(&self, other: &Vector2<T>) -> bool {
        self.x == other.x && self.y == other.y
    }
}

impl<T: Eq> Eq for Vector2<T> {}

impl<T: Debug> Debug for Vector2<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Vector2")
            .field("x", &self.x)
            .field("y", &self.y)
            .finish()
    }
}

impl<T: Display> Display for Vector2<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}
