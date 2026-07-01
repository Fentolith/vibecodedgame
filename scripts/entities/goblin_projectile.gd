extends Area3D

const SPEED:    float = 10.0
const LIFETIME: float = 3.0
const DAMAGE:   int   = 5

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
		if body.has_method("receive_hit"):
			body.receive_hit(DAMAGE, self)
		if randf() < 0.40 and body.has_method("apply_effect"):
			body.apply_effect("paralyzed")
		queue_free()
		return
	queue_free()
