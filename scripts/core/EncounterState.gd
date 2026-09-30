extends RefCounted
class_name EncounterState
## Stargazer - EncounterState
## The shared, engine-independent heart of every boss fight: health, phases
## and the intro -> fighting -> dying -> defeated lifecycle. Boss scripts own
## one of these so their visual/attack code stays free of bookkeeping, and so
## the rules can be unit tested without a scene tree.

enum Stage { INTRO, FIGHTING, DYING, DEFEATED }

var max_health: int = 100
var health: int = 100
## Descending health fractions at which the boss advances a phase.
var phase_thresholds: Array = []
var phase: int = 0
var stage: int = Stage.INTRO

var _phase_change_pending: bool = false
var victory_pending: bool = false

func configure(p_max_health: int, p_thresholds: Array) -> void:
	max_health = maxi(1, p_max_health)
	health = max_health
	phase_thresholds = p_thresholds.duplicate()
	phase = 0
	stage = Stage.INTRO
	_phase_change_pending = false
	victory_pending = false

## Phase index implied by a health fraction and a descending threshold list.
static func phase_for(fraction: float, thresholds: Array) -> int:
	var result := 0
	for t in thresholds:
		if fraction <= float(t):
			result += 1
	return result

func health_fraction() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

func phase_count() -> int:
	return phase_thresholds.size() + 1

func is_alive() -> bool:
	return health > 0

func can_act() -> bool:
	return stage == Stage.FIGHTING and health > 0

func begin_fight() -> void:
	if stage == Stage.INTRO:
		stage = Stage.FIGHTING

## Applies damage and returns how much was actually dealt.
func damage(amount: int) -> int:
	if amount <= 0 or stage == Stage.DYING or stage == Stage.DEFEATED or health <= 0:
		return 0
	var dealt: int = mini(amount, health)
	health -= dealt
	var new_phase := phase_for(health_fraction(), phase_thresholds)
	if new_phase > phase:
		phase = new_phase
		_phase_change_pending = true
	if health <= 0:
		stage = Stage.DYING
		victory_pending = true
	return dealt

## True exactly once per phase transition.
func consume_phase_change() -> bool:
	if _phase_change_pending:
		_phase_change_pending = false
		return true
	return false

## True exactly once per encounter, preventing double rewards.
func consume_victory() -> bool:
	if victory_pending:
		victory_pending = false
		stage = Stage.DEFEATED
		return true
	return false
