# EmailVerificationDialog.gd
# Diálogo para usuarios con email sin verificar: reenviar el email o comprobar
# si ya se verificó. Se crea por código desde AuthManager (no necesita escena).
class_name EmailVerificationDialog
extends AcceptDialog

signal resend_requested()
signal check_requested()

const ACTION_RESEND := "resend"
const ACTION_CHECK := "check"

var _email: String = ""
var _resend_button: Button


func _init() -> void:
	title = "Verifica tu email"
	ok_button_text = "Cerrar"
	dialog_autowrap = true
	min_size = Vector2i(460, 0)
	_resend_button = add_button("Reenviar email", false, ACTION_RESEND)
	add_button("Ya lo verifiqué", false, ACTION_CHECK)
	custom_action.connect(_on_custom_action)


func show_for(email: String) -> void:
	_email = email
	_set_message("")
	_resend_button.disabled = false
	popup_centered()


func set_status(status: String) -> void:
	_set_message(status)


func set_resend_enabled(enabled: bool) -> void:
	_resend_button.disabled = not enabled


func _set_message(status: String) -> void:
	var text := "Tu cuenta todavía no tiene el email verificado. Hasta verificarlo no podrás abrir sobres, editar mazos ni jugar partidas."
	if _email != "":
		text += "\n\nTe enviamos un enlace a: %s" % _email
	text += "\nAbre el enlace del correo (revisa también la carpeta de spam) y luego pulsa \"Ya lo verifiqué\"."
	if status != "":
		text += "\n\n%s" % status
	dialog_text = text


func _on_custom_action(action: StringName) -> void:
	match action:
		ACTION_RESEND:
			resend_requested.emit()
		ACTION_CHECK:
			check_requested.emit()
