class_name OfficeRoom
extends Node3D
## The office diorama: one cramped concrete slab, green wainscot, a steel
## door with a lit hatch, an extractor fan bolted to the east wall, and every
## surface wearing its grime. The room is a sealed box - four walls and a
## lid - so no camera angle inside it ever opens on the void.
## The fan is a machine, not dressing: it runs, sputters, stalls and gets
## kicked back on, and the sound bus reads its speed off fan_speed.

const MAT := preload("res://shaders/ps1_mat.gdshader")
const WALL_H := 3.0
const W := 28.0
const D := 16.0
const INK := Color("0a0c10")
const MAROON := Color(0.32, 0.14, 0.12)
const GLASS_G := Color(0.24, 0.34, 0.22)
const GLASS_B := Color(0.30, 0.20, 0.12)
const AMBER := Color(0.88, 0.62, 0.30)
const PHOS := Color(0.62, 0.78, 0.58)
const IRON_D := Color(0.14, 0.14, 0.16)
const WOOD_D := Color(0.20, 0.15, 0.11)

const EAST := Vector3(1, 0, 0)
const WEST := Vector3(-1, 0, 0)
const SOUTH := Vector3(0, 0, 1)

# the one spot you can use for now, ON its prop's body
const SPOT_POINTS := {
        "door": Vector3(26.4, 0, 8.0),       # the steel door, east wall
}
const MARKS := {
        "door": [Vector3(26.85, 1.2, 8.0), Vector3(-1, 0, 0)],
}

var spots := {}                 # name -> Vector3 (world space)
var _markers: Array[MeshInstance3D] = []
var _fan: Node3D                # the extractor fan on the east wall, spinning

# the fan machine: the one bit of stateful logic the room owns (K5 - a
# machine that visibly does things, with sound that follows it down)
enum { FAN_RUN, FAN_SPUTTER, FAN_STALL }
const FAN_RUN_TIME := 24.0      # seconds of honest running
const FAN_SPUTTER_TIME := 2.8   # the bearings complain
const FAN_STALL_TIME := 3.6     # dark and quiet, then the kick
const FAN_SPIN := 2.2           # radians a second at full speed

var fan_state: int = FAN_RUN    # read by the sound bus and the smoke gate
var fan_speed := 1.0            # 0..1, drives the spin and the fan loop
var _fan_t := 0.0
var _fan_rot := 0.0
var _fan_last := -1.0
var _fan_rng := RandomNumberGenerator.new()


func _ready() -> void:
        _fan_rng.seed = 1947           # deterministic cycle: QA can walk it
        for key in SPOT_POINTS:
                spots[key] = SPOT_POINTS[key]
        _build_shell()
        _build_windows()
        _build_door()
        _build_desk()
        _build_west_wall()
        _build_east_wall()
        _build_lounge()
        _build_industrial()
        _build_markers()


func spot(key: String) -> Vector3:
        return spots[key]


func pulse_markers(t: float) -> void:
        var dt := 0.0 if _fan_last < 0.0 else maxf(0.0, t - _fan_last)
        _fan_last = t
        _fan_step(dt)
        for m in _markers:
                (m.material_override as ShaderMaterial).set_shader_parameter(
                                "glow", 0.4 + 0.18 * sin(t * 2.6))


func _fan_step(dt: float) -> void:
        # the visible logic cycle: run, sputter, stall, kick. Headless-safe:
        # the smoke walks it with fixed ticks and asserts every transition.
        if _fan == null:
                return
        _fan_t += dt
        match fan_state:
                FAN_RUN:
                        fan_speed = 1.0
                        if _fan_t >= FAN_RUN_TIME:
                                _fan_t = 0.0
                                fan_state = FAN_SPUTTER
                FAN_SPUTTER:
                        fan_speed = 0.5 + 0.5 * absf(sin(_fan_t * 8.5)) \
                                        * _fan_rng.randf_range(0.8, 1.0)
                        if _fan_t >= FAN_SPUTTER_TIME:
                                _fan_t = 0.0
                                fan_state = FAN_STALL
                FAN_STALL:
                        fan_speed = maxf(0.0, 0.8 - _fan_t * 0.9)
                        if _fan_t >= FAN_STALL_TIME:
                                _fan_t = 0.0
                                fan_state = FAN_RUN     # somebody kicked it
        _fan_rot += fan_speed * FAN_SPIN * dt
        _fan.rotation.x = _fan_rot


# --- the material factory -------------------------------------------------------------

