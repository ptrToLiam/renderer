pub fn app(env: std.process.Environ) void {
  const app_name = "LmDev-" ++ AppName;
  const app_class = "LmDev-" ++ AppClass;

  const arena: *Arena = .init(.default);
  defer arena.release();

  var stio: Io.Threaded = .init_single_threaded;
  defer stio.deinit();
  const stdio = stio.io();
  const cwd = Io.Dir.cwd();

  var shader_file_stat: Io.File.Stat = cwd.statFile(
    stdio,
    "./src/shaders/comp.spv",
    .{},
  ) catch unreachable;

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

  //---------------------------------------------------------------------------

  const initial_width = 1280;
  const initial_height = 720;
  const render_width = 1280;
  const render_height = 720;

  //---------------------------------------------------------------------------
  // BEGIN PLATFORM CONNECTION INIT
  //---------------------------------------------------------------------------

  const connection_init_start_us = time.us();
  var connection: platform.Connection = .open(arena, env);
  defer connection.close();

  var surface = connection.acquire_surface(
    arena, .{
      .title = app_name, .class = app_class,
      .width = initial_width, .height = initial_height,
      .flags = .{ .resize = true },
    });
  defer surface.release();
  connection.lock_pointer(&surface, null);

  const connection_init_end_us = time.us();
  const connection_init_us = connection_init_end_us - connection_init_start_us;

  //---------------------------------------------------------------------------


 const tsa = time.us();
 const dev = connection.select_vk_physical_device(
      vk_ctx.instance_proxy,
      &vk_required_device_extensions);
  const tsb = time.us();

  // initialize vk device
  vk_ctx.init_device(
    dev,
    &vk_required_device_extensions,
    .{ .reset_command_buffer_bit = true },
  ) catch @panic("Unable to Initialize Vulkan Device!");

  const query_pool = vk_ctx.device_proxy.createQueryPool(
    &.{
      .query_type = .timestamp,
      .query_count = 32,
    },
    null,
  ) catch @panic("Unable to Create Query Pool!");
  defer vk_ctx.device_proxy.destroyQueryPool(query_pool, null);
  _ = &query_pool;

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

  const color_subresource: vk.ImageSubresourceLayers = .{
    .aspect_mask = .{ .color_bit = true },
    .mip_level = 0,
    .base_array_layer = 0,
    .layer_count = 1,
  };

  var compute_pipeline: ComputePipeline = createComputePipeline(
    stdio,
    vk_ctx.device_proxy,
    "./src/shaders/comp.spv",
  ) catch unreachable;
  defer vk_ctx.device_proxy.destroyPipeline(compute_pipeline.update, null);
  defer vk_ctx.device_proxy.destroyPipeline(compute_pipeline.render, null);

  const scene_buffer = vk_ctx.alloc_buffer(
    @sizeOf(GpuScene) * 2,
    .{ .storage_buffer_bit = true, .transfer_dst_bit = true },
    .{ .device_local_bit = true },
  ) catch @panic("Failed To Allocate Scene Buffer!");

  var input_packet: InputPacket = .{
    .packet_hash = undefined,
    .cpu_time_lo = undefined,
    .cpu_time_hi = undefined,
    .frame_idx = undefined,
  };
  const input_buffer = vk_ctx.alloc_buffer(
    @sizeOf(InputPacket) * 2,
    .{ .uniform_buffer_bit = true },
    .{ .host_visible_bit = true, .host_coherent_bit = true },
  ) catch @panic("Failed To Allocate Input Buffer!");
  comptime {
    base.Assert(math.is_pow2(@sizeOf(InputPacket) * 2));
  }
  var gpu_input_write: u32 = 0;
  const gpu_input = transmute(
    [*]InputPacket,
    vk_ctx.device_proxy.mapMemory(
      input_buffer.memory, 0, vk.WHOLE_SIZE, .{},
    ) catch @panic("Failed To Map Input Buffer!")
      orelse @panic("Got Null Input Buffer Mapping!"),
  );
  defer vk_ctx.device_proxy.unmapMemory(input_buffer.memory);
  _ = &gpu_input;

  const descriptor_set = createDescriptorSet(
    vk_ctx.device_proxy,
    compute_pipeline.dsl,
    render_image.view,
    scene_buffer,
    input_buffer,
  ) catch unreachable;

  var draw_fence: vk.Fence = vk_ctx.device_proxy.createFence(
    &.{ .flags = .{ .signaled_bit = true } },
    null,
  ) catch @panic("Failed to create draw_fence!");
  defer vk_ctx.device_proxy.destroyFence(draw_fence, null);

  const scene_ready_event = vk_ctx.device_proxy.createEvent(&.{}, null)
    catch @panic("Failed to create scene_ready_event!");
  defer vk_ctx.device_proxy.destroyEvent(scene_ready_event, null);

  var cmds: [2]vk.CommandBuffer = undefined;
  vk_ctx.device_proxy.allocateCommandBuffers(
    &.{
      .command_pool = vk_ctx.command_pool,
      .level = .primary,
      .command_buffer_count = 2
    },
    transmute([*]vk.CommandBuffer, &cmds),
  ) catch @panic("failed to allocate cmdbuf from cmdpool");
  const compute_cmd = cmds[0];
  const blit_cmd = cmds[1];

  record_compute_cmd(&vk_ctx, compute_cmd, compute_pipeline,
                    descriptor_set, render_image, scene_buffer,
                    scene_ready_event, query_pool)
                    catch @panic("Compute CmdBuf Record Failed!");

  //---------------------------------------------------------------------------
  // Initial GPU Scene Upload
  //---------------------------------------------------------------------------

  const initial_scene: GpuScene = .{
    .camera = .{
      .position = .{ 0, 1.3, -3 },
      .yaw = 0,
      .pitch = -0.3,
    },
    .edit_count = 2,
    .hovered = 0,
    .selected = 0,
    .edits = .{
      SdfEdit{
        .position = .{ 0.5, 0.5, 0.5 },
        .tag = 0,
        .extent = .{ 0.3, 0, 0 },
        .op = 0,
      },
      SdfEdit{
        .position = .{ 0.3, 1.0, 0.3 },
        .tag = 1,
        .extent = .{ 0.3, 0.3, 0.3 },
        .op = 0,
      },
    } ++ @as([510]SdfEdit, @splat(undefined)),
    .physics = .{
      PhysicsState{
        .pos_prev = .{ 0.5, 0.5, 0.5 },
        .mass = 1,
        .velocity = .{ 0, 0.1, 0 },
        .restitution = 0.8,
      },
      PhysicsState{
        .pos_prev = .{ 0.3, 1.0, 0.3 },
        .mass = 1,
        .velocity = .{ 0, 0.1, 0 },
        .restitution = 0.1,
      },
    } ++ @as([510]PhysicsState, @splat(undefined)),
  };

  vk_ctx.upload_buffer(GpuScene, &initial_scene, scene_buffer)
    catch @panic("GPU Scene Buffer Upload Failed");

  //---------------------------------------------------------------------------


  const setup_time_full = time.us();

  log.info(
    "vulkan instance initialized in {d}us ({d}ms)!",
    .{ vk_instance_init_us, vk_instance_init_us / time.us_per_ms },
  );
  log.info(
    "platform connection initialized in {d}us ({d:.2}ms)!",
    .{ connection_init_us, base.f64_(connection_init_us) / base.f64_(time.us_per_ms) },
  );
  log.info("time to select physical device :: {d:.2}ms", .{ base.f64_((tsb-tsa)/time.us_per_ms)});
  log.info("vk context init time :: {d:.2}ms", .{ base.f64_((setup_time_full - tsb)/time.us_per_ms) });
  log.info(
    "Full Setup Time :: {}us ({}ms)",
    .{ setup_time_full, setup_time_full / time.us_per_ms },
  );

  const exit_key: platform.Key = .q;
  var shader_want_reload = false;
  var want_exit = false;

  var mouse_pos: math.Vec2f32 = .{ .x = 0, .y = 0 };

  var bg_r: f32 = undefined;
  var bg_g: f32 = undefined;
  var bg_b: f32 = undefined;

  var frame_idx: u64 = 0;
  var first_attach = true;
  var events: platform.EventList = .empty;
  const time_target = time.us_per_s / 120;
  while (!want_exit) {
    const frame_time_start = time.us();
    // this will wrap after a while, but that doesn't matter too much yet.
    input_packet.frame_idx = u32_(frame_idx & 0xffffffff);
    input_packet.cpu_time_hi = u32_(frame_time_start >> 32);
    input_packet.cpu_time_lo = u32_(frame_time_start & 0xffffffff);
    defer { input_packet.mouse_x = 0; input_packet.mouse_y = 0; }

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
        .press => {
          const key_base = ev.key.toBase();
          if (u32_(key_base) < 64) {
            var input_packet_key_cur =
              (u64_(input_packet.key_arr_hi) << 32)
                  | input_packet.key_arr_lo;

            input_packet_key_cur |= (u64_(1) << cast(u6, u32_(key_base)));
            input_packet.key_arr_hi = u32_(input_packet_key_cur >> 32);
            input_packet.key_arr_lo = u32_(input_packet_key_cur & 0xffffffff);
          }
          if (ev.key == exit_key) want_exit = true;
          if (ev.key == .esc) connection.toggle_pointer_lock(&surface, null);
        },
        .release => {
          const key_base = ev.key.toBase();
          if (u32_(key_base) < 64) {
            var input_packet_key_cur =
              (u64_(input_packet.key_arr_hi) << 32)
                  | input_packet.key_arr_lo;

            input_packet_key_cur &= ~(u64_(1) << cast(u6, u32_(key_base)));
            input_packet.key_arr_hi = u32_(input_packet_key_cur >> 32);
            input_packet.key_arr_lo = u32_(input_packet_key_cur & 0xffffffff);
          }
        },
        .mouse_move => {
          defer mouse_pos = ev.pos;
          const input_mouse_x = if (!(ev.delta.x == 0))
            ev.delta.x
          else 0;
          const input_mouse_y = if (!(ev.delta.y == 0))
            ev.delta.y
          else 0;

          input_packet.mouse_x += input_mouse_x;
          input_packet.mouse_y += input_mouse_y;
        },
        .mouse_scroll => {
          // TODO: app-level input handling
        },
        else => {
          log.debug("app-level ev :: {any}", .{ev});
        },
      }
    }

    // Shader Reload
    {
      if (shader_want_reload) {
        shader_want_reload = false;
        vk_ctx.device_proxy.deviceWaitIdle() catch unreachable;
        vk_ctx.device_proxy.destroyPipeline(compute_pipeline.update, null);
        vk_ctx.device_proxy.destroyPipeline(compute_pipeline.render, null);
        compute_pipeline = createComputePipeline(
          stdio,
          vk_ctx.device_proxy,
          "./src/shaders/comp.spv",
        ) catch unreachable;

        log.info("Reloaded Compute Shader!", .{});

        record_compute_cmd(&vk_ctx, compute_cmd, compute_pipeline,
                    descriptor_set, render_image, scene_buffer,
                    scene_ready_event, query_pool)
                    catch @panic("Compute CmdBuf Record Failed!");

        log.info("Compute Command Buffer Re-Recorded!", .{});
      } else {
        const shader_stat_new = cwd.statFile(
          stdio,
          "./src/shaders/comp.spv",
          .{},
        ) catch unreachable;
        if (shader_stat_new.mtime.nanoseconds != shader_file_stat.mtime.nanoseconds) {
          shader_want_reload = true;
          shader_file_stat = shader_stat_new;
        }
      }
    }

    input_packet.write_hash();

    // 2-packet ringbuffer, mask idx
    const masked_gpu_write = gpu_input_write & (input_buffer.size - 1);
    @memcpy(
      transmute(
        [*]u8,
        gpu_input,
      )[masked_gpu_write..][0..@sizeOf(InputPacket)],
      transmute([*]const u8, &input_packet)[0..@sizeOf(InputPacket)],
    );
    gpu_input_write +%= @sizeOf(InputPacket);

    // Draw Logic
    {
      _ = vk_ctx.device_proxy.waitForFences(
        1, @ptrCast(&draw_fence), .true,
        math.maxInt(u32)) catch |err|
      {
        log.err("Failed to wait for fence on entry :: {s}", .{@errorName(err)});
        @panic("Failed to wait for fences");
      };
      vk_ctx.device_proxy.resetEvent(scene_ready_event)
        catch @panic("Failed to reset scene_ready_event!");

      var vk_timestamps: [8]u64 = undefined;
      if (vk_ctx.device_proxy.getQueryPoolResults(
        query_pool, 0, 8, 8 * @sizeOf(u64),
        &vk_timestamps, @sizeOf(u64),
        .{ .@"64_bit" = true }) catch unreachable == .success)
      {
        const gpu_update_ticks = vk_timestamps[ComputeUpdateDispatchTimestampEndIdx]
                               - vk_timestamps[ComputeUpdateDispatchTimestampBeginIdx];
        const gpu_render_ticks = vk_timestamps[ComputeRenderDispatchTimestampEndIdx]
                               - vk_timestamps[ComputeRenderDispatchTimestampBeginIdx];
        const gpu_blit_ticks   = vk_timestamps[BlitCmdTimestampEndIdx]
                               - vk_timestamps[BlitCmdTimestampBeginIdx];
        const gpu_total_ticks  = vk_timestamps[ComputeDispatchTimestampEndIdx]
                               - vk_timestamps[ComputeDispatchTimestampBeginIdx];

        const gpu_update_ns = f64_(gpu_update_ticks) * vk_ctx.device_ts_period;
        const gpu_render_ns = f64_(gpu_render_ticks) * vk_ctx.device_ts_period;
        const gpu_blit_ns   = f64_(gpu_blit_ticks)   * vk_ctx.device_ts_period;
        const gpu_total_ns  = f64_(gpu_total_ticks)  * vk_ctx.device_ts_period;
        if (true) {
          log.info(
            "F={:6}|U={:6.2}us|R={:6.2}us|B={:6.2}us|TOTAL={:6.2}us|",
            .{ frame_idx-%1, gpu_update_ns / time.ns_per_us,
            gpu_render_ns / time.ns_per_us, gpu_blit_ns / time.ns_per_us,
            gpu_total_ns / time.ns_per_us },
          );
        } else {
          _ = &gpu_update_ns;
          _ = &gpu_render_ns;
          _ = &gpu_blit_ns;
          _ = &gpu_total_ns;
        }
      }

      // reconstruct swapchain if needed
      if (swapchain.pending_resize) |new_dims| {
        @branchHint(.cold);
        swapchain.recreate(new_dims.x, new_dims.y, img_fmt)
          catch @panic("Swapchain recreation failed!");
      }

      // frame rendering done, acquire swapchain image
      const sc_image_opt = swapchain.acquire_image();
      if (sc_image_opt) |swapchain_image| {
        // Blit render image -> swapchain image
        record_blit_cmd(
          &vk_ctx,
          blit_cmd,
          render_image,
          swapchain_image.*,
          color_subresource,
          query_pool,
        ) catch @panic("Blit command recording failed!");

        // sync
        vk_ctx.device_proxy.resetFences(
          1,
          @ptrCast(&draw_fence),
        ) catch |err| {
          log.err("Fence reset failed :: {s}", .{@errorName(err)});
          @panic("Fence reset failed");
        };

        vk_ctx.device_proxy.resetQueryPool(
          query_pool,
          0,
          2,
        );
        vk_ctx.device_proxy.queueSubmit(
          vk_ctx.queue,
          1,
          &.{
            .{
              .command_buffer_count = 2,
              .p_command_buffers = &cmds,
            },
          },
          draw_fence,
        ) catch @panic("Failed to sumbmit to queue!");

        swapchain.present();
      }
    }

    connection.flush() catch unreachable;

    const frame_time_end = time.us();
    if (first_attach) {
      @branchHint(.cold);
      log.info(
        "Time to first frame attach :: {}us ({}ms) !",
        .{ frame_time_end, frame_time_end / time.us_per_ms },
      );
      first_attach = false;
    }
    const frame_elapsed_us = frame_time_end - frame_time_start;
    // log.info("FRAME#{}|CpuMainLoopTime   :: {}us",
    //         .{ frame_idx, frame_elapsed_us });
    if (frame_elapsed_us < time_target) {
      Thread.sleep((time_target - frame_elapsed_us) * time.ns_per_us);
    }
  }

  _ = vk_ctx.device_proxy.waitForFences(
    1, @ptrCast(&draw_fence), .true,
    math.maxInt(u32)) catch |err|
  {
    log.err("Failed to wait for fence on entry :: {s}", .{@errorName(err)});
    @panic("Failed to wait for fences");
  };
}

