# GameState.gd
extends Node

var all_quests_data: Dictionary = {}
var current_quest_id: String = ""
var current_quest_runtime_data: Dictionary = {}
var current_interaction_data: Dictionary = {}
var player_coins: int = 100
var unlocked_quests: Array[String] = ["the_wizards_spellbook"]
var completed_quests: Array[String] = []
var current_interaction_index: int = -1 # Initialisé à -1 pour être sûr
var interacted_npcs: Array[String] = []
var current_quest_score: int = 0

signal coins_updated

func _ready():
	print("GameState prêt.")

func set_all_quest_data(loaded_data: Dictionary):
	if loaded_data and loaded_data.has("quests"):
		all_quests_data = loaded_data
	else:
		printerr("GameState: Données de quêtes invalides reçues.")
		all_quests_data = {"quests": []}

func get_quest_data(quest_id: String) -> Dictionary:
	if all_quests_data.is_empty(): return {}
	for quest in all_quests_data.get("quests", []):
		if quest.get("id", "") == quest_id: return quest
	return {}

func can_afford(cost: int) -> bool:	return player_coins >= cost
func add_coins(amount: int): player_coins += amount; coins_updated.emit()

func spend_coins(amount: int) -> bool:
	if can_afford(amount): player_coins -= amount; coins_updated.emit(); return true
	return false

func unlock_quest(quest_id: String):
	if not quest_id in unlocked_quests: unlocked_quests.append(quest_id)

func mark_quest_completed(quest_id: String):
	if not quest_id in completed_quests: completed_quests.append(quest_id)

func start_quest(quest_id: String):
	current_quest_id = quest_id
	var quest_definition = get_quest_data(quest_id)
	if quest_definition.is_empty(): printerr("ERREUR: Tentative de démarrer quête inconnue: ", quest_id); return
	current_quest_runtime_data = quest_definition.duplicate(true)
	current_interaction_index = 0 # Réinitialise l'index au début de la quête
	interacted_npcs = []
	current_quest_score = 0
	current_interaction_data = {}
	# --- DEBUG LOG ---
	print("GameState.start_quest: Quête '%s' démarrée. Index mis à %d." % [quest_id, current_interaction_index])

func get_current_quest_npcs() -> Array: return current_quest_runtime_data.get("npcs", [])

func get_next_interaction() -> Dictionary:
	# --- DEBUG LOG ---
	print("GameState.get_next_interaction: Demande interaction à l'index ", current_interaction_index)
	if current_quest_runtime_data.is_empty(): return {}
	var interactions = current_quest_runtime_data.get("interactions", [])
	if current_interaction_index >= 0 and current_interaction_index < interactions.size():
		current_interaction_data = interactions[current_interaction_index]
		# --- DEBUG LOG ---
		print("GameState.get_next_interaction: Interaction trouvée (type: %s): %s" % [current_interaction_data.get("type","N/A"), current_interaction_data])
		return current_interaction_data
	else:
		current_interaction_data = {}
		# --- DEBUG LOG ---
		print("GameState.get_next_interaction: Index %d hors limites (max %d). Retourne vide." % [current_interaction_index, interactions.size() - 1])
		return {}

func advance_interaction():
	# --- DEBUG LOG ---
	print("GameState.advance_interaction: Index AVANT = ", current_interaction_index)
	current_interaction_index += 1
	# --- DEBUG LOG ---
	print("GameState.advance_interaction: Index APRÈS = ", current_interaction_index)


func mark_npc_interacted(npc_role: String):
	if not npc_role in interacted_npcs: interacted_npcs.append(npc_role)

func has_interacted_with(npc_role: String) -> bool: return npc_role in interacted_npcs
func add_to_quest_score(points: int): current_quest_score += points

func is_quest_finished() -> bool:
	if current_quest_runtime_data.is_empty(): return true # Si pas de données, considérer comme finie
	var interactions = current_quest_runtime_data.get("interactions", [])
	var result = current_interaction_index >= interactions.size()
	# --- DEBUG LOG ---
	# print("GameState.is_quest_finished: Index=%d, Size=%d, Result=%s" % [current_interaction_index, interactions.size(), result])
	return result