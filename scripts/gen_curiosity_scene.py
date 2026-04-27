"""One-shot generator for scenes/Curiosity.tscn.

Wires the 22 sliced frames into an AnimatedSprite2D + SpriteFrames resource
without hand-typing 22 ext_resource entries. Re-runnable: rewrites the scene
deterministically from the frame files in assets/characters/hero/frames/.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Anim:
    name: str
    frame_count: int
    fps: float
    loop: bool


ANIMS = [
    Anim("idle", 4, 6.0, True),
    Anim("walk", 6, 10.0, True),
    Anim("run", 6, 14.0, True),
    Anim("jump_start", 2, 12.0, False),
    Anim("air", 2, 6.0, True),
    Anim("land", 2, 12.0, False),
]


def main() -> None:
    ext_lines: list[str] = []
    ext_ids: dict[tuple[str, int], str] = {}

    next_id = 1
    script_id = f"{next_id}_curiosity"
    next_id += 1
    ext_lines.append(
        f'[ext_resource type="Script" path="res://scripts/Curiosity.gd" id="{script_id}"]'
    )

    for anim in ANIMS:
        for i in range(1, anim.frame_count + 1):
            tex_id = f"{next_id}_{anim.name}_{i:02d}"
            ext_ids[(anim.name, i)] = tex_id
            path = f"res://assets/characters/hero/frames/{anim.name}_{i:02d}.png"
            ext_lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{tex_id}"]')
            next_id += 1

    anim_blocks: list[str] = []
    for anim in ANIMS:
        frames = ",\n".join(
            f'{{"duration": 1.0, "texture": ExtResource("{ext_ids[(anim.name, i)]}")}}'
            for i in range(1, anim.frame_count + 1)
        )
        loop_str = "true" if anim.loop else "false"
        block = (
            "{\n"
            f'"frames": [{frames}],\n'
            f'"loop": {loop_str},\n'
            f'"name": &"{anim.name}",\n'
            f'"speed": {anim.fps}\n'
            "}"
        )
        anim_blocks.append(block)
    sprite_frames_body = "animations = [" + ", ".join(anim_blocks) + "]"

    ext_count = next_id - 1
    sub_count = 4  # SpriteFrames + RectangleShape2D + Gradient + GradientTexture2D
    load_steps = ext_count + sub_count + 1

    out = []
    out.append(f"[gd_scene load_steps={load_steps} format=3]")
    out.append("")
    out.extend(ext_lines)
    out.append("")
    out.append('[sub_resource type="SpriteFrames" id="SpriteFrames_curiosity"]')
    out.append(sprite_frames_body)
    out.append("")
    out.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]')
    # Height matches the AnimatedSprite2D bounds (135 px canvas * 3.2 scale)
    # so the collision bottom = the painted feet position. Keeps the slim body
    # width from prior tuning (88 px) — wide enough for grounded feel, narrow
    # enough to slip past tight props without snagging on the cloak/hair.
    out.append("size = Vector2(88, 432)")
    out.append("")
    out.append('[sub_resource type="Gradient" id="Gradient_lantern"]')
    out.append("offsets = PackedFloat32Array(0, 1)")
    out.append("colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)")
    out.append("")
    out.append('[sub_resource type="GradientTexture2D" id="GradientTexture2D_lantern"]')
    out.append('gradient = SubResource("Gradient_lantern")')
    out.append("width = 256")
    out.append("height = 256")
    out.append("fill = 1")
    out.append("fill_from = Vector2(0.5, 0.5)")
    out.append("fill_to = Vector2(1, 0.5)")
    out.append("")
    out.append('[node name="Curiosity" type="CharacterBody2D"]')
    out.append(f'script = ExtResource("{script_id}")')
    out.append("")
    out.append('[node name="Visual" type="AnimatedSprite2D" parent="."]')
    out.append("scale = Vector2(3.2, 3.2)")
    out.append('sprite_frames = SubResource("SpriteFrames_curiosity")')
    out.append('animation = &"idle"')
    out.append('autoplay = "idle"')
    out.append("")
    out.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="."]')
    out.append('shape = SubResource("RectangleShape2D_body")')
    out.append("")
    out.append('[node name="Lantern" type="PointLight2D" parent="."]')
    out.append("position = Vector2(-128, 96)")
    out.append("color = Color(1, 0.78, 0.42, 1)")
    out.append("energy = 1.1")
    out.append('texture = SubResource("GradientTexture2D_lantern")')
    out.append("texture_scale = 1.6")
    out.append("")
    out.append('[node name="Camera" type="Camera2D" parent="."]')
    out.append("position = Vector2(0, -160)")
    out.append("position_smoothing_enabled = true")
    out.append("position_smoothing_speed = 6.0")
    out.append("")

    with open("scenes/Curiosity.tscn", "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print(f"wrote scenes/Curiosity.tscn — {ext_count} ext, {sub_count} sub, load_steps={load_steps}")


if __name__ == "__main__":
    main()