inline fn record_compute_cmd(
  vk_ctx: *const VkContext,
  cmd: vk.CommandBuffer,
  pipeline: ComputePipeline,
  descriptor_set: DescriptorSet,
  render_image: VkContext.Image,
  scene_buffer: VkContext.Buffer,
  scene_ready_event: vk.Event,
  query_pool: vk.QueryPool,
) !void {
  try vk_ctx.device_proxy.beginCommandBuffer(cmd, &.{});
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeDispatchTimestampBeginIdx,
  );
   // --- UPDATE PASS ---
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeUpdateDispatchTimestampBeginIdx,
  );
  vk_ctx.device_proxy.cmdBindPipeline(cmd, .compute, pipeline.update);
  vk_ctx.device_proxy.cmdBindDescriptorSets(
    cmd, .compute, pipeline.layout, 0, 1,
    @ptrCast(&descriptor_set.set), 0, null,
  );
  vk_ctx.device_proxy.cmdDispatch(cmd, 128, 1, 1);

  // signal event when update writes are done
  vk_ctx.device_proxy.cmdSetEvent(
    cmd, scene_ready_event,
    .{ .compute_shader_bit = true },
  );
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeUpdateDispatchTimestampEndIdx,
  );
  // --- RENDER PASS ---
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeRenderDispatchTimestampBeginIdx,
  );
  vk_ctx.device_proxy.cmdBindPipeline(cmd, .compute, pipeline.render);
  vk_ctx.device_proxy.cmdBindDescriptorSets(
    cmd, .compute, pipeline.layout, 0, 1,
    @ptrCast(&descriptor_set.set), 0, null,
  );

  // wait for scene to be ready before reading
  vk_ctx.device_proxy.cmdWaitEvents(
    cmd,
    1, @ptrCast(&scene_ready_event),
    .{ .compute_shader_bit = true },
    .{ .compute_shader_bit = true },
    0, null,
    1, &.{.{
      .src_access_mask = .{ .shader_write_bit = true },
      .dst_access_mask = .{ .shader_read_bit = true },
      .buffer = scene_buffer.buffer,
      .offset = 0,
      .size = vk.WHOLE_SIZE,
      .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
      .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
    }},
    0, null,
  );

  // barrier render image for blit
  if (false) {
    vk_ctx.device_proxy.cmdPipelineBarrier(
      cmd, .{ .compute_shader_bit = true },
      .{ .transfer_bit = true },
      .{}, 0, null, 0, null, 1,
      &.{.{
        .src_access_mask = .{ .shader_write_bit = true },
        .dst_access_mask = .{ .transfer_read_bit = true },
        .old_layout = .general,
        .new_layout = .general,
        .image = render_image.image,
        .subresource_range = .{
          .aspect_mask = .{ .color_bit = true },
          .base_mip_level = 0, .level_count = 1,
          .base_array_layer = 0, .layer_count = 1,
        },
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
      }},
    );
  }

  vk_ctx.device_proxy.cmdDispatch(
    cmd,
    (render_image.width + 15) / 16,
    (render_image.height + 15) / 16,
    1,
  );
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeRenderDispatchTimestampEndIdx,
  );
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    ComputeDispatchTimestampEndIdx,
  );
  try vk_ctx.device_proxy.endCommandBuffer(cmd);
}

