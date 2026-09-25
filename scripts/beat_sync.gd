class_name BeatSync

extends Node

signal beat

var target_nodes: Array[NodePath] = []
var audio_stream_player: AudioStreamPlayer = null
var music: AudioStream = null
var beat_data_path: String = ""
var beats: Array = []
var beat_index: int = 0

func _init(_audio_stream_player: AudioStreamPlayer, _music: AudioStream, _target_nodes: Array[NodePath]) -> void:
	if not _music:
		push_error("_music is NULL.")
		return
	
	if not _music.resource_path:
		push_error("_music.resource_path is NULL.")
		return
	
	if not FileAccess.open(_music.resource_path.split(".")[0] + ".json", FileAccess.READ):
		push_error("Beat data file not found at: %s" % _music.resource_path.split(".")[0] + ".json")
		return
	
	beat_data_path = _music.resource_path.split(".")[0] + ".json"
	music = _music
	target_nodes = _target_nodes
	audio_stream_player = _audio_stream_player

func _ready():
	reset()

func reset() -> void:
	var file = FileAccess.open(beat_data_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_DICTIONARY:
			beats = json["beats"]
	else:
		push_error("Beat data file not found at: %s" % beat_data_path)
		return
	
	if not audio_stream_player:
		push_error("No audio_stream_player")
		return
	
	beat_index = 0
	
	audio_stream_player.bus = "Music"
	audio_stream_player.stream = music

func _process(delta: float):
	if audio_stream_player:
		undo_pulse(delta)
		if audio_stream_player.stream:
			if not audio_stream_player.playing:
				audio_stream_player.play()
				beat_index = 0
				
			if audio_stream_player.playing:
				if beat_index >= beats.size():
					beat_index = 0
				
				var pos = audio_stream_player.get_playback_position()
				if pos >= beats[beat_index]:
					emit_signal("beat")
					beat_index += 1
					pulse()
		#Gm.last_beat_index = beat_index

func undo_pulse(delta: float) -> void:
	if target_nodes and not target_nodes.is_empty():
		for p in target_nodes:
			var node = get_node(p)
			node.pivot_offset = node.size / 2
			node.scale = node.scale.lerp(Vector2.ONE, delta * 4.0)
			node.modulate = node.modulate.lerp(Color.WHITE, delta * 4.0)

func pulse() -> void:
	if target_nodes and not target_nodes.is_empty():
		for p in target_nodes:
			var node = get_node(p)
			node.pivot_offset = (node.size * node.scale) / 2
			node.scale = Vector2.ONE * 2.0
			node.modulate = Color.CRIMSON
