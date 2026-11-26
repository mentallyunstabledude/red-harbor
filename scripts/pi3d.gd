class_name Pi
extends CharacterBody3D
## The PI, rebuilt off the new reference sheet (docs/character_reference.png):
## a lanky middle-aged man in a light khaki shirt with chest pockets, a dark
## charcoal tie under open collar flaps, near-black braces over the shoulders
## that converge on a metal adjuster between the shoulder blades, a leather
## belt with a brass buckle, high-waist chocolate slacks and dark leather
## shoes. Grizzled gray-brown hair swept back with volume on top, a gray
## chevron mustache and a chin beard built as real geometry, a nose and a
## heavy brow on the face cell, and the belt kit off the back pose - a
## walkie-talkie and a key ring swinging on the stride. One ember accent:
## the cigarette. Every box face reads its own cell of the texture atlas
## (Godot's BoxMesh UVs). The stride crossfades with the idle breath,
## cadence follows real speed, he banks into turns, and the shirt tail
## rides a damped spring.
## He walks where the camera looks. No combat, no health - the office is a
## place to think, not to fight. A footstep lands every time the stride
## crosses its beat, so the office can put iron under his shoes.

const MAT := preload("res://shaders/ps1_mat.gdshader")
const SPEED := 4.6
const TURN := 10.0

const EMBER := Color(0.85, 0.30, 0.10)
const CIG := Color(0.90, 0.88, 0.82)
# the cloth-and-iron tints: nothing here gets its own texture sheet
const BRACES := Color(0.10, 0.09, 0.08)     # the suspenders, near-black
const TIE := Color(0.17, 0.17, 0.19)        # the charcoal tie
const BELT := Color(0.13, 0.11, 0.09)       # the leather belt
const BRASS := Color(0.62, 0.50, 0.30)      # the buckle, warm metal
const COLLAR := Color(0.77, 0.74, 0.64)     # the collar flaps, palest khaki
const BROW_T := Color(0.70, 0.65, 0.58)     # the brow ridge, shaded skin
const WALKIE := Color(0.12, 0.12, 0.13)     # the radio on the belt
const KEYS := Color(0.24, 0.24, 0.26)       # the key ring, dull iron

signal footstep                 # a shoe just planted on the boards

var cam: Camera3D               # the office orbit cam; the walk follows it
var _idle_t := 0.0              # the breath / glance clock, always running
var _walk_t := 0.0              # the stride clock, advances with real speed
var _blend := 0.0               # 0 = idle pose, 1 = stride pose, crossfaded
var _lean := 0.0                # the bank into a turn, smoothed
var _fwd_lean := 0.0            # the lean into the walk, smoothed
var _tail_a := 0.06             # shirt tail spring angle
var _tail_v := 0.0              # shirt tail spring velocity
var _torso: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _fore_l: Node3D
var _fore_r: Node3D
var _tails: Node3D
var _head: Node3D
var _kit: Node3D                # the belt kit: walkie + keys, swings on stride
var _ember: MeshInstance3D
var _step_sign := 0             # the last stride half the beat landed on


func _ready() -> void:
        add_to_group("player")
        collision_layer = 4
        collision_mask = 1
        var cs := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.radius = 0.34
        shape.height = 1.6
        cs.shape = shape
        cs.position = Vector3(0, 0.85, 0)
        add_child(cs)
        _build_rig()