inline fn record_blit_cmd(
  noalias vk_ctx: *const VkContext,
  cmd: vk.CommandBuffer,
  src: VkContext.Image,
  dst: VkContext.Image,
  subresource: vk.ImageSubresourceLayers,
  query_pool: vk.QueryPool,
) !void {
  try vk_ctx.device_proxy.beginCommandBuffer(
    cmd,
    &.{},
  );
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    BlitCmdTimestampBeginIdx,
  );
  vk_ctx.device_proxy.cmdBlitImage(
      cmd,
      src.image,
      .general,
      dst.image,
      .general,
      1,
      &.{
        .{
          .src_offsets = .{
            .{ .x = 0, .y = 0, .z = 0 },
            .{ .x = i32_(src.width), .y = i32_(src.height), .z = 1 },
          },
          .dst_offsets = .{
            .{ .x = 0, .y = 0, .z = 0 },
            .{ .x = i32_(dst.width), .y = i32_(dst.height), .z = 1 },
          },
          .src_subresource = subresource,
          .dst_subresource = subresource,
        },
      },
      .nearest,
  );

  vk_ctx.device_proxy.cmdPipelineBarrier(
    cmd,
    .{ .transfer_bit = true },
    .{ .bottom_of_pipe_bit = true },
    .{}, 0, null, 0, null, 1,
    &.{
      .{
        .src_access_mask = .{ .transfer_write_bit = true },
        .dst_access_mask = .{},
        .old_layout = .general,
        .new_layout = .general,
        .image = dst.image,
        .subresource_range = .{
            .aspect_mask = .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
      }
    },
  );
  vk_ctx.device_proxy.cmdWriteTimestamp(
    cmd,
    .{ .compute_shader_bit = true },
    query_pool,
    BlitCmdTimestampEndIdx,
  );
  try vk_ctx.device_proxy.endCommandBuffer(cmd);
}

