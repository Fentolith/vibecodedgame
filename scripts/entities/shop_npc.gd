extends StaticBody3D

func interact() -> void:
	GameManager.shop_opened.emit()
