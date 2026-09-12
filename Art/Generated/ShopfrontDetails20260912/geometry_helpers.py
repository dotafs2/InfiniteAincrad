"""Local mesh/PBR helpers adapted from the original StreetStructures20260912.

Only the minimal definitions were copied; this module performs no batch run,
imports no other asset library and reads no external art. Seeded normal maps
are generated locally. Use build_shopfront_details.py as the entry point.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
import random
import sys
import threading
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'game/assets/generated/shopfront_details_20260912'
QA = ROOT / 'docs/validation/art_parallel_20260912/shopfront'
R = random.Random(91231)
PALETTE = {
    'stone': 'C8BCA1', 'stone_light': 'E3D5B7', 'stone_dark': 'A79D88',
    'oak': '74583B', 'oak_light': '8F6E49', 'darkwood': '3C382E',
    'roof': '9E5E52', 'roof_light': 'B37B68', 'roof_dark': '8D5248',
    'sage': '719188', 'slate': '71898C', 'iron': '465454',
    'brass': 'C1A572', 'glass': '708E89', 'warmglass': 'F3CC8E',
    'paper': 'E0D1AB', 'ink': '827763', 'cloth': 'DDD1B1',
    'banner': '637F89', 'water': '639894', 'blue': '57BFD0',
}
MATS = {}
MAPS = {}
ASSETS = []


def linear(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in c) + (1,)


def make_normals():
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    rng = np.random.default_rng(91231)
    for key in ('stone', 'wood', 'cloth'):
        noise = rng.normal(0, .0015, (n, n)).astype(np.float32)
        if key == 'wood':
            h = .0028*np.sin((x+.018*np.sin(y*math.tau*2))*math.tau*35) + noise*.22
        elif key == 'cloth':
            h = .0012*(np.sin(x*math.tau*105)+np.sin(y*math.tau*105)) + noise*.10
        else:
            h = .004*np.sin(x*math.tau*7)*np.cos(y*math.tau*11) + noise
        dx = (np.roll(h,-1,1)-np.roll(h,1,1))*5
        dy = (np.roll(h,-1,0)-np.roll(h,1,0))*5
        a = np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
        a /= np.linalg.norm(a,axis=2)[:,:,None]
        rgba = np.ones((n,n,4),dtype=np.float32)
        rgba[:,:,:3] = a*.5+.5
        im = bpy.data.images.new('Shopfront_Authored_'+key+'_normal', width=n,height=n,alpha=True)
        im.colorspace_settings.name = 'Non-Color'
        im.pixels.foreach_set(rgba.ravel())
        im.filepath_raw = str(HERE/'textures'/f'{key}_normal.png')
        im.file_format = 'PNG'
        im.save()
        im.pack()
        MAPS[key] = im


def mat(role):
    if role in MATS:
        return MATS[role]
    m = bpy.data.materials.new('Shopfront_'+role)
    m.use_nodes = True
    m.diffuse_color = linear(PALETTE[role])
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = linear(PALETTE[role])
    bs.inputs['Roughness'].default_value = .72
    if role in ('iron','brass'):
        bs.inputs['Metallic'].default_value = .72
        bs.inputs['Roughness'].default_value = .36
    if role in ('glass','water'):
        bs.inputs['Roughness'].default_value = .25
        bs.inputs['Metallic'].default_value = .18
    if role == 'warmglass':
        bs.inputs['Emission Color'].default_value = linear(PALETTE[role])
        bs.inputs['Emission Strength'].default_value = .35
        bs.inputs['Roughness'].default_value = .3
    kind = 'stone' if role.startswith('stone') else 'wood' if role in ('oak','oak_light','darkwood','sage') else 'cloth' if role in ('cloth','banner') else None
    if kind:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = MAPS[kind]
        tex.extension = 'REPEAT'
        normal = m.node_tree.nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .4
        m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
        m.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    MATS[role] = m
    return m


FACES_BOX = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]


class Geo:
    def __init__(self):
        self.v=[]; self.f=[]; self.roles=[]; self.uv=[]

    def mesh(self, verts, faces, role, local=None):
        offset=len(self.v)
        self.v.extend(tuple(v) for v in verts)
        for face in faces:
            self.f.append(tuple(offset+i for i in face)); self.roles.append(role)
            coords=[Vector((local if local is not None else verts)[i]) for i in face]
            normal=(coords[1]-coords[0]).cross(coords[2]-coords[0])
            axis=max(range(3),key=lambda j:abs(normal[j]))
            axes=[j for j in range(3) if j!=axis]
            self.uv.append([(v[axes[0]]*.75,v[axes[1]]*.75) for v in coords])

    def box(self, p, s, role='stone', rot=None):
        v=[Vector((a*s[0]/2,b*s[1]/2,c*s[2]/2)) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.mesh([Vector(p)+(rot@q if rot else q) for q in v], FACES_BOX, role, v)

    def beam(self, a, b, width=.08, role='oak', depth=None):
        a,b=Vector(a),Vector(b); d=b-a
        self.box((a+b)/2,(width,depth or width,d.length),role,d.to_track_quat('Z','Y').to_matrix())

    def add(self,other,translation=(0,0,0),rotation=None):
        offset=len(self.v);p=Vector(translation)
        self.v.extend(tuple(p+(rotation@Vector(v) if rotation else Vector(v))) for v in other.v)
        self.f.extend(tuple(offset+i for i in face) for face in other.f)
        self.roles.extend(other.roles);self.uv.extend(other.uv)

    def lathe(self, p, profile, role='stone', segments=32, cap=True):
        v=[(p[0]+r*math.cos(i*math.tau/segments),p[1]+r*math.sin(i*math.tau/segments),p[2]+z) for r,z in profile for i in range(segments)]
        f=[]
        if cap:
            f=[tuple(range(segments-1,-1,-1)),tuple((len(profile)-1)*segments+i for i in range(segments))]
        for j in range(len(profile)-1):
            for i in range(segments):
                a=j*segments+i; b=j*segments+(i+1)%segments
                f.append((a,b,b+segments,a+segments))
        self.mesh(v,f,role)

    def cyl(self, a, b, r=.05, role='iron', segments=12, r2=None):
        a,b=Vector(a),Vector(b); d=b-a; q=d.to_track_quat('Z','Y').to_matrix()
        v=[a+q@Vector((rad*math.cos(i*math.tau/segments),rad*math.sin(i*math.tau/segments),z)) for z,rad in ((0,r),(d.length,r if r2 is None else r2)) for i in range(segments)]
        f=[tuple(range(segments-1,-1,-1)),tuple(segments+i for i in range(segments))]
        for i in range(segments):
            j=(i+1)%segments; f.append((i,j,j+segments,i+segments))
        self.mesh(v,f,role)

    def tube(self, pts, r=.02, role='iron', sides=8):
        # Smooth silhouette from connected cylindrical segments, capped at joints.
        for a,b in zip(pts,pts[1:]):
            if (Vector(a)-Vector(b)).length>1e-6: self.cyl(a,b,r,role,sides)

    def torus(self, p, major, minor=.015, role='iron', plane='XY', n=32, m=8):
        v=[]
        for i in range(n):
            a=i*math.tau/n
            for j in range(m):
                b=j*math.tau/m; rr=major+minor*math.cos(b)
                q=(rr*math.cos(a),rr*math.sin(a),minor*math.sin(b))
                if plane=='XZ': q=(q[0],q[2],q[1])
                if plane=='YZ': q=(q[2],q[0],q[1])
                v.append(tuple(Vector(p)+Vector(q)))
        f=[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)]
        self.mesh(v,f,role)

    def arch(self,x,y,z,r,thick=.2,depth=.28,role='stone_light',segments=20,gap=.003):
        for i in range(segments):
            a=math.pi*i/segments+gap; b=math.pi*(i+1)/segments-gap
            vs=[(x+rad*math.cos(t),y+dy,z+rad*math.sin(t)) for dy in (-depth/2,depth/2) for rad,t in [(r,a),(r,b),(r+thick,b),(r+thick,a)]]
            self.mesh(vs,FACES_BOX,role)

    def ring_blocks(self,p,inner,outer,z0,z1,segments=16,offset=0,role='stone'):
        for i in range(segments):
            a=math.tau*(i+offset)/segments+.009; b=math.tau*(i+1+offset)/segments-.009
            vs=[(p[0]+r*math.cos(t),p[1]+r*math.sin(t),z) for z in (z0,z1) for r,t in [(inner,a),(outer,a),(outer,b),(inner,b)]]
            self.mesh(vs,FACES_BOX,R.choice([role,role,'stone_light' if role=='stone' else role]))

    def object(self,name,col):
        me=bpy.data.meshes.new(name+'_mesh'); me.from_pydata(self.v,[],self.f); me.update()
        ob=bpy.data.objects.new(name,me); col.objects.link(ob)
        roles=list(dict.fromkeys(self.roles))
        for role in roles: me.materials.append(mat(role))
        uv=me.uv_layers.new(name='UV0_Metric')
        for face,role,coords in zip(me.polygons,self.roles,self.uv):
            face.material_index=roles.index(role)
            for li,co in zip(face.loop_indices,coords): uv.data[li].uv=co
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
        bpy.context.view_layer.objects.active=ob;ob.select_set(True)
        mod=ob.modifiers.new('Soft crafted edge highlights','BEVEL');mod.width=.009;mod.segments=2;mod.limit_method='ANGLE';mod.angle_limit=.63
        bpy.ops.object.modifier_apply(modifier=mod.name)
        me=ob.data
        # Exporter tangent construction requires triangles for bevel-generated ngons.
        bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces))
        # Tiny bevel slivers are unstable after float32 glTF serialization.
        bad=[face for face in bm.faces if face.calc_area()<1e-7]
        if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
        uv=me.uv_layers[0]
        for face in me.polygons:
            inds=list(face.loop_indices)
            a,b,c=(uv.data[i].uv.copy() for i in inds)
            signed_area=(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
            if abs(signed_area)<1e-9:
                # Preserve directional UVs except on collapsed bevel triangles.
                coords=[me.vertices[me.loops[i].vertex_index].co for i in inds]
                normal=(coords[1]-coords[0]).cross(coords[2]-coords[0])
                axis=max(range(3),key=lambda j:abs(normal[j]));axes=[j for j in range(3) if j!=axis]
                for li,co in zip(inds,coords):uv.data[li].uv=(co[axes[0]]*.75,co[axes[1]]*.75)
        ob.select_set(False)
        ob['units']='metres';ob['source']='Original authored geometry, 2026-09-12'
        ob['scope']='Visual prop only; no gameplay state, collision, navigation or LOD.'
        return ob
