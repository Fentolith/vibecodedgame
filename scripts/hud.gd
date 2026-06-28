extends CanvasLayer

@onready var health_bar: TextureProgressBar = $HealthOrb
@onready var mana_bar: TextureProgressBar = $ManaOrb
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var interact_label: Label = $InteractLabel

func _ready() -> void:
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_mana_changed.connect(_on_mana_changed)
	GameManager.player_stamina_changed.connect(_on_stamina_changed)
	interact_label.visible = false

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.value = (current / maximum) * 100.0

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.value = (current / maximum) * 100.0

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.value = (current / maximum) * 100.0

func show_interact_prompt(text: String) -> void:
	interact_label.text = "[F] " + text
	interact_label.visible = true

func hide_interact_prompt() -> void:
	interact_label.visible = false
