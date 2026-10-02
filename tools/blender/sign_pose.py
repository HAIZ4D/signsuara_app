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


def _rotation(bone, steps):
    """The bone's own rotation for [steps] = (axis, degrees) in T-pose axes, applied in order."""
    total = Quaternion()
    for axis, deg in steps:
        total = Quaternion(AXIS[axis], math.radians(deg)) @ total
    rest = armature().data.bones[bone].matrix_local.to_quaternion()
    return rest.inverted() @ total @ rest


def turn(bone, *steps):
    """Sets [bone]'s rotation: [steps] = (axis, degrees) in T-pose axes, applied in order."""
    pose = armature().pose.bones[bone]
    pose.rotation_mode = 'QUATERNION'
    pose.rotation_quaternion = _rotation(bone, steps)


def _rotate_world(bone, rotation):
    bpy.context.view_layer.update()
    pose = armature().pose.bones[bone]
    joint = pose.matrix.translation.copy()
    # rotation only: copying the whole matrix let tiny scale errors build up over many turns
    # (the right hand had become 0.68 x 0.95 x 1.55, which bent its fingers and thumb)
    m = (rotation @ pose.matrix.to_quaternion()).to_matrix().to_4x4()
    m.translation = joint
    pose.matrix = m
    pose.scale = (1, 1, 1)
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


def reach(side, wrist, elbow_hint=(0, 0.3, -1)):
    """Puts the wrist of arm [side] at the world point [wrist]: works out where the elbow must be
    (two bones of fixed length), bending towards [elbow_hint] (default: out, back and down)."""
    arm = armature()
    bones = arm.data.bones
    upper, lower, hand = (f'J_Bip_{side}_{b}' for b in ('UpperArm', 'LowerArm', 'Hand'))
    l1 = (bones[lower].head_local - bones[upper].head_local).length
    l2 = (bones[hand].head_local - bones[lower].head_local).length
    bpy.context.view_layer.update()
    shoulder = arm.pose.bones[upper].head.copy()
    to_wrist = Vector(wrist) - shoulder
    d = min(to_wrist.length, (l1 + l2) * 0.999)
    along = to_wrist.normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    hint = Vector(elbow_hint)
    if side == 'R':
        hint.x = -hint.x
    out = (hint - hint.project(along)).normalized()
    elbow = shoulder + along * a + out * h
    point_at(upper, elbow)
    point_at(lower, shoulder + along * d)


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


def _thumb_steps(side, joints):
    mirror = {'x': 1, 'y': -1, 'z': -1}
    return [[(axis, mirror[axis] * deg) for axis, deg in steps] if side == 'R' else steps for steps in joints]


def thumb(side, *joints):
    """Poses the thumb: [joints] = for Thumb1..3 a list of (axis, degrees) in T-pose axes, with the
    left hand's signs (they are mirrored for the right hand)."""
    for n, steps in enumerate(_thumb_steps(side, joints), start=1):
        turn(f'J_Bip_{side}_Thumb{n}', *steps)


def _thumb_tip(side, joints):
    """Where the thumb tip would be (world) with [joints], worked out bone by bone from the hand as
    it is posed now, without updating the scene (which would re-shape the whole character)."""
    arm = armature()
    bones = arm.data.bones
    parent = bones[f'J_Bip_{side}_Hand']
    m = arm.pose.bones[parent.name].matrix.copy()
    for n, steps in enumerate(_thumb_steps(side, joints), start=1):
        bone = bones[f'J_Bip_{side}_Thumb{n}']
        m = m @ (parent.matrix_local.inverted() @ bone.matrix_local) @ _rotation(bone.name, steps).to_matrix().to_4x4()
        parent = bone
    return arm.matrix_world @ (m @ Vector((0, parent.length, 0)))