func _mat(tex_name := "", tint := Color.WHITE, uv := Vector2.ONE, glow := 0.0) -> ShaderMaterial:
        var m := ShaderMaterial.new()
        m.shader = MAT
        m.set_shader_parameter("tint", tint)
        if tex_name != "":
                m.set_shader_parameter("textured", true)
                m.set_shader_parameter("tex", load("res://assets/tex/%s.png" % tex_name))
        m.set_shader_parameter("uv_scale", uv)
        m.set_shader_parameter("glow", glow)
        return m


func _collider(size: Vector3, pos: Vector3) -> void:
        var body := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        body.add_child(cs)
        body.position = pos
        add_child(body)


func _box(size: Vector3, pos: Vector3, mat: ShaderMaterial, solid := true) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        mi.mesh = mesh
        mi.material_override = mat
        mi.position = pos
        add_child(mi)
        if solid:
                var body := StaticBody3D.new()
                var cs := CollisionShape3D.new()
                var shape := BoxShape3D.new()
                shape.size = size
                cs.shape = shape
                body.add_child(cs)
                body.position = pos
                add_child(body)
        return mi


func _quad(size: Vector2, pos: Vector3, mat: ShaderMaterial, face := SOUTH,
                yaw := 0.0) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var mesh := PlaneMesh.new()
        mesh.size = size
        mesh.subdivide_width = 8
        mesh.subdivide_depth = 4
        mi.mesh = mesh
        mi.material_override = mat
        mi.position = pos
        # spin the base plane to its compass face; the wall turns go through
        # "up" first so textures stay upright on the wall
        if face == Vector3.UP:
                if yaw != 0.0:
                        mi.rotation.y = yaw
        elif face == Vector3.DOWN:
                mi.rotation.x = PI
        elif face == WEST:
                mi.rotation = Vector3(PI * 0.5, -PI * 0.5, 0)
        elif face == EAST:
                mi.rotation = Vector3(PI * 0.5, PI * 0.5, 0)
        else:                              # SOUTH: upright from both sides
                mi.rotation.x = PI * 0.5
        add_child(mi)
        return mi


# --- the shell ------------------------------------------------------------------------

func _build_shell() -> void:
        # floor: worn boards
        var mi := MeshInstance3D.new()
        var mesh := PlaneMesh.new()
        mesh.size = Vector2(W, D)
        mesh.subdivide_width = 14
        mesh.subdivide_depth = 8
        mi.mesh = mesh
        mi.position = Vector3(W * 0.5, 0, D * 0.5)
        mi.material_override = _mat("floor", Color.WHITE, Vector2(7, 4))
        add_child(mi)
        _collider(Vector3(W, 0.4, D), Vector3(W * 0.5, -0.2, D * 0.5))
        # the wainscot band and the plaster above it, on all four walls
        var band_h := 0.95
        _quad(Vector2(W, band_h), Vector3(W * 0.5, band_h * 0.5, 1.01),
                        _mat("wainscot", Color.WHITE, Vector2(7, 0.5)))
        _quad(Vector2(W, WALL_H - band_h), Vector3(W * 0.5, band_h + (WALL_H - band_h) * 0.5, 1.01),
                        _mat("wall", Color.WHITE, Vector2(7, 1)))
        _quad(Vector2(W, band_h), Vector3(W * 0.5, band_h * 0.5, D - 1.01),
                        _mat("wainscot", Color.WHITE, Vector2(7, 0.5)))
        _quad(Vector2(W, WALL_H - band_h), Vector3(W * 0.5, band_h + (WALL_H - band_h) * 0.5, D - 1.01),
                        _mat("wall", Color.WHITE, Vector2(7, 1)))
        _quad(Vector2(D, band_h), Vector3(1.01, band_h * 0.5, D * 0.5),
                        _mat("wainscot", Color.WHITE, Vector2(4, 0.5)), EAST)
        _quad(Vector2(D, WALL_H - band_h), Vector3(1.01, band_h + (WALL_H - band_h) * 0.5, D * 0.5),
                        _mat("wall", Color.WHITE, Vector2(4, 1)), EAST)
        _quad(Vector2(D, band_h), Vector3(W - 1.01, band_h * 0.5, D * 0.5),
                        _mat("wainscot", Color.WHITE, Vector2(4, 0.5)), WEST)
        _quad(Vector2(D, WALL_H - band_h), Vector3(W - 1.01, band_h + (WALL_H - band_h) * 0.5, D * 0.5),
                        _mat("wall", Color.WHITE, Vector2(4, 1)), WEST)
        # the lid
        _quad(Vector2(W, D), Vector3(W * 0.5, WALL_H, D * 0.5),
                        _mat("ceiling", Color.WHITE, Vector2(7, 4)), Vector3.DOWN)
        # wall collisions: the shell carries them
        _collider(Vector3(W, WALL_H, 1), Vector3(W * 0.5, WALL_H * 0.5, 0.5))
        _collider(Vector3(W, WALL_H, 1), Vector3(W * 0.5, WALL_H * 0.5, D - 0.5))
        _collider(Vector3(1, WALL_H, D), Vector3(0.5, WALL_H * 0.5, D * 0.5))
        _collider(Vector3(1, WALL_H, D), Vector3(W - 0.5, WALL_H * 0.5, D * 0.5))
        # a baseboard shadow strip where wall meets floor, all four walls
        var skirt := _mat("", IRON_D)
        _box(Vector3(W, 0.14, 0.06), Vector3(W * 0.5, 0.07, 1.04), skirt, false)
        _box(Vector3(W, 0.14, 0.06), Vector3(W * 0.5, 0.07, D - 1.04), skirt, false)
        _box(Vector3(0.06, 0.14, D), Vector3(1.04, 0.07, D * 0.5), skirt, false)
        _box(Vector3(0.06, 0.14, D), Vector3(W - 1.04, 0.07, D * 0.5), skirt, false)


