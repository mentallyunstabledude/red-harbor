extends Node3D
## The PI's office: a walkable diorama. One interaction for now - deal the
## next file at the steel door; the HUD keeps the case line. The room stays
## lean on purpose: the reading panels and the informant's phone are out
## until the stealth / roguelike / horror / espionage loop replaces them
## with mechanics that earn their keep. The HUD is terminal white on black
## bars, mono type throughout.
## Sound (K2a): a small honest bus - room tone bed, the fan loop riding the
## machine's speed, radio static on the radio cue, the shelf creak on the
## shelf drop, iron footsteps on the stride. No music, no mixer magic.

const PS1_VIEW := preload("res://scripts/comps/ps1_view.gd")
const ROOM := preload("res://scripts/office_room.gd")
const PAUSE_MENU := preload("res://scenes/pause_menu.tscn")
const GRAIN := preload("res://shaders/grain.gdshader")
const MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")

const SPAWN := Vector3(14.0, 0.1, 12.2)
const PIVOT := Vector3(0, 1.3, 0)       # the lens orbits the PI's chest
const CAM_DIST := 5.0
const CAM_PITCH_MIN := -0.45            # floor graze .. near the ceiling
const CAM_PITCH_MAX := 1.0
const CAM_MIN := Vector3(1.3, 0.5, 1.3)     # the lens stays in the office
const CAM_MAX := Vector3(26.7, 2.7, 15.45)
const LOOK_SENS := 0.0042
const REACH := 1.7
const SFX := "res://audio/"

# the one spot you can use for now, ON the door's body
const SPOTS := {
        "door": {"label": "DEAL THE NEXT CASE"},
}
const WHITE := Color("d8d2c4")
const GREY := Color("7e7d74")
const AMBER := Color("d0923c")
const RED := Color("b04a3a")

var deal_seed := -1              # >= 0 pins tonight's deal (tests / QA)
var _player: Pi
var _pause: CanvasLayer
var _hud: CanvasLayer
var _case_line: Label
var _prompt: Label
var _sub_bar: ColorRect
var _sub: Label
var _sub_t := 99.0
var _room: OfficeRoom
var _view: Ps1View
var _cam_pos: Vector3
var _yaw := 0.0
var _pitch := 0.22
var _snd_room: AudioStreamPlayer
var _snd_fan: AudioStreamPlayer
var _snd_radio: AudioStreamPlayer
var _snd_shelf: AudioStreamPlayer
var _snd_step: AudioStreamPlayer
var _steps: Array = []
var _step_rng := RandomNumberGenerator.new()
var qa_clock := -1.0            # >= 0 pins the room clock (QA captures:
                                # fan rotation and marker glow freeze in place)


func _ready() -> void:
        if deal_seed >= 0:
                Run.deal_case(deal_seed)
        else:
                Run.ensure_case()
        _build_world()
        _spawn_pi()
        _cam_pos = _cam_want()
        _view.camera.position = _cam_pos
        _view.camera.look_at(SPAWN + PIVOT)
        _build_hud()
        _pause = PAUSE_MENU.instantiate()
        add_child(_pause)
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        Ambient.begin_office()
        Ambient.ambient_line.connect(_on_line)
        Ambient.radio_cue.connect(_on_radio_cue)
        Ambient.shelf_drop.connect(_on_shelf_drop)
        _step_rng.seed = 47
        _build_sound()
        _player.footstep.connect(_on_footstep)


func _qa_time() -> float:
        # the room's machines run on the wall clock, or on the QA pin when
        # one is set, so reference captures come out identical every time
        return qa_clock if qa_clock >= 0.0 else Time.get_ticks_msec() / 1000.0


func _exit_tree() -> void:
        Ambient.end_office()
        # stop the bus before the players die: frees the mix playbacks, so a
        # scene change never strands a loop mid-breath
        for p in [_snd_room, _snd_fan, _snd_radio, _snd_shelf, _snd_step]:
                if p != null:
                        p.stop()