def place_thumb(side, target, bend_range=(0,)):
    """Finds the thumb pose whose tip lands closest to the world point [target]: a coarse search
    over the thumb's two base angles (and, optionally, how much its joints bend), then a fine one
    around the best. Returns the miss in metres."""
    target = Vector(target)
    bpy.context.view_layer.update()  # the hand as posed now

    def miss(z, x, bend):
        return (_thumb_tip(side, ([('z', z), ('x', x)], [('z', bend)], [('z', bend)])) - target).length

    best = min((miss(z, x, b), z, x, b) for b in bend_range for z in range(-10, 100, 10) for x in range(-60, 90, 10))
    _, z0, x0, b0 = best
    fine = [b0] if len(bend_range) == 1 else [b0 - 7.5, b0, b0 + 7.5]
    best = min(best, *((miss(z, x, b), z, x, b) for b in fine
                        for z in (z0 - 5, z0 - 2.5, z0 + 2.5, z0 + 5) for x in (x0 - 5, x0 - 2.5, x0, x0 + 2.5, x0 + 5)))
    d, z, x, bend = best
    thumb(side, [('z', z), ('x', x)], [('z', bend)], [('z', bend)])
    return d


def handshape(side, name, with_thumb=True):
    """Sets the fingers (and thumb) of hand [side] to a handshape, keeping the hand's direction:
    'relaxed', 'fist' (A: thumb up along the index), 'flat' (fingers together, thumb along the
    index), 'B' (flat, thumb across the palm), 'index' (index finger out), 'Y' (thumb and little
    finger out), 'H' (index and middle finger out together), '5' (open, fingers spread, thumb out),
    'bunched' (fingertips together on the thumb tip, as in MAKAN), 'claw' (a loose fist: fingers
    half bent, thumb along the index), 'thumb_up' (fist, thumb straight out to the side),
    'flat_thumb' (fingers straight together, thumb straight out to the side), 'thumb_along'
    (fist, thumb straight up past the knuckles along the index side), 'pinch' (other fingers in a
    fist, the index raised mainly at its knuckle and the thumb tip on its tip, as in BUAT APA; with
    the palm up the two meet above the fist) and 'pinch_open' (the same pinch opened: the index a
    little straighter and the thumb drawn back, tips about 2.5 cm apart, so both move when it
    closes)."""
    straight, bent = (0, 0, 0), (88, 100, 60)
    fingers = {
        'relaxed': dict.fromkeys(FINGERS, (8, 10, 6)),
        'fist': dict.fromkeys(FINGERS, bent),
        'flat': dict.fromkeys(FINGERS, straight),
        'B': dict.fromkeys(FINGERS, straight),
        'index': {'Index': straight, 'Middle': bent, 'Ring': bent, 'Little': bent},
        'Y': {'Index': bent, 'Middle': bent, 'Ring': bent, 'Little': straight},
        'H': {'Index': straight, 'Middle': straight, 'Ring': bent, 'Little': bent},
        '5': dict.fromkeys(FINGERS, straight),
        'bunched': {'Index': (52, 30, 14), 'Middle': (50, 30, 14), 'Ring': (52, 32, 14), 'Little': (56, 34, 14)},
        'claw': dict.fromkeys(FINGERS, (72, 88, 45)),
        'thumb_up': dict.fromkeys(FINGERS, bent),
        'flat_thumb': dict.fromkeys(FINGERS, straight),
        'thumb_along': dict.fromkeys(FINGERS, bent),
        'pinch': {'Index': (55, 20, 12), 'Middle': bent, 'Ring': bent, 'Little': bent},
        'pinch_open': {'Index': (55, 20, 12), 'Middle': bent, 'Ring': bent, 'Little': bent},
    }[name]
    spread = {  # sideways (degrees): plus turns a finger towards the thumb side, minus towards the little finger
        'flat': {'Index': -3, 'Middle': 0, 'Ring': 2, 'Little': 5},
        '5': {'Index': 9, 'Middle': 0, 'Ring': -6, 'Little': -13},
        'bunched': {'Index': -7, 'Middle': 0, 'Ring': 5, 'Little': 11},
    }.get('flat' if name in ('flat', 'B', 'H', 'flat_thumb') else name, dict.fromkeys(FINGERS, 0))
    sign = 1 if side == 'L' else -1
    for f, (mcp, pip, dip) in fingers.items():
        turn(f'J_Bip_{side}_{f}1', ('z', spread[f] if side == 'R' else -spread[f]), ('y', sign * mcp))
        turn(f'J_Bip_{side}_{f}2', ('y', sign * pip))
        turn(f'J_Bip_{side}_{f}3', ('y', sign * dip))
    if name == 'relaxed':
        thumb(side, [('z', 10)], [], [])
        return 0.0
    if not with_thumb:  # fingers only (fast), e.g. while the arm is still being placed
        return 0.0
    base = {f: Vector(point(f'J_Bip_{side}_{f}1')) for f in FINGERS}
    mid = {f: Vector(point(f'J_Bip_{side}_{f}2')) for f in FINGERS}
    radial = (base['Index'] - base['Middle']).normalized()   # towards the thumb side
    palm_n = (base['Middle'] - Vector(point(f'J_Bip_{side}_Hand'))).cross(radial).normalized()
    if side == 'R':
        palm_n = -palm_n
    if name == 'fist':
        return place_thumb(side, base['Index'] + radial * 0.012 + (base['Index'] - Vector(point(f'J_Bip_{side}_Hand'))).normalized() * 0.035)
    if name == 'flat':
        return place_thumb(side, mid['Index'] + radial * 0.012)
    if name == 'B':
        return place_thumb(side, base['Ring'] + palm_n * 0.016, bend_range=range(0, 75, 15))
    if name == 'index':  # thumb holds the curled middle finger down
        return place_thumb(side, mid['Middle'] + palm_n * 0.02, bend_range=range(0, 75, 15))
    if name == 'H':      # thumb folded across the curled ring and little fingers
        return place_thumb(side, (mid['Ring'] + mid['Little']) / 2 + palm_n * 0.02, bend_range=range(0, 75, 15))
    if name == 'Y':      # thumb spread out sideways
        return place_thumb(side, base['Index'] + radial * 0.07)
    along = (base['Middle'] - Vector(point(f'J_Bip_{side}_Hand'))).normalized()  # towards the fingertips
    if name == '5':      # thumb out, between sideways and along the fingers
        return place_thumb(side, base['Index'] + radial * 0.055 + along * 0.02)
    if name == 'bunched':  # thumb tip under the index and middle fingertips
        tips = (Vector(point(f'J_Bip_{side}_Index3', 'tail')) + Vector(point(f'J_Bip_{side}_Middle3', 'tail'))) / 2
        return place_thumb(side, tips + palm_n * 0.008, bend_range=range(0, 60, 10))
    if name == 'claw':   # thumb bent, its tip against the side of the bent index
        return place_thumb(side, mid['Index'] + radial * 0.01 + palm_n * 0.004, bend_range=range(0, 75, 15))
    if name in ('thumb_up', 'flat_thumb'):  # thumb straight out to the side ("up" when the hand is turned)
        return place_thumb(side, base['Index'] + radial * 0.072 - along * 0.005)
    if name == 'thumb_along':  # thumb straight on along the hand, past the knuckles (a slight bend keeps it straight up)
        return place_thumb(side, base['Index'] + radial * 0.008 + along * 0.035, bend_range=(10,))
    if name in ('pinch', 'pinch_open'):  # thumb tip on the index fingertip; open: then the index curls in
        # the index curl (55, 20, 12) is the natural curl (led by the knuckle) whose tip the thumb
        # reaches best (1-2 mm, searched); a curl led by the middle joint looked like a bent hook
        tip = Vector(point(f'J_Bip_{side}_Index3', 'tail'))
        miss = place_thumb(side, tip + radial * 0.006, bend_range=range(-10, 50, 10))
        if name == 'pinch_open':  # curling the index into the fist instead looked like it slid along a still thumb
            curl(side, 'Index', 45, 14, 8)
            miss = place_thumb(side, tip - along * 0.004 + radial * 0.013, bend_range=range(-10, 50, 10))
        return miss
    return 0.0


