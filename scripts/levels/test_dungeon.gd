extends Node3D

func _ready() -> void:
	$NavigationRegion3D.bake_navigation_mesh()