func _build_world() -> void:
        var env := WorldEnvironment.new()
        var e := Environment.new()
        e.background_mode = Environment.BG_COLOR
        e.background_color = Color(0.015, 0.02, 0.016)
        e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        e.ambient_light_sky_contribution = 0.0
        e.ambient_light_color = Color(0.30, 0.33, 0.30)
        e.ambient_light_energy = 4.0
        e.fog_enabled = true
        e.fog_light_color = Color(0.02, 0.025, 0.02)
        e.fog_density = 0.018
        env.environment = e
        # the cold heart: the hanging tube over the center
        var tube := OmniLight3D.new()
        tube.position = Vector3(14, 2.55, 8)
        tube.omni_range = 10.0
        tube.light_color = Color(0.72, 0.82, 0.68)
        tube.light_energy = 2.8
        add_child(tube)
        # the warm heart: the bulb over the desk
        var bulb := OmniLight3D.new()
        bulb.position = Vector3(14.2, 2.45, 9.5)
        bulb.omni_range = 7.0
        bulb.light_color = Color(1.0, 0.74, 0.42)
        bulb.light_energy = 2.6
        add_child(bulb)
        # the amber hatch over the door slot, and its pool on the steel
        var hatch := OmniLight3D.new()
        hatch.position = Vector3(26.6, 1.7, 8)
        hatch.omni_range = 3.5
        hatch.light_color = Color(0.9, 0.6, 0.3)
        hatch.light_energy = 1.6
        add_child(hatch)
        var door_pool := OmniLight3D.new()
        door_pool.position = Vector3(26.3, 1.4, 8)
        door_pool.omni_range = 2.6
        door_pool.light_color = Color(0.85, 0.62, 0.34)
        door_pool.light_energy = 1.9
        add_child(door_pool)
        # the cold city at the panes
        for wx in [18.5, 22.5]:
                var pane := OmniLight3D.new()
                pane.position = Vector3(wx, 1.9, 2.3)
                pane.omni_range = 6.0
                pane.light_color = Color(0.45, 0.56, 0.82)
                pane.light_energy = 0.9
                add_child(pane)
        # the floor lamp by the chair
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(19.0, 1.9, 14.3)
        lamp.omni_range = 5.0
        lamp.light_color = Color(1.0, 0.78, 0.5)
        lamp.light_energy = 0.8
        add_child(lamp)
        # a small pool where the work is: the file bank
        var bank := OmniLight3D.new()
        bank.position = Vector3(1.8, 1.7, 4.5)
        bank.omni_range = 4.0
        bank.light_color = Color(0.55, 0.6, 0.55)
        bank.light_energy = 0.5
        add_child(bank)
        _view = PS1_VIEW.new()
        add_child(_view)
        _view.tube().add_child(env)        # the tube owns the environment
        _room = ROOM.new()
        add_child(_room)


func _spawn_pi() -> void:
        _player = Pi.new()
        add_child(_player)
        _player.position = SPAWN
        _player.rotation.y = PI            # he faces the desk, lens behind
        _player.cam = _view.camera


func _process(delta: float) -> void:
        if is_instance_valid(_pause) and not _pause.open \
                        and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        var room_t := _qa_time()
        _room.pulse_markers(room_t)
        # the fan bus rides the machine: pitch and level follow the speed,
        # and the stall is allowed to be silent for a breath
        if _snd_fan != null:
                var sp: float = _room.fan_speed
                if sp > 0.04:
                        if not _snd_fan.playing:
                                _snd_fan.play()
                        _snd_fan.pitch_scale = 0.62 + 0.5 * sp
                        _snd_fan.volume_db = lerpf(-16.0, -7.0, sp)
                elif _snd_fan.playing:
                        _snd_fan.stop()
        # the subtitle strip fades after its line has had its moment
        if _sub_t < 6.0:
                _sub_t += delta
                _sub_bar.modulate.a = clampf(2.0 - _sub_t, 0.0, 1.0)
        _update_prompt()
        _follow_cam()


func _orbit_off() -> Vector3:
        # the lens rides a sphere around the PI: yaw spins the compass, pitch
        # lifts it from a floor graze up under the ceiling
        return Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))