HAND_PARTS = ('Thumb',) + FINGERS


def finger_pose(side, shape):
    """The finger and thumb rotations of handshape [shape] on hand [side]: {bone: quaternion}. They
    are the bones' own rotations, so they give the same handshape wherever the arm is."""
    keep = snapshot()
    handshape(side, shape)
    out = {n: q for n, q in snapshot().items() if n.startswith(f'J_Bip_{side}_') and n[8:].startswith(HAND_PARTS)}
    restore(keep)
    return out


def _hand_axes(side):
    """The hand's fingers and palm directions as hand_facing() counts them (its T-pose axes, turned
    the way the hand is turned now)."""
    bone = f'J_Bip_{side}_Hand'
    bpy.context.view_layer.update()
    arm = armature()
    rest_to_now = arm.pose.bones[bone].matrix.to_quaternion() @ arm.data.bones[bone].matrix_local.to_quaternion().inverted()
    t_fingers = Vector((1, 0, 0)) if side == 'L' else Vector((-1, 0, 0))
    return rest_to_now @ t_fingers, rest_to_now @ Vector((0, 0, -1))


def hand_now(side):
    """Where hand [side] is as posed now, as place() arguments: (wrist, fingers, palm, elbow hint).
    reach() and hand_facing() with these put the arm and hand back as they are now."""
    fingers, palm = _hand_axes(side)
    elbow = Vector(point(f'J_Bip_{side}_LowerArm')) - Vector(point(f'J_Bip_{side}_UpperArm'))
    if side == 'R':
        elbow.x = -elbow.x  # reach() mirrors the hint for the right arm
    return Vector(point(f'J_Bip_{side}_Hand')), fingers, palm, elbow


