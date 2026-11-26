extends Node
## AmbientEvents — autoload "Ambient".
## Fires timed events inside the office to make it feel alive between
## deals: the radio crackles with static and a one-liner, fog presses at
## the window, something falls off the shelves. Each event modifies
## nothing — it is pure atmosphere, and none of it asks you to act.
##
## The office scene connects to ambient_line / shelf_drop and can play
## sfx from there; this node only manages timers and state.

signal ambient_line(text: String)   # one-liner from the radio or city outside
signal radio_cue                    # the state radio crackles - static sfx
signal shelf_drop                   # a small creak and slide sfx

const AMBIENT_MIN := 10.0
const AMBIENT_MAX := 30.0

# Radio one-liners and city sounds that filter through the window.
const RADIO_LINES := [
        "...AND THE WEATHER SERVICE FORECASTS CONTINUED FOG THROUGH THE WEEK...",
        "...TONIGHT'S PROGRAMME IS BROUGHT TO YOU BY THE MINISTRY OF LIGHT INDUSTRY...",
        "...WE REMIND CITIZENS THAT CURFEW HOURS REMAIN IN EFFECT AFTER 23:00...",
        "...REQUESTS FOR TRAVEL PERMITS MUST BE FILED NO LATER THAN FOURTEEN DAYS IN ADVANCE...",
        "...THE BUREAU CONFIRMS: ALL IS NORMAL. ALL IS WELL...",
        "...STATIC... STATIC... ...A PIANO PLAYS SOMETHING THAT SOUNDS LIKE A LULLABY...",
        "...YOU'RE LISTENING TO STATE RADIO, THE VOICE OF THE CITY...",
        "...THE PORT ANNOUNCES REVISED SHIPPING LANES EFFECTIVE IMMEDIATELY...",
        "...TONIGHT: A PERFORMANCE OF THE THIRD SYMPHONY, APPROVED FOR BROADCAST...",
        "...CRACKLE... ...SILENCE... ...CRACKLE...",
]

const CITY_LINES := [
        "A TRAM GROANS PAST OUTSIDE.",
        "SOMEWHERE BELOW, A DOOR SLAMS.",
        "FOG PRESSES UP AGAINST THE GLASS.",
        "THE BUILDING SETTLES. OLD IRON.",
        "A SIREN, FAR AWAY. THEN NOTHING.",
        "FOOTSTEPS IN THE HALL. THEY PASS.",
        "THE RADIATOR CLICKS AND TICKS.",
        "A CAR IDLES IN THE STREET. THEN LEAVES.",
]

var _rng := RandomNumberGenerator.new()
var _ambient_timer: SceneTreeTimer
var _office_active := false


func _ready() -> void:
        _rng.randomize()


# --- called by the office scene when the player enters / exits ------------------

func begin_office() -> void:
        _office_active = true
        _schedule_ambient()


func end_office() -> void:
        _office_active = false
        # timers expire naturally; we just stop reacting to them


# --- ambient one-liners --------------------------------------------------------

func _schedule_ambient() -> void:
        if not _office_active:
                return
        var wait := _rng.randf_range(AMBIENT_MIN, AMBIENT_MAX)
        _ambient_timer = get_tree().create_timer(wait)
        _ambient_timer.timeout.connect(_on_ambient_time, CONNECT_ONE_SHOT)


func _on_ambient_time() -> void:
        if not _office_active:
                return
        var roll := _rng.randf()
        if roll < 0.40:
                ambient_line.emit(RADIO_LINES[_rng.randi_range(0, RADIO_LINES.size() - 1)])
                radio_cue.emit()
        elif roll < 0.80:
                ambient_line.emit(CITY_LINES[_rng.randi_range(0, CITY_LINES.size() - 1)])
        else:
                shelf_drop.emit()
        _schedule_ambient()
