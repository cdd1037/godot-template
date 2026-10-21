# Godot 4.7.2 desktop .NET release templates. Platform/arch come from build.sh.
target = 'template_release'
module_mono_enabled = True
production = True
optimize = 'speed'
lto = 'full'
debug_symbols = False
threads = True
opengl3 = True
vulkan = False
d3d12 = False
metal = False
angle = False
# Keep public core API required by official C# bindings.
disable_3d = False
disable_xr = False
disable_navigation_3d = False
disable_physics_3d = False
# Remove unneeded implementations/standalone 3D/XR facilities.
module_navigation_3d_enabled = False
module_godot_physics_3d_enabled = False
module_jolt_physics_enabled = False
module_openxr_enabled = False
module_mobile_vr_enabled = False
module_webxr_enabled = False
module_csg_enabled = False
module_gridmap_enabled = False
module_gltf_enabled = False
module_fbx_enabled = False
module_lightmapper_rd_enabled = False
module_raycast_enabled = False
module_vhacd_enabled = False
module_xatlas_unwrap_enabled = False
# Networking and high-level replication handled outside Godot.
module_enet_enabled = False
module_webrtc_enabled = False
module_websocket_enabled = False
module_upnp_enabled = False
module_multiplayer_enabled = False
module_jsonrpc_enabled = False
# Preserve 2D, UI, text, common image/audio, GDExtension,
# filesystem, crypto and compression defaults.

# Explicitly match this preview: AccessKit dependency is not included.
accesskit = False

# Second pass: only these three additions versus baseline.
module_visual_shader_enabled = False
module_regex_enabled = False
module_camera_enabled = False

# Third pass: only disable GDScript versus trim3.
module_gdscript_enabled = False

# Fourth pass: only disable Theora versus trim4. Keep Ogg/Vorbis.
module_theora_enabled = False

# Fifth pass: only disable BMP, TGA, HDR and EXR versus trim5.
module_bmp_enabled = False
module_tga_enabled = False
module_hdr_enabled = False
module_tinyexr_enabled = False

# Explicit across all desktop platforms.
graphite = True
disable_3d = False