def track_frames(tracks, start):
    """Every frame of [tracks] = {side: [(frame, wrist, fingers, palm, hint, shape), ...]}, each
    placed from snapshot [start] (bones not in a track stay as there). Per side, between two keys
    the wrist moves straight (eased in and out), the hand turns the shortest way, and the elbow hint
    and the handshape blend; before its first key and after its last, a side holds that key. Both
    arms can move at once. [shape] is a handshape name or a finger_pose() (e.g. of the rest pose).
    Returns [(frame, snapshot)] for make_action()."""
    shapes = {}
    for side, keys in tracks.items():
        for k in keys:
            if not isinstance(k[5], dict) and (side, k[5]) not in shapes:
                shapes[side, k[5]] = finger_pose(side, k[5])

    def shape(side, s):
        return s if isinstance(s, dict) else shapes[side, s]

    first = min(keys[0][0] for keys in tracks.values())
    last = max(keys[-1][0] for keys in tracks.values())
    bones = armature().pose.bones
    out, twist = [], {}
    for f in range(first, last + 1):
        restore(start)
        for side, keys in tracks.items():
            a = max((k for k in keys if k[0] <= f), key=lambda k: k[0], default=keys[0])
            b = min((k for k in keys if k[0] >= f), key=lambda k: k[0], default=keys[-1])
            t = 0.0 if b[0] == a[0] else (f - a[0]) / (b[0] - a[0])
            t = t * t * (3 - 2 * t)
            qa, qb = _hand_frame(a[2], a[3]), _hand_frame(b[2], b[3])
            if qa.dot(qb) < 0:
                qb = -qb
            m = qa.slerp(qb, t).to_matrix()
            reach(side, Vector(a[1]).lerp(Vector(b[1]), t), Vector(a[4]).lerp(Vector(b[4]), t))
            hand_facing(side, m.col[0], m.col[1])
            sa, sb = shape(side, a[5]), shape(side, b[5])
            for name, q in sa.items():
                q2 = sb[name]
                bones[name].rotation_quaternion = q.slerp(-q2 if q.dot(q2) < 0 else q2, t)
            twist[side] = share_twist(side, prev=twist.get(side))
        out.append((f, snapshot()))
    return out


def point(bone, end='head'):
    bpy.context.view_layer.update()
    arm = armature()
    return [round(v, 3) for v in (arm.matrix_world @ getattr(arm.pose.bones[bone], end))]


def place(side, shape, wrist, fingers, palm, hint=(0, 0.3, -1), touch=None, rounds=6):
    """Arm [side] reaches to [wrist], the hand faces [fingers] / [palm], in handshape [shape].
    With touch=(function giving a point of the hand, target) the wrist is moved until that point
    is at the target (a fingertip on the chest). Returns (touch miss, thumb miss) in metres."""
    w = Vector(wrist)
    for _ in range(rounds if touch else 1):
        reach(side, w, hint)
        hand_facing(side, fingers, palm)
        handshape(side, shape, with_thumb=False)
        if not touch:
            break
        w += Vector(touch[1]) - touch[0]()
    miss = (touch[0]() - Vector(touch[1])).length if touch else 0.0
    return miss, handshape(side, shape)