func _build_windows() -> void:
        # the city beyond the glass, two panes with iron frames
        # the two panes, the city at night behind them
        for wx in [18.5, 22.5]:
                _quad(Vector2(2.2, 1.6), Vector3(wx, 1.95, 1.02), _mat("", INK))
                _quad(Vector2(2.0, 1.4), Vector3(wx, 1.95, 1.04),
                                _mat("window", Color.WHITE, Vector2.ONE, 1.3))
                for part in [[Vector3(2.24, 0.08, 0.08), Vector3(wx, 1.19, 1.06)],
                                [Vector3(2.24, 0.08, 0.08), Vector3(wx, 2.71, 1.06)],
                                [Vector3(0.08, 1.6, 0.08), Vector3(wx - 1.08, 1.95, 1.06)],
                                [Vector3(0.08, 1.6, 0.08), Vector3(wx + 1.08, 1.95, 1.06)],
                                [Vector3(0.06, 1.6, 0.06), Vector3(wx, 1.95, 1.06)]]:
                        _box(part[0], part[1], _mat("", IRON_D), false)
        # the radiator under the right pane, five iron fins
        for i in 5:
                _box(Vector3(0.14, 0.52, 0.1), Vector3(21.9 + i * 0.16, 0.36, 1.2),
                                _mat("", IRON_D))
        _box(Vector3(0.95, 0.06, 0.14), Vector3(22.2, 0.66, 1.2), _mat("", IRON_D), false)


func _build_door() -> void:
        # the steel door on the east wall, its hatch glowing amber over the slot
        _quad(Vector2(1.3, 2.36), Vector3(W - 1.03, 1.18, 8.0),
                        _mat("door", Color.WHITE, Vector2.ONE, 0.3), WEST)
        for part in [[Vector3(0.1, 2.4, 0.1), Vector3(W - 1.05, 1.2, 7.3)],
                        [Vector3(0.1, 2.4, 0.1), Vector3(W - 1.05, 1.2, 8.7)],
                        [Vector3(0.08, 2.4, 1.5), Vector3(W - 1.05, 1.2, 8.0)]]:
                _box(part[0], part[1], _mat("", IRON_D))
        _quad(Vector2(0.34, 0.38), Vector3(W - 1.07, 1.62, 8.0),
                        _mat("", AMBER, Vector2.ONE, 1.4), WEST)
        _box(Vector3(0.06, 0.42, 0.38), Vector3(W - 1.06, 1.62, 8.0),
                        _mat("", IRON_D), false)
        _box(Vector3(0.05, 0.3, 0.06), Vector3(W - 1.1, 1.05, 7.55),
                        _mat("", IRON_D), false)          # the handle
        # the trash bin beside it
        _box(Vector3(0.3, 0.55, 0.3), Vector3(W - 1.3, 0.275, 10.2), _mat("iron"))
        _collider(Vector3(0.4, 0.6, 0.4), Vector3(W - 1.3, 0.3, 10.2))


