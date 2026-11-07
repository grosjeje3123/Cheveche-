class_name Week
extends RefCounted
## Calendrier de la semaine, du lundi au dimanche. Tout se calcule sur des dates du calendrier
## (jour, mois, année) : aucun fuseau horaire ni changement d'heure à gérer.

const DAY_LETTERS := ["L", "M", "M", "J", "V", "S", "D"]
const DAY_NAMES := ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
const MONTHS_SHORT := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]


## Clé de tri et de sauvegarde d'un jour : « 2026-11-03 ».
static func key(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


## L'inverse de key() : « 2026-11-03 » donne {year: 2026, month: 11, day: 3}.
static func from_key(text: String) -> Dictionary:
	var p := text.split("-")
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}


static func today() -> Dictionary:
	return Time.get_date_dict_from_system()


static func today_key() -> String:
	return key(today())


static func is_key(text: String) -> bool:
	return RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(text) != null


# Midi, en secondes depuis 1970, pour une date du calendrier (le même calcul dans les deux sens).
static func _unix(date: Dictionary) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": int(date["year"]), "month": int(date["month"]),
			"day": int(date["day"]), "hour": 12, "minute": 0, "second": 0})


## La date `days` jours plus tard (ou plus tôt si négatif).
static func shifted(date: Dictionary, days: int) -> Dictionary:
	return Time.get_date_dict_from_unix_time(_unix(date) + days * 86400)


## 0 = lundi … 6 = dimanche.
static func weekday_index(date: Dictionary) -> int:
	return (int(Time.get_date_dict_from_unix_time(_unix(date))["weekday"]) + 6) % 7


static func monday_of(date: Dictionary) -> Dictionary:
	return shifted(date, -weekday_index(date))


## Les sept dates, du lundi au dimanche, de la semaine qui contient `date`.
static func days_of(date: Dictionary) -> Array:
	var monday := monday_of(date)
	var out: Array = []
	for i in 7:
		out.append(shifted(monday, i))
	return out


## « 2 – 8 nov. » ou « 26 oct. – 1 nov. ».
static func range_label(date: Dictionary) -> String:
	var days := days_of(date)
	var a: Dictionary = days[0]
	var b: Dictionary = days[6]
	if int(a["month"]) == int(b["month"]):
		return "%d – %d %s" % [int(a["day"]), int(b["day"]), MONTHS_SHORT[int(b["month"]) - 1]]
	return "%d %s – %d %s" % [int(a["day"]), MONTHS_SHORT[int(a["month"]) - 1],
			int(b["day"]), MONTHS_SHORT[int(b["month"]) - 1]]