def share_twist(side, part=0.5, prev=None):
    """Moves [part] of the hand's twist into the forearm (there are no twist bones), so the wrist
    does not wring. [prev] = the twist of the frame before (radians): the nearest equal twist is
    used, so it never turns round suddenly. Returns the twist."""
    bpy.context.view_layer.update()
    arm = armature()
    hand, lower = arm.pose.bones[f'J_Bip_{side}_Hand'], arm.pose.bones[f'J_Bip_{side}_LowerArm']
    q = hand.rotation_quaternion
    angle = (2 * math.atan2(q.y, q.w) + math.pi) % (2 * math.pi) - math.pi
    if prev is not None:
        angle = prev + ((angle - prev + math.pi) % (2 * math.pi) - math.pi)
    keep = hand.matrix.copy()
    lower.rotation_quaternion = lower.rotation_quaternion @ Quaternion((0, 1, 0), angle * part)
    bpy.context.view_layer.update()
    hand.matrix = keep
    bpy.context.view_layer.update()
    return angle


def _hand_frame(fingers, palm):
    f = Vector(fingers).normalized()
    p = (Vector(palm) - Vector(palm).project(f)).normalized()
    return Matrix((f, p, f.cross(p))).transposed().to_quaternion()


def ik_frames(side, shape, keys, start):
    """Every frame from the first to the last of [keys] = [(frame, (wrist, fingers, palm, hint))],
    each placed from snapshot [start]: the wrist moves smoothly, the hand turns the shortest way and
    the arm follows. For moves between two signing poses: blending the joint rotations one by one
    (make_action) can swing the elbow out when the forearm twist changes a lot."""
    out, prev = [], None
    for n, ((fa, a), (fb, b)) in enumerate(zip(keys, keys[1:])):
        qa, qb = _hand_frame(a[1], a[2]), _hand_frame(b[1], b[2])
        if qa.dot(qb) < 0:
            qb = -qb
        for f in range(fa if n == 0 else fa + 1, fb + 1):
            t = (f - fa) / (fb - fa)
            t = t * t * (3 - 2 * t)
            m = qa.slerp(qb, t).to_matrix()
            restore(start)
            place(side, shape, Vector(a[0]).lerp(Vector(b[0]), t), m.col[0], m.col[1],
                  hint=Vector(a[3]).lerp(Vector(b[3]), t))
            prev = share_twist(side, prev=prev)
            out.append((f, snapshot()))
    return out


def hands_clash(body='Body'):
    """How many triangles of the right hand's skin pass through the left hand's skin, with the
    character as posed now (0 = no fingers clipping through each other). A vertex belongs to a
    hand when at least half of its weight is on that hand's bones."""
    from mathutils.bvhtree import BVHTree
    obj = bpy.data.objects[body]
    names = {g.index: g.name for g in obj.vertex_groups}
    parts = ('Hand', 'Thumb', 'Index', 'Middle', 'Ring', 'Little')

    def hand_of(v):
        w = {'L': 0.0, 'R': 0.0}
        for g in v.groups:
            n = names.get(g.group, '')
            if n[:8] in ('J_Bip_L_', 'J_Bip_R_') and n[8:].startswith(parts):
                w[n[6]] += g.weight
        return 'L' if w['L'] >= 0.5 else 'R' if w['R'] >= 0.5 else None

    hands = [hand_of(v) for v in obj.data.vertices]
    bpy.context.view_layer.update()
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        verts = [v.co.copy() for v in mesh.vertices]
        polys = {'L': [], 'R': []}
        for p in mesh.polygons:
            owner = {hands[i] for i in p.vertices}
            if len(owner) == 1 and None not in owner:
                polys[owner.pop()].append(tuple(p.vertices))
        trees = [BVHTree.FromPolygons(verts, polys[s]) for s in 'RL']
        return len(trees[0].overlap(trees[1]))
    finally:
        evaluated.to_mesh_clear()


TORSO = ('J_Bip_C_Hips', 'J_Bip_C_Spine', 'J_Bip_C_Chest', 'J_Bip_C_UpperChest')


def forearm_parts(side):
    """The vertex groups of arm [side] from the elbow down (forearm, hand, fingers)."""
    return tuple(f'J_Bip_{side}_{p}' for p in ('LowerArm', 'Hand', 'Thumb', 'Index', 'Middle', 'Ring', 'Little'))


