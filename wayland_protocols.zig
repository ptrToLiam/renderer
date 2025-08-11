// WARNING :: This file is auto-generated and should not be edited.
//            Any issues with this file should be addressed in the tool
//            that produced this file.
//
//            - LM

pub const LinuxDmabufV1 = struct {
    /// Following the interfaces from:
    /// https://www.khronos.org/registry/egl/extensions/EXT/EGL_EXT_image_dma_buf_import.txt
    /// https://www.khronos.org/registry/EGL/extensions/EXT/EGL_EXT_image_dma_buf_import_modifiers.txt
    /// and the Linux DRM sub-system's AddFb2 ioctl.
    /// This interface offers ways to create generic dmabuf-based wl_buffers.
    /// Clients can use the get_surface_feedback request to get dmabuf feedback
    /// for a particular surface. If the client wants to retrieve feedback not
    /// tied to a surface, they can use the get_default_feedback request.
    /// The following are required from clients:
    /// - Clients must ensure that either all data in the dma-buf is
    /// coherent for all subsequent read access or that coherency is
    /// correctly handled by the underlying kernel-side dma-buf
    /// implementation.
    /// - Don't make any more attachments after sending the buffer to the
    /// compositor. Making more attachments later increases the risk of
    /// the compositor not being able to use (re-import) an existing
    /// dmabuf-based wl_buffer.
    /// The underlying graphics stack must ensure the following:
    /// - The dmabuf file descriptors relayed to the server will stay valid
    /// for the whole lifetime of the wl_buffer. This means the server may
    /// at any time use those fds to import the dmabuf into any kernel
    /// sub-system that might accept it.
    /// However, when the underlying graphics stack fails to deliver the
    /// promise, because of e.g. a device hot-unplug which raises internal
    /// errors, after the wl_buffer has been successfully created the
    /// compositor must not raise protocol errors to the client when dmabuf
    /// import later fails.
    /// To create a wl_buffer from one or more dmabufs, a client creates a
    /// zwp_linux_dmabuf_params_v1 object with a zwp_linux_dmabuf_v1.create_params
    /// request. All planes required by the intended format are added with
    /// the 'add' request. Finally, a 'create' or 'create_immed' request is
    /// issued, which has the following outcome depending on the import success.
    /// The 'create' request,
    /// - on success, triggers a 'created' event which provides the final
    /// wl_buffer to the client.
    /// - on failure, triggers a 'failed' event to convey that the server
    /// cannot use the dmabufs received from the client.
    /// For the 'create_immed' request,
    /// - on success, the server immediately imports the added dmabufs to
    /// create a wl_buffer. No event is sent from the server in this case.
    /// - on failure, the server can choose to either:
    /// - terminate the client by raising a fatal error.
    /// - mark the wl_buffer as failed, and send a 'failed' event to the
    /// client. If the client uses a failed wl_buffer as an argument to any
    /// request, the behaviour is compositor implementation-defined.
    /// For all DRM formats and unless specified in another protocol extension,
    /// pre-multiplied alpha is used for pixel values.
    /// Unless specified otherwise in another protocol extension, implicit
    /// synchronization is used. In other words, compositors and clients must
    /// wait and signal fences implicitly passed via the DMA-BUF's reservation
    /// mechanism.
    ///
    pub const LinuxDmabufV1 = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn create_params(proxy: *Proxy) zwp_linux_buffer_params_v1 {
            _ = proxy;
        }

        pub fn get_default_feedback(proxy: *Proxy) zwp_linux_dmabuf_feedback_v1 {
            _ = proxy;
        }

        pub fn get_surface_feedback(
            proxy: *Proxy,
            params: struct {
                surface: wl_surface,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            format: @This().Format,
            modifier: @This().Modifier,

            /// This event advertises one buffer format that the server supports.
            /// All the supported formats are advertised once when the client
            /// binds to this interface. A roundtrip after binding guarantees
            /// that the client has received all supported formats.
            /// For the definition of the format codes, see the
            /// zwp_linux_buffer_params_v1::create request.
            /// Starting version 4, the format event is deprecated and must not be
            /// sent by compositors. Instead, use get_default_feedback or
            /// get_surface_feedback.
            ///
            pub const Format = struct {
                format: u32,
            };

            /// This event advertises the formats that the server supports, along with
            /// the modifiers supported for each format. All the supported modifiers
            /// for all the supported formats are advertised once when the client
            /// binds to this interface. A roundtrip after binding guarantees that
            /// the client has received all supported format-modifier pairs.
            /// For legacy support, DRM_FORMAT_MOD_INVALID (that is, modifier_hi ==
            /// 0x00ffffff and modifier_lo == 0xffffffff) is allowed in this event.
            /// It indicates that the server can support the format with an implicit
            /// modifier. When a plane has DRM_FORMAT_MOD_INVALID as its modifier, it
            /// is as if no explicit modifier is specified. The effective modifier
            /// will be derived from the dmabuf.
            /// A compositor that sends valid modifiers and DRM_FORMAT_MOD_INVALID for
            /// a given format supports both explicit modifiers and implicit modifiers.
            /// For the definition of the format and modifier codes, see the
            /// zwp_linux_buffer_params_v1::create and zwp_linux_buffer_params_v1::add
            /// requests.
            /// Starting version 4, the modifier event is deprecated and must not be
            /// sent by compositors. Instead, use get_default_feedback or
            /// get_surface_feedback.
            ///
            pub const Modifier = struct {
                format: u32,
                modifier_hi: u32,
                modifier_lo: u32,
            };
        };

        pub const InterfaceName = "zwp_linux_dmabuf_v1";
        pub const InterfaceVersion = 5;
    };

    /// This temporary object is a collection of dmabufs and other
    /// parameters that together form a single logical buffer. The temporary
    /// object may eventually create one wl_buffer unless cancelled by
    /// destroying it before requesting 'create'.
    /// Single-planar formats only require one dmabuf, however
    /// multi-planar formats may require more than one dmabuf. For all
    /// formats, an 'add' request must be called once per plane (even if the
    /// underlying dmabuf fd is identical).
    /// You must use consecutive plane indices ('plane_idx' argument for 'add')
    /// from zero to the number of planes used by the drm_fourcc format code.
    /// All planes required by the format must be given exactly once, but can
    /// be given in any order. Each plane index can be set only once.
    ///
    pub const LinuxBufferParamsV1 = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn add(
            proxy: *Proxy,
            params: struct {
                fd: std.posix.fd_t,
                plane_idx: u32,
                offset: u32,
                stride: u32,
                modifier_hi: u32,
                modifier_lo: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn create(
            proxy: *Proxy,
            params: struct {
                width: i32,
                height: i32,
                format: u32,
                flags: LinuxBufferParamsV1.Enum.flags,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn create_immed(
            proxy: *Proxy,
            params: struct {
                width: i32,
                height: i32,
                format: u32,
                flags: LinuxBufferParamsV1.Enum.flags,
            },
        ) wl_buffer {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            created: @This().Created,
            failed: @This().Failed,

            /// This event indicates that the attempted buffer creation was
            /// successful. It provides the new wl_buffer referencing the dmabuf(s).
            /// Upon receiving this event, the client should destroy the
            /// zwp_linux_buffer_params_v1 object.
            ///
            pub const Created = struct {
                buffer: u32,
            };

            /// This event indicates that the attempted buffer creation has
            /// failed. It usually means that one of the dmabuf constraints
            /// has not been fulfilled.
            /// Upon receiving this event, the client should destroy the
            /// zwp_linux_buffer_params_v1 object.
            ///
            pub const Failed = void;
        };

        pub const Enum = union(enum) {
            @"error": Error,
            flags: Flags,

            pub const Error = enum(u32) {
                already_used = 0,
                plane_idx = 1,
                plane_set = 2,
                incomplete = 3,
                invalid_format = 4,
                invalid_dimensions = 5,
                out_of_bounds = 6,
                invalid_wl_buffer = 7,
            };

            pub const Flags = packed struct(u32) {
                y_invert: bool = false,
                interlaced: bool = false,
                bottom_first: bool = false,
                __reserved_bits: u29 = 0,
            };
        };

        pub const InterfaceName = "zwp_linux_buffer_params_v1";
        pub const InterfaceVersion = 5;
    };

    /// This object advertises dmabuf parameters feedback. This includes the
    /// preferred devices and the supported formats/modifiers.
    /// The parameters are sent once when this object is created and whenever they
    /// change. The done event is always sent once after all parameters have been
    /// sent. When a single parameter changes, all parameters are re-sent by the
    /// compositor.
    /// Compositors can re-send the parameters when the current client buffer
    /// allocations are sub-optimal. Compositors should not re-send the
    /// parameters if re-allocating the buffers would not result in a more optimal
    /// configuration. In particular, compositors should avoid sending the exact
    /// same parameters multiple times in a row.
    /// The tranche_target_device and tranche_formats events are grouped by
    /// tranches of preference. For each tranche, a tranche_target_device, one
    /// tranche_flags and one or more tranche_formats events are sent, followed
    /// by a tranche_done event finishing the list. The tranches are sent in
    /// descending order of preference. All formats and modifiers in the same
    /// tranche have the same preference.
    /// To send parameters, the compositor sends one main_device event, tranches
    /// (each consisting of one tranche_target_device event, one tranche_flags
    /// event, tranche_formats events and then a tranche_done event), then one
    /// done event.
    ///
    pub const LinuxDmabufFeedbackV1 = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            done: @This().Done,
            format_table: @This().FormatTable,
            main_device: @This().MainDevice,
            tranche_done: @This().TrancheDone,
            tranche_target_device: @This().TrancheTargetDevice,
            tranche_formats: @This().TrancheFormats,
            tranche_flags: @This().TrancheFlags,

            /// This event is sent after all parameters of a wp_linux_dmabuf_feedback
            /// object have been sent.
            /// This allows changes to the wp_linux_dmabuf_feedback parameters to be
            /// seen as atomic, even if they happen via multiple events.
            ///
            pub const Done = void;

            /// This event provides a file descriptor which can be memory-mapped to
            /// access the format and modifier table.
            /// The table contains a tightly packed array of consecutive format +
            /// modifier pairs. Each pair is 16 bytes wide. It contains a format as a
            /// 32-bit unsigned integer, followed by 4 bytes of unused padding, and a
            /// modifier as a 64-bit unsigned integer. The native endianness is used.
            /// The client must map the file descriptor in read-only private mode.
            /// Compositors are not allowed to mutate the table file contents once this
            /// event has been sent. Instead, compositors must create a new, separate
            /// table file and re-send feedback parameters. Compositors are allowed to
            /// store duplicate format + modifier pairs in the table.
            ///
            pub const FormatTable = struct {
                fd: std.posix.fd_t,
                size: u32,
            };

            /// This event advertises the main device that the server prefers to use
            /// when direct scan-out to the target device isn't possible. The
            /// advertised main device may be different for each
            /// wp_linux_dmabuf_feedback object, and may change over time.
            /// There is exactly one main device. The compositor must send at least
            /// one preference tranche with tranche_target_device equal to main_device.
            /// Clients need to create buffers that the main device can import and
            /// read from, otherwise creating the dmabuf wl_buffer will fail (see the
            /// wp_linux_buffer_params.create and create_immed requests for details).
            /// The main device will also likely be kept active by the compositor,
            /// so clients can use it instead of waking up another device for power
            /// savings.
            /// In general the device is a DRM node. The DRM node type (primary vs.
            /// render) is unspecified. Clients must not rely on the compositor sending
            /// a particular node type. Clients cannot check two devices for equality
            /// by comparing the dev_t value.
            /// If explicit modifiers are not supported and the client performs buffer
            /// allocations on a different device than the main device, then the client
            /// must force the buffer to have a linear layout.
            ///
            pub const MainDevice = struct {
                device: []const u8,
            };

            /// This event splits tranche_target_device and tranche_formats events in
            /// preference tranches. It is sent after a set of tranche_target_device
            /// and tranche_formats events; it represents the end of a tranche. The
            /// next tranche will have a lower preference.
            ///
            pub const TrancheDone = void;

            /// This event advertises the target device that the server prefers to use
            /// for a buffer created given this tranche. The advertised target device
            /// may be different for each preference tranche, and may change over time.
            /// There is exactly one target device per tranche.
            /// The target device may be a scan-out device, for example if the
            /// compositor prefers to directly scan-out a buffer created given this
            /// tranche. The target device may be a rendering device, for example if
            /// the compositor prefers to texture from said buffer.
            /// The client can use this hint to allocate the buffer in a way that makes
            /// it accessible from the target device, ideally directly. The buffer must
            /// still be accessible from the main device, either through direct import
            /// or through a potentially more expensive fallback path. If the buffer
            /// can't be directly imported from the main device then clients must be
            /// prepared for the compositor changing the tranche priority or making
            /// wl_buffer creation fail (see the wp_linux_buffer_params.create and
            /// create_immed requests for details).
            /// If the device is a DRM node, the DRM node type (primary vs. render) is
            /// unspecified. Clients must not rely on the compositor sending a
            /// particular node type. Clients cannot check two devices for equality by
            /// comparing the dev_t value.
            /// This event is tied to a preference tranche, see the tranche_done event.
            ///
            pub const TrancheTargetDevice = struct {
                device: []const u8,
            };

            /// This event advertises the format + modifier combinations that the
            /// compositor supports.
            /// It carries an array of indices, each referring to a format + modifier
            /// pair in the last received format table (see the format_table event).
            /// Each index is a 16-bit unsigned integer in native endianness.
            /// For legacy support, DRM_FORMAT_MOD_INVALID is an allowed modifier.
            /// It indicates that the server can support the format with an implicit
            /// modifier. When a buffer has DRM_FORMAT_MOD_INVALID as its modifier, it
            /// is as if no explicit modifier is specified. The effective modifier
            /// will be derived from the dmabuf.
            /// A compositor that sends valid modifiers and DRM_FORMAT_MOD_INVALID for
            /// a given format supports both explicit modifiers and implicit modifiers.
            /// Compositors must not send duplicate format + modifier pairs within the
            /// same tranche or across two different tranches with the same target
            /// device and flags.
            /// This event is tied to a preference tranche, see the tranche_done event.
            /// For the definition of the format and modifier codes, see the
            /// wp_linux_buffer_params.create request.
            ///
            pub const TrancheFormats = struct {
                indices: []const u8,
            };

            /// This event sets tranche-specific flags.
            /// The scanout flag is a hint that direct scan-out may be attempted by the
            /// compositor on the target device if the client appropriately allocates a
            /// buffer. How to allocate a buffer that can be scanned out on the target
            /// device is implementation-defined.
            /// This event is tied to a preference tranche, see the tranche_done event.
            ///
            pub const TrancheFlags = struct {
                flags: LinuxDmabufFeedbackV1.Enum.tranche_flags,
            };
        };

        pub const Enum = union(enum) {
            tranche_flags: TrancheFlags,

            pub const TrancheFlags = packed struct(u32) {
                scanout: bool = false,
                __reserved_bits: u31 = 0,
            };
        };

        pub const InterfaceName = "zwp_linux_dmabuf_feedback_v1";
        pub const InterfaceVersion = 5;
    };
};

pub const PresentationTime = struct {
    pub const Presentation = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn feedback(
            proxy: *Proxy,
            params: struct {
                surface: wl_surface,
            },
        ) wp_presentation_feedback {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            clock_id: @This().ClockId,

            /// This event tells the client in which clock domain the
            /// compositor interprets the timestamps used by the presentation
            /// extension. This clock is called the presentation clock.
            /// The compositor sends this event when the client binds to the
            /// presentation interface. The presentation clock does not change
            /// during the lifetime of the client connection.
            /// The clock identifier is platform dependent. On POSIX platforms, the
            /// identifier value is one of the clockid_t values accepted by
            /// clock_gettime(). clock_gettime() is defined by POSIX.1-2001.
            /// Timestamps in this clock domain are expressed as tv_sec_hi,
            /// tv_sec_lo, tv_nsec triples, each component being an unsigned
            /// 32-bit value. Whole seconds are in tv_sec which is a 64-bit
            /// value combined from tv_sec_hi and tv_sec_lo, and the
            /// additional fractional part in tv_nsec as nanoseconds. Hence,
            /// for valid timestamps tv_nsec must be in [0, 999999999].
            /// Note that clock_id applies only to the presentation clock,
            /// and implies nothing about e.g. the timestamps used in the
            /// Wayland core protocol input events.
            /// Compositors should prefer a clock which does not jump and is
            /// not slewed e.g. by NTP. The absolute value of the clock is
            /// irrelevant. Precision of one millisecond or better is
            /// recommended. Clients must be able to query the current clock
            /// value directly, not by asking the compositor.
            ///
            pub const ClockId = struct {
                clk_id: u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_timestamp = 0,
                invalid_flag = 1,
            };
        };

        pub const InterfaceName = "wp_presentation";
        pub const InterfaceVersion = 2;
    };

    /// A presentation_feedback object returns an indication that a
    /// wl_surface content update has become visible to the user.
    /// One object corresponds to one content update submission
    /// (wl_surface.commit). There are two possible outcomes: the
    /// content update is presented to the user, and a presentation
    /// timestamp delivered; or, the user did not see the content
    /// update because it was superseded or its surface destroyed,
    /// and the content update is discarded.
    /// Once a presentation_feedback object has delivered a 'presented'
    /// or 'discarded' event it is automatically destroyed.
    ///
    pub const PresentationFeedback = struct {
        pub const Event = union(enum) {
            sync_output: @This().SyncOutput,
            presented: @This().Presented,
            discarded: @This().Discarded,

            /// As presentation can be synchronized to only one output at a
            /// time, this event tells which output it was. This event is only
            /// sent prior to the presented event.
            /// As clients may bind to the same global wl_output multiple
            /// times, this event is sent for each bound instance that matches
            /// the synchronized output. If a client has not bound to the
            /// right wl_output global at all, this event is not sent.
            ///
            pub const SyncOutput = struct {
                output: u32,
            };

            /// The associated content update was displayed to the user at the
            /// indicated time (tv_sec_hi/lo, tv_nsec). For the interpretation of
            /// the timestamp, see presentation.clock_id event.
            /// The timestamp corresponds to the time when the content update
            /// turned into light the first time on the surface's main output.
            /// Compositors may approximate this from the framebuffer flip
            /// completion events from the system, and the latency of the
            /// physical display path if known.
            /// This event is preceded by all related sync_output events
            /// telling which output's refresh cycle the feedback corresponds
            /// to, i.e. the main output for the surface. Compositors are
            /// recommended to choose the output containing the largest part
            /// of the wl_surface, or keeping the output they previously
            /// chose. Having a stable presentation output association helps
            /// clients predict future output refreshes (vblank).
            /// The 'refresh' argument gives the compositor's prediction of how
            /// many nanoseconds after tv_sec, tv_nsec the very next output
            /// refresh may occur. This is to further aid clients in
            /// predicting future refreshes, i.e., estimating the timestamps
            /// targeting the next few vblanks. If such prediction cannot
            /// usefully be done, the argument is zero.
            /// For version 2 and later, if the output does not have a constant
            /// refresh rate, explicit video mode switches excluded, then the
            /// refresh argument must be either an appropriate rate picked by the
            /// compositor (e.g. fastest rate), or 0 if no such rate exists.
            /// For version 1, if the output does not have a constant refresh rate,
            /// the refresh argument must be zero.
            /// The 64-bit value combined from seq_hi and seq_lo is the value
            /// of the output's vertical retrace counter when the content
            /// update was first scanned out to the display. This value must
            /// be compatible with the definition of MSC in
            /// GLX_OML_sync_control specification. Note, that if the display
            /// path has a non-zero latency, the time instant specified by
            /// this counter may differ from the timestamp's.
            /// If the output does not have a concept of vertical retrace or a
            /// refresh cycle, or the output device is self-refreshing without
            /// a way to query the refresh count, then the arguments seq_hi
            /// and seq_lo must be zero.
            ///
            pub const Presented = struct {
                tv_sec_hi: u32,
                tv_sec_lo: u32,
                tv_nsec: u32,
                refresh: u32,
                seq_hi: u32,
                seq_lo: u32,
                flags: PresentationFeedback.Enum.kind,
            };

            /// The content update was never displayed to the user.
            ///
            pub const Discarded = void;
        };

        pub const Enum = union(enum) {
            kind: Kind,

            pub const Kind = packed struct(u32) {
                vsync: bool = false,
                hw_clock: bool = false,
                hw_completion: bool = false,
                zero_copy: bool = false,
                __reserved_bits: u28 = 0,
            };
        };

        pub const InterfaceName = "wp_presentation_feedback";
        pub const InterfaceVersion = 2;
    };
};

