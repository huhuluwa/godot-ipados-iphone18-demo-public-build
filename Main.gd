extends Control

var taps := 0

@onready var counter_label: Label = %Counter
@onready var status_label: Label = %Status

func _ready() -> void:
	get_viewport().size_changed.connect(_update_status)
	_update_status()

func _on_tap_pressed() -> void:
	taps += 1
	counter_label.text = str(taps)
	status_label.text = "触控已响应 · 第 %d 次" % taps

func _on_reset_pressed() -> void:
	taps = 0
	counter_label.text = "0"
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap_pressed()

func _update_status() -> void:
	var viewport_size := get_viewport_rect().size
	status_label.text = "Viewport %d × %d · Mobile renderer" % [viewport_size.x, viewport_size.y]