def parts_clash(a_parts, b_parts=TORSO, body='Body'):
    """How many triangles of mesh part A (vertex groups starting with [a_parts], e.g.
    forearm_parts('L')) pass through part B (default: the torso), with the character as posed now.
    A vertex belongs to a part when at least half of its weight is on that part's bones. Even the
    rest pose gives about 55 for each forearm (the sleeves touch the jacket's sides); a forearm
    inside the body gives hundreds."""
    from mathutils.bvhtree import BVHTree
    obj = bpy.data.objects[body]
    names = {g.index: g.name for g in obj.vertex_groups}

    def owner(v):
        wa = wb = 0.0
        for g in v.groups:
            n = names.get(g.group, '')
            if n.startswith(a_parts):
                wa += g.weight
            elif n.startswith(b_parts):
                wb += g.weight
        return 'A' if wa >= 0.5 else 'B' if wb >= 0.5 else None

    own = [owner(v) for v in obj.data.vertices]
    bpy.context.view_layer.update()
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        verts = [v.co.copy() for v in mesh.vertices]
        polys = {'A': [], 'B': []}
        for p in mesh.polygons:
            o = {own[i] for i in p.vertices}
            if len(o) == 1 and None not in o:
                polys[o.pop()].append(tuple(p.vertices))
        a, b = BVHTree.FromPolygons(verts, polys['A']), BVHTree.FromPolygons(verts, polys['B'])
        return len(a.overlap(b))
    finally:
        evaluated.to_mesh_clear()


SLIM_SLEEVES = 'SignSuara slim sleeves'