func _build_rig() -> void:
        # the reference sheet, in boxes: a tucked khaki shirt over high-waist
        # slacks, braces and a tie as proud geometry so they catch the tube's
        # light, the head carrying nose, brow, swept hair and a gray beard
        _torso = Node3D.new()
        add_child(_torso)
        _torso.position.y = 0.92

        # --- the hips and the belt -------------------------------------------------------
        _box(_torso, Vector3(0.44, 0.20, 0.28), Vector3(0, 0.08, 0), "pi_slacks")
        _box(_torso, Vector3(0.46, 0.06, 0.30), Vector3(0, 0.21, 0), "", BELT)
        _box(_torso, Vector3(0.075, 0.05, 0.02), Vector3(0, 0.21, 0.155), "", BRASS)

        # --- the shirt ------------------------------------------------------------------
        _box(_torso, Vector3(0.50, 0.56, 0.32), Vector3(0, 0.50, 0), "pi_shirt")
        # the collar flaps: two pale slabs opening over the tie
        for side in [-1.0, 1.0]:
                var flap := _box(_torso, Vector3(0.09, 0.075, 0.025),
                                Vector3(side * 0.085, 0.76, 0.148), "", COLLAR)
                flap.rotation.z = side * 0.38
                flap.rotation.x = -0.08
        # the tie: a knot under the collar, a blade down the chest
        _box(_torso, Vector3(0.09, 0.07, 0.05), Vector3(0, 0.735, 0.17), "", TIE)
        _box(_torso, Vector3(0.085, 0.26, 0.035), Vector3(0, 0.575, 0.165), "", TIE)
        # the braces: straight straps down the front, angled into the back
        # adjuster between the shoulder blades
        for side in [-1.0, 1.0]:
                _box(_torso, Vector3(0.05, 0.42, 0.02),
                                Vector3(side * 0.145, 0.50, 0.168), "", BRACES)
                var back := _box(_torso, Vector3(0.05, 0.40, 0.02),
                                Vector3(side * 0.115, 0.50, -0.168), "", BRACES)
                back.rotation.z = -side * 0.22
        _box(_torso, Vector3(0.05, 0.07, 0.02), Vector3(0, 0.40, -0.172), "", KEYS)
        # the shirt tail: the spring cloth behind the waist
        _tails = _pivot(_torso, Vector3(0, 0.30, -0.145))
        _box(_tails, Vector3(0.42, 0.30, 0.08), Vector3(0, -0.15, 0), "pi_shirt")

        # --- the belt kit, off the back pose: the radio and the keys ride the hip
        _kit = _pivot(_torso, Vector3(0, 0.21, -0.145))
        _box(_kit, Vector3(0.07, 0.15, 0.045), Vector3(0.155, -0.07, -0.02), "", WALKIE)
        _box(_kit, Vector3(0.018, 0.11, 0.018), Vector3(0.158, 0.05, -0.02), "", WALKIE)
        _box(_kit, Vector3(0.035, 0.07, 0.012), Vector3(-0.16, -0.06, -0.02), "", KEYS)
        _box(_kit, Vector3(0.028, 0.055, 0.012), Vector3(-0.165, -0.10, -0.008), "", KEYS)

        # --- the arms -------------------------------------------------------------------
        _arm_l = _pivot(_torso, Vector3(-0.31, 0.70, 0))
        _arm_r = _pivot(_torso, Vector3(0.31, 0.70, 0))
        for arm in [_arm_l, _arm_r]:
                _box(arm, Vector3(0.13, 0.34, 0.15), Vector3(0, -0.17, 0), "pi_sleeve")
        var elbow := Vector3(0, -0.34, 0)
        _fore_l = _pivot(_arm_l, elbow)
        _fore_r = _pivot(_arm_r, elbow)
        for fore in [_fore_l, _fore_r]:
                _box(fore, Vector3(0.11, 0.28, 0.13), Vector3(0, -0.14, 0), "pi_sleeve")
                # the mitten: a fist nearly as big as the arm it hangs on
                _box(fore, Vector3(0.15, 0.16, 0.14), Vector3(0, -0.37, 0.005), "pi_hand")
                for i in 4:                      # four fingers curling forward
                        var f := _pivot(fore, Vector3(-0.0475 + i * 0.031, -0.385, 0.052))
                        f.rotation.x = -0.45
                        _box(f, Vector3(0.026, 0.08, 0.046), Vector3.ZERO, "pi_hand")

        # --- the legs: high-waist wide slacks, chunky dark shoes ------------------------
        _leg_l = _pivot(_torso, Vector3(-0.115, 0.02, 0))
        _leg_r = _pivot(_torso, Vector3(0.115, 0.02, 0))
        for leg in [_leg_l, _leg_r]:
                _box(leg, Vector3(0.165, 0.42, 0.19), Vector3(0, -0.21, 0), "pi_slacks")
                _box(leg, Vector3(0.15, 0.38, 0.17), Vector3(0, -0.61, 0), "pi_slacks")
                _box(leg, Vector3(0.175, 0.11, 0.31), Vector3(0, -0.855, 0.045), "pi_boot")
                _box(leg, Vector3(0.15, 0.05, 0.11), Vector3(0, -0.885, -0.08), "pi_boot")

        # --- the head -------------------------------------------------------------------
        _head = _pivot(_torso, Vector3(0, 0.78, 0))
        # the neck plugs the skull into the shirt so a glance never opens a gap
        _box(_head, Vector3(0.14, 0.10, 0.14), Vector3(0, -0.06, 0), "pi_skin")
        _box(_head, Vector3(0.25, 0.26, 0.23), Vector3(0, 0.10, 0), "pi_face")
        # the nose and the heavy brow, proud of the face cell
        _box(_head, Vector3(0.04, 0.075, 0.045), Vector3(0, 0.045, 0.13), "pi_skin")
        _box(_head, Vector3(0.18, 0.04, 0.035), Vector3(0, 0.155, 0.105), "pi_skin", BROW_T)
        for ear in [-0.125, 0.125]:
                _box(_head, Vector3(0.02, 0.06, 0.05),
                                Vector3(ear, 0.10, 0.005), "pi_skin")
        # the hair, grizzled and swept back: a crown slab, a volume slab tipped
        # up at the front, a tail down the nape and side coverage over the ears
        var hair := _pivot(_head, Vector3.ZERO)
        hair.rotation.x = 0.03
        _box(hair, Vector3(0.27, 0.08, 0.25), Vector3(0, 0.255, -0.005), "pi_hair")
        var quiff := _box(hair, Vector3(0.26, 0.07, 0.11),
                        Vector3(0, 0.29, 0.04), "pi_hair")
        quiff.rotation.x = -0.08
        _box(hair, Vector3(0.26, 0.16, 0.06), Vector3(0, 0.175, -0.105), "pi_hair")
        for side in [-1.0, 1.0]:
                _box(hair, Vector3(0.025, 0.11, 0.17),
                                Vector3(side * 0.132, 0.20, -0.005), "pi_hair")
        # the beard: a gray chevron mustache drooping past the lip corners and
        # a chin beard under the jaw, real geometry so they read in profile
        for side in [-1.0, 1.0]:
                var mus := _box(_head, Vector3(0.055, 0.05, 0.03),
                                Vector3(side * 0.033, 0.008, 0.125), "pi_hair")
                mus.rotation.z = side * 0.15
                mus.rotation.x = 0.1
        _box(_head, Vector3(0.10, 0.055, 0.04), Vector3(0, -0.02, 0.105), "pi_hair")
        # the cigarette: a white rod drooping from the lip corner, an ember that
        # pulses on its own rhythm and flares in the walk's wind
        var cig := _pivot(_head, Vector3(0.065, 0.015, 0.128))
        cig.rotation.x = -0.12
        _box(cig, Vector3(0.022, 0.022, 0.095), Vector3(0, 0, 0.045), "", CIG)
        _ember = _box(cig, Vector3(0.022, 0.022, 0.022), Vector3(0, 0, 0.10), "", EMBER)
        var em := _ember.material_override as ShaderMaterial
        em.set_shader_parameter("glow", 0.85)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
        var p := Node3D.new()
        p.position = pos
        parent.add_child(p)
        return p


