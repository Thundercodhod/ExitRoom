import bpy,json,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];src=root.parent/'ExitRoom'
(root/'tools/tmp').mkdir(exist_ok=True)
tempfile.tempdir=str(root/'tools/tmp')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src/'animation/Breathing Idle.fbx'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
actions={'idle':rig.animation_data.action}
for file,name in [('Walking','walk'),('Running','run'),('Sitting Idle','sit'),('Standing To Crouched','crouch_down'),('Crouched To Standing','stand_up')]:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(src/'animation'/(file+'.fbx')))
    imported=set(bpy.data.objects)-before
    other=next(o for o in imported if o.type=='ARMATURE')
    a=other.animation_data.action;a.use_fake_user=True;a.name=name;actions[name]=a
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data.action=None
for name,a in actions.items():
    a.name=name
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,a)
    if a.slots:strip.action_slot=a.slots[0]
image=bpy.data.images.load(str(src/'Male Character PS1_PSX/MaleCharacter_Texture.png'))
m=bpy.data.materials.new('CharacterTextured');m.use_nodes=True
node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.9
m.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
for o in bpy.data.objects:
    if o.type=='MESH':o.data.materials.clear();o.data.materials.append(m)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/male_animated.glb'),export_format='GLB',export_animation_mode='NLA_TRACKS',export_animations=True,use_selection=True,export_cameras=False,export_lights=False)
(root/'animation_manifest.json').write_text(json.dumps({'source':'ExitRoom/animation','animations':list(actions),'missing':['sleep','wake_from_bed'],'note':'Original supplied FBX meshes and rig retained; texture references repaired.'},indent=2))
print('ANIMATIONS_EXPORTED')
