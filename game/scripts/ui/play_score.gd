extends RefCounted
## Action score kept apart from the dollar ledger. PROPOSED flat defaults.
## No time accrual and no multiplier is applied to Social Damage.

const HIT_POINTS: int = 100
const THROW_POINTS: int = 200
const KNOCKDOWN_BONUS: int = 400
const CHAIN_BONUS: int = 50
const CHAIN_WINDOW: float = 2.0
const STAGE_POINTS: Dictionary = {2: 400, 3: 800, 4: 1200}

var total: int = 0
var _chain: int = 0
var _last_hit_at: float = -100.0

func award_hit(kind: String, now: float) -> int:
	var gain: int = THROW_POINTS if kind == "THROW" else HIT_POINTS
	if _chain > 0 and now - _last_hit_at <= CHAIN_WINDOW:
		_chain += 1
		gain += CHAIN_BONUS
	else:
		_chain = 1
	_last_hit_at = now
	total += gain
	return gain

func award_knockdown() -> int:
	# The hit itself is already scored. This bonus makes one clean knockdown worth 500.
	total += KNOCKDOWN_BONUS
	return KNOCKDOWN_BONUS

func award_stage(phase: int) -> int:
	var gain: int = int(STAGE_POINTS.get(phase, 0))
	if gain <= 0:
		return 0
	total += gain
	return gain

func reset() -> void:
	total = 0
	_chain = 0
	_last_hit_at = -100.0

static func format_points(amount: int) -> String:
	var negative: bool = amount < 0
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	return ("-" + grouped) if negative else grouped
