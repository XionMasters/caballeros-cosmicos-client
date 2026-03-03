# PvPMatch.gd
# Modo partida jugador vs jugador real (online).
# Extiende GameMatch con comportamiento específico de PvP.
#
# Diferencias respecto a TestMatch:
#   · El rival es un jugador humano — sus cartas son siempre dorsos
#   · En el futuro: reconexión, timeouts, emotes, chat

class_name PvPMatch
extends GameMatch

# _on_phase_changed heredado de GameMatch es suficiente para PvP.
# Añadir overrides aquí cuando sean necesarios.