pub const Wayland = struct {
    /// The core global object.  This is a special singleton object.  It
    /// is used for internal Wayland protocol features.
    ///
    pub const Display = struct {
        pub fn sync(proxy: *Proxy) wl_callback {
            _ = proxy;
        }

        pub fn get_registry(proxy: *Proxy) wl_registry {
            _ = proxy;
        }

        pub const Event = union(enum) {
            @"error": @This().Error,
            delete_id: @This().DeleteId,

            /// The error event is sent out when a fatal (non-recoverable)
            /// error has occurred.  The object_id argument is the object
            /// where the error occurred, most often in response to a request
            /// to that object.  The code identifies the error and is defined
            /// by the object interface.  As such, each interface defines its
            /// own set of error codes.  The message is a brief description
            /// of the error, for (debugging) convenience.
            ///
            pub const Error = struct {
                object_id: u32,
                code: u32,
                message: [:0]const u8,
            };

            /// This event is used internally by the object ID management
            /// logic. When a client deletes an object that it had created,
            /// the server will send this event to acknowledge that it has
            /// seen the delete request. When the client receives this event,
            /// it will know that it can safely reuse the object ID.
            ///
            pub const DeleteId = struct {
                id: u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_object = 0,
                invalid_method = 1,
                no_memory = 2,
                implementation = 3,
            };
        };

        pub const InterfaceName = "wl_display";
        pub const InterfaceVersion = 1;
    };

    /// The singleton global registry object.  The server has a number of
    /// global objects that are available to all clients.  These objects
    /// typically represent an actual object in the server (for example,
    /// an input device) or they are singleton objects that provide
    /// extension functionality.
    /// When a client creates a registry object, the registry object
    /// will emit a global event for each global currently in the
    /// registry.  Globals come and go as a result of device or
    /// monitor hotplugs, reconfiguration or other events, and the
    /// registry will send out global and global_remove events to
    /// keep the client up to date with the changes.  To mark the end
    /// of the initial burst of events, the client can use the
    /// wl_display.sync request immediately after calling
    /// wl_display.get_registry.
    /// A client can bind to a global object by using the bind
    /// request.  This creates a client-side handle that lets the object
    /// emit events to the client and lets the client invoke requests on
    /// the object.
    ///
    pub const Registry = struct {
        pub fn bind(
            proxy: *Proxy,
            params: struct {
                name: u32,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            global: @This().Global,
            global_remove: @This().GlobalRemove,

            /// Notify the client of global objects.
            /// The event notifies the client that a global object with
            /// the given name is now available, and it implements the
            /// given version of the given interface.
            ///
            pub const Global = struct {
                name: u32,
                interface: [:0]const u8,
                version: u32,
            };

            /// Notify the client of removed global objects.
            /// This event notifies the client that the global identified
            /// by name is no longer available.  If the client bound to
            /// the global using the bind request, the client should now
            /// destroy that object.
            /// The object remains valid and requests to the object will be
            /// ignored until the client destroys it, to avoid races between
            /// the global going away and a client sending a request to it.
            ///
            pub const GlobalRemove = struct {
                name: u32,
            };
        };

        pub const InterfaceName = "wl_registry";
        pub const InterfaceVersion = 1;
    };

    /// Clients can handle the 'done' event to get notified when
    /// the related request is done.
    /// Note, because wl_callback objects are created from multiple independent
    /// factory interfaces, the wl_callback interface is frozen at version 1.
    ///
    pub const Callback = struct {
        pub const Event = union(enum) {
            done: @This().Done,

            /// Notify the client when the related request is done.
            ///
            pub const Done = struct {
                callback_data: u32,
            };
        };

        pub const InterfaceName = "wl_callback";
        pub const InterfaceVersion = 1;
    };

    /// A compositor.  This object is a singleton global.  The
    /// compositor is in charge of combining the contents of multiple
    /// surfaces into one displayable output.
    ///
    pub const Compositor = struct {
        pub fn create_surface(proxy: *Proxy) wl_surface {
            _ = proxy;
        }

        pub fn create_region(proxy: *Proxy) wl_region {
            _ = proxy;
        }

        pub const InterfaceName = "wl_compositor";
        pub const InterfaceVersion = 6;
    };

    /// The wl_shm_pool object encapsulates a piece of memory shared
    /// between the compositor and client.  Through the wl_shm_pool
    /// object, the client can allocate shared memory wl_buffer objects.
    /// All objects created through the same pool share the same
    /// underlying mapped memory. Reusing the mapped memory avoids the
    /// setup/teardown overhead and is useful when interactively resizing
    /// a surface or for many small buffers.
    ///
    pub const ShmPool = struct {
        pub fn create_buffer(
            proxy: *Proxy,
            params: struct {
                offset: i32,
                width: i32,
                height: i32,
                stride: i32,
                format: ShmPool.Enum.@"wl_shm.format",
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn resize(
            proxy: *Proxy,
            params: struct {
                size: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const InterfaceName = "wl_shm_pool";
        pub const InterfaceVersion = 2;
    };

    /// A singleton global object that provides support for shared
    /// memory.
    /// Clients can create wl_shm_pool objects using the create_pool
    /// request.
    /// On binding the wl_shm object one or more format events
    /// are emitted to inform clients about the valid pixel formats
    /// that can be used for buffers.
    ///
    pub const Shm = struct {
        pub fn create_pool(
            proxy: *Proxy,
            params: struct {
                fd: std.posix.fd_t,
                size: i32,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            format: @This().Format,

            /// Informs the client about a valid pixel format that
            /// can be used for buffers. Known formats include
            /// argb8888 and xrgb8888.
            ///
            pub const Format = struct {
                format: Shm.Enum.format,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,
            format: Format,

            pub const Error = enum(u32) {
                invalid_format = 0,
                invalid_stride = 1,
                invalid_fd = 2,
            };

            pub const Format = enum(u32) {
                argb8888 = 0,
                xrgb8888 = 1,
                c8 = 0x20203843,
                rgb332 = 0x38424752,
                bgr233 = 0x38524742,
                xrgb4444 = 0x32315258,
                xbgr4444 = 0x32314258,
                rgbx4444 = 0x32315852,
                bgrx4444 = 0x32315842,
                argb4444 = 0x32315241,
                abgr4444 = 0x32314241,
                rgba4444 = 0x32314152,
                bgra4444 = 0x32314142,
                xrgb1555 = 0x35315258,
                xbgr1555 = 0x35314258,
                rgbx5551 = 0x35315852,
                bgrx5551 = 0x35315842,
                argb1555 = 0x35315241,
                abgr1555 = 0x35314241,
                rgba5551 = 0x35314152,
                bgra5551 = 0x35314142,
                rgb565 = 0x36314752,
                bgr565 = 0x36314742,
                rgb888 = 0x34324752,
                bgr888 = 0x34324742,
                xbgr8888 = 0x34324258,
                rgbx8888 = 0x34325852,
                bgrx8888 = 0x34325842,
                abgr8888 = 0x34324241,
                rgba8888 = 0x34324152,
                bgra8888 = 0x34324142,
                xrgb2101010 = 0x30335258,
                xbgr2101010 = 0x30334258,
                rgbx1010102 = 0x30335852,
                bgrx1010102 = 0x30335842,
                argb2101010 = 0x30335241,
                abgr2101010 = 0x30334241,
                rgba1010102 = 0x30334152,
                bgra1010102 = 0x30334142,
                yuyv = 0x56595559,
                yvyu = 0x55595659,
                uyvy = 0x59565955,
                vyuy = 0x59555956,
                ayuv = 0x56555941,
                nv12 = 0x3231564e,
                nv21 = 0x3132564e,
                nv16 = 0x3631564e,
                nv61 = 0x3136564e,
                yuv410 = 0x39565559,
                yvu410 = 0x39555659,
                yuv411 = 0x31315559,
                yvu411 = 0x31315659,
                yuv420 = 0x32315559,
                yvu420 = 0x32315659,
                yuv422 = 0x36315559,
                yvu422 = 0x36315659,
                yuv444 = 0x34325559,
                yvu444 = 0x34325659,
                r8 = 0x20203852,
                r16 = 0x20363152,
                rg88 = 0x38384752,
                gr88 = 0x38385247,
                rg1616 = 0x32334752,
                gr1616 = 0x32335247,
                xrgb16161616f = 0x48345258,
                xbgr16161616f = 0x48344258,
                argb16161616f = 0x48345241,
                abgr16161616f = 0x48344241,
                xyuv8888 = 0x56555958,
                vuy888 = 0x34325556,
                vuy101010 = 0x30335556,
                y210 = 0x30313259,
                y212 = 0x32313259,
                y216 = 0x36313259,
                y410 = 0x30313459,
                y412 = 0x32313459,
                y416 = 0x36313459,
                xvyu2101010 = 0x30335658,
                xvyu12_16161616 = 0x36335658,
                xvyu16161616 = 0x38345658,
                y0l0 = 0x304c3059,
                x0l0 = 0x304c3058,
                y0l2 = 0x324c3059,
                x0l2 = 0x324c3058,
                yuv420_8bit = 0x38305559,
                yuv420_10bit = 0x30315559,
                xrgb8888_a8 = 0x38415258,
                xbgr8888_a8 = 0x38414258,
                rgbx8888_a8 = 0x38415852,
                bgrx8888_a8 = 0x38415842,
                rgb888_a8 = 0x38413852,
                bgr888_a8 = 0x38413842,
                rgb565_a8 = 0x38413552,
                bgr565_a8 = 0x38413542,
                nv24 = 0x3432564e,
                nv42 = 0x3234564e,
                p210 = 0x30313250,
                p010 = 0x30313050,
                p012 = 0x32313050,
                p016 = 0x36313050,
                axbxgxrx106106106106 = 0x30314241,
                nv15 = 0x3531564e,
                q410 = 0x30313451,
                q401 = 0x31303451,
                xrgb16161616 = 0x38345258,
                xbgr16161616 = 0x38344258,
                argb16161616 = 0x38345241,
                abgr16161616 = 0x38344241,
                c1 = 0x20203143,
                c2 = 0x20203243,
                c4 = 0x20203443,
                d1 = 0x20203144,
                d2 = 0x20203244,
                d4 = 0x20203444,
                d8 = 0x20203844,
                r1 = 0x20203152,
                r2 = 0x20203252,
                r4 = 0x20203452,
                r10 = 0x20303152,
                r12 = 0x20323152,
                avuy8888 = 0x59555641,
                xvuy8888 = 0x59555658,
                p030 = 0x30333050,
            };
        };

        pub const InterfaceName = "wl_shm";
        pub const InterfaceVersion = 2;
    };

    /// A buffer provides the content for a wl_surface. Buffers are
    /// created through factory interfaces such as wl_shm, wp_linux_buffer_params
    /// (from the linux-dmabuf protocol extension) or similar. It has a width and
    /// a height and can be attached to a wl_surface, but the mechanism by which a
    /// client provides and updates the contents is defined by the buffer factory
    /// interface.
    /// Color channels are assumed to be electrical rather than optical (in other
    /// words, encoded with a transfer function) unless otherwise specified. If
    /// the buffer uses a format that has an alpha channel, the alpha channel is
    /// assumed to be premultiplied into the electrical color channel values
    /// (after transfer function encoding) unless otherwise specified.
    /// Note, because wl_buffer objects are created from multiple independent
    /// factory interfaces, the wl_buffer interface is frozen at version 1.
    ///
    pub const Buffer = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            release: @This().Release,

            /// Sent when this wl_buffer is no longer used by the compositor.
            /// The client is now free to reuse or destroy this buffer and its
            /// backing storage.
            /// If a client receives a release event before the frame callback
            /// requested in the same wl_surface.commit that attaches this
            /// wl_buffer to a surface, then the client is immediately free to
            /// reuse the buffer and its backing storage, and does not need a
            /// second buffer for the next surface content update. Typically
            /// this is possible, when the compositor maintains a copy of the
            /// wl_surface contents, e.g. as a GL texture. This is an important
            /// optimization for GL(ES) compositors with wl_shm clients.
            ///
            pub const Release = void;
        };

        pub const InterfaceName = "wl_buffer";
        pub const InterfaceVersion = 1;
    };

    /// A wl_data_offer represents a piece of data offered for transfer
    /// by another client (the source client).  It is used by the
    /// copy-and-paste and drag-and-drop mechanisms.  The offer
    /// describes the different mime types that the data can be
    /// converted to and provides the mechanism for transferring the
    /// data directly from the source client.
    ///
    pub const DataOffer = struct {
        pub fn accept(
            proxy: *Proxy,
            params: struct {
                serial: u32,
                mime_type: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn receive(
            proxy: *Proxy,
            params: struct {
                mime_type: [:0]const u8,
                fd: std.posix.fd_t,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn finish(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_actions(
            proxy: *Proxy,
            params: struct {
                dnd_actions: DataOffer.Enum.@"wl_data_device_manager.dnd_action",
                preferred_action: DataOffer.Enum.@"wl_data_device_manager.dnd_action",
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            offer: @This().Offer,
            source_actions: @This().SourceActions,
            action: @This().Action,

            /// Sent immediately after creating the wl_data_offer object.  One
            /// event per offered mime type.
            ///
            pub const Offer = struct {
                mime_type: [:0]const u8,
            };

            /// This event indicates the actions offered by the data source. It
            /// will be sent immediately after creating the wl_data_offer object,
            /// or anytime the source side changes its offered actions through
            /// wl_data_source.set_actions.
            ///
            pub const SourceActions = struct {
                source_actions: DataOffer.Enum.@"wl_data_device_manager.dnd_action",
            };

            /// This event indicates the action selected by the compositor after
            /// matching the source/destination side actions. Only one action (or
            /// none) will be offered here.
            /// This event can be emitted multiple times during the drag-and-drop
            /// operation in response to destination side action changes through
            /// wl_data_offer.set_actions.
            /// This event will no longer be emitted after wl_data_device.drop
            /// happened on the drag-and-drop destination, the client must
            /// honor the last action received, or the last preferred one set
            /// through wl_data_offer.set_actions when handling an "ask" action.
            /// Compositors may also change the selected action on the fly, mainly
            /// in response to keyboard modifier changes during the drag-and-drop
            /// operation.
            /// The most recent action received is always the valid one. Prior to
            /// receiving wl_data_device.drop, the chosen action may change (e.g.
            /// due to keyboard modifiers being pressed). At the time of receiving
            /// wl_data_device.drop the drag-and-drop destination must honor the
            /// last action received.
            /// Action changes may still happen after wl_data_device.drop,
            /// especially on "ask" actions, where the drag-and-drop destination
            /// may choose another action afterwards. Action changes happening
            /// at this stage are always the result of inter-client negotiation, the
            /// compositor shall no longer be able to induce a different action.
            /// Upon "ask" actions, it is expected that the drag-and-drop destination
            /// may potentially choose a different action and/or mime type,
            /// based on wl_data_offer.source_actions and finally chosen by the
            /// user (e.g. popping up a menu with the available options). The
            /// final wl_data_offer.set_actions and wl_data_offer.accept requests
            /// must happen before the call to wl_data_offer.finish.
            ///
            pub const Action = struct {
                dnd_action: DataOffer.Enum.@"wl_data_device_manager.dnd_action",
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_finish = 0,
                invalid_action_mask = 1,
                invalid_action = 2,
                invalid_offer = 3,
            };
        };

        pub const InterfaceName = "wl_data_offer";
        pub const InterfaceVersion = 3;
    };

    /// The wl_data_source object is the source side of a wl_data_offer.
    /// It is created by the source client in a data transfer and
    /// provides a way to describe the offered data and a way to respond
    /// to requests to transfer the data.
    ///
    pub const DataSource = struct {
        pub fn offer(
            proxy: *Proxy,
            params: struct {
                mime_type: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_actions(
            proxy: *Proxy,
            params: struct {
                dnd_actions: DataSource.Enum.@"wl_data_device_manager.dnd_action",
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            target: @This().Target,
            send: @This().Send,
            cancelled: @This().Cancelled,
            dnd_drop_performed: @This().DndDropPerformed,
            dnd_finished: @This().DndFinished,
            action: @This().Action,

            /// Sent when a target accepts pointer_focus or motion events.  If
            /// a target does not accept any of the offered types, type is NULL.
            /// Used for feedback during drag-and-drop.
            ///
            pub const Target = struct {
                mime_type: ?[:0]const u8,
            };

            /// Request for data from the client.  Send the data as the
            /// specified mime type over the passed file descriptor, then
            /// close it.
            ///
            pub const Send = struct {
                mime_type: [:0]const u8,
                fd: std.posix.fd_t,
            };

            /// This data source is no longer valid. There are several reasons why
            /// this could happen:
            /// - The data source has been replaced by another data source.
            /// - The drag-and-drop operation was performed, but the drop destination
            /// did not accept any of the mime types offered through
            /// wl_data_source.target.
            /// - The drag-and-drop operation was performed, but the drop destination
            /// did not select any of the actions present in the mask offered through
            /// wl_data_source.action.
            /// - The drag-and-drop operation was performed but didn't happen over a
            /// surface.
            /// - The compositor cancelled the drag-and-drop operation (e.g. compositor
            /// dependent timeouts to avoid stale drag-and-drop transfers).
            /// The client should clean up and destroy this data source.
            /// For objects of version 2 or older, wl_data_source.cancelled will
            /// only be emitted if the data source was replaced by another data
            /// source.
            ///
            pub const Cancelled = void;

            /// The user performed the drop action. This event does not indicate
            /// acceptance, wl_data_source.cancelled may still be emitted afterwards
            /// if the drop destination does not accept any mime type.
            /// However, this event might however not be received if the compositor
            /// cancelled the drag-and-drop operation before this event could happen.
            /// Note that the data_source may still be used in the future and should
            /// not be destroyed here.
            ///
            pub const DndDropPerformed = void;

            /// The drop destination finished interoperating with this data
            /// source, so the client is now free to destroy this data source and
            /// free all associated data.
            /// If the action used to perform the operation was "move", the
            /// source can now delete the transferred data.
            ///
            pub const DndFinished = void;

            /// This event indicates the action selected by the compositor after
            /// matching the source/destination side actions. Only one action (or
            /// none) will be offered here.
            /// This event can be emitted multiple times during the drag-and-drop
            /// operation, mainly in response to destination side changes through
            /// wl_data_offer.set_actions, and as the data device enters/leaves
            /// surfaces.
            /// It is only possible to receive this event after
            /// wl_data_source.dnd_drop_performed if the drag-and-drop operation
            /// ended in an "ask" action, in which case the final wl_data_source.action
            /// event will happen immediately before wl_data_source.dnd_finished.
            /// Compositors may also change the selected action on the fly, mainly
            /// in response to keyboard modifier changes during the drag-and-drop
            /// operation.
            /// The most recent action received is always the valid one. The chosen
            /// action may change alongside negotiation (e.g. an "ask" action can turn
            /// into a "move" operation), so the effects of the final action must
            /// always be applied in wl_data_offer.dnd_finished.
            /// Clients can trigger cursor surface changes from this point, so
            /// they reflect the current action.
            ///
            pub const Action = struct {
                dnd_action: DataSource.Enum.@"wl_data_device_manager.dnd_action",
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_action_mask = 0,
                invalid_source = 1,
            };
        };

        pub const InterfaceName = "wl_data_source";
        pub const InterfaceVersion = 3;
    };

    /// There is one wl_data_device per seat which can be obtained
    /// from the global wl_data_device_manager singleton.
    /// A wl_data_device provides access to inter-client data transfer
    /// mechanisms such as copy-and-paste and drag-and-drop.
    ///
    pub const DataDevice = struct {
        pub fn start_drag(
            proxy: *Proxy,
            params: struct {
                source: ?wl_data_source,
                origin: wl_surface,
                icon: ?wl_surface,
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_selection(
            proxy: *Proxy,
            params: struct {
                source: ?wl_data_source,
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            data_offer: @This().DataOffer,
            enter: @This().Enter,
            leave: @This().Leave,
            motion: @This().Motion,
            drop: @This().Drop,
            selection: @This().Selection,

            /// The data_offer event introduces a new wl_data_offer object,
            /// which will subsequently be used in either the
            /// data_device.enter event (for drag-and-drop) or the
            /// data_device.selection event (for selections).  Immediately
            /// following the data_device.data_offer event, the new data_offer
            /// object will send out data_offer.offer events to describe the
            /// mime types it offers.
            ///
            pub const DataOffer = struct {
                id: u32,
            };

            /// This event is sent when an active drag-and-drop pointer enters
            /// a surface owned by the client.  The position of the pointer at
            /// enter time is provided by the x and y arguments, in surface-local
            /// coordinates.
            ///
            pub const Enter = struct {
                serial: u32,
                surface: u32,
                x: f32,
                y: f32,
                id: ?u32,
            };

            /// This event is sent when the drag-and-drop pointer leaves the
            /// surface and the session ends.  The client must destroy the
            /// wl_data_offer introduced at enter time at this point.
            ///
            pub const Leave = void;

            /// This event is sent when the drag-and-drop pointer moves within
            /// the currently focused surface. The new position of the pointer
            /// is provided by the x and y arguments, in surface-local
            /// coordinates.
            ///
            pub const Motion = struct {
                time: u32,
                x: f32,
                y: f32,
            };

            /// The event is sent when a drag-and-drop operation is ended
            /// because the implicit grab is removed.
            /// The drag-and-drop destination is expected to honor the last action
            /// received through wl_data_offer.action, if the resulting action is
            /// "copy" or "move", the destination can still perform
            /// wl_data_offer.receive requests, and is expected to end all
            /// transfers with a wl_data_offer.finish request.
            /// If the resulting action is "ask", the action will not be considered
            /// final. The drag-and-drop destination is expected to perform one last
            /// wl_data_offer.set_actions request, or wl_data_offer.destroy in order
            /// to cancel the operation.
            ///
            pub const Drop = void;

            /// The selection event is sent out to notify the client of a new
            /// wl_data_offer for the selection for this device.  The
            /// data_device.data_offer and the data_offer.offer events are
            /// sent out immediately before this event to introduce the data
            /// offer object.  The selection event is sent to a client
            /// immediately before receiving keyboard focus and when a new
            /// selection is set while the client has keyboard focus.  The
            /// data_offer is valid until a new data_offer or NULL is received
            /// or until the client loses keyboard focus.  Switching surface with
            /// keyboard focus within the same client doesn't mean a new selection
            /// will be sent.  The client must destroy the previous selection
            /// data_offer, if any, upon receiving this event.
            ///
            pub const Selection = struct {
                id: ?u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                role = 0,
                used_source = 1,
            };
        };

        pub const InterfaceName = "wl_data_device";
        pub const InterfaceVersion = 3;
    };

    /// The wl_data_device_manager is a singleton global object that
    /// provides access to inter-client data transfer mechanisms such as
    /// copy-and-paste and drag-and-drop.  These mechanisms are tied to
    /// a wl_seat and this interface lets a client get a wl_data_device
    /// corresponding to a wl_seat.
    /// Depending on the version bound, the objects created from the bound
    /// wl_data_device_manager object will have different requirements for
    /// functioning properly. See wl_data_source.set_actions,
    /// wl_data_offer.accept and wl_data_offer.finish for details.
    ///
    pub const DataDeviceManager = struct {
        pub fn create_data_source(proxy: *Proxy) wl_data_source {
            _ = proxy;
        }

        pub fn get_data_device(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const Enum = union(enum) {
            dnd_action: DndAction,

            pub const DndAction = packed struct(u32) {
                none: bool = false,
                copy: bool = false,
                move: bool = false,
                ask: bool = false,
                __reserved_bits: u28 = 0,
            };
        };

        pub const InterfaceName = "wl_data_device_manager";
        pub const InterfaceVersion = 3;
    };

    /// This interface is implemented by servers that provide
    /// desktop-style user interfaces.
    /// It allows clients to associate a wl_shell_surface with
    /// a basic surface.
    /// Note! This protocol is deprecated and not intended for production use.
    /// For desktop-style user interfaces, use xdg_shell. Compositors and clients
    /// should not implement this interface.
    ///
    pub const Shell = struct {
        pub fn get_shell_surface(
            proxy: *Proxy,
            params: struct {
                surface: wl_surface,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                role = 0,
            };
        };

        pub const InterfaceName = "wl_shell";
        pub const InterfaceVersion = 1;
    };

    /// An interface that may be implemented by a wl_surface, for
    /// implementations that provide a desktop-style user interface.
    /// It provides requests to treat surfaces like toplevel, fullscreen
    /// or popup windows, move, resize or maximize them, associate
    /// metadata like title and class, etc.
    /// On the server side the object is automatically destroyed when
    /// the related wl_surface is destroyed. On the client side,
    /// wl_shell_surface_destroy() must be called before destroying
    /// the wl_surface object.
    ///
    pub const ShellSurface = struct {
        pub fn pong(
            proxy: *Proxy,
            params: struct {
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn move(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn resize(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
                edges: ShellSurface.Enum.resize,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_toplevel(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_transient(
            proxy: *Proxy,
            params: struct {
                parent: wl_surface,
                x: i32,
                y: i32,
                flags: ShellSurface.Enum.transient,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_fullscreen(
            proxy: *Proxy,
            params: struct {
                method: ShellSurface.Enum.fullscreen_method,
                framerate: u32,
                output: ?wl_output,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_popup(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
                parent: wl_surface,
                x: i32,
                y: i32,
                flags: ShellSurface.Enum.transient,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_maximized(
            proxy: *Proxy,
            params: struct {
                output: ?wl_output,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_title(
            proxy: *Proxy,
            params: struct {
                title: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_class(
            proxy: *Proxy,
            params: struct {
                class_: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            ping: @This().Ping,
            configure: @This().Configure,
            popup_done: @This().PopupDone,

            /// Ping a client to check if it is receiving events and sending
            /// requests. A client is expected to reply with a pong request.
            ///
            pub const Ping = struct {
                serial: u32,
            };

            /// The configure event asks the client to resize its surface.
            /// The size is a hint, in the sense that the client is free to
            /// ignore it if it doesn't resize, pick a smaller size (to
            /// satisfy aspect ratio or resize in steps of NxM pixels).
            /// The edges parameter provides a hint about how the surface
            /// was resized. The client may use this information to decide
            /// how to adjust its content to the new size (e.g. a scrolling
            /// area might adjust its content position to leave the viewable
            /// content unmoved).
            /// The client is free to dismiss all but the last configure
            /// event it received.
            /// The width and height arguments specify the size of the window
            /// in surface-local coordinates.
            ///
            pub const Configure = struct {
                edges: ShellSurface.Enum.resize,
                width: i32,
                height: i32,
            };

            /// The popup_done event is sent out when a popup grab is broken,
            /// that is, when the user clicks a surface that doesn't belong
            /// to the client owning the popup surface.
            ///
            pub const PopupDone = void;
        };

        pub const Enum = union(enum) {
            resize: Resize,
            transient: Transient,
            fullscreen_method: FullscreenMethod,

            pub const Resize = packed struct(u32) {
                none: bool = false,
                top: bool = false,
                bottom: bool = false,
                left: bool = false,
                top_left: bool = false,
                bottom_left: bool = false,
                right: bool = false,
                top_right: bool = false,
                bottom_right: bool = false,
                __reserved_bits: u23 = 0,
            };

            pub const Transient = packed struct(u32) {
                inactive: bool = false,
                __reserved_bits: u31 = 0,
            };

            pub const FullscreenMethod = enum(u32) {
                default = 0,
                scale = 1,
                driver = 2,
                fill = 3,
            };
        };

        pub const InterfaceName = "wl_shell_surface";
        pub const InterfaceVersion = 1;
    };

    /// A surface is a rectangular area that may be displayed on zero
    /// or more outputs, and shown any number of times at the compositor's
    /// discretion. They can present wl_buffers, receive user input, and
    /// define a local coordinate system.
    /// The size of a surface (and relative positions on it) is described
    /// in surface-local coordinates, which may differ from the buffer
    /// coordinates of the pixel content, in case a buffer_transform
    /// or a buffer_scale is used.
    /// A surface without a "role" is fairly useless: a compositor does
    /// not know where, when or how to present it. The role is the
    /// purpose of a wl_surface. Examples of roles are a cursor for a
    /// pointer (as set by wl_pointer.set_cursor), a drag icon
    /// (wl_data_device.start_drag), a sub-surface
    /// (wl_subcompositor.get_subsurface), and a window as defined by a
    /// shell protocol (e.g. wl_shell.get_shell_surface).
    /// A surface can have only one role at a time. Initially a
    /// wl_surface does not have a role. Once a wl_surface is given a
    /// role, it is set permanently for the whole lifetime of the
    /// wl_surface object. Giving the current role again is allowed,
    /// unless explicitly forbidden by the relevant interface
    /// specification.
    /// Surface roles are given by requests in other interfaces such as
    /// wl_pointer.set_cursor. The request should explicitly mention
    /// that this request gives a role to a wl_surface. Often, this
    /// request also creates a new protocol object that represents the
    /// role and adds additional functionality to wl_surface. When a
    /// client wants to destroy a wl_surface, they must destroy this role
    /// object before the wl_surface, otherwise a defunct_role_object error is
    /// sent.
    /// Destroying the role object does not remove the role from the
    /// wl_surface, but it may stop the wl_surface from "playing the role".
    /// For instance, if a wl_subsurface object is destroyed, the wl_surface
    /// it was created for will be unmapped and forget its position and
    /// z-order. It is allowed to create a wl_subsurface for the same
    /// wl_surface again, but it is not allowed to use the wl_surface as
    /// a cursor (cursor is a different role than sub-surface, and role
    /// switching is not allowed).
    ///
    pub const Surface = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn attach(
            proxy: *Proxy,
            params: struct {
                buffer: ?wl_buffer,
                x: i32,
                y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn damage(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn frame(proxy: *Proxy) wl_callback {
            _ = proxy;
        }

        pub fn set_opaque_region(
            proxy: *Proxy,
            params: struct {
                region: ?wl_region,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_input_region(
            proxy: *Proxy,
            params: struct {
                region: ?wl_region,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn commit(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_buffer_transform(
            proxy: *Proxy,
            params: struct {
                transform: Surface.Enum.@"wl_output.transform",
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_buffer_scale(
            proxy: *Proxy,
            params: struct {
                scale: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn damage_buffer(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn offset(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            enter: @This().Enter,
            leave: @This().Leave,
            preferred_buffer_scale: @This().PreferredBufferScale,
            preferred_buffer_transform: @This().PreferredBufferTransform,

            /// This is emitted whenever a surface's creation, movement, or resizing
            /// results in some part of it being within the scanout region of an
            /// output.
            /// Note that a surface may be overlapping with zero or more outputs.
            ///
            pub const Enter = struct {
                output: u32,
            };

            /// This is emitted whenever a surface's creation, movement, or resizing
            /// results in it no longer having any part of it within the scanout region
            /// of an output.
            /// Clients should not use the number of outputs the surface is on for frame
            /// throttling purposes. The surface might be hidden even if no leave event
            /// has been sent, and the compositor might expect new surface content
            /// updates even if no enter event has been sent. The frame event should be
            /// used instead.
            ///
            pub const Leave = struct {
                output: u32,
            };

            /// This event indicates the preferred buffer scale for this surface. It is
            /// sent whenever the compositor's preference changes.
            /// Before receiving this event the preferred buffer scale for this surface
            /// is 1.
            /// It is intended that scaling aware clients use this event to scale their
            /// content and use wl_surface.set_buffer_scale to indicate the scale they
            /// have rendered with. This allows clients to supply a higher detail
            /// buffer.
            /// The compositor shall emit a scale value greater than 0.
            ///
            pub const PreferredBufferScale = struct {
                factor: i32,
            };

            /// This event indicates the preferred buffer transform for this surface.
            /// It is sent whenever the compositor's preference changes.
            /// Before receiving this event the preferred buffer transform for this
            /// surface is normal.
            /// Applying this transformation to the surface buffer contents and using
            /// wl_surface.set_buffer_transform might allow the compositor to use the
            /// surface buffer more efficiently.
            ///
            pub const PreferredBufferTransform = struct {
                transform: Surface.Enum.@"wl_output.transform",
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_scale = 0,
                invalid_transform = 1,
                invalid_size = 2,
                invalid_offset = 3,
                defunct_role_object = 4,
            };
        };

        pub const InterfaceName = "wl_surface";
        pub const InterfaceVersion = 6;
    };

    /// A seat is a group of keyboards, pointer and touch devices. This
    /// object is published as a global during start up, or when such a
    /// device is hot plugged.  A seat typically has a pointer and
    /// maintains a keyboard focus and a pointer focus.
    ///
    pub const Seat = struct {
        pub fn get_pointer(proxy: *Proxy) wl_pointer {
            _ = proxy;
        }

        pub fn get_keyboard(proxy: *Proxy) wl_keyboard {
            _ = proxy;
        }

        pub fn get_touch(proxy: *Proxy) wl_touch {
            _ = proxy;
        }

        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            capabilities: @This().Capabilities,
            name: @This().Name,

            /// This is emitted whenever a seat gains or loses the pointer,
            /// keyboard or touch capabilities.  The argument is a capability
            /// enum containing the complete set of capabilities this seat has.
            /// When the pointer capability is added, a client may create a
            /// wl_pointer object using the wl_seat.get_pointer request. This object
            /// will receive pointer events until the capability is removed in the
            /// future.
            /// When the pointer capability is removed, a client should destroy the
            /// wl_pointer objects associated with the seat where the capability was
            /// removed, using the wl_pointer.release request. No further pointer
            /// events will be received on these objects.
            /// In some compositors, if a seat regains the pointer capability and a
            /// client has a previously obtained wl_pointer object of version 4 or
            /// less, that object may start sending pointer events again. This
            /// behavior is considered a misinterpretation of the intended behavior
            /// and must not be relied upon by the client. wl_pointer objects of
            /// version 5 or later must not send events if created before the most
            /// recent event notifying the client of an added pointer capability.
            /// The above behavior also applies to wl_keyboard and wl_touch with the
            /// keyboard and touch capabilities, respectively.
            ///
            pub const Capabilities = struct {
                capabilities: Seat.Enum.capability,
            };

            /// In a multi-seat configuration the seat name can be used by clients to
            /// help identify which physical devices the seat represents.
            /// The seat name is a UTF-8 string with no convention defined for its
            /// contents. Each name is unique among all wl_seat globals. The name is
            /// only guaranteed to be unique for the current compositor instance.
            /// The same seat names are used for all clients. Thus, the name can be
            /// shared across processes to refer to a specific wl_seat global.
            /// The name event is sent after binding to the seat global. This event is
            /// only sent once per seat object, and the name does not change over the
            /// lifetime of the wl_seat global.
            /// Compositors may re-use the same seat name if the wl_seat global is
            /// destroyed and re-created later.
            ///
            pub const Name = struct {
                name: [:0]const u8,
            };
        };

        pub const Enum = union(enum) {
            capability: Capability,
            @"error": Error,

            pub const Capability = packed struct(u32) {
                pointer: bool = false,
                keyboard: bool = false,
                touch: bool = false,
                __reserved_bits: u29 = 0,
            };

            pub const Error = enum(u32) {
                missing_capability = 0,
            };
        };

        pub const InterfaceName = "wl_seat";
        pub const InterfaceVersion = 10;
    };

    /// The wl_pointer interface represents one or more input devices,
    /// such as mice, which control the pointer location and pointer_focus
    /// of a seat.
    /// The wl_pointer interface generates motion, enter and leave
    /// events for the surfaces that the pointer is located over,
    /// and button and axis events for button presses, button releases
    /// and scrolling.
    ///
    pub const Pointer = struct {
        pub fn set_cursor(
            proxy: *Proxy,
            params: struct {
                serial: u32,
                surface: ?wl_surface,
                hotspot_x: i32,
                hotspot_y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            enter: @This().Enter,
            leave: @This().Leave,
            motion: @This().Motion,
            button: @This().Button,
            axis: @This().Axis,
            frame: @This().Frame,
            axis_source: @This().AxisSource,
            axis_stop: @This().AxisStop,
            axis_discrete: @This().AxisDiscrete,
            axis_value120: @This().AxisValue120,
            axis_relative_direction: @This().AxisRelativeDirection,

            /// Notification that this seat's pointer is focused on a certain
            /// surface.
            /// When a seat's focus enters a surface, the pointer image
            /// is undefined and a client should respond to this event by setting
            /// an appropriate pointer image with the set_cursor request.
            ///
            pub const Enter = struct {
                serial: u32,
                surface: u32,
                surface_x: f32,
                surface_y: f32,
            };

            /// Notification that this seat's pointer is no longer focused on
            /// a certain surface.
            /// The leave notification is sent before the enter notification
            /// for the new focus.
            ///
            pub const Leave = struct {
                serial: u32,
                surface: u32,
            };

            /// Notification of pointer location change. The arguments
            /// surface_x and surface_y are the location relative to the
            /// focused surface.
            ///
            pub const Motion = struct {
                time: u32,
                surface_x: f32,
                surface_y: f32,
            };

            /// Mouse button click and release notifications.
            /// The location of the click is given by the last motion or
            /// enter event.
            /// The time argument is a timestamp with millisecond
            /// granularity, with an undefined base.
            /// The button is a button code as defined in the Linux kernel's
            /// linux/input-event-codes.h header file, e.g. BTN_LEFT.
            /// Any 16-bit button code value is reserved for future additions to the
            /// kernel's event code list. All other button codes above 0xFFFF are
            /// currently undefined but may be used in future versions of this
            /// protocol.
            ///
            pub const Button = struct {
                serial: u32,
                time: u32,
                button: u32,
                state: Pointer.Enum.button_state,
            };

            /// Scroll and other axis notifications.
            /// For scroll events (vertical and horizontal scroll axes), the
            /// value parameter is the length of a vector along the specified
            /// axis in a coordinate space identical to those of motion events,
            /// representing a relative movement along the specified axis.
            /// For devices that support movements non-parallel to axes multiple
            /// axis events will be emitted.
            /// When applicable, for example for touch pads, the server can
            /// choose to emit scroll events where the motion vector is
            /// equivalent to a motion event vector.
            /// When applicable, a client can transform its content relative to the
            /// scroll distance.
            ///
            pub const Axis = struct {
                time: u32,
                axis: Pointer.Enum.axis,
                value: f32,
            };

            /// Indicates the end of a set of events that logically belong together.
            /// A client is expected to accumulate the data in all events within the
            /// frame before proceeding.
            /// All wl_pointer events before a wl_pointer.frame event belong
            /// logically together. For example, in a diagonal scroll motion the
            /// compositor will send an optional wl_pointer.axis_source event, two
            /// wl_pointer.axis events (horizontal and vertical) and finally a
            /// wl_pointer.frame event. The client may use this information to
            /// calculate a diagonal vector for scrolling.
            /// When multiple wl_pointer.axis events occur within the same frame,
            /// the motion vector is the combined motion of all events.
            /// When a wl_pointer.axis and a wl_pointer.axis_stop event occur within
            /// the same frame, this indicates that axis movement in one axis has
            /// stopped but continues in the other axis.
            /// When multiple wl_pointer.axis_stop events occur within the same
            /// frame, this indicates that these axes stopped in the same instance.
            /// A wl_pointer.frame event is sent for every logical event group,
            /// even if the group only contains a single wl_pointer event.
            /// Specifically, a client may get a sequence: motion, frame, button,
            /// frame, axis, frame, axis_stop, frame.
            /// The wl_pointer.enter and wl_pointer.leave events are logical events
            /// generated by the compositor and not the hardware. These events are
            /// also grouped by a wl_pointer.frame. When a pointer moves from one
            /// surface to another, a compositor should group the
            /// wl_pointer.leave event within the same wl_pointer.frame.
            /// However, a client must not rely on wl_pointer.leave and
            /// wl_pointer.enter being in the same wl_pointer.frame.
            /// Compositor-specific policies may require the wl_pointer.leave and
            /// wl_pointer.enter event being split across multiple wl_pointer.frame
            /// groups.
            ///
            pub const Frame = void;

            /// Source information for scroll and other axes.
            /// This event does not occur on its own. It is sent before a
            /// wl_pointer.frame event and carries the source information for
            /// all events within that frame.
            /// The source specifies how this event was generated. If the source is
            /// wl_pointer.axis_source.finger, a wl_pointer.axis_stop event will be
            /// sent when the user lifts the finger off the device.
            /// If the source is wl_pointer.axis_source.wheel,
            /// wl_pointer.axis_source.wheel_tilt or
            /// wl_pointer.axis_source.continuous, a wl_pointer.axis_stop event may
            /// or may not be sent. Whether a compositor sends an axis_stop event
            /// for these sources is hardware-specific and implementation-dependent;
            /// clients must not rely on receiving an axis_stop event for these
            /// scroll sources and should treat scroll sequences from these scroll
            /// sources as unterminated by default.
            /// This event is optional. If the source is unknown for a particular
            /// axis event sequence, no event is sent.
            /// Only one wl_pointer.axis_source event is permitted per frame.
            /// The order of wl_pointer.axis_discrete and wl_pointer.axis_source is
            /// not guaranteed.
            ///
            pub const AxisSource = struct {
                axis_source: Pointer.Enum.axis_source,
            };

            /// Stop notification for scroll and other axes.
            /// For some wl_pointer.axis_source types, a wl_pointer.axis_stop event
            /// is sent to notify a client that the axis sequence has terminated.
            /// This enables the client to implement kinetic scrolling.
            /// See the wl_pointer.axis_source documentation for information on when
            /// this event may be generated.
            /// Any wl_pointer.axis events with the same axis_source after this
            /// event should be considered as the start of a new axis motion.
            /// The timestamp is to be interpreted identical to the timestamp in the
            /// wl_pointer.axis event. The timestamp value may be the same as a
            /// preceding wl_pointer.axis event.
            ///
            pub const AxisStop = struct {
                time: u32,
                axis: Pointer.Enum.axis,
            };

            /// Discrete step information for scroll and other axes.
            /// This event carries the axis value of the wl_pointer.axis event in
            /// discrete steps (e.g. mouse wheel clicks).
            /// This event is deprecated with wl_pointer version 8 - this event is not
            /// sent to clients supporting version 8 or later.
            /// This event does not occur on its own, it is coupled with a
            /// wl_pointer.axis event that represents this axis value on a
            /// continuous scale. The protocol guarantees that each axis_discrete
            /// event is always followed by exactly one axis event with the same
            /// axis number within the same wl_pointer.frame. Note that the protocol
            /// allows for other events to occur between the axis_discrete and
            /// its coupled axis event, including other axis_discrete or axis
            /// events. A wl_pointer.frame must not contain more than one axis_discrete
            /// event per axis type.
            /// This event is optional; continuous scrolling devices
            /// like two-finger scrolling on touchpads do not have discrete
            /// steps and do not generate this event.
            /// The discrete value carries the directional information. e.g. a value
            /// of -2 is two steps towards the negative direction of this axis.
            /// The axis number is identical to the axis number in the associated
            /// axis event.
            /// The order of wl_pointer.axis_discrete and wl_pointer.axis_source is
            /// not guaranteed.
            ///
            pub const AxisDiscrete = struct {
                axis: Pointer.Enum.axis,
                discrete: i32,
            };

            /// Discrete high-resolution scroll information.
            /// This event carries high-resolution wheel scroll information,
            /// with each multiple of 120 representing one logical scroll step
            /// (a wheel detent). For example, an axis_value120 of 30 is one quarter of
            /// a logical scroll step in the positive direction, a value120 of
            /// -240 are two logical scroll steps in the negative direction within the
            /// same hardware event.
            /// Clients that rely on discrete scrolling should accumulate the
            /// value120 to multiples of 120 before processing the event.
            /// The value120 must not be zero.
            /// This event replaces the wl_pointer.axis_discrete event in clients
            /// supporting wl_pointer version 8 or later.
            /// Where a wl_pointer.axis_source event occurs in the same
            /// wl_pointer.frame, the axis source applies to this event.
            /// The order of wl_pointer.axis_value120 and wl_pointer.axis_source is
            /// not guaranteed.
            ///
            pub const AxisValue120 = struct {
                axis: Pointer.Enum.axis,
                value120: i32,
            };

            /// Relative directional information of the entity causing the axis
            /// motion.
            /// For a wl_pointer.axis event, the wl_pointer.axis_relative_direction
            /// event specifies the movement direction of the entity causing the
            /// wl_pointer.axis event. For example:
            /// - if a user's fingers on a touchpad move down and this
            /// causes a wl_pointer.axis vertical_scroll down event, the physical
            /// direction is 'identical'
            /// - if a user's fingers on a touchpad move down and this causes a
            /// wl_pointer.axis vertical_scroll up scroll up event ('natural
            /// scrolling'), the physical direction is 'inverted'.
            /// A client may use this information to adjust scroll motion of
            /// components. Specifically, enabling natural scrolling causes the
            /// content to change direction compared to traditional scrolling.
            /// Some widgets like volume control sliders should usually match the
            /// physical direction regardless of whether natural scrolling is
            /// active. This event enables clients to match the scroll direction of
            /// a widget to the physical direction.
            /// This event does not occur on its own, it is coupled with a
            /// wl_pointer.axis event that represents this axis value.
            /// The protocol guarantees that each axis_relative_direction event is
            /// always followed by exactly one axis event with the same
            /// axis number within the same wl_pointer.frame. Note that the protocol
            /// allows for other events to occur between the axis_relative_direction
            /// and its coupled axis event.
            /// The axis number is identical to the axis number in the associated
            /// axis event.
            /// The order of wl_pointer.axis_relative_direction,
            /// wl_pointer.axis_discrete and wl_pointer.axis_source is not
            /// guaranteed.
            ///
            pub const AxisRelativeDirection = struct {
                axis: Pointer.Enum.axis,
                direction: Pointer.Enum.axis_relative_direction,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,
            button_state: ButtonState,
            axis: Axis,
            axis_source: AxisSource,
            axis_relative_direction: AxisRelativeDirection,

            pub const Error = enum(u32) {
                role = 0,
            };

            pub const ButtonState = enum(u32) {
                released = 0,
                pressed = 1,
            };

            pub const Axis = enum(u32) {
                vertical_scroll = 0,
                horizontal_scroll = 1,
            };

            pub const AxisSource = enum(u32) {
                wheel = 0,
                finger = 1,
                continuous = 2,
                wheel_tilt = 3,
            };

            pub const AxisRelativeDirection = enum(u32) {
                identical = 0,
                inverted = 1,
            };
        };

        pub const InterfaceName = "wl_pointer";
        pub const InterfaceVersion = 10;
    };

    /// The wl_keyboard interface represents one or more keyboards
    /// associated with a seat.
    /// Each wl_keyboard has the following logical state:
    /// - an active surface (possibly null),
    /// - the keys currently logically down,
    /// - the active modifiers,
    /// - the active group.
    /// By default, the active surface is null, the keys currently logically down
    /// are empty, the active modifiers and the active group are 0.
    ///
    pub const Keyboard = struct {
        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            keymap: @This().Keymap,
            enter: @This().Enter,
            leave: @This().Leave,
            key: @This().Key,
            modifiers: @This().Modifiers,
            repeat_info: @This().RepeatInfo,

            /// This event provides a file descriptor to the client which can be
            /// memory-mapped in read-only mode to provide a keyboard mapping
            /// description.
            /// From version 7 onwards, the fd must be mapped with MAP_PRIVATE by
            /// the recipient, as MAP_SHARED may fail.
            ///
            pub const Keymap = struct {
                format: Keyboard.Enum.keymap_format,
                fd: std.posix.fd_t,
                size: u32,
            };

            /// Notification that this seat's keyboard focus is on a certain
            /// surface.
            /// The compositor must send the wl_keyboard.modifiers event after this
            /// event.
            /// In the wl_keyboard logical state, this event sets the active surface to
            /// the surface argument and the keys currently logically down to the keys
            /// in the keys argument. The compositor must not send this event if the
            /// wl_keyboard already had an active surface immediately before this event.
            /// Clients should not use the list of pressed keys to emulate key-press
            /// events. The order of keys in the list is unspecified.
            ///
            pub const Enter = struct {
                serial: u32,
                surface: u32,
                keys: []const u8,
            };

            /// Notification that this seat's keyboard focus is no longer on
            /// a certain surface.
            /// The leave notification is sent before the enter notification
            /// for the new focus.
            /// In the wl_keyboard logical state, this event resets all values to their
            /// defaults. The compositor must not send this event if the active surface
            /// of the wl_keyboard was not equal to the surface argument immediately
            /// before this event.
            ///
            pub const Leave = struct {
                serial: u32,
                surface: u32,
            };

            /// A key was pressed or released.
            /// The time argument is a timestamp with millisecond
            /// granularity, with an undefined base.
            /// The key is a platform-specific key code that can be interpreted
            /// by feeding it to the keyboard mapping (see the keymap event).
            /// If this event produces a change in modifiers, then the resulting
            /// wl_keyboard.modifiers event must be sent after this event.
            /// In the wl_keyboard logical state, this event adds the key to the keys
            /// currently logically down (if the state argument is pressed) or removes
            /// the key from the keys currently logically down (if the state argument is
            /// released). The compositor must not send this event if the wl_keyboard
            /// did not have an active surface immediately before this event. The
            /// compositor must not send this event if state is pressed (resp. released)
            /// and the key was already logically down (resp. was not logically down)
            /// immediately before this event.
            /// Since version 10, compositors may send key events with the "repeated"
            /// key state when a wl_keyboard.repeat_info event with a rate argument of
            /// 0 has been received. This allows the compositor to take over the
            /// responsibility of key repetition.
            ///
            pub const Key = struct {
                serial: u32,
                time: u32,
                key: u32,
                state: Keyboard.Enum.key_state,
            };

            /// Notifies clients that the modifier and/or group state has
            /// changed, and it should update its local state.
            /// The compositor may send this event without a surface of the client
            /// having keyboard focus, for example to tie modifier information to
            /// pointer focus instead. If a modifier event with pressed modifiers is sent
            /// without a prior enter event, the client can assume the modifier state is
            /// valid until it receives the next wl_keyboard.modifiers event. In order to
            /// reset the modifier state again, the compositor can send a
            /// wl_keyboard.modifiers event with no pressed modifiers.
            /// In the wl_keyboard logical state, this event updates the modifiers and
            /// group.
            ///
            pub const Modifiers = struct {
                serial: u32,
                mods_depressed: u32,
                mods_latched: u32,
                mods_locked: u32,
                group: u32,
            };

            /// Informs the client about the keyboard's repeat rate and delay.
            /// This event is sent as soon as the wl_keyboard object has been created,
            /// and is guaranteed to be received by the client before any key press
            /// event.
            /// Negative values for either rate or delay are illegal. A rate of zero
            /// will disable any repeating (regardless of the value of delay).
            /// This event can be sent later on as well with a new value if necessary,
            /// so clients should continue listening for the event past the creation
            /// of wl_keyboard.
            ///
            pub const RepeatInfo = struct {
                rate: i32,
                delay: i32,
            };
        };

        pub const Enum = union(enum) {
            keymap_format: KeymapFormat,
            key_state: KeyState,

            pub const KeymapFormat = enum(u32) {
                no_keymap = 0,
                xkb_v1 = 1,
            };

            pub const KeyState = enum(u32) {
                released = 0,
                pressed = 1,
                repeated = 2,
            };
        };

        pub const InterfaceName = "wl_keyboard";
        pub const InterfaceVersion = 10;
    };

    /// The wl_touch interface represents a touchscreen
    /// associated with a seat.
    /// Touch interactions can consist of one or more contacts.
    /// For each contact, a series of events is generated, starting
    /// with a down event, followed by zero or more motion events,
    /// and ending with an up event. Events relating to the same
    /// contact point can be identified by the ID of the sequence.
    ///
    pub const Touch = struct {
        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            down: @This().Down,
            up: @This().Up,
            motion: @This().Motion,
            frame: @This().Frame,
            cancel: @This().Cancel,
            shape: @This().Shape,
            orientation: @This().Orientation,

            /// A new touch point has appeared on the surface. This touch point is
            /// assigned a unique ID. Future events from this touch point reference
            /// this ID. The ID ceases to be valid after a touch up event and may be
            /// reused in the future.
            ///
            pub const Down = struct {
                serial: u32,
                time: u32,
                surface: u32,
                id: i32,
                x: f32,
                y: f32,
            };

            /// The touch point has disappeared. No further events will be sent for
            /// this touch point and the touch point's ID is released and may be
            /// reused in a future touch down event.
            ///
            pub const Up = struct {
                serial: u32,
                time: u32,
                id: i32,
            };

            /// A touch point has changed coordinates.
            ///
            pub const Motion = struct {
                time: u32,
                id: i32,
                x: f32,
                y: f32,
            };

            /// Indicates the end of a set of events that logically belong together.
            /// A client is expected to accumulate the data in all events within the
            /// frame before proceeding.
            /// A wl_touch.frame terminates at least one event but otherwise no
            /// guarantee is provided about the set of events within a frame. A client
            /// must assume that any state not updated in a frame is unchanged from the
            /// previously known state.
            ///
            pub const Frame = void;

            /// Sent if the compositor decides the touch stream is a global
            /// gesture. No further events are sent to the clients from that
            /// particular gesture. Touch cancellation applies to all touch points
            /// currently active on this client's surface. The client is
            /// responsible for finalizing the touch points, future touch points on
            /// this surface may reuse the touch point ID.
            /// No frame event is required after the cancel event.
            ///
            pub const Cancel = void;

            /// Sent when a touchpoint has changed its shape.
            /// This event does not occur on its own. It is sent before a
            /// wl_touch.frame event and carries the new shape information for
            /// any previously reported, or new touch points of that frame.
            /// Other events describing the touch point such as wl_touch.down,
            /// wl_touch.motion or wl_touch.orientation may be sent within the
            /// same wl_touch.frame. A client should treat these events as a single
            /// logical touch point update. The order of wl_touch.shape,
            /// wl_touch.orientation and wl_touch.motion is not guaranteed.
            /// A wl_touch.down event is guaranteed to occur before the first
            /// wl_touch.shape event for this touch ID but both events may occur within
            /// the same wl_touch.frame.
            /// A touchpoint shape is approximated by an ellipse through the major and
            /// minor axis length. The major axis length describes the longer diameter
            /// of the ellipse, while the minor axis length describes the shorter
            /// diameter. Major and minor are orthogonal and both are specified in
            /// surface-local coordinates. The center of the ellipse is always at the
            /// touchpoint location as reported by wl_touch.down or wl_touch.move.
            /// This event is only sent by the compositor if the touch device supports
            /// shape reports. The client has to make reasonable assumptions about the
            /// shape if it did not receive this event.
            ///
            pub const Shape = struct {
                id: i32,
                major: f32,
                minor: f32,
            };

            /// Sent when a touchpoint has changed its orientation.
            /// This event does not occur on its own. It is sent before a
            /// wl_touch.frame event and carries the new shape information for
            /// any previously reported, or new touch points of that frame.
            /// Other events describing the touch point such as wl_touch.down,
            /// wl_touch.motion or wl_touch.shape may be sent within the
            /// same wl_touch.frame. A client should treat these events as a single
            /// logical touch point update. The order of wl_touch.shape,
            /// wl_touch.orientation and wl_touch.motion is not guaranteed.
            /// A wl_touch.down event is guaranteed to occur before the first
            /// wl_touch.orientation event for this touch ID but both events may occur
            /// within the same wl_touch.frame.
            /// The orientation describes the clockwise angle of a touchpoint's major
            /// axis to the positive surface y-axis and is normalized to the -180 to
            /// +180 degree range. The granularity of orientation depends on the touch
            /// device, some devices only support binary rotation values between 0 and
            /// 90 degrees.
            /// This event is only sent by the compositor if the touch device supports
            /// orientation reports.
            ///
            pub const Orientation = struct {
                id: i32,
                orientation: f32,
            };
        };

        pub const InterfaceName = "wl_touch";
        pub const InterfaceVersion = 10;
    };

    /// An output describes part of the compositor geometry.  The
    /// compositor works in the 'compositor coordinate system' and an
    /// output corresponds to a rectangular area in that space that is
    /// actually visible.  This typically corresponds to a monitor that
    /// displays part of the compositor space.  This object is published
    /// as global during start up, or when a monitor is hotplugged.
    ///
    pub const Output = struct {
        pub fn release(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            geometry: @This().Geometry,
            mode: @This().Mode,
            done: @This().Done,
            scale: @This().Scale,
            name: @This().Name,
            description: @This().Description,

            /// The geometry event describes geometric properties of the output.
            /// The event is sent when binding to the output object and whenever
            /// any of the properties change.
            /// The physical size can be set to zero if it doesn't make sense for this
            /// output (e.g. for projectors or virtual outputs).
            /// The geometry event will be followed by a done event (starting from
            /// version 2).
            /// Clients should use wl_surface.preferred_buffer_transform instead of the
            /// transform advertised by this event to find the preferred buffer
            /// transform to use for a surface.
            /// Note: wl_output only advertises partial information about the output
            /// position and identification. Some compositors, for instance those not
            /// implementing a desktop-style output layout or those exposing virtual
            /// outputs, might fake this information. Instead of using x and y, clients
            /// should use xdg_output.logical_position. Instead of using make and model,
            /// clients should use name and description.
            ///
            pub const Geometry = struct {
                x: i32,
                y: i32,
                physical_width: i32,
                physical_height: i32,
                subpixel: Output.Enum.subpixel,
                make: [:0]const u8,
                model: [:0]const u8,
                transform: Output.Enum.transform,
            };

            /// The mode event describes an available mode for the output.
            /// The event is sent when binding to the output object and there
            /// will always be one mode, the current mode.  The event is sent
            /// again if an output changes mode, for the mode that is now
            /// current.  In other words, the current mode is always the last
            /// mode that was received with the current flag set.
            /// Non-current modes are deprecated. A compositor can decide to only
            /// advertise the current mode and never send other modes. Clients
            /// should not rely on non-current modes.
            /// The size of a mode is given in physical hardware units of
            /// the output device. This is not necessarily the same as
            /// the output size in the global compositor space. For instance,
            /// the output may be scaled, as described in wl_output.scale,
            /// or transformed, as described in wl_output.transform. Clients
            /// willing to retrieve the output size in the global compositor
            /// space should use xdg_output.logical_size instead.
            /// The vertical refresh rate can be set to zero if it doesn't make
            /// sense for this output (e.g. for virtual outputs).
            /// The mode event will be followed by a done event (starting from
            /// version 2).
            /// Clients should not use the refresh rate to schedule frames. Instead,
            /// they should use the wl_surface.frame event or the presentation-time
            /// protocol.
            /// Note: this information is not always meaningful for all outputs. Some
            /// compositors, such as those exposing virtual outputs, might fake the
            /// refresh rate or the size.
            ///
            pub const Mode = struct {
                flags: Output.Enum.mode,
                width: i32,
                height: i32,
                refresh: i32,
            };

            /// This event is sent after all other properties have been
            /// sent after binding to the output object and after any
            /// other property changes done after that. This allows
            /// changes to the output properties to be seen as
            /// atomic, even if they happen via multiple events.
            ///
            pub const Done = void;

            /// This event contains scaling geometry information
            /// that is not in the geometry event. It may be sent after
            /// binding the output object or if the output scale changes
            /// later. The compositor will emit a non-zero, positive
            /// value for scale. If it is not sent, the client should
            /// assume a scale of 1.
            /// A scale larger than 1 means that the compositor will
            /// automatically scale surface buffers by this amount
            /// when rendering. This is used for very high resolution
            /// displays where applications rendering at the native
            /// resolution would be too small to be legible.
            /// Clients should use wl_surface.preferred_buffer_scale
            /// instead of this event to find the preferred buffer
            /// scale to use for a surface.
            /// The scale event will be followed by a done event.
            ///
            pub const Scale = struct {
                factor: i32,
            };

            /// Many compositors will assign user-friendly names to their outputs, show
            /// them to the user, allow the user to refer to an output, etc. The client
            /// may wish to know this name as well to offer the user similar behaviors.
            /// The name is a UTF-8 string with no convention defined for its contents.
            /// Each name is unique among all wl_output globals. The name is only
            /// guaranteed to be unique for the compositor instance.
            /// The same output name is used for all clients for a given wl_output
            /// global. Thus, the name can be shared across processes to refer to a
            /// specific wl_output global.
            /// The name is not guaranteed to be persistent across sessions, thus cannot
            /// be used to reliably identify an output in e.g. configuration files.
            /// Examples of names include 'HDMI-A-1', 'WL-1', 'X11-1', etc. However, do
            /// not assume that the name is a reflection of an underlying DRM connector,
            /// X11 connection, etc.
            /// The name event is sent after binding the output object. This event is
            /// only sent once per output object, and the name does not change over the
            /// lifetime of the wl_output global.
            /// Compositors may re-use the same output name if the wl_output global is
            /// destroyed and re-created later. Compositors should avoid re-using the
            /// same name if possible.
            /// The name event will be followed by a done event.
            ///
            pub const Name = struct {
                name: [:0]const u8,
            };

            /// Many compositors can produce human-readable descriptions of their
            /// outputs. The client may wish to know this description as well, e.g. for
            /// output selection purposes.
            /// The description is a UTF-8 string with no convention defined for its
            /// contents. The description is not guaranteed to be unique among all
            /// wl_output globals. Examples might include 'Foocorp 11" Display' or
            /// 'Virtual X11 output via :1'.
            /// The description event is sent after binding the output object and
            /// whenever the description changes. The description is optional, and may
            /// not be sent at all.
            /// The description event will be followed by a done event.
            ///
            pub const Description = struct {
                description: [:0]const u8,
            };
        };

        pub const Enum = union(enum) {
            subpixel: Subpixel,
            transform: Transform,
            mode: Mode,

            pub const Subpixel = enum(u32) {
                unknown = 0,
                none = 1,
                horizontal_rgb = 2,
                horizontal_bgr = 3,
                vertical_rgb = 4,
                vertical_bgr = 5,
            };

            pub const Transform = enum(u32) {
                normal = 0,
                @"90" = 1,
                @"180" = 2,
                @"270" = 3,
                flipped = 4,
                flipped_90 = 5,
                flipped_180 = 6,
                flipped_270 = 7,
            };

            pub const Mode = packed struct(u32) {
                current: bool = false,
                preferred: bool = false,
                __reserved_bits: u30 = 0,
            };
        };

        pub const InterfaceName = "wl_output";
        pub const InterfaceVersion = 4;
    };

    /// A region object describes an area.
    /// Region objects are used to describe the opaque and input
    /// regions of a surface.
    ///
    pub const Region = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn add(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn subtract(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const InterfaceName = "wl_region";
        pub const InterfaceVersion = 1;
    };

    /// The global interface exposing sub-surface compositing capabilities.
    /// A wl_surface, that has sub-surfaces associated, is called the
    /// parent surface. Sub-surfaces can be arbitrarily nested and create
    /// a tree of sub-surfaces.
    /// The root surface in a tree of sub-surfaces is the main
    /// surface. The main surface cannot be a sub-surface, because
    /// sub-surfaces must always have a parent.
    /// A main surface with its sub-surfaces forms a (compound) window.
    /// For window management purposes, this set of wl_surface objects is
    /// to be considered as a single window, and it should also behave as
    /// such.
    /// The aim of sub-surfaces is to offload some of the compositing work
    /// within a window from clients to the compositor. A prime example is
    /// a video player with decorations and video in separate wl_surface
    /// objects. This should allow the compositor to pass YUV video buffer
    /// processing to dedicated overlay hardware when possible.
    ///
    pub const Subcompositor = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn get_subsurface(
            proxy: *Proxy,
            params: struct {
                surface: wl_surface,
                parent: wl_surface,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                bad_surface = 0,
                bad_parent = 1,
            };
        };

        pub const InterfaceName = "wl_subcompositor";
        pub const InterfaceVersion = 1;
    };

    /// An additional interface to a wl_surface object, which has been
    /// made a sub-surface. A sub-surface has one parent surface. A
    /// sub-surface's size and position are not limited to that of the parent.
    /// Particularly, a sub-surface is not automatically clipped to its
    /// parent's area.
    /// A sub-surface becomes mapped, when a non-NULL wl_buffer is applied
    /// and the parent surface is mapped. The order of which one happens
    /// first is irrelevant. A sub-surface is hidden if the parent becomes
    /// hidden, or if a NULL wl_buffer is applied. These rules apply
    /// recursively through the tree of surfaces.
    /// The behaviour of a wl_surface.commit request on a sub-surface
    /// depends on the sub-surface's mode. The possible modes are
    /// synchronized and desynchronized, see methods
    /// wl_subsurface.set_sync and wl_subsurface.set_desync. Synchronized
    /// mode caches the wl_surface state to be applied when the parent's
    /// state gets applied, and desynchronized mode applies the pending
    /// wl_surface state directly. A sub-surface is initially in the
    /// synchronized mode.
    /// Sub-surfaces also have another kind of state, which is managed by
    /// wl_subsurface requests, as opposed to wl_surface requests. This
    /// state includes the sub-surface position relative to the parent
    /// surface (wl_subsurface.set_position), and the stacking order of
    /// the parent and its sub-surfaces (wl_subsurface.place_above and
    /// .place_below). This state is applied when the parent surface's
    /// wl_surface state is applied, regardless of the sub-surface's mode.
    /// As the exception, set_sync and set_desync are effective immediately.
    /// The main surface can be thought to be always in desynchronized mode,
    /// since it does not have a parent in the sub-surfaces sense.
    /// Even if a sub-surface is in desynchronized mode, it will behave as
    /// in synchronized mode, if its parent surface behaves as in
    /// synchronized mode. This rule is applied recursively throughout the
    /// tree of surfaces. This means, that one can set a sub-surface into
    /// synchronized mode, and then assume that all its child and grand-child
    /// sub-surfaces are synchronized, too, without explicitly setting them.
    /// Destroying a sub-surface takes effect immediately. If you need to
    /// synchronize the removal of a sub-surface to the parent surface update,
    /// unmap the sub-surface first by attaching a NULL wl_buffer, update parent,
    /// and then destroy the sub-surface.
    /// If the parent wl_surface object is destroyed, the sub-surface is
    /// unmapped.
    /// A sub-surface never has the keyboard focus of any seat.
    /// The wl_surface.offset request is ignored: clients must use set_position
    /// instead to move the sub-surface.
    ///
    pub const Subsurface = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_position(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn place_above(
            proxy: *Proxy,
            params: struct {
                sibling: wl_surface,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn place_below(
            proxy: *Proxy,
            params: struct {
                sibling: wl_surface,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_sync(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_desync(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                bad_surface = 0,
            };
        };

        pub const InterfaceName = "wl_subsurface";
        pub const InterfaceVersion = 1;
    };
};

pub const XdgDecorationUnstableV1 = struct {
    /// This interface allows a compositor to announce support for server-side
    /// decorations.
    /// A window decoration is a set of window controls as deemed appropriate by
    /// the party managing them, such as user interface components used to move,
    /// resize and change a window's state.
    /// A client can use this protocol to request being decorated by a supporting
    /// compositor.
    /// If compositor and client do not negotiate the use of a server-side
    /// decoration using this protocol, clients continue to self-decorate as they
    /// see fit.
    /// Warning! The protocol described in this file is experimental and
    /// backward incompatible changes may be made. Backward compatible changes
    /// may be added together with the corresponding interface version bump.
    /// Backward incompatible changes are done by bumping the version number in
    /// the protocol and interface names and resetting the interface version.
    /// Once the protocol is to be declared stable, the 'z' prefix and the
    /// version number in the protocol and interface names are removed and the
    /// interface version number is reset.
    ///
    pub const DecorationManagerV1 = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn get_toplevel_decoration(
            proxy: *Proxy,
            params: struct {
                toplevel: xdg_toplevel,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub const InterfaceName = "zxdg_decoration_manager_v1";
        pub const InterfaceVersion = 1;
    };

    /// The decoration object allows the compositor to toggle server-side window
    /// decorations for a toplevel surface. The client can request to switch to
    /// another mode.
    /// The xdg_toplevel_decoration object must be destroyed before its
    /// xdg_toplevel.
    ///
    pub const ToplevelDecorationV1 = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_mode(
            proxy: *Proxy,
            params: struct {
                mode: ToplevelDecorationV1.Enum.mode,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn unset_mode(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            configure: @This().Configure,

            /// The configure event configures the effective decoration mode. The
            /// configured state should not be applied immediately. Clients must send an
            /// ack_configure in response to this event. See xdg_surface.configure and
            /// xdg_surface.ack_configure for details.
            /// A configure event can be sent at any time. The specified mode must be
            /// obeyed by the client.
            ///
            pub const Configure = struct {
                mode: ToplevelDecorationV1.Enum.mode,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,
            mode: Mode,

            pub const Error = enum(u32) {
                unconfigured_buffer = 0,
                already_constructed = 1,
                orphaned = 2,
                invalid_mode = 3,
            };

            pub const Mode = enum(u32) {
                client_side = 1,
                server_side = 2,
            };
        };

        pub const InterfaceName = "zxdg_toplevel_decoration_v1";
        pub const InterfaceVersion = 1;
    };
};

pub const XdgShell = struct {
    /// The xdg_wm_base interface is exposed as a global object enabling clients
    /// to turn their wl_surfaces into windows in a desktop environment. It
    /// defines the basic functionality needed for clients and the compositor to
    /// create windows that can be dragged, resized, maximized, etc, as well as
    /// creating transient windows such as popup menus.
    ///
    pub const WmBase = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn create_positioner(proxy: *Proxy) xdg_positioner {
            _ = proxy;
        }

        pub fn get_xdg_surface(
            proxy: *Proxy,
            params: struct {
                surface: wl_surface,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub fn pong(
            proxy: *Proxy,
            params: struct {
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            ping: @This().Ping,

            /// The ping event asks the client if it's still alive. Pass the
            /// serial specified in the event back to the compositor by sending
            /// a "pong" request back with the specified serial. See xdg_wm_base.pong.
            /// Compositors can use this to determine if the client is still
            /// alive. It's unspecified what will happen if the client doesn't
            /// respond to the ping request, or in what timeframe. Clients should
            /// try to respond in a reasonable amount of time. The “unresponsive”
            /// error is provided for compositors that wish to disconnect unresponsive
            /// clients.
            /// A compositor is free to ping in any way it wants, but a client must
            /// always respond to any xdg_wm_base object it created.
            ///
            pub const Ping = struct {
                serial: u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                role = 0,
                defunct_surfaces = 1,
                not_the_topmost_popup = 2,
                invalid_popup_parent = 3,
                invalid_surface_state = 4,
                invalid_positioner = 5,
                unresponsive = 6,
            };
        };

        pub const InterfaceName = "xdg_wm_base";
        pub const InterfaceVersion = 6;
    };

    /// The xdg_positioner provides a collection of rules for the placement of a
    /// child surface relative to a parent surface. Rules can be defined to ensure
    /// the child surface remains within the visible area's borders, and to
    /// specify how the child surface changes its position, such as sliding along
    /// an axis, or flipping around a rectangle. These positioner-created rules are
    /// constrained by the requirement that a child surface must intersect with or
    /// be at least partially adjacent to its parent surface.
    /// See the various requests for details about possible rules.
    /// At the time of the request, the compositor makes a copy of the rules
    /// specified by the xdg_positioner. Thus, after the request is complete the
    /// xdg_positioner object can be destroyed or reused; further changes to the
    /// object will have no effect on previous usages.
    /// For an xdg_positioner object to be considered complete, it must have a
    /// non-zero size set by set_size, and a non-zero anchor rectangle set by
    /// set_anchor_rect. Passing an incomplete xdg_positioner object when
    /// positioning a surface raises an invalid_positioner error.
    ///
    pub const Positioner = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_size(
            proxy: *Proxy,
            params: struct {
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_anchor_rect(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_anchor(
            proxy: *Proxy,
            params: struct {
                anchor: Positioner.Enum.anchor,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_gravity(
            proxy: *Proxy,
            params: struct {
                gravity: Positioner.Enum.gravity,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_constraint_adjustment(
            proxy: *Proxy,
            params: struct {
                constraint_adjustment: Positioner.Enum.constraint_adjustment,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_offset(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_reactive(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_parent_size(
            proxy: *Proxy,
            params: struct {
                parent_width: i32,
                parent_height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_parent_configure(
            proxy: *Proxy,
            params: struct {
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Enum = union(enum) {
            @"error": Error,
            anchor: Anchor,
            gravity: Gravity,
            constraint_adjustment: ConstraintAdjustment,

            pub const Error = enum(u32) {
                invalid_input = 0,
            };

            pub const Anchor = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 3,
                right = 4,
                top_left = 5,
                bottom_left = 6,
                top_right = 7,
                bottom_right = 8,
            };

            pub const Gravity = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 3,
                right = 4,
                top_left = 5,
                bottom_left = 6,
                top_right = 7,
                bottom_right = 8,
            };

            pub const ConstraintAdjustment = packed struct(u32) {
                none: bool = false,
                slide_x: bool = false,
                slide_y: bool = false,
                flip_x: bool = false,
                flip_y: bool = false,
                resize_x: bool = false,
                resize_y: bool = false,
                __reserved_bits: u25 = 0,
            };
        };

        pub const InterfaceName = "xdg_positioner";
        pub const InterfaceVersion = 6;
    };

    /// An interface that may be implemented by a wl_surface, for
    /// implementations that provide a desktop-style user interface.
    /// It provides a base set of functionality required to construct user
    /// interface elements requiring management by the compositor, such as
    /// toplevel windows, menus, etc. The types of functionality are split into
    /// xdg_surface roles.
    /// Creating an xdg_surface does not set the role for a wl_surface. In order
    /// to map an xdg_surface, the client must create a role-specific object
    /// using, e.g., get_toplevel, get_popup. The wl_surface for any given
    /// xdg_surface can have at most one role, and may not be assigned any role
    /// not based on xdg_surface.
    /// A role must be assigned before any other requests are made to the
    /// xdg_surface object.
    /// The client must call wl_surface.commit on the corresponding wl_surface
    /// for the xdg_surface state to take effect.
    /// Creating an xdg_surface from a wl_surface which has a buffer attached or
    /// committed is a client error, and any attempts by a client to attach or
    /// manipulate a buffer prior to the first xdg_surface.configure call must
    /// also be treated as errors.
    /// After creating a role-specific object and setting it up (e.g. by sending
    /// the title, app ID, size constraints, parent, etc), the client must
    /// perform an initial commit without any buffer attached. The compositor
    /// will reply with initial wl_surface state such as
    /// wl_surface.preferred_buffer_scale followed by an xdg_surface.configure
    /// event. The client must acknowledge it and is then allowed to attach a
    /// buffer to map the surface.
    /// Mapping an xdg_surface-based role surface is defined as making it
    /// possible for the surface to be shown by the compositor. Note that
    /// a mapped surface is not guaranteed to be visible once it is mapped.
    /// For an xdg_surface to be mapped by the compositor, the following
    /// conditions must be met:
    /// (1) the client has assigned an xdg_surface-based role to the surface
    /// (2) the client has set and committed the xdg_surface state and the
    /// role-dependent state to the surface
    /// (3) the client has committed a buffer to the surface
    /// A newly-unmapped surface is considered to have met condition (1) out
    /// of the 3 required conditions for mapping a surface if its role surface
    /// has not been destroyed, i.e. the client must perform the initial commit
    /// again before attaching a buffer.
    ///
    pub const Surface = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn get_toplevel(proxy: *Proxy) xdg_toplevel {
            _ = proxy;
        }

        pub fn get_popup(
            proxy: *Proxy,
            params: struct {
                parent: ?xdg_surface,
                positioner: xdg_positioner,
            },
        ) u32 {
            _ = proxy;
            _ = params;
        }

        pub fn set_window_geometry(
            proxy: *Proxy,
            params: struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn ack_configure(
            proxy: *Proxy,
            params: struct {
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            configure: @This().Configure,

            /// The configure event marks the end of a configure sequence. A configure
            /// sequence is a set of one or more events configuring the state of the
            /// xdg_surface, including the final xdg_surface.configure event.
            /// Where applicable, xdg_surface surface roles will during a configure
            /// sequence extend this event as a latched state sent as events before the
            /// xdg_surface.configure event. Such events should be considered to make up
            /// a set of atomically applied configuration states, where the
            /// xdg_surface.configure commits the accumulated state.
            /// Clients should arrange their surface for the new states, and then send
            /// an ack_configure request with the serial sent in this configure event at
            /// some point before committing the new surface.
            /// If the client receives multiple configure events before it can respond
            /// to one, it is free to discard all but the last event it received.
            ///
            pub const Configure = struct {
                serial: u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                not_constructed = 1,
                already_constructed = 2,
                unconfigured_buffer = 3,
                invalid_serial = 4,
                invalid_size = 5,
                defunct_role_object = 6,
            };
        };

        pub const InterfaceName = "xdg_surface";
        pub const InterfaceVersion = 6;
    };

    /// This interface defines an xdg_surface role which allows a surface to,
    /// among other things, set window-like properties such as maximize,
    /// fullscreen, and minimize, set application-specific metadata like title and
    /// id, and well as trigger user interactive operations such as interactive
    /// resize and move.
    /// A xdg_toplevel by default is responsible for providing the full intended
    /// visual representation of the toplevel, which depending on the window
    /// state, may mean things like a title bar, window controls and drop shadow.
    /// Unmapping an xdg_toplevel means that the surface cannot be shown
    /// by the compositor until it is explicitly mapped again.
    /// All active operations (e.g., move, resize) are canceled and all
    /// attributes (e.g. title, state, stacking, ...) are discarded for
    /// an xdg_toplevel surface when it is unmapped. The xdg_toplevel returns to
    /// the state it had right after xdg_surface.get_toplevel. The client
    /// can re-map the toplevel by performing a commit without any buffer
    /// attached, waiting for a configure event and handling it as usual (see
    /// xdg_surface description).
    /// Attaching a null buffer to a toplevel unmaps the surface.
    ///
    pub const Toplevel = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_parent(
            proxy: *Proxy,
            params: struct {
                parent: ?xdg_toplevel,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_title(
            proxy: *Proxy,
            params: struct {
                title: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_app_id(
            proxy: *Proxy,
            params: struct {
                app_id: [:0]const u8,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn show_window_menu(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
                x: i32,
                y: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn move(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn resize(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
                edges: Toplevel.Enum.resize_edge,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_max_size(
            proxy: *Proxy,
            params: struct {
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_min_size(
            proxy: *Proxy,
            params: struct {
                width: i32,
                height: i32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn set_maximized(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn unset_maximized(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_fullscreen(
            proxy: *Proxy,
            params: struct {
                output: ?wl_output,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn unset_fullscreen(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn set_minimized(proxy: *Proxy) void {
            _ = proxy;
        }

        pub const Event = union(enum) {
            configure: @This().Configure,
            close: @This().Close,
            configure_bounds: @This().ConfigureBounds,
            wm_capabilities: @This().WmCapabilities,

            /// This configure event asks the client to resize its toplevel surface or
            /// to change its state. The configured state should not be applied
            /// immediately. See xdg_surface.configure for details.
            /// The width and height arguments specify a hint to the window
            /// about how its surface should be resized in window geometry
            /// coordinates. See set_window_geometry.
            /// If the width or height arguments are zero, it means the client
            /// should decide its own window dimension. This may happen when the
            /// compositor needs to configure the state of the surface but doesn't
            /// have any information about any previous or expected dimension.
            /// The states listed in the event specify how the width/height
            /// arguments should be interpreted, and possibly how it should be
            /// drawn.
            /// Clients must send an ack_configure in response to this event. See
            /// xdg_surface.configure and xdg_surface.ack_configure for details.
            ///
            pub const Configure = struct {
                width: i32,
                height: i32,
                states: []const u8,
            };

            /// The close event is sent by the compositor when the user
            /// wants the surface to be closed. This should be equivalent to
            /// the user clicking the close button in client-side decorations,
            /// if your application has any.
            /// This is only a request that the user intends to close the
            /// window. The client may choose to ignore this request, or show
            /// a dialog to ask the user to save their data, etc.
            ///
            pub const Close = void;

            /// The configure_bounds event may be sent prior to a xdg_toplevel.configure
            /// event to communicate the bounds a window geometry size is recommended
            /// to constrain to.
            /// The passed width and height are in surface coordinate space. If width
            /// and height are 0, it means bounds is unknown and equivalent to as if no
            /// configure_bounds event was ever sent for this surface.
            /// The bounds can for example correspond to the size of a monitor excluding
            /// any panels or other shell components, so that a surface isn't created in
            /// a way that it cannot fit.
            /// The bounds may change at any point, and in such a case, a new
            /// xdg_toplevel.configure_bounds will be sent, followed by
            /// xdg_toplevel.configure and xdg_surface.configure.
            ///
            pub const ConfigureBounds = struct {
                width: i32,
                height: i32,
            };

            /// This event advertises the capabilities supported by the compositor. If
            /// a capability isn't supported, clients should hide or disable the UI
            /// elements that expose this functionality. For instance, if the
            /// compositor doesn't advertise support for minimized toplevels, a button
            /// triggering the set_minimized request should not be displayed.
            /// The compositor will ignore requests it doesn't support. For instance,
            /// a compositor which doesn't advertise support for minimized will ignore
            /// set_minimized requests.
            /// Compositors must send this event once before the first
            /// xdg_surface.configure event. When the capabilities change, compositors
            /// must send this event again and then send an xdg_surface.configure
            /// event.
            /// The configured state should not be applied immediately. See
            /// xdg_surface.configure for details.
            /// The capabilities are sent as an array of 32-bit unsigned integers in
            /// native endianness.
            ///
            pub const WmCapabilities = struct {
                capabilities: []const u8,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,
            resize_edge: ResizeEdge,
            state: State,
            wm_capabilities: WmCapabilities,

            pub const Error = enum(u32) {
                invalid_resize_edge = 0,
                invalid_parent = 1,
                invalid_size = 2,
            };

            pub const ResizeEdge = enum(u32) {
                none = 0,
                top = 1,
                bottom = 2,
                left = 4,
                top_left = 5,
                bottom_left = 6,
                right = 8,
                top_right = 9,
                bottom_right = 10,
            };

            pub const State = enum(u32) {
                maximized = 1,
                fullscreen = 2,
                resizing = 3,
                activated = 4,
                tiled_left = 5,
                tiled_right = 6,
                tiled_top = 7,
                tiled_bottom = 8,
                suspended = 9,
            };

            pub const WmCapabilities = enum(u32) {
                window_menu = 1,
                maximize = 2,
                fullscreen = 3,
                minimize = 4,
            };
        };

        pub const InterfaceName = "xdg_toplevel";
        pub const InterfaceVersion = 6;
    };

    /// A popup surface is a short-lived, temporary surface. It can be used to
    /// implement for example menus, popovers, tooltips and other similar user
    /// interface concepts.
    /// A popup can be made to take an explicit grab. See xdg_popup.grab for
    /// details.
    /// When the popup is dismissed, a popup_done event will be sent out, and at
    /// the same time the surface will be unmapped. See the xdg_popup.popup_done
    /// event for details.
    /// Explicitly destroying the xdg_popup object will also dismiss the popup and
    /// unmap the surface. Clients that want to dismiss the popup when another
    /// surface of their own is clicked should dismiss the popup using the destroy
    /// request.
    /// A newly created xdg_popup will be stacked on top of all previously created
    /// xdg_popup surfaces associated with the same xdg_toplevel.
    /// The parent of an xdg_popup must be mapped (see the xdg_surface
    /// description) before the xdg_popup itself.
    /// The client must call wl_surface.commit on the corresponding wl_surface
    /// for the xdg_popup state to take effect.
    ///
    pub const Popup = struct {
        pub fn destroy(proxy: *Proxy) void {
            _ = proxy;
        }

        pub fn grab(
            proxy: *Proxy,
            params: struct {
                seat: wl_seat,
                serial: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub fn reposition(
            proxy: *Proxy,
            params: struct {
                positioner: xdg_positioner,
                token: u32,
            },
        ) void {
            _ = proxy;
            _ = params;
        }

        pub const Event = union(enum) {
            configure: @This().Configure,
            popup_done: @This().PopupDone,
            repositioned: @This().Repositioned,

            /// This event asks the popup surface to configure itself given the
            /// configuration. The configured state should not be applied immediately.
            /// See xdg_surface.configure for details.
            /// The x and y arguments represent the position the popup was placed at
            /// given the xdg_positioner rule, relative to the upper left corner of the
            /// window geometry of the parent surface.
            /// For version 2 or older, the configure event for an xdg_popup is only
            /// ever sent once for the initial configuration. Starting with version 3,
            /// it may be sent again if the popup is setup with an xdg_positioner with
            /// set_reactive requested, or in response to xdg_popup.reposition requests.
            ///
            pub const Configure = struct {
                x: i32,
                y: i32,
                width: i32,
                height: i32,
            };

            /// The popup_done event is sent out when a popup is dismissed by the
            /// compositor. The client should destroy the xdg_popup object at this
            /// point.
            ///
            pub const PopupDone = void;

            /// The repositioned event is sent as part of a popup configuration
            /// sequence, together with xdg_popup.configure and lastly
            /// xdg_surface.configure to notify the completion of a reposition request.
            /// The repositioned event is to notify about the completion of a
            /// xdg_popup.reposition request. The token argument is the token passed
            /// in the xdg_popup.reposition request.
            /// Immediately after this event is emitted, xdg_popup.configure and
            /// xdg_surface.configure will be sent with the updated size and position,
            /// as well as a new configure serial.
            /// The client should optionally update the content of the popup, but must
            /// acknowledge the new popup configuration for the new position to take
            /// effect. See xdg_surface.ack_configure for details.
            ///
            pub const Repositioned = struct {
                token: u32,
            };
        };

        pub const Enum = union(enum) {
            @"error": Error,

            pub const Error = enum(u32) {
                invalid_grab = 0,
            };
        };

        pub const InterfaceName = "xdg_popup";
        pub const InterfaceVersion = 6;
    };
};

pub const Object = struct {
    ptr: *anyopaque,
    vtable: VTable,

    pub inline fn parse_msg(noalias object: *Object, op: u16, data: []const u8) Proxy.ParseError!void {
        try @call(.auto, object.vtable.parse_msg, .{ op, data });
    }

    pub inline fn write_msg(noalias object: *Object, op: u16, args: []MessageArg) Proxy.WriteError!void {
        try @call(.auto, object.vtable.write_msg, .{ op, args });
    }

    pub const VTable = struct {
        parse_msg: *const fn (ctx: *anyopaque, op: u16, data: []const u8) Proxy.ParseError!void,
        write_msg: *const fn (ctx: *anyopaque, op: u16, args: []MessageArg) Proxy.WriteError!void,
    };
};

const Proxy = struct {
    ctx: *anyopaque,
    vtable: VTable,

    pub inline fn msg_parse(noalias proxy: *const Proxy, args_out: []MessageArg, data: []const u8) ParseError!void {
        try @call(.auto, proxy.vtable.msg_parse_fn, .{ args_out, data });
    }
    pub inline fn msg_write(noalias proxy: *const Proxy, id: u32, op: u16, args: []MessageArg) WriteError!void {
        try @call(.auto, proxy.vtable.msg_write_fn, .{ id, op, args });
    }

    const VTable = struct {
        msg_parse_fn: *const fn (ctx: *anyopaque, args_out: []MessageArg, data: []const u8) ParseError!void,
        msg_write_fn: *const fn (ctx: *anyopaque, id: u32, op: u16, args: []MessageArg) WriteError!void,
    };

    pub const ParseError = error{
        ParseFailed,
    };
    pub const WriteError = error{
        WriteFailed,
    };
};

const MessageArg = union(enum) {
    int: i32,
    uint: u32,
    fixed: f32,
    object: u32,
    string: [:0]const u8,
    array: []const u8,
    new_id: u32,
    fd: std.posix.fd_t,
    @"enum": Enum,
};

pub const Event = union(enum) {
    zwp_linux_dmabuf_v1: zwp_linux_dmabuf_v1.Event,
    zwp_linux_buffer_params_v1: zwp_linux_buffer_params_v1.Event,
    zwp_linux_dmabuf_feedback_v1: zwp_linux_dmabuf_feedback_v1.Event,
    wp_presentation: wp_presentation.Event,
    wp_presentation_feedback: wp_presentation_feedback.Event,
    wl_display: wl_display.Event,
    wl_registry: wl_registry.Event,
    wl_callback: wl_callback.Event,
    wl_shm: wl_shm.Event,
    wl_buffer: wl_buffer.Event,
    wl_data_offer: wl_data_offer.Event,
    wl_data_source: wl_data_source.Event,
    wl_data_device: wl_data_device.Event,
    wl_shell_surface: wl_shell_surface.Event,
    wl_surface: wl_surface.Event,
    wl_seat: wl_seat.Event,
    wl_pointer: wl_pointer.Event,
    wl_keyboard: wl_keyboard.Event,
    wl_touch: wl_touch.Event,
    wl_output: wl_output.Event,
    zxdg_toplevel_decoration_v1: zxdg_toplevel_decoration_v1.Event,
    xdg_wm_base: xdg_wm_base.Event,
    xdg_surface: xdg_surface.Event,
    xdg_toplevel: xdg_toplevel.Event,
    xdg_popup: xdg_popup.Event,
};

pub const Enum = union(enum) {
    zwp_linux_buffer_params_v1: zwp_linux_buffer_params_v1.Enum,
    zwp_linux_dmabuf_feedback_v1: zwp_linux_dmabuf_feedback_v1.Enum,
    wp_presentation: wp_presentation.Enum,
    wp_presentation_feedback: wp_presentation_feedback.Enum,
    wl_display: wl_display.Enum,
    wl_shm: wl_shm.Enum,
    wl_data_offer: wl_data_offer.Enum,
    wl_data_source: wl_data_source.Enum,
    wl_data_device: wl_data_device.Enum,
    wl_data_device_manager: wl_data_device_manager.Enum,
    wl_shell: wl_shell.Enum,
    wl_shell_surface: wl_shell_surface.Enum,
    wl_surface: wl_surface.Enum,
    wl_seat: wl_seat.Enum,
    wl_pointer: wl_pointer.Enum,
    wl_keyboard: wl_keyboard.Enum,
    wl_output: wl_output.Enum,
    wl_subcompositor: wl_subcompositor.Enum,
    wl_subsurface: wl_subsurface.Enum,
    zxdg_toplevel_decoration_v1: zxdg_toplevel_decoration_v1.Enum,
    xdg_wm_base: xdg_wm_base.Enum,
    xdg_positioner: xdg_positioner.Enum,
    xdg_surface: xdg_surface.Enum,
    xdg_toplevel: xdg_toplevel.Enum,
    xdg_popup: xdg_popup.Enum,
};

const zwp_linux_dmabuf_v1 = LinuxDmabufV1.LinuxDmabufV1;
const zwp_linux_buffer_params_v1 = LinuxDmabufV1.LinuxBufferParamsV1;
const zwp_linux_dmabuf_feedback_v1 = LinuxDmabufV1.LinuxDmabufFeedbackV1;
const wp_presentation = PresentationTime.Presentation;
const wp_presentation_feedback = PresentationTime.PresentationFeedback;
const wl_display = Wayland.Display;
const wl_registry = Wayland.Registry;
const wl_callback = Wayland.Callback;
const wl_compositor = Wayland.Compositor;
const wl_shm_pool = Wayland.ShmPool;
const wl_shm = Wayland.Shm;
const wl_buffer = Wayland.Buffer;
const wl_data_offer = Wayland.DataOffer;
const wl_data_source = Wayland.DataSource;
const wl_data_device = Wayland.DataDevice;
const wl_data_device_manager = Wayland.DataDeviceManager;
const wl_shell = Wayland.Shell;
const wl_shell_surface = Wayland.ShellSurface;
const wl_surface = Wayland.Surface;
const wl_seat = Wayland.Seat;
const wl_pointer = Wayland.Pointer;
const wl_keyboard = Wayland.Keyboard;
const wl_touch = Wayland.Touch;
const wl_output = Wayland.Output;
const wl_region = Wayland.Region;
const wl_subcompositor = Wayland.Subcompositor;
const wl_subsurface = Wayland.Subsurface;
const zxdg_decoration_manager_v1 = XdgDecorationUnstableV1.DecorationManagerV1;
const zxdg_toplevel_decoration_v1 = XdgDecorationUnstableV1.ToplevelDecorationV1;
const xdg_wm_base = XdgShell.WmBase;
const xdg_positioner = XdgShell.Positioner;
const xdg_surface = XdgShell.Surface;
const xdg_toplevel = XdgShell.Toplevel;
const xdg_popup = XdgShell.Popup;

const std = @import("std");
