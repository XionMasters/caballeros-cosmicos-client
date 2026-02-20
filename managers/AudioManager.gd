# AudioManager.gd
# Autoload singleton para manejar efectos de sonido
extends Node

# Audio players para diferentes tipos de sonidos
var sfx_player: AudioStreamPlayer

func _ready():
	# Crear player de efectos de sonido
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func play_card_draw():
	"""Sonido de robar carta"""
	# TODO: Cargar y reproducir sonido real
	_play_placeholder_sound(0.3, 800.0)

func play_card_place():
	"""Sonido de colocar carta"""
	_play_placeholder_sound(0.2, 600.0)

func play_card_drag():
	"""Sonido de arrastrar carta"""
	_play_placeholder_sound(0.1, 400.0)

func play_turn_change():
	"""Sonido de cambio de turno"""
	_play_placeholder_sound(0.4, 1000.0)

func play_cosmos_gain():
	"""Sonido de ganar cosmos"""
	_play_placeholder_sound(0.3, 1200.0)

func play_damage():
	"""Sonido de recibir daño"""
	_play_placeholder_sound(0.5, 300.0)

func _play_placeholder_sound(volume: float, _frequency: float):
	"""Genera un tono simple como placeholder hasta tener sonidos reales"""
	# Crear un generador de audio sintético simple
	var audio_stream = AudioStreamGenerator.new()
	audio_stream.mix_rate = 22050
	
	sfx_player.stream = audio_stream
	sfx_player.volume_db = linear_to_db(volume)
	sfx_player.play()
	
	# Programar detención después de 0.1 segundos
	await get_tree().create_timer(0.1).timeout
	if sfx_player.playing:
		sfx_player.stop()