func _build_desk() -> void:
        # the heavy top in the middle of the room, the chair behind it
        var wood := _mat("desk", Color.WHITE, Vector2.ONE)
        # the top is a subdivided plane so the bulb's pool actually lands in it
        var top := MeshInstance3D.new()
        var tm := PlaneMesh.new()
        tm.size = Vector2(1.7, 0.95)
        tm.subdivide_width = 6
        tm.subdivide_depth = 4
        top.mesh = tm
        top.material_override = wood
        top.position = Vector3(14.0, 0.925, 9.2)
        add_child(top)
        _box(Vector3(1.7, 0.08, 0.95), Vector3(14.0, 0.88, 9.2), wood)
        for leg in [Vector3(13.25, 0.42, 8.82), Vector3(14.75, 0.42, 8.82),
                        Vector3(13.25, 0.42, 9.58), Vector3(14.75, 0.42, 9.58)]:
                _box(Vector3(0.09, 0.84, 0.09), leg, _mat("", WOOD_D))
        _collider(Vector3(1.8, 1.0, 1.05), Vector3(14.0, 0.5, 9.2))
        # the chair, back to the north wall light
        _box(Vector3(0.5, 0.08, 0.5), Vector3(14.0, 0.5, 8.35), _mat("desk"), false)
        _box(Vector3(0.5, 0.55, 0.08), Vector3(14.0, 0.82, 8.14), _mat("desk"), false)
        for leg in [Vector3(13.78, 0.23, 8.13), Vector3(14.22, 0.23, 8.13),
                        Vector3(13.78, 0.23, 8.57), Vector3(14.22, 0.23, 8.57)]:
                _box(Vector3(0.06, 0.46, 0.06), leg, _mat("", WOOD_D), false)
        _collider(Vector3(0.6, 1.1, 0.6), Vector3(14.0, 0.55, 8.35))
        # the typewriter, waiting for the report nobody will file
        _box(Vector3(0.5, 0.22, 0.42), Vector3(13.15, 1.0, 8.72), _mat("typewriter"), false)
        # the desk lamp: iron base, stem, a warm head over the desk
        _box(Vector3(0.16, 0.05, 0.16), Vector3(14.7, 0.915, 9.5), _mat("", IRON_D), false)
        _box(Vector3(0.05, 0.36, 0.05), Vector3(14.7, 1.11, 9.5), _mat("", IRON_D), false)
        _box(Vector3(0.22, 0.10, 0.22), Vector3(14.7, 1.33, 9.45), _mat("", IRON_D), false)
        _quad(Vector2(0.18, 0.18), Vector3(14.7, 1.27, 9.45),
                        _mat("", AMBER * 0.9, Vector2.ONE, 1.2), Vector3.DOWN)
        _collider(Vector3(0.3, 1.4, 0.3), Vector3(14.7, 0.7, 9.5))
        # the ashtray with last night's proof
        _box(Vector3(0.12, 0.04, 0.12), Vector3(13.9, 0.92, 9.45), _mat("", IRON_D), false)
        # the case boxes on the floor, dealt and dealt again
        _box(Vector3(0.55, 0.38, 0.42), Vector3(12.5, 0.19, 10.7),
                        _mat("paper", Color(0.55, 0.53, 0.5), Vector2.ONE))
        _box(Vector3(0.5, 0.34, 0.38), Vector3(12.55, 0.55, 10.72),
                        _mat("paper", Color(0.5, 0.48, 0.46), Vector2.ONE), false)
        _collider(Vector3(0.6, 0.8, 0.5), Vector3(12.5, 0.4, 10.7))