inline fn createDescriptorSet(
  device: vk.DeviceProxy,
  dsl: vk.DescriptorSetLayout,
  render_image_view: vk.ImageView,
  scene_buffer: VkContext.Buffer,
  input_buffer: VkContext.Buffer,
) !DescriptorSet {
  const pool = try device.createDescriptorPool(
    &.{ .max_sets = 1, .pool_size_count = 3,
      .p_pool_sizes = &.{
        .{ .type = .storage_image,  .descriptor_count = 1 },
        .{ .type = .storage_buffer, .descriptor_count = 1 },
        .{ .type = .uniform_buffer, .descriptor_count = 1 },
    }}, null,
  );
  errdefer device.destroyDescriptorPool(pool, null);

  var set: vk.DescriptorSet = undefined;
  try device.allocateDescriptorSets(&.{
    .descriptor_pool = pool,
    .descriptor_set_count = 1,
    .p_set_layouts = &.{dsl},
  }, @ptrCast(&set));

  // Write the storage image binding
  device.updateDescriptorSets(
    3, &.{
      .{
        .dst_set = set,
        .dst_binding = 0,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .storage_image,
        .p_buffer_info = &.{},
        .p_texel_buffer_view = &.{},
        .p_image_info = &.{
          .{
            .sampler = .null_handle,
            .image_view = render_image_view,
            .image_layout = .general,
          },
        },
      },
      .{
        .dst_set = set,
        .dst_binding = 1,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .storage_buffer,
        .p_texel_buffer_view = &.{},
        .p_image_info = &.{},
        .p_buffer_info = &.{
          .{
            .offset = 0,
            .buffer = scene_buffer.buffer,
            .range = scene_buffer.size,
          },
        },
      },
      .{
        .dst_set = set,
        .dst_binding = 2,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .uniform_buffer,
        .p_texel_buffer_view = &.{},
        .p_image_info = &.{},
        .p_buffer_info = &.{
          .{
            .offset = 0,
            .buffer = input_buffer.buffer,
            .range = input_buffer.size,
          },
        },
      },
  }, 0, null);
  return .{ .pool = pool, .set = set };
}