func _in_room(p: Vector3) -> bool:
        return p.x > CAM_MIN.x and p.x < CAM_MAX.x and p.y > CAM_MIN.y \
                        and p.y < CAM_MAX.y and p.z > CAM_MIN.z and p.z < CAM_MAX.z


func _cam_want() -> Vector3:
        # the orbit pivot rides the PI's chest; the offset walks in until the
        # camera is inside the office, then a ray to the walls and props pulls
        # it further in, so the lens never ends up inside a solid box
        var pivot: Vector3 = _player.position + PIVOT
        var t := 1.0
        while t > 0.18 and not _in_room(pivot + _orbit_off() * (CAM_DIST * t)):
                t -= 0.05
        var want := pivot + _orbit_off() * (CAM_DIST * t)
        var space := get_world_3d().direct_space_state
        var q := PhysicsRayQueryParameters3D.create(
                        pivot, want, 1, [_player.get_rid()])
        var hit := space.intersect_ray(q)
        if hit:
                want = hit["position"] + (pivot - want).normalized() * 0.3
        return want


func _follow_cam() -> void:
        # A mouse-orbited third person: the lens swings all the way around the
        # PI and pulls in near the walls, and the drift quantizes so the frame
        # jitters the PS1 way. His body steps aside when the lens closes in.
        var want := _cam_want()
        want.x = clampf(want.x, CAM_MIN.x, CAM_MAX.x)
        want.y = clampf(want.y, CAM_MIN.y, CAM_MAX.y)
        want.z = clampf(want.z, CAM_MIN.z, CAM_MAX.z)
        _cam_pos = _cam_pos.lerp(want, 0.16)
        _view.camera.position = _cam_pos.snapped(Vector3(0.03, 0.03, 0.03))
        _view.camera.look_at(_player.position + PIVOT)
        _player.visible = _view.camera.position.distance_to(
                        _player.position + PIVOT) > 1.35


# --- the sound -----------------------------------------------------------------------

func _build_sound() -> void:
        # the beds and the cues; everything here was written by gen_sfx.py
        _snd_room = _speaker(_looped(SFX + "room_tone.wav"), -8.0)
        _snd_room.play()
        _snd_fan = _speaker(_looped(SFX + "fan_loop.wav"), -7.0)
        _snd_radio = _speaker(load(SFX + "radio_static.wav"), -4.0)
        _snd_shelf = _speaker(load(SFX + "shelf_creak.wav"), -3.0)
        _snd_step = _speaker(null, -7.0)
        for i in [1, 2, 3]:
                _steps.append(load(SFX + "footstep_iron_%d.wav" % i))


func _speaker(stream: AudioStream, db: float) -> AudioStreamPlayer:
        var p := AudioStreamPlayer.new()
        p.stream = stream
        p.volume_db = db
        add_child(p)
        return p


func _looped(path: String) -> AudioStreamWAV:
        var s: AudioStreamWAV = load(path)
        s.loop_mode = AudioStreamWAV.LOOP_FORWARD
        s.loop_begin = 0
        s.loop_end = s.data.size() / 2        # 16-bit mono frames
        return s


func _on_radio_cue() -> void:
        _snd_radio.pitch_scale = _step_rng.randf_range(0.9, 1.15)
        _snd_radio.play()


func _on_shelf_drop() -> void:
        _snd_shelf.pitch_scale = _step_rng.randf_range(0.92, 1.08)
        _snd_shelf.play()


func _on_footstep() -> void:
        _snd_step.stream = _steps[_step_rng.randi_range(0, _steps.size() - 1)]
        _snd_step.pitch_scale = _step_rng.randf_range(0.94, 1.06)
        _snd_step.play()


# --- the HUD ------------------------------------------------------------------------

