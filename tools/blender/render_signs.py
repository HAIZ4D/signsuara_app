"""Renders the signer's sign animations to PNG frames (README "Signer").

Run inside Blender with the signer .blend open (Scripting tab: open this file, Run Script; or
through the Blender MCP). Every action named "sign:<id>" (for example "sign:terima_kasih", or
"sign:rest" for the avatar standing ready) is played on the character's armature and rendered
with the scene's camera and settings to:  character/renders/<id>/0001.png, 0002.png, ...
Then, on the PC:  python tools/make_sign_clips.py

Each action needs a frame range (Action > Manual Frame Range), and should start and end in the
rest pose so the clips join without a jump. Only signs checked by a fluent BIM signer go in the app.
"""
import os

import bpy

PROJECT = os.environ.get('SIGNSUARA_PROJECT', r'C:\FlutterProject\signsuara_app')
ARMATURE = 'Armature'
ONLY = None  # e.g. {'rest', 'terima_kasih'} to render just these


def render_signs():
    scene = bpy.context.scene
    armature = bpy.data.objects[ARMATURE]
    armature.animation_data_create()
    before = (armature.animation_data.action, scene.frame_start, scene.frame_end, scene.render.filepath)
    done = []
    try:
        for action in bpy.data.actions:
            if not action.name.startswith('sign:'):
                continue
            sign = action.name[len('sign:'):]
            if ONLY and sign not in ONLY:
                continue
            armature.animation_data.action = action
            first, last = (int(f) for f in action.frame_range)
            folder = os.path.join(PROJECT, 'character', 'renders', sign)
            os.makedirs(folder, exist_ok=True)
            for old in os.listdir(folder):  # a shorter new version must not keep old frames
                if old.endswith('.png'):
                    os.remove(os.path.join(folder, old))
            for n, frame in enumerate(range(first, last + 1), start=1):
                scene.frame_set(frame)
                scene.render.filepath = os.path.join(folder, f'{n:04d}.png')
                bpy.ops.render.render(write_still=True)
            done.append((sign, last - first + 1))
    finally:
        armature.animation_data.action = before[0]
        scene.frame_start, scene.frame_end, scene.render.filepath = before[1:]
    return done


if __name__ == '__main__':
    for sign, frames in render_signs():
        print(f'{sign}: {frames} frame(s)')
