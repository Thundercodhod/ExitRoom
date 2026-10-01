from pathlib import Path
import struct,json,shutil
root=Path(__file__).parent
src=root.parent/'ExitRoom'
for d in ['assets/models','assets/textures','assets/shaders','audio','scripts','tools','previews','licenses']:(root/d).mkdir(parents=True,exist_ok=True)
def extract(path,wanted):
    b=path.read_bytes(); n=struct.unpack_from('<I',b,12)[0]; j=json.loads(b[20:20+n]); binary=b[28+n:]
    for m in j['materials']:
        if m['name'] not in wanted:continue
        t=m['pbrMetallicRoughness']['baseColorTexture']['index']; i=j['images'][j['textures'][t]['source']]; v=j['bufferViews'][i['bufferView']]
        extension='.png' if 'png' in i['mimeType'] else '.jpg'
        (root/'assets/textures'/ (wanted[m['name']]+extension)).write_bytes(binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])
extract(src/'3Dmodel_import/low-poly_furnished_abandoned_house.glb',{'M_Tecido10':'fabric10','M_Tecido7':'fabric7','M_Acolchoado':'quilt','M_Tapete1':'rug','M_Pintura1':'painting','M_Cortina2':'curtain'})
extract(src/'404/soviet_apartment_interior_-_low_poly.glb',{'LivingRoomWallper':'wallpaper','BedRoomWallper':'bedroom_wallpaper','WoodenFloor':'apartment_floor'})
for name in ['wood_table_001_albedo.jpg','plastered_wall_albedo.jpg']:
    shutil.copy2(src/'assets/textures/abandoned'/name,root/'assets/textures'/name)
shutil.copy2(src/'assets/shaders/retro_horror.gdshader',root/'assets/shaders/retro_horror.gdshader')
for name in ['drone.wav','step.wav']:shutil.copy2(src/'audio'/name,root/'audio'/name)
shutil.copy2(src/'Forgotten Bedroom - PS1 Style Asset Pack/License.txt',root/'licenses/ForgottenBedroom.txt')
shutil.copy2(src/'boxes-byPomidorkastudios/README.txt',root/'licenses/Boxes.txt')
shutil.copy2(src/'NotoSansThai.ttf',root/'assets/NotoSansThai.ttf') if (src/'NotoSansThai.ttf').exists() else None
print('Prepared sources, textures, licenses. Original project unchanged.')
