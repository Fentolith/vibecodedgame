extends StaticBody3D

func interact() -> void:
	var p: Node = GameManager.player_node
	if p:
		GameManager.player_health  = p.health
		GameManager.player_mana    = p.mana
		GameManager.player_stamina = p.stamina
		GameManager.player_hunger  = p.hunger
		GameManager.player_thirst  = p.thirst
	GameManager.current_floor += 1
	get_tree().change_scene_to_file("res://scenes/levels/dungeon.tscn")