inline fn createComputePipeline(
  io: Io,
  device: vk.DeviceProxy,
  shader_filename: []const u8,
) !ComputePipeline {
  const cwd = Io.Dir.cwd();
  const scratch = Thread.Context.get_scratch(0, .{}).?;
  defer scratch.end();
  const shader_code = transmute(
    []const u32,
    cwd.readFileAlloc(
      io, shader_filename,
      scratch.arena.allocator(),
      .unlimited,
    ) catch unreachable);

  const dsl = try device.createDescriptorSetLayout(
    &.{ .binding_count = 3, .p_bindings = &.{
      .{
        .binding = 0, .descriptor_type = .storage_image,
        .descriptor_count = 1, .stage_flags = .{ .compute_bit = true },
      },
      .{
        .binding = 2, .descriptor_type = .uniform_buffer,
        .descriptor_count = 1, .stage_flags = .{ .compute_bit = true },
      },
      .{
        .binding = 1, .descriptor_type = .storage_buffer,
        .descriptor_count = 1, .stage_flags = .{ .compute_bit = true },
      },
    }}, null);
  errdefer device.destroyDescriptorSetLayout(dsl, null);

  const layout = try device.createPipelineLayout(
    &.{
      .set_layout_count = 1, .p_set_layouts = &.{dsl},
      .push_constant_range_count = 0, .p_push_constant_ranges = null,
    }, null);
  errdefer device.destroyPipelineLayout(layout, null);

  const shader_module = try device.createShaderModule(&.{
    .code_size = shader_code.len * @sizeOf(u32),
    .p_code = shader_code.ptr,
  }, null);
  defer device.destroyShaderModule(shader_module, null);

  var pipelines = [_]vk.Pipeline{
    undefined,
    undefined,
  };
  _ = try device.createComputePipelines(
    .null_handle, 2, &.{
      .{
       .stage = .{
          .stage = .{ .compute_bit = true },
          .module = shader_module, .p_name = "compUpdate",
        },
        .layout = layout, .base_pipeline_index = -1,
      },
      .{
        .stage = .{
          .stage = .{ .compute_bit = true },
          .module = shader_module, .p_name = "compRender",
        },
        .layout = layout, .base_pipeline_index = -1,
      },
    }, null, &pipelines);

  return .{
    .update = pipelines[0],
    .render = pipelines[1],
    .layout = layout,
    .dsl = dsl,
  };
}

