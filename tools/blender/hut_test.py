# Headless Blender smoke test: low-poly flat-shaded hut -> PNG, so Claude can look at assets.
# Run: Blender -b -P tools/blender/hut_test.py -- out.png
import bpy, sys, math
out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name, rgb):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); return m
red, roof, ice = mat("red",(.55,.12,.08)), mat("roof",(.12,.14,.25)), mat("ice",(.45,.75,.9))
def add(kind, loc, scale, m):
    getattr(bpy.ops.mesh, kind)(location=loc); o = bpy.context.object; o.scale = scale
    o.data.materials.append(m); return o
add("primitive_plane_add", (0,0,0), (6,6,1), ice)
add("primitive_cube_add", (0,0,0.8), (1.4,1.0,0.8), red)
r = add("primitive_cone_add", (0,0,2.0), (1.9,1.4,0.9), roof); r.rotation_euler[2] = math.pi/4
bpy.ops.object.light_add(type="SUN", location=(4,-4,8)); bpy.context.object.data.energy = 4
bpy.ops.object.camera_add(location=(7,-7,6), rotation=(math.radians(60),0,math.radians(45)))
bpy.context.scene.camera = bpy.context.object
s = bpy.context.scene; s.render.engine = "BLENDER_WORKBENCH"
s.display.shading.color_type = "MATERIAL"; s.display.shading.light = "STUDIO"
s.render.resolution_x, s.render.resolution_y = 960, 540
s.render.filepath = out; bpy.ops.render.render(write_still=True)
