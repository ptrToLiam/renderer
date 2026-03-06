pub fn app(env: std.process.Environ) void {
  const app_name = "LmDev-" ++ AppName;
  const app_class = "LmDev-" ++ AppClass;

  const arena: *Arena = .init(.default);
  defer arena.release();

  //---------------------------------------------------------------------------
  // BEGIN VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vk_instance_init_start = time.us();

  var vk_ctx: VkContext = undefined;
  vk_ctx.init_instance(
    &.{
      .name = app_name,
      .app_version = vk.makeApiVersion(0, 1, 0, 0),
      .engine_name = "custom",
      .engine_version = vk.makeApiVersion(0, 1, 0, 0),
      .api_version = vk.API_VERSION_1_4,
    },
  ) catch @panic("Failed Vulkan Instance Init!");
  defer vk_ctx.destroy();

  const vk_instance_init_end = time.us();
  const vk_instance_init_us = vk_instance_init_end - vk_instance_init_start;
  log.info(
    "vulkan instance initialized in {d}us ({d}ms)!",
    .{ vk_instance_init_us, vk_instance_init_us / time.us_per_ms },
  );

  //---------------------------------------------------------------------------

  const initial_width = 1280;
  const initial_height = 720;
  const render_width = 960;
  const render_height = 540;
  const slang_shader = arena.push(u32, slang_shader_bytes.len / 4);
  @memcpy(transmute([]u8, slang_shader), slang_shader_bytes);

  //---------------------------------------------------------------------------
  // BEGIN PLATFORM CONNECTION INIT
  //---------------------------------------------------------------------------

  const connection_init_start_us = time.us();
  var connection: platform.Connection = .open(arena, env);
  defer connection.close();

  var surface = connection.acquire_surface(
    arena,
    .{
      .title = app_name,
      .class = app_class,
      .width = initial_width,
      .height = initial_height,
      .flags = .{ .resize = true },
    },
  );
  defer surface.release();

  const connection_init_end_us = time.us();
  const connection_init_us = connection_init_end_us - connection_init_start_us;

  //---------------------------------------------------------------------------

  log.info(
    "platform connection initialized in {d}us ({d:.2}ms)!",
    .{ connection_init_us, base.f64_(connection_init_us) / base.f64_(time.us_per_ms) },
  );

  // initialize vk device
  vk_ctx.init_device(
    connection.select_vk_physical_device(
      vk_ctx.instance_proxy,
      &vk_required_device_extensions,
    ),
    &vk_required_device_extensions,
    .{ .reset_command_buffer_bit = true },
  ) catch @panic("Unable to Initialize Vulkan Device!");

  const img_fmt: gfx.Format = .rgba32;

  // prepare render image
  const render_image = vk_ctx.alloc_image(
    render_width,
    render_height,
    img_fmt.toVk(),
    .{ .storage_bit = true, .transfer_src_bit = true },
    .optimal,
    null,
    null,
  ) catch @panic("Failed to allocate primary render image!");
  defer vk_ctx.destroy_image(render_image);

  // swapchain construction
  var swapchain = platform.Swapchain.alloc(
    arena,
    &vk_ctx,
    &surface,
    initial_width,
    initial_height,
    img_fmt,
    2,
  ) catch unreachable;
  defer swapchain.release();

  var cmd: vk.CommandBuffer = undefined;
  vk_ctx.device_proxy.allocateCommandBuffers(
    &.{
      .command_pool = vk_ctx.command_pool,
      .level = .primary,
      .command_buffer_count = 1
    },
    transmute([*]vk.CommandBuffer, &cmd),
  ) catch @panic("failed to allocate cmdbuf from cmdpool");

  const color_subresource = vk.ImageSubresourceLayers{
    .aspect_mask = .{ .color_bit = true },
    .mip_level = 0,
    .base_array_layer = 0,
    .layer_count = 1,
  };

  const compute_pipeline = createComputePipeline(
    vk_ctx.device_proxy,
    slang_shader,
  ) catch unreachable;
  defer vk_ctx.device_proxy.destroyPipeline(compute_pipeline.pipeline, null);

  const descriptor_set = createDescriptorSet(
    vk_ctx.device_proxy,
    compute_pipeline.dsl,
    render_image.view,
  ) catch unreachable;

  var draw_fence: vk.Fence = vk_ctx.device_proxy.createFence(
    &.{
      .flags = .{ .signaled_bit = true },
    },
    null,
  ) catch @panic("Failed to create draw_fence!");
  defer vk_ctx.device_proxy.destroyFence(draw_fence, null);

  const setup_time_full = time.us();
  log.info(
    "Full Setup Time :: {}us ({}ms)",
    .{ setup_time_full, setup_time_full / time.us_per_ms },
  );

  var events: platform.EventList = .empty;
  var want_exit = false;

  var bg_r: f32 = undefined;
  var bg_g: f32 = undefined;
  var bg_b: f32 = undefined;

  var frame_idx: u64 = 0;
  var first_attach = true;
  const time_target = time.us_per_s / 120;
  while (!want_exit) {
    const frame_time_start = time.us();
    var frame_scratch = Thread.Context.get_scratch(1, .{arena}).?;

    defer frame_scratch.end();
    const frame_arena = frame_scratch.arena;
    defer frame_idx +%= 1;

    bg_r = math.sin(f32_(frame_idx) / 200);
    bg_g = math.sin(f32_(frame_idx) / 400);
    bg_b = math.sin(f32_(frame_idx) / 600);

    events = connection.get_events(frame_arena, &surface);
    var event_opt = events.first;
    while (event_opt) |ev| : (event_opt = ev.next) {
      // event handling loop
      switch (ev.type) {
        .surface_close => {
          want_exit = true;
        },
        .surface_resize => {
          swapchain.mark_outdated(u32_(ev.delta.x), u32_(ev.delta.y));
        },
        .buffer_release => {
          swapchain.release_buffer();
        },
        else => {
          log.debug("app-level ev :: {any}", .{ev});
        },
      }
    }
    const g: ShaderGlobals = .{
        .color = .{ bg_r, bg_g, bg_b, },
        .time = f32_(u32_(time.us())),
    };
    // Draw Logic
    {
      _ = vk_ctx.device_proxy.waitForFences(
        1,
        @ptrCast(&draw_fence),
        .true,
        math.maxInt(u32),
      ) catch |err| {
        log.err("Failed to wait for fence on entry :: {s}", .{@errorName(err)});
        @panic("Failed to wait for fences");
      };


      // reconstruct swapchain if needed
      if (swapchain.pending_resize) |new_dims| {
        @branchHint(.cold);
        swapchain.recreate(new_dims.x, new_dims.y, img_fmt) catch unreachable;
      }
      // - command_buffer_begin
      vk_ctx.device_proxy.beginCommandBuffer(
        cmd,
        &.{},
      ) catch @panic("Failed to begin command buffer");

      vk_ctx.device_proxy.cmdPushConstants(
          cmd,
          compute_pipeline.layout,
          .{ .compute_bit = true },
          0,
          @sizeOf(ShaderGlobals),
          &g,
      );

      // Compute shader dispatch
      vk_ctx.device_proxy.cmdBindPipeline(cmd, .compute, compute_pipeline.pipeline);
      vk_ctx.device_proxy.cmdBindDescriptorSets(
        cmd,
        .compute,
        compute_pipeline.layout,
        0,
        1,
        @ptrCast(&descriptor_set.set),
        0,
        null,
      );
      vk_ctx.device_proxy.cmdDispatch(cmd,
        (render_image.width + 15) / 16,
        (render_image.height + 15) / 16,
        1
      );

      // frame rendering done, acquire swapchain image

      const sc_image_opt = swapchain.acquire_image();
      if (sc_image_opt) |swapchain_image| {
        // render image is 960x540, swapchain image is 1920x1080
        // Blit render image -> swapchain image
        vk_ctx.device_proxy.cmdBlitImage(cmd,
            render_image.image, .general,
            swapchain_image.image, .general,
            1,
            &.{
              .{
                .src_offsets = .{
                  .{ .x = 0, .y = 0, .z = 0 },
                  .{ .x = i32_(render_image.width), .y = i32_(render_image.height), .z = 1 },
                },
                .dst_offsets = .{
                  .{ .x = 0, .y = 0, .z = 0 },
                  .{ .x = i32_(swapchain_image.width), .y = i32_(swapchain_image.height), .z = 1 },
                },
                .src_subresource = color_subresource,
                .dst_subresource = color_subresource,
              },
            },
            .nearest,
        );

        vk_ctx.device_proxy.endCommandBuffer(cmd) catch unreachable;
        // sync
        vk_ctx.device_proxy.resetFences(
          1,
          @ptrCast(&draw_fence),
        ) catch |err| {
          log.err("Fence reset failed :: {s}", .{@errorName(err)});
          @panic("Fence reset failed");
        };
        const submit_info: vk.SubmitInfo = .{
          .wait_semaphore_count = 0,
          .command_buffer_count = 1,
          .p_command_buffers = @ptrCast(&cmd),
          .signal_semaphore_count = 0,
        };
        vk_ctx.device_proxy.queueSubmit(
          vk_ctx.queue,
          1,
          @ptrCast(&submit_info),
          draw_fence,
        ) catch @panic("Failed to sumbmit to queue!");

        if (sc_image_opt != null)
          swapchain.present();
      } else {
        vk_ctx.device_proxy.endCommandBuffer(cmd) catch unreachable;
      }
    }

    connection.flush() catch unreachable;

    const frame_time_end = time.us();
    if (first_attach) {
      @branchHint(.cold);
      log.info(
        "Time to first frame presentation :: {}us ({}ms) !",
        .{ frame_time_end, frame_time_end / time.us_per_ms },
      );
      first_attach = false;
    }
    const frame_elapsed_us = frame_time_end - frame_time_start;
    if (frame_elapsed_us < time_target) {
      Thread.sleep((time_target - frame_elapsed_us) * time.ns_per_us);
    }
  }
  _ = vk_ctx.device_proxy.waitForFences(
    1,
    @ptrCast(&draw_fence),
    .true,
    math.maxInt(u32),
  ) catch |err| {
    log.err("Failed to wait for fence on entry :: {s}", .{@errorName(err)});
    @panic("Failed to wait for fences");
  };
}