def _smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def slim_sleeves(body='Body', fore=0.72, cuff=0.62, layers=(('N00_007_01_Tops_01_CLOTH', 0.008), ('N00_007_02_Tops_01_CLOTH', 0.004))):
    """Adds shape key SLIM_SLEEVES (value 1) to the character: the sleeves are slimmer along the
    whole forearm (radius x [fore], from just above the elbow), taper more towards the cuff (x [cuff])
    and end at the wrist. The model's wide jacket sleeves made the forearms look big (radius about
    5.3 cm round an arm of about 2.4 cm), and the cuffs hid the hand whenever the wrist bent (SAYA
    pointing at the chest). [layers] = (material, gap): jacket and shirt get the same factors, so the
    shirt never comes out through the jacket, and neither comes closer to the arm's skin than its
    gap (metres), measured all round the arm. The original mesh is untouched: set the key's value to
    0 to get the old sleeves back."""
    obj = bpy.data.objects[body]
    me = obj.data
    arm = armature()
    gap_of = {i: g for i, m in enumerate(me.materials) for name, g in layers if m and m.name.startswith(name)}
    skin_mats = {i for i, m in enumerate(me.materials) if m and 'SKIN' in m.name}
    cloth, skin = {}, set()
    for p in me.polygons:
        for v in p.vertices:
            if p.material_index in gap_of:
                cloth[v] = max(cloth.get(v, 0.0), gap_of[p.material_index])  # the jacket's gap where they meet
            elif p.material_index in skin_mats:
                skin.add(v)
    if not me.shape_keys:
        obj.shape_key_add(name='Basis', from_mix=False)
    if SLIM_SLEEVES in me.shape_keys.key_blocks:
        obj.shape_key_remove(me.shape_keys.key_blocks[SLIM_SLEEVES])
    key = obj.shape_key_add(name=SLIM_SLEEVES, from_mix=False)
    to_local = obj.matrix_world.inverted() @ arm.matrix_world
    for side in 'LR':
        elbow = to_local @ arm.data.bones[f'J_Bip_{side}_LowerArm'].head_local
        axis = to_local @ arm.data.bones[f'J_Bip_{side}_Hand'].head_local - elbow
        length = axis.length
        axis.normalize()
        ref = axis.orthogonal().normalized()
        ref2 = axis.cross(ref)

        def where(co):
            d = co - elbow
            s = d.dot(axis) / length                   # 0 at the elbow, 1 at the wrist
            r = d - axis * d.dot(axis)
            return s, r, round(s * 20), int((math.degrees(math.atan2(r.dot(ref2), r.dot(ref))) + 360) % 360 // 30)

        outer = {}  # (s bin, angle bin) -> the skin's radius there (its outer vertices)
        for i in skin:
            s, r, sb, ab = where(me.vertices[i].co)
            if -0.2 <= s <= 1.1 and r.length < 0.12:
                outer.setdefault((sb, ab), []).append(r.length)
        floor = {b: sorted(v)[int(0.9 * (len(v) - 1))] for b, v in outer.items()}
        for i, gap in cloth.items():
            s, r, sb, ab = where(me.vertices[i].co)
            if s < -0.15 or r.length > 0.12:          # upper arm and body stay as they are
                continue
            k = 1 - (1 - fore) * _smooth(-0.15, 0.15, s)       # slimmer from just above the elbow
            k *= 1 - (1 - cuff / fore) * _smooth(0.6, 0.95, s)  # and more towards the cuff
            near = [floor[b] for b in ((sb + ds, (ab + da) % 12) for ds in (-1, 0, 1) for da in (-1, 0, 1)) if b in floor]
            radius = max(r.length * k, (max(near) + gap) if near else 0.0)
            radius = min(radius, r.length)                     # never wider than before
            s = s if s <= 1.0 else 1.0 + (s - 1.0) * 0.4      # the cuff ends near the wrist
            key.data[i].co = elbow + axis * (s * length) + r.normalized() * radius
    key.value = 1.0
    return key


def hair_colour(images=('_20', '_21', '_07'), hue=0.075, saturation=0.85, value=0.92, restore=False):
    """Recolours the hair: for each texture in [images] (this model: _20 back hair, _21 hair, _07
    eyebrows) a copy "<name> brown" gets every pixel's colour turned to [hue] (0.075 = warm brown),
    with its saturation and brightness scaled (shading and highlights stay), and replaces the
    original in every material. The originals are kept: restore=True puts them back."""
    import numpy as np
    swap = {}
    for name in images:
        orig = bpy.data.images[name]
        orig.use_fake_user = True  # kept in the .blend while unused
        copy = bpy.data.images.get(name + ' brown')
        if restore:
            if copy:
                swap[copy] = orig
            continue
        px = np.empty(len(orig.pixels), dtype=np.float32)
        orig.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        v = px[:, :3].max(axis=1)
        s = (v - px[:, :3].min(axis=1)) / np.maximum(v, 1e-6) * saturation
        v = v * value
        low = v * (1 - s)
        # hue between red (0) and yellow (1/6): red is the brightest channel, blue the darkest
        px[:, 0], px[:, 1], px[:, 2] = v, low + (v - low) * hue * 6, low
        if copy is None:
            copy = bpy.data.images.new(name + ' brown', *orig.size, alpha=True)
            copy.colorspace_settings.name = orig.colorspace_settings.name
        copy.pixels.foreach_set(px.ravel())
        copy.pack()
        swap[orig] = copy
    for m in bpy.data.materials:
        for n in (m.node_tree.nodes if m.node_tree else ()):
            if n.type == 'TEX_IMAGE' and n.image in swap:
                n.image = swap[n.image]
        ext = getattr(m, 'vrm_addon_extension', None)
        if ext:  # the VRM add-on keeps its own texture links (it rebuilds the nodes from them)
            mtoon = ext.mtoon1
            for tex in (mtoon.pbr_metallic_roughness.base_color_texture,
                        mtoon.extensions.vrmc_materials_mtoon.shade_multiply_texture):
                if tex.index.source in swap:
                    tex.index.source = swap[tex.index.source]
    return sorted(i.name for i in swap.values())


FACE = 'Face'


def face_keys():
    return bpy.data.objects[FACE].data.shape_keys


def make_face_action(name, keys):
    """Creates (or replaces) face action [name] (e.g. 'face:terima_kasih'): [keys] = [(frame,
    {shape key: value}), ...]. Shape keys not named are 0 (neutral) at every key."""
    key = face_keys()
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    key.animation_data_create()
    key.animation_data.action = action
    shapes = sorted({s for _, values in keys for s in values})
    for frame, values in keys:
        for s in shapes:
            block = key.key_blocks[s]
            block.value = values.get(s, 0.0)
            block.keyframe_insert('value', frame=frame)
    action.use_frame_range = True
    action.frame_start, action.frame_end = keys[0][0], keys[-1][0]
    key.animation_data.action = None
    for s in shapes:
        key.key_blocks[s].value = 0.0
    return action


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
    """Puts every bone back to the rotations in [shot] (location and scale back to none)."""
    for p in armature().pose.bones:
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = shot[p.name]
        p.location = (0, 0, 0)
        p.scale = (1, 1, 1)
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
