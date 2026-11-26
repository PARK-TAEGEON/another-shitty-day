#!/usr/bin/env bash
# Local Linux mirror of tools/test-kim-integration.ps1: same check list, modes,
# flags, arguments, exit-code/ERROR-line rules and pass markers. CI runs the
# PowerShell script itself; PowerShell was not available in this workspace.
# Usage: run-kim-matrix.sh <godot> <repo-root> <evidence-dir>
set -u
GODOT="$1"; ROOT="$2"; OUT="$3"
PROJECT="$ROOT/game"; TESTS="$ROOT/tools/tests"
mkdir -p "$OUT"
"$GODOT" --headless --path "$PROJECT" --editor --import > "$OUT/import.txt" 2>&1
CHECKS="wall_throw_regression opening_reaction_regression boss_approach_regression boss_lecture_regression hand_motion_regression npc_office_behavior_regression property_damage_regression social_damage_regression office_layout_regression floor_transition_regression minimal_hud_regression ui_stars_result_regression star_pill_alignment_regression ceo_hold_regression police_hold_regression police_arrival_regression police_arrival_damage_regression kim_demo_integration hit_feel_regression"
FAIL=0; COUNT=0
run() { # mode test logfile flags...
	local mode="$1" test="$2" file="$3"; shift 3
	timeout 300 "$GODOT" --headless --fixed-fps 60 --path "$PROJECT" --script "$TESTS/$test.gd" -- "$@" > "$file" 2>&1
	local code=$?
	local marker; marker="$(echo "$test" | tr '[:lower:]' '[:upper:]')_OK"
	# Same rules as Invoke-DeskBreakerGodot: exit code, ERROR lines, then the marker.
	if [ "$code" -ne 0 ]; then echo "FAIL $mode $test (exit $code)"; FAIL=$((FAIL+1))
	elif grep -qE '^\s*(SCRIPT ERROR|ERROR):' "$file"; then echo "FAIL $mode $test (ERROR line)"; FAIL=$((FAIL+1))
	elif grep -q "$marker" "$file"; then echo "PASS $mode $test"
	else echo "FAIL $mode $test (no $marker)"; FAIL=$((FAIL+1)); fi
	COUNT=$((COUNT+1))
}
for mode in default health-only legacy; do
	flags=()
	[ "$mode" = health-only ] && flags=(--kim-health-only)
	[ "$mode" = legacy ] && flags=(--kim-legacy)
	for test in $CHECKS; do run "$mode" "$test" "$OUT/$mode-$test.txt" "${flags[@]}"; done
done
for test in kim_rig_regression kim_restart_regression hit_flight_obstacle_regression; do
	if [ "$test" = kim_rig_regression ]; then
		run rig-31 "$test" "$OUT/$test.txt" --report "$OUT/physics.json" --kim-rig
	else
		run default "$test" "$OUT/$test.txt" --report "$OUT/physics.json"
	fi
done
run default kim_flight_pose_regression "$OUT/default-kim_flight_pose_regression.txt"
run rig-31 kim_flight_pose_regression "$OUT/rig-31-kim_flight_pose_regression.txt" --kim-rig
echo "RAN $COUNT FAILED $FAIL"
[ "$FAIL" -eq 0 ] && echo "KIM_INTEGRATION_MATRIX_OK: 3 modes x 19 regressions, plus rig, reload, flight and flight-pose (50-bone, 31-bone) checks"
exit "$FAIL"