inline fn createShaderModule(
  dev: vk.DeviceProxy,
  code: []const u32,
) vk.ShaderModule {
  const shader_module = dev.createShaderModule(
    &.{
      .flags = .{},
      .code_size = code.len * @sizeOf(u32),
      .p_code = code.ptr,
    }, null) catch unreachable;
  return shader_module;
}

const DescriptorSet = struct {
  pool: vk.DescriptorPool,
  set: vk.DescriptorSet,
};

const ComputePipeline = struct {
  update: vk.Pipeline,
  render: vk.Pipeline,
  layout: vk.PipelineLayout,
  dsl: vk.DescriptorSetLayout,
};

const ComputeDispatchTimestampBeginIdx = 0;
const ComputeUpdateDispatchTimestampBeginIdx = 1;
const ComputeUpdateDispatchTimestampEndIdx = 2;
const ComputeRenderDispatchTimestampBeginIdx = 3;
const ComputeRenderDispatchTimestampEndIdx = 4;
const ComputeDispatchTimestampEndIdx = 5;
const BlitCmdTimestampBeginIdx = 6;
const BlitCmdTimestampEndIdx = 7;

//-----------------------------------------------------------------------------
// Shader-Side Structs
//-----------------------------------------------------------------------------

const InputPacket = extern struct {
  packet_hash: u32,
  mouse_x: f32 = 0,
  mouse_y: f32 = 0,
  cpu_time_lo: u32,
  cpu_time_hi: u32,
  key_arr_lo: u32 = 0,
  key_arr_hi: u32 = 0,
  resolution_xy: u32 = 0,
  frame_idx: u32,
  __reserved_0: u32 = 0,
  __reserved_1: u32 = 0,
  __reserved_2: u32 = 0,
  __reserved_3: u32 = 0,
  __reserved_4: u32 = 0,
  __reserved_5: u32 = 0,
  __reserved_6: u32 = 0,

  pub fn write_hash(ip: *InputPacket) void {
    ip.packet_hash = 0x55555555;
    inline for (@typeInfo(InputPacket).@"struct".fields, 0..) |field, idx| {
      if (idx > 0) {
        const val = @field(ip, field.name);
        ip.packet_hash ^= transmute(u32, val);
      }
    }
  }
};


