"""Prepare a gameplay copy in an isolated Blender background process."""
import bpy, json, tempfile
from pathlib import Path
from mathutils import Vector

project=Path(__file__).resolve().parents[1]
temporary=project/'.buildtmp'
temporary.mkdir(exist_ok=True)
tempfile.tempdir=str(temporary)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(project/'3Dmodel_import/low-poly_furnished_abandoned_house.glb'))
walls=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('polySurface3_')]
points=[o.matrix_world@Vector(c) for o in walls for c in o.bound_box]
before={"min":[min(p[i] for p in points) for i in range(3)],"max":[max(p[i] for p in points) for i in range(3)]}
print('BLENDER_WALL_BOUNDS',json.dumps(before),flush=True)
assert len(walls)>=5, 'Expected the measured house wall surfaces'
assert -9 < before['min'][0] < -7 and 2.4 < before['max'][2] < 2.6, 'Unexpected coordinate system'
bpy.ops.object.select_all(action='DESELECT')
for o in walls:
    o.select_set(True)
bpy.context.view_layer.objects.active=walls[0]
bpy.ops.object.join()
wall=bpy.context.object
wall.name='HouseWalls_Playable'
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.object.mode_set(mode='OBJECT')
# glTF/Godot +Z corresponds to Blender -Y. The house front is at glTF Z=-0.817.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0.0,0.70,1.08))
cutter=bpy.context.object
cutter.name='EntranceCut_TEMP'
cutter.dimensions=(1.80,0.85,2.24)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
modifier=wall.modifiers.new('Walkable front doorway','BOOLEAN')
modifier.operation='DIFFERENCE'
modifier.solver='EXACT'
modifier.object=cutter
bpy.context.view_layer.objects.active=wall
bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cutter,do_unlink=True)
bpy.ops.mesh.primitive_cube_add(size=1,location=(0.0,-6.54,1.08))
cutter=bpy.context.object
cutter.dimensions=(1.80,0.85,2.24)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
modifier=wall.modifiers.new('Kitchen clearance for third-person movement','BOOLEAN')
modifier.operation='DIFFERENCE'
modifier.solver='EXACT'
modifier.object=cutter
bpy.context.view_layer.objects.active=wall
bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cutter,do_unlink=True)
assert len(wall.data.polygons)>100, 'Boolean removed too much geometry'
bpy.ops.export_scene.gltf(filepath=str(project/'assets/abandoned_house_playable.glb'),export_format='GLB',export_cameras=False,export_lights=False,export_animations=False)
(project/'tools/house-preparation.json').write_text(json.dumps({"source":"low-poly_furnished_abandoned_house.glb","output":"assets/abandoned_house_playable.glb","original_wall_bounds_blender":before,"entrance_godot_center":[0.0,1.08,-0.70],"kitchen_godot_center":[0.0,1.08,6.54],"doorway_dimensions":[1.8,2.24,0.85],"wall_polygons_after":len(wall.data.polygons),"changes":"Join wall surfaces retaining material slots, weld shared seams, cut front doorway and widen kitchen doorway. Original file unchanged."},indent=2),encoding='utf-8')
print('PLAYABLE_HOUSE_EXPORTED',flush=True)
