extends Resource
class_name StatusEffect

# All times in seconds
const DEFINITIONS: Dictionary = {
	"cut": {
		display_name = "CUT",
		color        = Color(0.90, 0.20, 0.20),
		duration     = 10.0,
		tick_interval= 2.0,
		tick_damage  = 1,
		move_mult    = 1.0,
	},
	"deep_cut": {
		display_name = "DEEP CUT",
		color        = Color(0.75, 0.05, 0.05),
		duration     = 15.0,
		tick_interval= 1.5,
		tick_damage  = 3,
		move_mult    = 0.85,
	},
	"burning": {
		display_name = "BURNING",
		color        = Color(1.00, 0.45, 0.05),
		duration     = 8.0,
		tick_interval= 1.0,
		tick_damage  = 4,
		move_mult    = 1.0,
	},
	"poisoned": {
		display_name = "POISONED",
		color        = Color(0.35, 0.80, 0.20),
		duration     = 20.0,
		tick_interval= 2.0,
		tick_damage  = 2,
		move_mult    = 0.9,
	},
	"paralyzed": {
		display_name = "PARALYZED",
		color        = Color(0.60, 0.60, 1.00),
		duration     = 4.0,
		tick_interval= 0.0,
		tick_damage  = 0,
		move_mult    = 0.0,
	},
	"haste": {
		display_name = "HASTE",
		color        = Color(0.90, 0.90, 0.20),
		duration     = 10.0,
		tick_interval= 0.0,
		tick_damage  = 0,
		move_mult    = 1.5,
	},
}

var id:           String = ""
var display_name: String = ""
var color:        Color  = Color.WHITE
var duration:     float  = 0.0
var tick_interval:float  = 2.0
var tick_damage:  int    = 0
var move_mult:    float  = 1.0
var _tick_acc:    float  = 0.0

static func create(effect_id: String) -> StatusEffect:
	if not effect_id in DEFINITIONS:
		return null
	var def: Dictionary = DEFINITIONS[effect_id]
	var e := StatusEffect.new()
	e.id            = effect_id
	e.display_name  = def.display_name
	e.color         = def.color
	e.duration      = def.duration
	e.tick_interval = def.tick_interval
	e.tick_damage   = def.tick_damage
	e.move_mult     = def.move_mult
	return e

func tick(delta: float) -> int:
	duration -= delta
	if tick_interval <= 0.0 or tick_damage == 0:
		return 0
	_tick_acc += delta
	if _tick_acc >= tick_interval:
		_tick_acc -= tick_interval
		return tick_damage
	return 0

func is_expired() -> bool:
	return duration <= 0.0
