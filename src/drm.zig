pub const Format = enum (u32) {
};

pub const ModifierValue = packed struct (u64) {
  code: u56,
  vendor: Vendor,

  pub fn create(vendor: Vendor, num: u64) ModifierValue {
    return .{
      .vendor = vendor,
      .code = @truncate(num & 0x00ffffffffffffff),
    };
  }

  pub const Vendor = enum (u8) {
    none = 0,
    intel = 0x01,
    amd = 0x02,
    nvidia = 0x03,
    samsung = 0x04,
    qcom = 0x05,
    vivante = 0x06,
    broadcom = 0x07,
    arm = 0x08,
    allwinner = 0x09,
    amlogic = 0x0a,
  };
};

pub const Modifier = enum (u64) {
  invalid = base.u64_(ModifierValue.create(.none, ((1<<56) - 1))),
  linear = base.u64_(ModifierValue.create(.none, 0)),
};

const base = @import("base");
