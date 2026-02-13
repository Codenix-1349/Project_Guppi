extends AudioStreamPlayer

@export var music_dir: String = "res://assets/gamemusic"
@export var allowed_ext: PackedStringArray = ["ogg", "mp3", "wav"]

var _streams: Array[AudioStream] = []
var _order: Array[int] = []
var _pos: int = 0

func _ready() -> void:
	randomize()
	_load_folder_streams()

	if _streams.is_empty():
		push_warning("Keine Musik gefunden in: %s" % music_dir)
		return

	_shuffle_new_round()
	finished.connect(_on_finished)
	_play_current()

func _load_folder_streams() -> void:
	_streams.clear()

	var dir := DirAccess.open(music_dir)
	if dir == null:
		push_warning("Ordner nicht gefunden: %s" % music_dir)
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var ext := file.get_extension().to_lower()
			if allowed_ext.has(ext):
				var path := music_dir.path_join(file)
				var res := load(path)
				if res is AudioStream:
					_streams.append(res)
		file = dir.get_next()
	dir.list_dir_end()

func _shuffle_new_round() -> void:
	_order.clear()
	for i in range(_streams.size()):
		_order.append(i)
	_order.shuffle()
	_pos = 0

func _play_current() -> void:
	stream = _streams[_order[_pos]]
	play()

func _on_finished() -> void:
	_pos += 1
	if _pos >= _order.size():
		_shuffle_new_round()
	_play_current()