// Note: Tag/Op can be combined into 2 u16s later, if in need of
//       adding more data into the fields.
// -LM
const SdfEdit = extern struct {
  position: [3]f32,
  tag: u32,
  extent: [3]f32,
  op: u32,
};

const PhysicsState = extern struct {
  pos_prev: [3]f32 align(16),
  mass: f32,
  velocity: [3]f32 align(16),
  restitution: f32,
};

const GpuScene = extern struct {
  camera: Camera,
  edit_count: u32,
  hovered: u32,
  selected: u32,
  prev_time: u64 = 0,
  edits: [512]SdfEdit align(16),
  physics: [512]PhysicsState align(16),
};

// const GpuSceneOld = extern struct {
//   camera: Camera,
//   sphere: Sphere,
//   box: Box,
// };

const Sphere = extern struct {
  color: [4]f32,
  center: [3]f32 align(16),
  radius: f32,
};

const Box = extern struct {
  color: [4]f32,
  center: [3]f32 align(16),
  size: [3]f32 align(16),
};

const Camera = extern struct {
  position: [3]f32 align(16),
  yaw:      f32,
  pitch:    f32,
};

//-----------------------------------------------------------------------------

const vk_required_device_extensions = [_][*:0]const u8{
  vk.extensions.khr_external_memory.name,
  vk.extensions.khr_external_memory_fd.name,
  vk.extensions.ext_external_memory_dma_buf.name,
  vk.extensions.ext_image_drm_format_modifier.name,
};

const OffscreenBuffer = platform.OffscreenBuffer;

const AppName = "vkRender";
const AppClass = "Liam.Games.vkRender";

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
const Io = std.Io;

const std = @import("std");
const builtin = @import("builtin");