func _build_hud() -> void:
        _hud = CanvasLayer.new()
        _hud.layer = 2
        add_child(_hud)
        var root := Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _hud.add_child(root)

        # the terminal bars: black strips, white mono type, like the subs
        _bar(root, Vector2(0, 0), Vector2(640, 20))
        _mlbl(root, Vector2(8, 4), 300, 9, "RED HARBOR - ROOM 407", WHITE)
        _mlbl(root, Vector2(340, 4), 292, 9, "23:47 - FOG ON THE GLASS", GREY,
                        HORIZONTAL_ALIGNMENT_RIGHT)
        _bar(root, Vector2(0, 330), Vector2(640, 30))
        _case_line = _mlbl(root, Vector2(8, 336), 420, 9, "", WHITE)
        _mlbl(root, Vector2(430, 336), 202, 9, "WASD WALK - E USE - ESC PAUSE", GREY,
                        HORIZONTAL_ALIGNMENT_RIGHT)
        _refresh_case_line()
        # the subtitle strip: ambient lines land here and fade
        _sub_bar = _bar(root, Vector2(60, 288), Vector2(520, 26))
        _sub_bar.modulate.a = 0.0
        _sub = _mlbl(_sub_bar, Vector2(8, 6), 504, 9, "", WHITE,
                        HORIZONTAL_ALIGNMENT_CENTER)
        _prompt = _mlbl(root, Vector2(0, 258), 640, 11, "", AMBER,
                        HORIZONTAL_ALIGNMENT_CENTER)
        _add_grain()


func _bar(parent: Control, pos: Vector2, size: Vector2) -> ColorRect:
        var b := ColorRect.new()
        b.position = pos
        b.size = size
        b.color = Color(0.02, 0.02, 0.02, 0.92)
        b.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(b)
        return b


func _mlbl(parent: Control, pos: Vector2, width: float, size: int,
                msg: String, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
        var l := Label.new()
        l.position = pos
        l.size = Vector2(width, size + 8)
        l.text = msg
        l.horizontal_alignment = align as HorizontalAlignment
        l.add_theme_font_override("font", MONO)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", color)
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(l)
        return l


func _refresh_case_line() -> void:
        var c: Dictionary = Run.case
        if c.is_empty():
                _case_line.text = "NO FILE ON THE DESK"
        else:
                _case_line.text = "CASE %s - %s - %s" % [c["no"], c["title"], c["district"]]


func _on_line(text: String) -> void:
        _flash_sub(text)


func _flash_sub(text: String) -> void:
        _sub.text = text
        _sub_t = 0.0
        _sub_bar.modulate.a = 1.0


func _add_grain() -> void:
        # animated film grain above the tube
        var layer := CanvasLayer.new()
        layer.layer = 60
        add_child(layer)
        var grain := ColorRect.new()
        grain.set_anchors_preset(Control.PRESET_FULL_RECT)
        grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var mat := ShaderMaterial.new()
        mat.shader = GRAIN
        mat.set_shader_parameter("vignette", 0.0)
        grain.material = mat
        layer.add_child(grain)


func _update_prompt() -> void:
        var near := _near_spot()
        _prompt.text = "" if near == "" else "[E] %s" % SPOTS[near]["label"]
        _prompt.add_theme_color_override("font_color", RED)


func _near_spot() -> String:
        if _player == null:
                return ""
        for key in SPOTS:
                if _player.position.distance_to(_room.spot(key)) <= REACH:
                        return key
        return ""


# --- the door ------------------------------------------------------------------------

func deal_next_case() -> bool:
        # The steel door: close this file, deal the next one from the bag.
        Run.deal_case()
        _refresh_case_line()
        return true


# --- input --------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
        if _player != null and Input.is_action_just_pressed("interact") \
                        and _near_spot() == "door":
                deal_next_case()


func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventMouseMotion:
                # the free look: yaw spins the compass, pitch lifts the lens
                if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                        _yaw = wrapf(_yaw - event.relative.x * LOOK_SENS, -PI, PI)
                        _pitch = clampf(_pitch + event.relative.y * LOOK_SENS,
                                        CAM_PITCH_MIN, CAM_PITCH_MAX)
                return
        # Esc: hand the room to the pause menu.
        if event.is_action_pressed("pause"):
                get_viewport().set_input_as_handled()
                _pause.open_menu()
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
