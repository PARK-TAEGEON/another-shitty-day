extends RefCounted
## One round's fictional social-loss assessment. Costs never drive response logic.
## A cumulative amount is supplied per target/category; only its increase is booked.

const CATEGORIES: Array[String] = ["property", "care", "work", "response"]
const RECORD_SECTION: String = "records"
const RECORD_KEY: String = "social_damage_usd_v1"

var _assessments: Dictionary = {}
var _totals: Dictionary = {"property": 0, "care": 0, "work": 0, "response": 0}
var _total: int = 0
var _frozen: bool = false

func assess(target_id: String, category: String, cumulative_amount: int) -> int:
	if _frozen or target_id.is_empty() or not CATEGORIES.has(category) or cumulative_amount < 0:
		return 0
	# Nested dictionaries avoid accidental collisions between target and category names.
	var targets: Dictionary = _assessments.get(category, {})
	var booked: int = int(targets.get(target_id, 0))
	var increase: int = maxi(0, cumulative_amount - booked)
	if increase == 0:
		return 0
	targets[target_id] = cumulative_amount
	_assessments[category] = targets
	_totals[category] = int(_totals[category]) + increase
	_total += increase
	return increase

func total() -> int:
	return _total

func breakdown() -> Dictionary:
	# The result screen receives a copy, never a mutable reference to the ledger.
	return _totals.duplicate(true)

func assessed(target_id: String, category: String) -> int:
	var targets: Dictionary = _assessments.get(category, {})
	return int(targets.get(target_id, 0))

func freeze() -> void:
	_frozen = true

func is_frozen() -> bool:
	return _frozen

func reset() -> void:
	_assessments.clear()
	_totals = {"property": 0, "care": 0, "work": 0, "response": 0}
	_total = 0
	_frozen = false

static func format_currency(amount: int) -> String:
	var digits: String = str(maxi(0, amount))
	var grouped: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			grouped += ","
		grouped += digits[index]
	return "$" + grouped
