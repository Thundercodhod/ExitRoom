import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
root=Path(__file__).resolve().parents[1]; src=root.parent/'ExitRoom'; tex=root/'assets/textures'; out=root/'assets/models'
report={}
def material(name,texture=None,tint=(1,1,1,1),metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=tint;bs.inputs['Roughness'].default_value=.9;bs.inputs['Metallic'].default_value=metal
    if texture:
        p=next(tex.glob(texture+'.*'));im=bpy.data.images.load(str(p),check_existing=True)
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
        m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    return m
def export(name):
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
def bounds(objects):
    bpy.context.view_layer.update()
    pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    return Vector([min(p[i] for p in pts) for i in range(3)]),Vector([max(p[i] for p in pts) for i in range(3)])
specs=[('Bed/Bed.blend','bed',2.15,1,0),('Bedside Table/Bedside Table.blend','nightstand',.55,2,0),('Wardrobe Closet/Wardrobe.blend','wardrobe',2.05,2,90),('Wooden Drawer/Wooden Drawer.blend','dresser',1.1,2,90),('Lamp/Lamp.blend','lamp',.48,2,0),('Ceiling Light/Ceiling Light.blend','ceiling_light',.42,0,0),('Door/Wooden_Door.blend','wooden_door',2.2,2,0),('Shelf/Shelf.blend','shelf',1.3,1,90)]
for file,name,target,axis,angle in specs:
    bpy.ops.wm.open_mainfile(filepath=str(src/'Forgotten Bedroom - PS1 Style Asset Pack/Assets'/file))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH'];low,high=bounds(objs);scale=target/(high-low)[axis]
    rot=Matrix.Rotation(math.radians(angle),4,'Z')
    for o in objs:
        o.data.transform(Matrix.Scale(scale,4)@rot@o.matrix_world);o.matrix_world=Matrix.Identity(4)
    low,high=bounds(objs);offset=Vector((-(low.x+high.x)/2,-(low.y+high.y)/2,-low.z))
    for o in objs:o.data.transform(Matrix.Translation(offset))
    wood=material('Old oak','wood_table_001_albedo');cloth=material('Woven bedding','quilt');blanket=material('Patterned blanket','fabric7');brass=material('Aged brass',tint=(.21,.16,.095,1),metal=.65)
    for o in objs:
        previous=[m.name.lower() if m else '' for m in o.data.materials]
        indices=[p.material_index for p in o.data.polygons]
        if not previous:previous=['wood']
        o.data.materials.clear()
        for label in previous:
            mat=blanket if 'blanket' in label else cloth if any(x in label for x in ['matress','pillow']) else brass if 'knob' in label else wood
            if name in ('lamp','ceiling_light'):mat=cloth
            o.data.materials.append(mat)
        for p,idx in zip(o.data.polygons,indices):p.material_index=min(idx,len(previous)-1)
        # Project real texture maps onto the source geometry; no generated flat materials.
        uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
        for p in o.data.polygons:
            normal=p.normal;dominant=max(range(3),key=lambda a:abs(normal[a]));axes=[i for i in range(3) if i!=dominant]
            for li in p.loop_indices:
                v=o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv=(v[axes[0]],v[axes[1]])
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    lo,hi=bounds(objs);report[name]={'dimensions_blender':list(hi-lo),'source':file,'scale':scale}
    export(name)
# Preserve the original rig and repair material image links in the exported copy.
bpy.ops.wm.open_mainfile(filepath=str(src/'Male Character PS1_PSX/_Blender/MaleCharacter.blend'))
image=bpy.data.images.load(str(src/'Male Character PS1_PSX/MaleCharacter_Texture.png'),check_existing=False)
for mat in bpy.data.materials:
    if mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE':node.image=image
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type in ('MESH','ARMATURE'):o.select_set(True)
export('male_standing')
# Static sleeping stand-in; the rigged standing export stays available for animation replacement.
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for n in ['forearm_left','forearm_right']:
    rig.pose.bones[n].rotation_mode='XYZ';rig.pose.bones[n].rotation_euler.x=math.radians(-12)
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get(); originals=[o for o in bpy.context.scene.objects if o.type=='MESH'];static=[]
for o in originals:
    mesh=bpy.data.meshes.new_from_object(o.evaluated_get(deps));obj=bpy.data.objects.new(o.name+'_sleep',mesh);bpy.context.collection.objects.link(obj)
    obj.data.transform(Matrix.Rotation(-math.pi/2,4,'X')@o.matrix_world);static.append(obj)
lo,hi=bounds(static); shift=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
for o in static:o.data.transform(Matrix.Translation(shift))
bpy.ops.object.select_all(action='DESELECT')
for o in static:o.select_set(True)
export('male_sleeping')
report['male_sleeping']={'dimensions_blender':list(hi-lo),'note':'Static pose only; animation pending'}
for kind in ['closedbox','openbox']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src/'boxes-byPomidorkastudios/assets/asset'/kind/'gltf/model.gltf'))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH'];lo,hi=bounds(objs);s=.5/max(hi-lo)
    for o in objs:o.data.transform(Matrix.Scale(s,4)@o.matrix_world);o.matrix_world=Matrix.Identity(4)
    lo,hi=bounds(objs)
    for o in objs:o.data.transform(Matrix.Translation(Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))))
    bpy.ops.object.select_all(action='SELECT');export(kind)
(root/'asset_export_report.json').write_text(json.dumps(report,indent=2))
print('EXPORT_COMPLETE')
