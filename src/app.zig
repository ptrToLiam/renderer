pub fn app(env: std.process.Environ) void {
  const app_name = "LmDev-" ++ AppName;
  const app_class = "LmDev-" ++ AppClass;

  const arena: *Arena = .init(.default);
  defer arena.release();

  var vk_handle = std.DynLib.open("libvulkan.so.1") catch @panic("Failed to load libvulkan.so.1");
  defer vk_handle.close();
  const vk_get_instance_proc_addr = vk_handle.lookup(
    vk.PfnGetInstanceProcAddr,
    "vkGetInstanceProcAddr",
  ) orelse @panic("Failed to locate vkGetInstanceProcAddr");

  const vk_state_init_start_us = time.us();

  //---------------------------------------------------------------------------
  // BEGIN VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vkb: vk.BaseWrapper = .load(vk_get_instance_proc_addr);
  const app_info: vk.ApplicationInfo = .{
    .p_application_name = app_name,
    .application_version = u32_(vk.makeApiVersion(0, 1, 0, 0)),
    .p_engine_name = "custom",
    .engine_version = u32_(vk.makeApiVersion(0, 1, 0, 0)),
    .api_version = u32_(vk.API_VERSION_1_4),
  };

  const instance_create_info: vk.InstanceCreateInfo = .{
    .p_application_info = &app_info,
  };
  const vk_instance, const vk_iw: vk.InstanceWrapper = vk_i_iw: {
    const instance = vkb.createInstance(
      &instance_create_info,
      null,
    ) catch @panic("Failed to create Vulkan Instance!");
    break :vk_i_iw .{
      instance,
      .load(instance, vk_get_instance_proc_addr),
    };
  };
  const vki: vk.InstanceProxy = .init(vk_instance, &vk_iw);
  defer vki.destroyInstance(null);

  //---------------------------------------------------------------------------
  // END VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vk_state_init_end_us = time.us();
  const vk_state_init_us = vk_state_init_end_us - vk_state_init_start_us;
  log.debug(
    "vulkan instance init complete in {d}us ({d}ms)!",
    .{ vk_state_init_us, vk_state_init_us / time.us_per_ms },
  );

  const initial_width = 960;
  const initial_height = 540;
  const slang_shader = arena.push(u32, slang_shader_bytes.len / 4);
  @memcpy(transmute([]u8, slang_shader), slang_shader_bytes);

  //---------------------------------------------------------------------------
  // BEGIN PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  const platform_init_start_us = time.us();
  var connection: platform.Connection = .open(arena, env);
  defer connection.close();

  var wl_conn_proxy = connection.handle.proxy();

  var surface = connection.acquire_surface(
    arena,
    .{
      .title = app_name,
      .class = app_class,
      .width = initial_width,
      .height = initial_height,
    },
  );
  defer surface.release();

  const platform_init_end_us = time.us();
  const platform_init_us = platform_init_end_us - platform_init_start_us;

  //---------------------------------------------------------------------------
  // END PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  log.debug(
    "platform state init complete in {d}us ({d:.2}ms)!",
    .{ platform_init_us, base.f64_(platform_init_us) / base.f64_(time.us_per_ms) },
  );

  const vk_pdev,
  const vk_device,
  const vk_dw: vk.DeviceWrapper,
  const qfi
  = vk_d_dw_qfi: {
    const pdev = connection.select_vk_physical_device(
      vki,
      &vk_required_device_extensions,
    );
    log.debug("selected physical device :: {x}", .{u64_(pdev)});

    const device, const qfi = connection.create_vk_logical_device(
      vki,
      pdev,
      &vk_required_device_extensions,
    );

    break :vk_d_dw_qfi .{
      pdev,
      device,
      .load(
        device,
        vki.wrapper.dispatch.vkGetDeviceProcAddr.?,
      ),
      qfi,
    };
  };
  const vkd: vk.DeviceProxy = .init(vk_device, &vk_dw);
  defer vkd.destroyDevice(null);

  const vk_queue: vk.Queue = vkd.getDeviceQueue(qfi, 0);
  var vk_pipeline: vk.Pipeline = undefined;
  var vk_cmdbuf: vk.CommandBuffer = undefined;

  // vk image creation / swapchain construction
  const img_fmt: gfx.Format = .rgba32;
  var ofb: [2]OffscreenBuffer = undefined;
  var ofb_wlbuf: [2]platform.wayland.WaylandBuffer = undefined;
  const drm_mod = connection.handle.select_drm_modifier_for_format(img_fmt);
  for (0..ofb.len) |idx| {
    ofb[idx] = .create(
      vki,
      vkd,
      vk_pdev,
      u32_(surface.width),
      u32_(surface.height),
      img_fmt,
      drm_mod,
    );
    ofb_wlbuf[idx] = connection.handle.wl_buffer(
      ofb[idx],
    );
  }
  defer {
    for (ofb) |buf| {
      vkd.destroyImageView(buf.image_view, null);
      vkd.destroyImage(buf.image, null);
      vkd.freeMemory(buf.device_memory, null);
    }
  }

  // vk pipeline creation
  createGraphicsPipeline(
    &vk_pipeline,
    vkd,
    slang_shader,
    img_fmt.toVk(),
    u32_(surface.width),
    u32_(surface.height),
  );
  defer vkd.destroyPipeline(vk_pipeline, null);
  // vk cmdpool / cmdbuf init
  const vk_cmdpool = vkd.createCommandPool(
    &.{
      .flags = .{ .reset_command_buffer_bit = true },
      .queue_family_index = qfi,
    },
    null,
  ) catch unreachable;
  defer vkd.destroyCommandPool(vk_cmdpool, null);

  vkd.allocateCommandBuffers(
    &.{
      .command_pool = vk_cmdpool,
      .level = .primary,
      .command_buffer_count = 1
    },
    transmute([*]vk.CommandBuffer, &vk_cmdbuf),
  ) catch @panic("failed to allocate cmdbuf from cmdpool");

  // var present_complete_semaphore: vk.Semaphore = vkd.createSemaphore(
  //   &.{},
  //   null,
  // ) catch @panic("Failed to create present_complete_semaphore!");
  // var render_finished_semaphore: vk.Semaphore = vkd.createSemaphore(
  //   &.{},
  //   null,
  // ) catch @panic("Failed to create render_finished_semaphore!");
  var draw_fence: vk.Fence = vkd.createFence(
    &.{
      .flags = .{ .signaled_bit = true },
    },
    null,
  ) catch @panic("Failed to create draw_fence!");
  defer vkd.destroyFence(draw_fence, null);
  // _ = &present_complete_semaphore;
  // _ = &render_finished_semaphore;
  _ = &draw_fence;

  const setup_time_full = time.us();
  log.info("Full Setup Time :: {}us ({}ms)", .{ setup_time_full, setup_time_full / time.us_per_ms });

  var events: platform.EventList = .empty;
  var want_exit = false;

  var buf_idx: u32 = 0;

  var first_attach = true;
  const time_target = time.us_per_s / 120;
  while (!want_exit) {
    defer buf_idx = (buf_idx + 1) % 2;
    const frame_time_start = time.us();
    var frame_scratch = Thread.Context.get_scratch(1, .{arena}).?;
    defer frame_scratch.end();
    const frame_arena = frame_scratch.arena;
    events = connection.get_events(frame_arena, &surface);
    var event_opt = events.first;
    while (event_opt) |ev| : (event_opt = ev.next) {
      // event handling loop
      switch (ev.type) {
        .surface_close => {
          want_exit = true;
        },
        else => {
          log.debug("app-level ev :: {any}", .{ev});
        },
      }
    }

    // Draw Logic
    {
      _ = vkd.waitForFences(
        1,
        @ptrCast(&draw_fence),
        .true,
        math.maxInt(u32),
      ) catch |err| {
        log.err("Failed to wait for fence on entry :: {s}", .{@errorName(err)});
        @panic("Failed to wait for fences");
      };
      // - command_buffer_begin
      vkd.beginCommandBuffer(
        vk_cmdbuf,
        &.{},
      ) catch @panic("Failed to begin command buffer");

      // - set clearColor
      const clear_color: vk.ClearColorValue = .{
        .float_32 = .{ 0, 0, 0, 1 },
      };
      // - attachmentInfo setup
      const attachment_info: vk.RenderingAttachmentInfo = .{
        .image_view = ofb[buf_idx].image_view,
        .image_layout = .color_attachment_optimal,
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{ .color = clear_color },
        .resolve_mode = .{},
        .resolve_image_layout = .general,
      };
      // - renderingInfo setup
      const rendering_info: vk.RenderingInfo = .{
        .render_area = .{
          .offset = .{ .x = 0, .y = 0 },
          .extent = .{ .width = u32_(surface.width), .height = u32_(surface.height) },
        },
        .layer_count = 1,
        .color_attachment_count = 1,
        .view_mask = 0,
        .p_color_attachments = transmute(
          [*]const vk.RenderingAttachmentInfo,
          &attachment_info,
        ),
      };
      // - begin rendering
      vkd.cmdBeginRendering(vk_cmdbuf, &rendering_info);
      // - render commands
      vkd.cmdBindPipeline(vk_cmdbuf, .graphics, vk_pipeline);
      vkd.cmdSetViewport(
        vk_cmdbuf,
        0,
        1,
        &.{
          .{
            .x = 0,
            .y = 0,
            .width = f32_(surface.width),
            .height = f32_(surface.height),
            .min_depth = 0,
            .max_depth = 1,
          },
        },
      );
      vkd.cmdSetScissor(
        vk_cmdbuf,
        0,
        1,
        &.{
          .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = u32_(surface.width), .height = u32_(surface.height) },
          },
        },
      );
      vkd.cmdDraw(vk_cmdbuf, 3, 1, 0, 0);
      // - end rendering
      vkd.cmdEndRendering(vk_cmdbuf);
      // - command_buffer_end
      vkd.endCommandBuffer(vk_cmdbuf) catch unreachable;

      // sync
      vkd.resetFences(
        1,
        @ptrCast(&draw_fence),
      ) catch |err| {
        log.err("Fence reset failed :: {s}", .{@errorName(err)});
        @panic("Fence reset failed");
      };
      const submit_info: vk.SubmitInfo = .{
        .wait_semaphore_count = 0,
        // .p_wait_semaphores = @ptrCast(&present_complete_semaphore),
        // .p_wait_dst_stage_mask = @ptrCast(&wait_destination_stage_mask),
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast(&vk_cmdbuf),
        .signal_semaphore_count = 0,
        // .p_signal_semaphores = @ptrCast(&render_finished_semaphore),
      };
      vkd.queueSubmit(
        vk_queue,
        1,
        @ptrCast(&submit_info),
        draw_fence,
      ) catch @panic("Failed to sumbmit to queue!");
    }

    // TODO:
    // platform-level surface image submission
    surface.handle.wl_surface.attach(&wl_conn_proxy, ofb_wlbuf[buf_idx], 0, 0);
    surface.handle.wl_surface.damage_buffer(&wl_conn_proxy, 0, 0, surface.width, surface.height);
    surface.handle.wl_surface.commit(&wl_conn_proxy);
    connection.handle.flush() catch unreachable;

    if (first_attach) {
      const ts = time.us();
      log.info("Time to first attach :: {}us ({}ms) !", .{ ts, ts / time.us_per_ms });
      first_attach = false;
    }
    const frame_time_end = time.us();
    const frame_elapsed_us = frame_time_end - frame_time_start;
    if (frame_elapsed_us < time_target) {
      Thread.sleep((time_target - frame_elapsed_us) * time.ns_per_us);
    }
  }
  _ = vkd.waitForFences(
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

fn createGraphicsPipeline(
  pipeline: *vk.Pipeline,
  vkd: vk.DeviceProxy,
  code: []const u32,
  format: vk.Format,
  width: u32,
  height: u32,
) void {
  _ = height; _ = width;
  const shader_module = createShaderModule(vkd, code);
  defer vkd.destroyShaderModule(shader_module, null);

  const pipelineRenderingCreateInfo: vk.PipelineRenderingCreateInfo = .{
    .color_attachment_count = 1,
    .p_color_attachment_formats = &.{format},
    .view_mask = 0,
    .depth_attachment_format = .undefined,
    .stencil_attachment_format = .undefined,
  };
  const pipelineCreateInfo: vk.GraphicsPipelineCreateInfo = .{
    .p_next = &pipelineRenderingCreateInfo,
    .stage_count = 2,
    .p_stages = &.{
      // vert stage
      .{
        .stage = .{ .vertex_bit = true },
        .flags = .{},
        .module = shader_module,
        .p_name = "vertMain",
      },
      // frag stage
      .{
        .stage = .{ .fragment_bit = true },
        .flags = .{},
        .module = shader_module,
        .p_name = "fragMain",
      },
    },
    .p_dynamic_state = &.{
      .dynamic_state_count = 2,
      .p_dynamic_states = &.{ .viewport, .scissor },
    },
    .p_vertex_input_state = &.{},
    .p_input_assembly_state = &.{
      .topology = .triangle_list,
      .primitive_restart_enable = .false,
    },
    .p_viewport_state = &.{
      .viewport_count = 1,
      .scissor_count = 1,
    },
    .p_rasterization_state = &.{
      // .flags: PipelineRasterizationStateCreateFlags = .{},
      .depth_clamp_enable = .false,
      .rasterizer_discard_enable = .false,
      .polygon_mode = .fill,
      .cull_mode = .{ .back_bit = true },
      .front_face = .clockwise,
      .depth_bias_enable = .false,
      .depth_bias_constant_factor = 1,
      .depth_bias_clamp = 0,
      .depth_bias_slope_factor = 0,
      .line_width = 1,
    },
    .p_multisample_state = &.{
      .rasterization_samples = .{ .@"1_bit" = true },
      .sample_shading_enable = .false,
      .min_sample_shading = 0,
      .alpha_to_coverage_enable = .false,
      .alpha_to_one_enable = .false,
    },
    .p_color_blend_state = &.{
      .logic_op_enable = .false,
      .logic_op = .copy,
      .attachment_count = 1,
      .p_attachments = &.{
        .{
          .blend_enable = .false,
          .src_color_blend_factor = .zero,
          .dst_color_blend_factor = .zero,
          .color_blend_op = .add,
          .color_write_mask = .{
            .r_bit = true,
            .g_bit = true,
            .b_bit = true,
            .a_bit = true,
          },
          .src_alpha_blend_factor = .zero,
          .dst_alpha_blend_factor = .zero,
          .alpha_blend_op = .add,
        },
      },
      .blend_constants = .{0, 0, 0, 0},
    },
    .layout = vkd.createPipelineLayout(
      &.{
        .set_layout_count = 0,
        .push_constant_range_count = 0,
      },
      null,
    ) catch @panic("failed to create pipeline layout!"),
    .subpass = undefined,
    .base_pipeline_index = -1,
  };
  defer vkd.destroyPipelineLayout(pipelineCreateInfo.layout, null);

  _ = vkd.createGraphicsPipelines(
    .null_handle,
    1,
    &.{pipelineCreateInfo},
    null,
    transmute([*]vk.Pipeline, pipeline),
  ) catch |err| {
    log.err("VkPipeline creation failed with error :: {s}", .{@errorName(err)});
    @panic("Failed to create pipeline");
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

const slang_shader_bytes = @embedFile("shaders/slang.spv");

const cast = base.casts.cast;
const transmute = base.casts.transmute;

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

const base = @import("base");
const os = @import("os");
const vk = @import("vulkan");
const platform = @import("platform");

const log = std.log.scoped(.App);

const std = @import("std");
const builtin = @import("builtin");