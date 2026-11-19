extends RefCounted
## One-round newspaper sentences from events that actually occurred.

var downed: Array[String] = []
var interrupted: Array[String] = []
var dispatches: Array[String] = []

func reset() -> void:
	downed.clear()
	interrupted.clear()
	dispatches.clear()

func note_label(label: String) -> void:
	if label.ends_with(" 치료·수습"):
		_remember(downed, label.trim_suffix(" 치료·수습"))
	elif label.ends_with(" 업무 중단"):
		_remember(interrupted, label.trim_suffix(" 업무 중단"))
	elif label.ends_with(" 업무 복귀 불가"):
		_remember(interrupted, label.trim_suffix(" 업무 복귀 불가"))

func note_phase(phase: int) -> void:
	var line: String = ""
	if phase == 2:
		line = "사내 경비가 출동했다"
	elif phase == 3:
		line = "경찰이 출동했다"
	elif phase == 4:
		line = "지원 경찰이 합류했다"
	if not line.is_empty() and not dispatches.has(line):
		dispatches.append(line)

func headline() -> String:
	if downed.is_empty():
		return "운영지원팀 사무실에서 소동"
	return "사무실 난동, %s 쓰러져" % downed[0]

func subhead() -> String:
	if dispatches.is_empty():
		return "큰 출동 없이 마무리된 하루"
	if dispatches.size() >= 3:
		return "지원 경찰까지 합류… 운영지원팀 업무 중단"
	if dispatches.size() == 2:
		return "경찰 출동… 운영지원팀에서 소동"
	return "사내 경비, 현장에서 대응"

func article(total_text: String) -> String:
	var bits: PackedStringArray = PackedStringArray()
	bits.append("[운영지원팀=본지] 이날 본사 운영지원팀 사무실에서 소동이 일었다.")
	if downed.is_empty():
		bits.append("쓰러진 사람은 확인되지 않았다.")
	else:
		bits.append("%s 쓰러졌다." % _joined(downed))
	if not interrupted.is_empty():
		bits.append("%s 일을 멈췄다." % _joined(interrupted))
	if dispatches.is_empty():
		bits.append("경비와 경찰은 이 판에 들어오지 않았다.")
	else:
		bits.append("%s." % " ".join(dispatches))
	bits.append("회사가 장부로 추산한 하루 피해액은 %s이다." % total_text)
	return " ".join(bits)

func _remember(bucket: Array[String], name: String) -> void:
	var cleaned: String = name.strip_edges()
	if not cleaned.is_empty() and not bucket.has(cleaned):
		bucket.append(cleaned)

func _joined(names: Array[String]) -> String:
	if names.size() == 1:
		return _subject(names[0])
	var parts: PackedStringArray = PackedStringArray()
	for index: int in range(names.size() - 1):
		parts.append(_and(names[index]))
	parts.append(_subject(names[names.size() - 1]))
	return " ".join(parts)

func _subject(name: String) -> String:
	return name + ("이" if _batchim(name) else "가")

func _and(name: String) -> String:
	return name + ("과" if _batchim(name) else "와")

func _batchim(name: String) -> bool:
	if name.is_empty():
		return false
	var code: int = name.unicode_at(name.length() - 1)
	return code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0
