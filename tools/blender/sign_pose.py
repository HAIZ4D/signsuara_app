"""Posing helpers for the signer character in Blender (README "Signer").

Load inside Blender (for example through the Blender MCP):
    pose = runpy.run_path(r'C:\\FlutterProject\\signsuara_app\\tools\\blender\\sign_pose.py')

The character faces -Y (towards the camera); her right side is -X, her left side +X.
Rotations given "in T-pose axes" are world axes as they are in the character's T-pose, so the same
numbers mean the same joint movement wherever the parent bones are posed.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

ARMATURE = 'Armature'
AXIS = {'x': Vector((1, 0, 0)), 'y': Vector((0, 1, 0)), 'z': Vector((0, 0, 1))}
FINGERS = ('Index', 'Middle', 'Ring', 'Little')


def armature():
    return bpy.data.objects[ARMATURE]


def turn(bone, *steps):
    """Sets [bone]'s rotation: [steps] = (axis, degrees) in T-pose axes, applied in order."""
    arm = armature()
    total = Quaternion()
    for axis, deg in steps:
        total = Quaternion(AXIS[axis], math.radians(deg)) @ total
    rest = arm.data.bones[bone].matrix_local.to_quaternion()
    pose = arm.pose.bones[bone]
    pose.rotation_mode = 'QUATERNION'
    pose.rotation_quaternion = rest.inverted() @ total @ rest


def _rotate_world(bone, rotation):
    bpy.context.view_layer.update()
    pose = armature().pose.bones[bone]
    m = pose.matrix.copy()
    joint = m.translation.copy()
    m = rotation.to_matrix().to_4x4() @ m
    m.translation = joint
    pose.matrix = m
    bpy.context.view_layer.update()


def world_turn(bone, axis, deg):
    """Turns [bone] as posed now around a world axis through its joint."""
    _rotate_world(bone, Quaternion(AXIS[axis], math.radians(deg)))


def aim(bone, direction):
    """Turns [bone] (as posed now) the shortest way so it points along [direction] (world)."""
    bpy.context.view_layer.update()
    pose = armature().pose.bones[bone]
    now = (pose.tail - pose.head).normalized()
    _rotate_world(bone, now.rotation_difference(Vector(direction).normalized()))


def point_at(bone, target):
    """Aims [bone] at a world position."""
    bpy.context.view_layer.update()
    pose = armature().pose.bones[bone]
    aim(bone, Vector(target) - pose.head)


def hand_facing(side, fingers, palm):
    """Orients the hand: fingers along [fingers], palm facing [palm] (world directions).
    In the T-pose the fingers point outwards and the palms face down (-Z)."""
    bone = f'J_Bip_{side}_Hand'
    bpy.context.view_layer.update()
    arm = armature()
    pose = arm.pose.bones[bone]
    rest_to_now = pose.matrix.to_quaternion() @ arm.data.bones[bone].matrix_local.to_quaternion().inverted()
    t_fingers = Vector((1, 0, 0)) if side == 'L' else Vector((-1, 0, 0))
    now_f = rest_to_now @ t_fingers
    now_p = rest_to_now @ Vector((0, 0, -1))
    want_f = Vector(fingers).normalized()
    want_p = (Vector(palm) - Vector(palm).project(want_f)).normalized()
    now_m = Matrix((now_f, now_p, now_f.cross(now_p))).transposed()
    want_m = Matrix((want_f, want_p, want_f.cross(want_p))).transposed()
    _rotate_world(bone, (want_m @ now_m.inverted()).to_quaternion())


def curl(side, finger, mcp, pip, dip):
    """Bends a finger towards the palm at its three joints (degrees)."""
    sign = 1 if side == 'L' else -1
    for joint, deg in ((1, mcp), (2, pip), (3, dip)):
        turn(f'J_Bip_{side}_{finger}{joint}', ('y', sign * deg))


def thumb(side, *joints):
    """Poses the thumb: [joints] = for Thumb1..3 a list of (axis, degrees) in T-pose axes, with the
    left hand's signs (they are mirrored for the right hand)."""
    mirror = {'x': 1, 'y': -1, 'z': -1}
    for n, steps in enumerate(joints, start=1):
        if side == 'R':
            steps = [(axis, mirror[axis] * deg) for axis, deg in steps]
        turn(f'J_Bip_{side}_Thumb{n}', *steps)


def point(bone, end='head'):
    bpy.context.view_layer.update()
    arm = armature()
    return [round(v, 3) for v in (arm.matrix_world @ getattr(arm.pose.bones[bone], end))]


def use_action(name):
    """Shows an action's first frame (e.g. 'sign:rest') as the pose to start from."""
    arm = armature()
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[name]
    bpy.context.scene.frame_set(int(bpy.data.actions[name].frame_range[0]))
    snapshot = {p.name: p.rotation_quaternion.copy() for p in arm.pose.bones}
    arm.animation_data.action = None
    for p in arm.pose.bones:
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = snapshot[p.name]
    bpy.context.view_layer.update()
    return snapshot


def snapshot():
    return {p.name: p.rotation_quaternion.copy() for p in armature().pose.bones}


def restore(shot):
    for p in armature().pose.bones:
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = shot[p.name]
    bpy.context.view_layer.update()


def tween(a, b, t):
    """The pose [t] (0..1) of the way from snapshot [a] to [b]: every bone turns the shortest way."""
    out = {}
    for name, qa in a.items():
        qb = b[name]
        if qa.dot(qb) < 0:  # the same rotation, other sign: going this way round would be the long way
            qb = -qb
        out[name] = qa.slerp(qb, t)
    return out


def make_action(name, keys):
    """Creates (or replaces) action [name] from [keys] = [(frame, snapshot), ...]. Every frame in
    between is keyed too (shortest turns, eased in and out), so Blender's own curves never take the
    long way round. Every bone is keyed, so the pose is fully defined. Frame range = first..last key."""
    arm = armature()
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    frames = [(keys[0][0], keys[0][1])]
    for (f0, a), (f1, b) in zip(keys, keys[1:]):
        for f in range(f0 + 1, f1 + 1):
            t = (f - f0) / (f1 - f0)
            frames.append((f, tween(a, b, t * t * (3 - 2 * t))))  # smoothstep: ease in and out
    for frame, shot in frames:
        restore(shot)
        for p in arm.pose.bones:
            p.keyframe_insert('rotation_quaternion', frame=frame, group=p.name)
    action.use_frame_range = True
    action.frame_start, action.frame_end = keys[0][0], keys[-1][0]
    arm.animation_data.action = None
    return action
