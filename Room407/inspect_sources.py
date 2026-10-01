import bpy, json
from pathlib import Path
from mathutils import Vector
src=Path(__file__).parent.parent/'ExitRoom'
result={}
files=list((src/'Forgotten Bedroom - PS1 Style Asset Pack'/'Assets').rglob('*.blend'))+[src/'Male Character PS1_PSX'/'_Blender'/'MaleCharacter.blend',src/'PSX Character.fbx']
for f in files:
    if f.suffix=='.blend': bpy.ops.wm.open_mainfile(filepath=str(f))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(f))
    objects=[]
    for o in bpy.data.objects:
        if o.type not in ('MESH','ARMATURE'):continue
        pts=[o.matrix_world@Vector(c) for c in o.bound_box]
        objects.append(dict(name=o.name,type=o.type,dim=list(o.dimensions),min=[min(p[i] for p in pts) for i in range(3)],max=[max(p[i] for p in pts) for i in range(3)],materials=[m.name if m else None for m in o.data.materials] if o.type=='MESH' else [],bones=[b.name for b in o.data.bones] if o.type=='ARMATURE' else []))
    result[str(f.relative_to(src))]=dict(objects=objects,images=[dict(name=i.name,size=list(i.size),packed=bool(i.packed_file),path=i.filepath) for i in bpy.data.images],actions=[a.name for a in bpy.data.actions])
Path(__file__).with_name('source_inspection.json').write_text(json.dumps(result,indent=2))
print('INSPECTION_COMPLETE')
