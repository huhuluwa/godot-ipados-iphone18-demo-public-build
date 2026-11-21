extends Control

const ORIENTATION_NAMES := {
	DisplayServer.SCREEN_LANDSCAPE: "Landscape",
	DisplayServer.SCREEN_PORTRAIT: "Portrait",
	DisplayServer.SCREEN_REVERSE_LANDSCAPE: "Reverse landscape",
	DisplayServer.SCREEN_REVERSE_PORTRAIT: "Reverse portrait",
	DisplayServer.SCREEN_SENSOR_LANDSCAPE: "Sensor landscape",
	DisplayServer.SCREEN_SENSOR_PORTRAIT: "Sensor portrait",
	DisplayServer.SCREEN_SENSOR: "Sensor"
}

var taps := 0
var active_touches: Dictionary = {}
var last_gesture := "等待触摸"
var last_pinch_distance := 0.0
var lifecycle_status := "运行中"

@onready var counter_label: Label = %Counter
@onready var status_label: Label = %Status
@onready var touch_label: Label = %TouchMetrics
@onready var device_label: Label = %DeviceMetrics
@onready var lifecycle_label: Label = %LifecycleMetrics
@onready var margin_container: MarginContainer = %SafeMargins

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update_status)
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.orientation_changed.connect(_on_orientation_changed)
	_update_status()

func _process(_delta: float) -> void:
	_update_metrics()
	queue_redraw()

func _draw() -> void:
	for touch_position in active_touches.values():
		draw_circle(touch_position, 28.0, Color(0.25, 0.75, 1.0, 0.25))
		draw_arc(touch_position, 28.0, 0.0, TAU, 32, Color(0.35, 0.85, 1.0, 0.9), 3.0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			last_gesture = "按下触点 %d" % event.index
		else:
			active_touches.erase(event.index)
			last_gesture = "抬起触点 %d" % event.index
		_update_metrics()
	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		last_gesture = "拖动触点 %d · %.0f, %.0f" % [event.index, event.position.x, event.position.y]
		_update_pinch_distance()
		_update_metrics()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_tap_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		lifecycle_status = "已暂停 · 已收到 iOS 生命周期通知"
		_update_metrics()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		lifecycle_status = "已恢复 · iOS 生命周期通知正常"
		_update_metrics()

func _on_tap_pressed() -> void:
	taps += 1
	counter_label.text = str(taps)
	status_label.text = "触控已响应 · 第 %d 次" % taps
	Input.vibrate_handheld(20, 0.35)

func _on_reset_pressed() -> void:
	taps = 0
	last_gesture = "已重置"
	last_pinch_distance = 0.0
	counter_label.text = "0"
	_update_status()

func _on_haptic_pressed() -> void:
	Input.vibrate_handheld(70, 0.7)
	status_label.text = "已请求设备触觉反馈"

func _on_text_changed(new_text: String) -> void:
	status_label.text = "键盘输入已更新 · %d 个字符" % new_text.length()

func _on_orientation_changed(_orientation: DisplayServer.ScreenOrientation) -> void:
	_update_status()

func _update_pinch_distance() -> void:
	if active_touches.size() < 2:
		return
	var positions := active_touches.values()
	last_pinch_distance = positions[0].distance_to(positions[1])
	last_gesture = "双指捏合距离 %.0f px" % last_pinch_distance

func _update_metrics() -> void:
	touch_label.text = "触点 %d · %s" % [active_touches.size(), last_gesture]
	lifecycle_label.text = "%s · FPS %d" % [lifecycle_status, Engine.get_frames_per_second()]

func _update_status() -> void:
	var viewport_size := get_viewport_rect().size
	var orientation := DisplayServer.screen_get_orientation()
	var orientation_name: String = ORIENTATION_NAMES.get(orientation, "Unknown")
	var safe_area := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	if safe_area.size.x > 0 and screen_size.x > 0:
		var scale := Vector2(viewport_size.x / float(screen_size.x), viewport_size.y / float(screen_size.y))
		margin_container.add_theme_constant_override("margin_left", maxi(24, int(safe_area.position.x * scale.x)))
		margin_container.add_theme_constant_override("margin_top", maxi(24, int(safe_area.position.y * scale.y)))
		var right_inset := int((screen_size.x - safe_area.end.x) * scale.x)
		var bottom_inset := int((screen_size.y - safe_area.end.y) * scale.y)
		margin_container.add_theme_constant_override("margin_right", maxi(24, right_inset))
		margin_container.add_theme_constant_override("margin_bottom", maxi(24, bottom_inset))
	else:
		margin_container.add_theme_constant_override("margin_left", 24)
		margin_container.add_theme_constant_override("margin_top", 24)
		margin_container.add_theme_constant_override("margin_right", 24)
		margin_container.add_theme_constant_override("margin_bottom", 24)
	status_label.text = "Viewport %d × %d · %s · Mobile renderer" % [viewport_size.x, viewport_size.y, orientation_name]
	device_label.text = "屏幕 %d × %d · 安全区 %d,%d %d×%d" % [screen_size.x, screen_size.y, safe_area.position.x, safe_area.position.y, safe_area.size.x, safe_area.size.y]
	_update_metrics()

