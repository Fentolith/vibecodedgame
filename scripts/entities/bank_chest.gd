extends StaticBody3D

func interact() -> void:
	GameManager.bank_opened.emit()