func _build_west_wall() -> void:
        # the file bank: three painted cabinets, paper loads on top, two bottles
        for i in 3:
                _box(Vector3(0.55, 1.9, 0.62), Vector3(1.32, 0.95, 3.5 + i * 1.05),
                                _mat("cabinet", Color.WHITE, Vector2.ONE))
                _box(Vector3(0.4, 0.14, 0.5),
                                Vector3(1.3, 1.97, 3.4 + i * 1.05),
                                _mat("paper", Color(0.62, 0.60, 0.57), Vector2.ONE), false)
        _collider(Vector3(0.7, 2.0, 3.3), Vector3(1.35, 1.0, 4.55))
        for i in 2:
                var bcol: Color = [GLASS_G, GLASS_B][i]
                _box(Vector3(0.1, 0.3, 0.1), Vector3(1.3, 2.11, 5.3 + i * 0.35),
                                _mat("", bcol), false)
        # the crates in the southwest corner, boards like the floor
        for part in [[Vector3(0.75, 0.75, 0.75), Vector3(1.4, 0.375, 14.55)],
                        [Vector3(0.6, 0.6, 0.6), Vector3(1.45, 1.05, 14.5)]]:
                _box(part[0], part[1], _mat("floor", Color(0.8, 0.75, 0.7), Vector2.ONE))
        _collider(Vector3(0.9, 1.4, 0.9), Vector3(1.4, 0.7, 14.55))
        # the dead plant in the northeast corner
        _box(Vector3(0.32, 0.32, 0.32), Vector3(W - 1.4, 0.16, D - 1.2),
                        _mat("iron"), false)
        for part in [[Vector3(0.4, 0.34, 0.4), Vector3(W - 1.4, 0.5, D - 1.2), Color(0.14, 0.20, 0.11)],
                        [Vector3(0.26, 0.3, 0.26), Vector3(W - 1.4, 0.8, D - 1.2), Color(0.18, 0.24, 0.12)],
                        [Vector3(0.12, 0.24, 0.12), Vector3(W - 1.4, 1.05, D - 1.2), Color(0.2, 0.26, 0.13)]]:
                _box(part[0], part[1], _mat("", part[2]), false)
        _collider(Vector3(0.45, 0.6, 0.45), Vector3(W - 1.4, 0.3, D - 1.2))


func _build_east_wall() -> void:
        # the coat rack by the door, holding the coat he walks the streets in
        # - off indoors, over the shirt and the braces; no hat, he owns none
        for part in [[Vector3(0.32, 0.06, 0.32), Vector3(W - 1.35, 0.03, 5.8)],
                        [Vector3(0.07, 1.66, 0.07), Vector3(W - 1.35, 0.86, 5.8)],
                        [Vector3(0.4, 0.05, 0.05), Vector3(W - 1.35, 1.68, 5.8)],
                        [Vector3(0.05, 0.05, 0.4), Vector3(W - 1.35, 1.68, 5.8)]]:
                _box(part[0], part[1], _mat("iron"))
        _box(Vector3(0.34, 0.55, 0.24), Vector3(W - 1.35, 1.32, 5.8),
                        _mat("", MAROON), false)
        _collider(Vector3(0.4, 1.8, 0.4), Vector3(W - 1.35, 0.9, 5.8))


func _build_lounge() -> void:
        # the worn rug and the armchair, facing the desk; the floor lamp beside
        _quad(Vector2(2.6, 1.9), Vector3(20.5, 0.02, 12.6),
                        _mat("rug", Color.WHITE, Vector2.ONE), Vector3.UP)
        for part in [[Vector3(0.85, 0.4, 0.85), Vector3(20.5, 0.2, 12.6)],
                        [Vector3(0.25, 0.8, 0.85), Vector3(20.85, 0.6, 12.6)],
                        [Vector3(0.85, 0.55, 0.2), Vector3(20.5, 0.475, 12.28)],
                        [Vector3(0.85, 0.55, 0.2), Vector3(20.5, 0.475, 12.92)]]:
                _box(part[0], part[1], _mat("", MAROON), false)
        _collider(Vector3(0.9, 0.9, 0.9), Vector3(20.5, 0.45, 12.6))
        _box(Vector3(0.3, 0.06, 0.3), Vector3(19.0, 0.03, 14.3), _mat("", IRON_D), false)
        _box(Vector3(0.06, 1.5, 0.06), Vector3(19.0, 0.78, 14.3), _mat("", IRON_D), false)
        _box(Vector3(0.26, 0.16, 0.26), Vector3(19.0, 1.63, 14.3),
                        _mat("", AMBER * 0.9, Vector2.ONE, 1.1), false)
        _collider(Vector3(0.35, 1.75, 0.35), Vector3(19.0, 0.875, 14.3))