fn update() void {
}

fn draw() void {
}
const ShaderGlobals = extern struct {
    color: [3]f32,
    time: f32,
};

fn createDescriptorSet(
    device: vk.DeviceProxy,
    dsl: vk.DescriptorSetLayout,
    render_image_view: vk.ImageView,
) !struct { pool: vk.DescriptorPool, set: vk.DescriptorSet } {

    // 1. Pool sized for one storage image
    const pool = try device.createDescriptorPool(&.{
        .max_sets = 1,
        .pool_size_count = 1,
        .p_pool_sizes = &.{.{
            .type = .storage_image,
            .descriptor_count = 1,
        }},
    }, null);
    errdefer device.destroyDescriptorPool(pool, null);

    // 2. Allocate the set
    var set: vk.DescriptorSet = undefined;
    try device.allocateDescriptorSets(&.{
        .descriptor_pool = pool,
        .descriptor_set_count = 1,
        .p_set_layouts = &.{dsl},
    }, @ptrCast(&set));

    // 3. Write the storage image binding
    device.updateDescriptorSets(1, &.{.{
        .dst_set = set,
        .dst_binding = 0,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .storage_image,
        .p_buffer_info = &.{},
        .p_texel_buffer_view = &.{},
        .p_image_info = &.{.{
            .sampler = .null_handle,
            .image_view = render_image_view,
            .image_layout = .general,
        }},
    }}, 0, null);

    return .{ .pool = pool, .set = set };
}
fn createComputePipeline(
    device: vk.DeviceProxy,
    shader_code: []const u32, // compiled SPIR-V from Slang
) !struct { pipeline: vk.Pipeline, layout: vk.PipelineLayout, dsl: vk.DescriptorSetLayout } {
  // 1. Descriptor set layout — single storage image binding
  const dsl = try device.createDescriptorSetLayout(&.{
    .binding_count = 1,
    .p_bindings = &.{.{
        .binding = 0,
        .descriptor_type = .storage_image,
        .descriptor_count = 1,
        .stage_flags = .{ .compute_bit = true },
    }},
  }, null);
  errdefer device.destroyDescriptorSetLayout(dsl, null);

  // 2. Pipeline layout
  const layout = try device.createPipelineLayout(&.{
    .set_layout_count = 1,
    .p_set_layouts = &.{dsl},
    .push_constant_range_count = 1,
    .p_push_constant_ranges = &.{.{
        .stage_flags = .{ .compute_bit = true },
        .offset = 0,
        .size = @sizeOf(ShaderGlobals),
    }},
}, null);
  errdefer device.destroyPipelineLayout(layout, null);

  // 3. Shader module
  const shader_module = try device.createShaderModule(&.{
    .code_size = shader_code.len * @sizeOf(u32),
    .p_code = shader_code.ptr,
  }, null);
  defer device.destroyShaderModule(shader_module, null);

  // 4. Compute pipeline — just one stage, no rasterizer state
  var pipeline: vk.Pipeline = undefined;
  _ = try device.createComputePipelines(
    .null_handle, // pipeline cache, wire one in later
    1,
    &.{.{
        .stage = .{
            .stage = .{ .compute_bit = true },
            .module = shader_module,
            .p_name = "compMain",
        },
        .layout = layout,
        .base_pipeline_index = -1,
    }},
    null,
    @ptrCast(&pipeline),
  );

  return .{
    .pipeline = pipeline,
    .layout = layout,
    .dsl = dsl,
  };
}