func _box(parent: Node3D, size: Vector3, pos: Vector3, tex := "", tint := Color.WHITE) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = size
        mi.mesh = mesh
        var m := ShaderMaterial.new()
        m.shader = MAT
        if tex != "":
                m.set_shader_parameter("textured", true)
                m.set_shader_parameter("tex", load("res://assets/tex/%s.png" % tex))
        m.set_shader_parameter("tint", tint)
        mi.material_override = m
        mi.position = pos
        parent.add_child(mi)
        return mi


func _physics_process(delta: float) -> void:
        var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
        var basis := Basis.IDENTITY
        if cam != null:
                basis = cam.global_basis
        var fwd := -basis.z
        fwd.y = 0.0
        var right := basis.x
        right.y = 0.0
        var wish := right * dir.x + fwd * -dir.y
        if wish.length() > 1.0:
                wish = wish.normalized()
        wish *= SPEED
        velocity.x = move_toward(velocity.x, wish.x, 30.0 * delta)
        velocity.z = move_toward(velocity.z, wish.z, 30.0 * delta)
        velocity.y = -4.0
        move_and_slide()
        _animate(delta)


func _animate(delta: float) -> void:
        var planar := Vector2(velocity.x, velocity.z)
        var speed := planar.length()
        var moving := speed > 0.4
        var frac := clampf(speed / SPEED, 0.0, 1.0)
        # two clocks: the stride advances with real speed so the feet never
        # slide, the breath keeps running underneath so idle is always alive
        _walk_t += delta * 9.5 * frac
        _idle_t += delta * 1.6
        # the walk <-> idle crossfade: quick to pick up, soft to settle
        _blend = _damp(_blend, 1.0 if moving else 0.0, 10.0 if moving else 6.0, delta)
        var amp := frac * _blend
        if moving:
                var prev := rotation.y
                rotation.y = lerp_angle(rotation.y, atan2(planar.x, planar.y), TURN * delta)
                var yaw_rate := wrapf(rotation.y - prev, -PI, PI) / maxf(delta, 0.0001)
                _lean = _damp(_lean, clampf(-yaw_rate * 0.06, -0.18, 0.18), 6.0, delta)
        else:
                _lean = _damp(_lean, 0.0, 6.0, delta)
        _fwd_lean = _damp(_fwd_lean, 0.07 * frac, 5.0, delta)
        var sw := sin(_walk_t)
        var breathe := sin(_idle_t * 1.3)
        var b := _blend
        # a foot plants on every beat flip: iron on boards, for the bus below
        if moving and is_on_floor():
                var half := 1 if sw >= 0.0 else -1
                if half != _step_sign:
                        _step_sign = half
                        footstep.emit()
        # the stride pose crossfaded with the idle settle - no snaps either way
        _leg_l.rotation.x = sw * 0.55 * amp
        _leg_r.rotation.x = -sw * 0.55 * amp
        _arm_l.rotation.x = -sw * 0.42 * amp
        _arm_r.rotation.x = sw * 0.42 * amp
        _arm_l.rotation.z = lerpf(0.05 + breathe * 0.02, 0.06, b)
        _arm_r.rotation.z = lerpf(-0.05 - breathe * 0.02, -0.06, b)
        # forearms: a bent elbow at rest, one that barely moves - the puppet read
        var bend := 0.14 + breathe * 0.02
        _fore_l.rotation.x = bend
        _fore_r.rotation.x = bend
        # torso: bob on the stride beat, breath at rest, bank and lean smoothed
        _torso.position.y = 0.92 + lerpf(breathe * 0.012, absf(cos(_walk_t)) * 0.05 * frac, b)
        _torso.rotation.z = sw * 0.04 * amp + _lean
        _torso.rotation.x = _fwd_lean
        # head: scans the office at rest, steady on the move, counter-rolls a
        # little so the hair stays level while the body banks
        _head.rotation.y = lerpf(sin(_idle_t * 0.35) * 0.35, sw * 0.05, b)
        _head.rotation.x = lerpf(breathe * 0.012, 0.03 * frac, b) - _fwd_lean * 0.6
        _head.rotation.z = -_torso.rotation.z * 0.55
        # coat tails: a damped spring chasing the stride kick - they overshoot
        # and settle on their own when he starts, stops, or swings around
        # (the shirt tail keeps the same spring, just lighter cloth)
        var tail_target := 0.06 + breathe * 0.015 * (1.0 - b) + (0.16 + sw * 0.07) * amp
        _tail_v += (tail_target - _tail_a) * 42.0 * delta
        _tail_v *= exp(-7.0 * delta)
        _tail_a += _tail_v * delta
        _tails.rotation.x = _tail_a
        _tails.rotation.z = _damp(_tails.rotation.z, _lean * 1.6, 5.0, delta)
        # the belt kit pendulums on the stride beat and banks with the turn
        if _kit != null:
                _kit.rotation.x = sw * 0.12 * amp + breathe * 0.015 * (1.0 - b)
                _kit.rotation.z = _damp(_kit.rotation.z, -_lean * 0.8, 5.0, delta)
        # the ember breathes on its own rhythm and flares a little in the wind
        if _ember != null:
                var em := _ember.material_override as ShaderMaterial
                em.set_shader_parameter("glow", 0.5 + sin(_idle_t * 2.7) * 0.15 + frac * 0.12)


func _damp(a: float, b: float, k: float, dt: float) -> float:
        # frame-rate independent exponential settle
        return lerpf(a, b, 1.0 - exp(-k * dt))
