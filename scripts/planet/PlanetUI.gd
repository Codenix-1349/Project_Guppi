extends Control

signal build_requested(building_id: String)

@onready var container = $Panel/VBoxContainer

func _ready() -> void:
	# Clear existing (if any)
	for c in container.get_children():
		c.queue_free()
		
	# Populate Buttons from BuildingData
	for id in BuildingData.get_all_ids():
		var data = BuildingData.get_building(id)
		var btn = Button.new()
		btn.text = data.name + " (" + str(data.cost.iron) + " Fe)"
		btn.pressed.connect(func(): _on_build_pressed(id))
		container.add_child(btn)

func _on_build_pressed(id: String) -> void:
	emit_signal("build_requested", id)
