extends Area3D

const SPEED:    float = 24.0
const LIFETIME: float = 2.5
const DAMAGE:   int   = 8

var direction: Vector3 = Vector3.FORWARD
var _timer:    float   = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == GameManager.player_node:
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE, "ranged")
	queue_free()
