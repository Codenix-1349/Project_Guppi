extends Node

# Manages drone fabrication jobs

class Job:
	var drone_id: String
	var name: String
	var total_turns: int
	var remaining_turns: int
	
	func _init(id: String, drone_name: String, turns: int):
		drone_id = id
		name = drone_name
		total_turns = turns
		remaining_turns = turns

var slots = [null, null, null] # 3 Printer slots
var inventory = {} # drone_id -> count

signal printer_updated()
signal drone_fabricated(drone_id)

func _ready():
	# Starting fleet
	inventory["miner_v1"] = 2
	print("Printer Manager initialized with 2 starting Miners.")

func add_job(drone: Dictionary) -> Dictionary:
	# Find free slot
	var free_slot = -1
	for i in range(slots.size()):
		if slots[i] == null:
			free_slot = i
			break
			
	if free_slot == -1:
		return {"success": false, "message": "NO FREE PRINTER SLOTS!"}
			
	# Check costs dynamically
	var missing_resources = []
	for res in drone.cost:
		if Global.resources.get(res, 0) < drone.cost[res]:
			missing_resources.append(res.capitalize())
			
	if missing_resources.size() > 0:
		return {"success": false, "message": "INSUFFICIENT RESOURCES: " + ", ".join(missing_resources)}
	
	# Deduct costs
	for res in drone.cost:
		Global.resources[res] -= drone.cost[res]
	
	# Tier 1 drones take 2 turns (placeholder logic)
	slots[free_slot] = Job.new(drone.id, drone.name, 2)
	emit_signal("printer_updated")
	print("Started printing ", drone.name, " in slot ", free_slot)
	return {"success": true, "message": "STARTED PRINTING: " + drone.name.to_upper()}

func process_turn():
	for i in range(slots.size()):
		var job = slots[i]
		if job:
			job.remaining_turns -= 1
			if job.remaining_turns <= 0:
				_complete_job(i)
	
	emit_signal("printer_updated")

func _complete_job(slot_index: int):
	var job = slots[slot_index]
	var drone_id = job.drone_id
	
	if not inventory.has(drone_id):
		inventory[drone_id] = 0
	inventory[drone_id] += 1
	
	print("Fabrication complete: ", job.name)
	emit_signal("drone_fabricated", drone_id)
	slots[slot_index] = null

func get_job_progress(slot_index: int) -> float:
	var job = slots[slot_index]
	if not job: return 0.0
	return 1.0 - (float(job.remaining_turns) / float(job.total_turns))