func _build_industrial() -> void:
        # the industrial steel: an extractor fan bolted to the east wall,
        # conduit runs over the north wall, drop pipes from the lid. Iron
        # everywhere, all of it solid, so the camera ray keeps the lens out
        # of the steel.
        var iron := _mat("iron")
        var iron_d := _mat("", IRON_D)
        # the extractor fan: wall plate, square rim, four wide galvanized
        # blades on one spinning core, a three-bar grill in front. The blades
        # are the palest iron in the room so the fan reads at tube resolution.
        _box(Vector3(0.16, 1.9, 1.9), Vector3(W - 1.45, 1.85, 12.5), iron)
        # the black throat the blades turn against
        _box(Vector3(0.02, 1.42, 1.42), Vector3(W - 1.54, 1.85, 12.5),
                        _mat("", Color(0.05, 0.05, 0.06)), false)
        for part in [[Vector3(0.14, 0.22, 1.9), Vector3(W - 1.56, 2.69, 12.5)],
                        [Vector3(0.14, 0.22, 1.9), Vector3(W - 1.56, 1.01, 12.5)],
                        [Vector3(0.14, 1.46, 0.22), Vector3(W - 1.56, 1.85, 11.66)],
                        [Vector3(0.14, 1.46, 0.22), Vector3(W - 1.56, 1.85, 13.34)]]:
                _box(part[0], part[1], iron_d)
        _fan = Node3D.new()
        _fan.position = Vector3(W - 1.66, 1.85, 12.5)
        add_child(_fan)
        var steel := _mat("iron", Color(1.0, 1.0, 1.0), Vector2.ONE, 0.3)
        var hub := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = Vector3(0.24, 0.3, 0.3)
        hub.mesh = hm
        hub.material_override = iron_d
        _fan.add_child(hub)
        var cap := MeshInstance3D.new()     # the bolt cap, so the core reads
        var cm := BoxMesh.new()
        cm.size = Vector3(0.05, 0.14, 0.14)
        cap.mesh = cm
        cap.position = Vector3(-0.13, 0, 0)
        cap.material_override = steel
        _fan.add_child(cap)
        for i in 4:                # wide pitched blades, pale on the black throat
                var holder := Node3D.new()
                holder.rotation.x = i * PI * 0.5
                _fan.add_child(holder)
                var arm := MeshInstance3D.new()
                var am := BoxMesh.new()
                am.size = Vector3(0.08, 0.46, 0.34)
                arm.mesh = am
                arm.material_override = steel
                arm.position = Vector3(0, 0.4, 0)
                arm.rotation.y = 0.5
                holder.add_child(arm)
        for gy in [1.47, 1.85, 2.23]:      # the grill, three bars bridging the rim
                _box(Vector3(0.03, 0.07, 1.4), Vector3(W - 1.81, gy, 12.5), iron_d, false)
        # the conduit run over the north wall, three lines with junction boxes
        for k in 3:
                _box(Vector3(W - 4.0, 0.08, 0.08),
                                Vector3(W * 0.5 - 1.0, 2.72 + k * 0.11, 1.32), iron)
        for jx in [5.0, 14.0, 23.0]:
                _box(Vector3(0.22, 0.34, 0.16), Vector3(jx, 2.88, 1.32), iron_d)
        # two drop pipes from the lid, with caps
        for dpx in [6.5, 21.0]:
                _box(Vector3(0.14, 0.9, 0.14), Vector3(dpx, WALL_H - 0.45, 1.5), iron_d)
                _box(Vector3(0.2, 0.08, 0.2), Vector3(dpx, WALL_H - 0.04, 1.5), iron)
        # one long feed pipe along the east wall, over the fan
        _box(Vector3(0.08, 0.08, D - 4.0), Vector3(W - 1.6, 2.64, D * 0.5), iron)
        for bz in [3.0, 8.0, 13.0]:
                _box(Vector3(0.16, 0.2, 0.1), Vector3(W - 1.6, 2.64, bz), iron_d)
        # the hanging tube over the center, the room's cold heart
        _box(Vector3(0.09, 0.42, 0.09), Vector3(14.0, WALL_H - 0.21, 8.0), iron_d, false)
        _box(Vector3(1.6, 0.08, 0.34), Vector3(14.0, WALL_H - 0.46, 8.0), iron_d, false)
        _quad(Vector2(1.4, 0.18), Vector3(14.0, WALL_H - 0.5, 8.0),
                        _mat("", PHOS, Vector2.ONE, 1.35), Vector3.DOWN)
        # the hanging bulb over the desk, the warm heart
        _box(Vector3(0.03, 0.55, 0.03), Vector3(14.2, WALL_H - 0.275, 9.5), iron_d, false)
        _box(Vector3(0.14, 0.18, 0.14), Vector3(14.2, WALL_H - 0.64, 9.5),
                        _mat("", AMBER * 0.85, Vector2.ONE, 1.3), false)


func _build_markers() -> void:
        # A small amber tag marks the thing you can use - pinned close to its
        # prop's body; the pulse rides the emission so it glows, not glares
        for key in MARKS:
                var mi := _quad(Vector2(0.2, 0.2), MARKS[key][0],
                                _mat("", AMBER * 0.85, Vector2.ONE, 0.55), MARKS[key][1])
                _markers.append(mi)
