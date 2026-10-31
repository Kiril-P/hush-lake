extends Node
## Shared incremental core: one currency, upgrades with scaling costs, autosave.

signal currency_changed(amount: float)
signal upgrade_bought(id: String, level: int)

var currency: float = 0.0
var upgrades: Dictionary = {}  # id -> level

func add(amount: float) -> void:
	currency += amount
	currency_changed.emit(currency)

func level(id: String) -> int:
	return upgrades.get(id, 0)

func cost(id: String, base: float, growth: float = 1.15) -> float:
	return ceil(base * pow(growth, level(id)))

func try_buy(id: String, base: float, growth: float = 1.15) -> bool:
	var c := cost(id, base, growth)
	if currency < c:
		return false
	currency -= c
	upgrades[id] = level(id) + 1
	currency_changed.emit(currency)
	upgrade_bought.emit(id, upgrades[id])
	return true
