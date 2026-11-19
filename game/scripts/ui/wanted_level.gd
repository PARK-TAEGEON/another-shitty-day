extends RefCounted
## Wanted stars from hidden response heat. PROPOSED defaults, not a ledger change.
## Full stars land on the real dispatch thresholds 8 / 18 / 32 (guard, police, backup).
## A half star is the midpoint of the open stage, before the next service arrives.
## Nothing above backup police is reachable: the cap is 3.0 of the 5 drawn stars.

const CAP_HALVES: int = 6
const GUARD_HEAT: float = 8.0
const POLICE_HEAT: float = 18.0
const BACKUP_HEAT: float = 32.0

static func halves_for_heat(heat: float) -> int:
	if not is_finite(heat) or heat < GUARD_HEAT:
		return 0
	# 1.0 at the guard, then +0.5 at each stage midpoint, then +0.5 when the next service arrives.
	var halves: int = 2
	if heat >= (GUARD_HEAT + POLICE_HEAT) * 0.5:
		halves = 3
	if heat >= POLICE_HEAT:
		halves = 4
	if heat >= (POLICE_HEAT + BACKUP_HEAT) * 0.5:
		halves = 5
	if heat >= BACKUP_HEAT:
		halves = CAP_HALVES
	return halves

static func stars_for_heat(heat: float) -> float:
	return float(halves_for_heat(heat)) * 0.5
