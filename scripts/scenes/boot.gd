extends Control
## Açılış: autoload'lar (kayıt, bölüm kataloğu) hazır olduktan sonra menüye geçer.


func _ready() -> void:
	UiKit.build_screen(self)
	SceneRouter.goto_menu()
