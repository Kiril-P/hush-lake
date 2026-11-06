#!/bin/bash
# Runs every headless suite and prints one summary line per suite and a verdict. Exit code 0 = all passed.
#   tools/run_all.sh            all suites (about 10-15 minutes: smoke and first10 are the long ones)
#   tools/run_all.sh quick      skip smoke, econ and first10 (a couple of minutes)
#   tools/run_all.sh bots       also run the windowed real-input bot (opens a window; keep it in front)
# Windowed tools (shots, perf_render, play_bot) are not part of the default run: they need a display.
cd "$(dirname "$0")/.."
quick=0; bots=0
for a in "$@"; do [ "$a" = quick ] && quick=1; [ "$a" = bots ] && bots=1; done
suites="hands machines weather opening yard safety guide ui sectors audio score fishing story progress life fx"
[ $quick = 0 ] && suites="smoke $suites econ"
fails=0
start=$(date +%s)
for s in $suites; do
	[ -x "tools/run_$s.sh" ] || continue
	t0=$(date +%s)
	if "tools/run_$s.sh" > "/tmp/run_all_$s.log" 2>&1; then r="ok  "; else r="FAIL"; fails=$((fails+1)); fi
	printf "%s  %-9s %3ds\n" "$r" "$s" $(( $(date +%s) - t0 ))
	[ "$r" = "FAIL" ] && grep -E "^FAIL|SCRIPT ERROR|^ERROR" "/tmp/run_all_$s.log" | head -4 | sed 's/^/        /'
done
if [ $quick = 0 ]; then
	t0=$(date +%s)
	if tools/first10.sh > /tmp/run_all_first10.log 2>&1; then r="ok  "; else r="FAIL"; fails=$((fails+1)); fi
	printf "%s  %-9s %3ds\n" "$r" "first10" $(( $(date +%s) - t0 ))
fi
if [ $bots = 1 ]; then
	t0=$(date +%s)
	if tools/play_bot.sh > /tmp/run_all_bot.log 2>&1; then r="ok  "; else r="FAIL"; fails=$((fails+1)); fi
	printf "%s  %-9s %3ds\n" "$r" "play_bot" $(( $(date +%s) - t0 ))
fi
echo "-----"
if [ $fails = 0 ]; then echo "ALL PASS in $(( $(date +%s) - start )) s"; else echo "$fails SUITE(S) FAILED (logs in /tmp/run_all_*.log)"; fi
exit $fails
