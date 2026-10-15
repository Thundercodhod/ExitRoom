import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
results={}
for f in (root.parent/'ExitRoom/animation').glob('*.fbx'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(f))
    results[f.name]={'objects':[{'name':o.name,'type':o.type,'bones':[b.name for b in o.data.bones] if o.type=='ARMATURE' else [],'dim':list(o.dimensions)} for o in bpy.data.objects], 'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],'images':[{'name':i.name,'path':i.filepath,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images]}
(root/'animation_inspection.json').write_text(json.dumps(results,indent=2))
print('ANIMATION_INSPECTED')
