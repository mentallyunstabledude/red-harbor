extends Node3D
## Gait QA harness for the PI (run under xvfb, never headless).
## Walks him down a straight lane and measures how fast each sole slides
## over the floor while its stride phase is mid-stance - the window where a
## planted sole should be parked under the passing body. Any horizontal
## sole speed there is skate. The lens is locked on the walk axis
## (yaw = PI/2, due west of him) so the camera-relative wish never curves
## the lane, and W/S read off a fixed compass. Two legs:
##   level  - the plain lens pitch (0.22), the stride reference
##   pitch  - the lens cranked to CAM_PITCH_MAX (1.0), proving W speed no
##            longer dies when the camera looks steeply down
##   godot --path . --resolution 640x640 res://tests/gait_probe.tscn

const SETTLE := 40           # frames to reach full speed before a leg counts
const LEG_A := 120           # measured frames per leg (2 s of stride)
const WINDOW := 0.35         # mid-stance phase band, radians either side

const M1_START := SETTLE + 1
const M1_END := SETTLE + LEG_A
const M2_START := SETTLE * 2 + LEG_A + 1
const M2_END := M2_START + LEG_A - 1

var _office: Node3D
var _player: Pi
var _knee: Array = []
var _boot: Array = []
var _sole := [Vector3.ZERO, Vector3.ZERO]     # sole world pos, last frame
var _in_win := [false, false]                 # sole was in its phase window
var _drift := [0.0, 0.0]                      # skate path in-window, meters
var _time := [0.0, 0.0]                       # seconds spent in-window
var _cross := [false, false]                  # phase-crossing edge detect
var _steps := 0                               # stride cycles this leg
var _dist := 0.0                              # body travel this leg, meters
var _tick := 0
var _leg := 0                                 # 0 = level lens, 1 = steep pitch
var _leg0 := {}                               # snapshot of the level leg


func _ready() -> void:
        _office = (load("res://scenes/office.tscn") as PackedScene).instantiate()
        add_child(_office)
        await get_tree().process_frame
        await get_tree().process_frame
        _player = _office.get("_player")
        _office.set("_yaw", PI * 0.5)          # the lens parks due east of him
        Input.action_press("move_up")          # walk due west down the lane
        for knee in [_player.get("_knee_l"), _player.get("_knee_r")]:
                var boot: MeshInstance3D = null
                for c in knee.get_children():
                        if c is MeshInstance3D and (c.mesh as BoxMesh).size.z > 0.25:
                                boot = c
                _knee.append(knee)
                _boot.append(boot)
        print("GAIT: boots found l=%s r=%s" % [_boot[0] != null, _boot[1] != null])


func _physics_process(delta: float) -> void:
        _tick += 1
        if _tick > M2_END + 1:
                _report()
                return
        if _tick == SETTLE + LEG_A + 1:
                _leg0 = _snapshot()
                _flip_leg()
        if _tick == M2_START:
                _zero_leg()
        var measuring := (_tick >= M1_START and _tick <= M1_END) \
                        or (_tick >= M2_START and _tick <= M2_END)
        if not measuring:
                return
        var planar := Vector2(_player.velocity.x, _player.velocity.z)
        _dist += planar.length() * delta
        # stride phase: 0 = left sole mid-stance, PI = right sole mid-stance
        var ph: float = wrapf(_player.get("_walk_t"), 0.0, TAU)
        for edge in [0.0, PI]:
                var idx := 0 if edge == 0.0 else 1
                var crossed: bool = _cross[idx]
                var now := _near(ph, edge)
                if now and not crossed:
                        _steps += 1
                _cross[idx] = now
        if _tick % 40 == 0:
                var p := _player.position
                print("GAIT: tick=%d leg=%d pos=(%.1f, %.1f) speed=%.2f sole_y=(%.3f, %.3f)" % [
                                _tick, _leg, p.x, p.z, planar.length(),
                                _sole[0].y, _sole[1].y])
        for i in 2:
                var size: Vector3 = (_boot[i].mesh as BoxMesh).size
                var sole: Vector3 = _knee[i].global_transform * (
                                _boot[i].position + Vector3(0, -size.y * 0.5, 0))
                var win := _near(ph, 0.0) if i == 0 else _near(ph, PI)
                if win and _in_win[i]:
                        _drift[i] += Vector2(sole.x - _sole[i].x,
                                        sole.z - _sole[i].z).length()
                        _time[i] += delta
                _in_win[i] = win
                _sole[i] = sole


func _near(ph: float, center: float) -> bool:
        var d: float = absf(wrapf(ph - center + PI, 0.0, TAU) - PI)
        return d < WINDOW


func _flip_leg() -> void:
        # turn the lens up to its steepest downward pitch and walk back east
        # down the same lane; the settle window absorbs the about-face
        Input.action_release("move_up")
        Input.action_press("move_down")
        _office.set("_pitch", 1.0)
        _leg = 1


func _zero_leg() -> void:
        _dist = 0.0
        _drift = [0.0, 0.0]
        _time = [0.0, 0.0]
        _steps = 0
        _in_win = [false, false]


func _snapshot() -> Dictionary:
        var t: float = _time[0] + _time[1]
        return {
                "dist": _dist,
                "speed": _dist / (float(LEG_A) / 60.0),
                "skate": (_drift[0] + _drift[1]) / maxf(t, 1e-6),
                "cad": _steps / (float(LEG_A) / 60.0),
                "stride": _dist / maxf(_steps, 1),
        }


func _report() -> void:
        var leg1 := _snapshot()
        for leg in [_leg0, leg1]:
                if leg.is_empty():
                        print("GAIT: no data")
                        continue
                print("GAIT: lens=pitch%s speed=%.2f m/s (%.0f%% of level) mid-stance skate=%.3f m/s (%.1f%% of body speed) cad=%.2f steps/s stride=%.2f m" % [
                                "0.22" if leg == _leg0 else "1.0",
                                leg["speed"],
                                leg["speed"] / maxf(_leg0["speed"], 0.01) * 100.0,
                                leg["skate"],
                                leg["skate"] / maxf(_leg0["speed"], 0.01) * 100.0,
                                leg["cad"], leg["stride"]])
        get_tree().quit()