fn createShaderModule(
  dev: vk.DeviceProxy,
  code: []const u32,
) vk.ShaderModule {
  const createInfo: vk.ShaderModuleCreateInfo = .{
    .flags = .{},
    .code_size = code.len * 4,
    .p_code = code.ptr,
  };

  const shader_module = dev.createShaderModule(
    &createInfo,
    null,
  ) catch unreachable;
  return shader_module;
}

const vk_required_device_extensions = [_][*:0]const u8{
  vk.extensions.khr_external_memory.name,
  vk.extensions.khr_external_memory_fd.name,
  vk.extensions.ext_external_memory_dma_buf.name,
  vk.extensions.ext_image_drm_format_modifier.name,
};

const OffscreenBuffer = platform.OffscreenBuffer;

const AppName = "vkRender";
const AppClass = "Liam.Games.vkRender";

const slang_shader_bytes = @embedFile("shaders/comp.spv");

const cast = base.casts.cast;
const transmute = base.casts.transmute;

const i32_ = base.i32_;
const u32_ = base.u32_;
const u64_ = base.u64_;

const f32_ = base.f32_;
const f64_ = base.f64_;

const Arena = base.Arena;
const Thread = base.Thread;
const math = base.math;
const time = base.time;

const Drm = gfx.Drm;
const gfx = platform.gfx;

const VkContext = platform.VkContext;

const base = @import("base");
const os = @import("os");
const vk = @import("vulkan");
const platform = @import("platform");

const log = std.log.scoped(.App);

const std = @import("std");
const builtin = @import("builtin");