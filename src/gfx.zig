pub const Image = []Pixel;

pub const Pixel = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

