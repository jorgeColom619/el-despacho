extends Node
## Capa de pagos intercambiable.
##
## El juego nunca debe conceder moneda premium sin una confirmación del proveedor de pagos.
## Proveedores previstos:
##   - "test":   modo de prueba. Simula la compra SIN realizar ningún cargo (desarrollo).
##   - "steam":  Steam microtransactions (Steamworks + extensión GodotSteam). La compra se
##               inicia con ISteamMicroTxn desde un servidor propio y Steam confirma con el
##               callback MicroTxnAuthorizationResponse. Requiere cuenta de Steamworks.
##   - "stripe": Stripe Checkout. El juego abre la URL de pago que devuelve un servidor propio
##               (que guarda la clave secreta de Stripe) y consulta después al servidor si el
##               pago se completó (webhook checkout.session.completed). Requiere cuenta de Stripe.
## Para activar un proveedor real basta con implementar _start_purchase() para él y cambiar
## PROVIDER. Nunca guardes claves secretas dentro del juego.

signal purchase_completed(product_id: String, receipt: Dictionary)
signal purchase_failed(product_id: String, reason: String)
signal purchase_started(product_id: String)

const PROVIDER := "test"
const SERVER_URL := ""


func is_test_mode() -> bool:
	return PROVIDER == "test"


func provider_name() -> String:
	match PROVIDER:
		"steam":
			return "Steam"
		"stripe":
			return "Stripe"
	return "Modo de prueba"


func buy(product_id: String) -> void:
	purchase_started.emit(product_id)
	_start_purchase(product_id)


func _start_purchase(product_id: String) -> void:
	match PROVIDER:
		"test":
			# Simulación local: no hay cargo real.
			await get_tree().create_timer(0.8).timeout
			var receipt := {"provider": "test", "product": product_id, "id": "TEST-%d" % Time.get_unix_time_from_system(), "date": Time.get_datetime_string_from_system()}
			purchase_completed.emit(product_id, receipt)
		_:
			purchase_failed.emit(product_id, "El proveedor de pagos «%s» todavía no está configurado." % PROVIDER)
