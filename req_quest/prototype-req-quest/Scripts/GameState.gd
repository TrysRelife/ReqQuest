# Dans GameState.gd

extends Node

# Données de toutes les quêtes (sera rempli par StartScreen)
var all_quests_data: Dictionary = {}
# ... (toutes les autres variables comme player_coins, unlocked_quests, etc. restent ici) ...
var current_quest_id: String = ""
var current_quest_runtime_data: Dictionary = {}
var current_interaction_data: Dictionary = {}
var player_coins: int = 100
var unlocked_quests: Array[String] = ["the_wizards_spellbook"]
var completed_quests: Array[String] = []
var current_interaction_index: int = 0
var interacted_npcs: Array[String] = []
var current_quest_score: int = 0

signal coins_updated

# La fonction _ready DE GameState NE charge PLUS le JSON ici
func _ready():
	print("GameState prêt.")
	# Si tu avais load_all_quest_definitions() ici, supprime-le.

# NOUVELLE fonction pour que StartScreen puisse définir les données
func set_all_quest_data(loaded_data: Dictionary):
	if loaded_data and loaded_data.has("quests"):
		all_quests_data = loaded_data
		print("GameState: Données de quêtes reçues et stockées. Nombre de quêtes: ", all_quests_data.get("quests", []).size())
	else:
		printerr("GameState: Tentative de définir des données de quêtes invalides ou vides.")
		all_quests_data = {"quests": []} # Assurer une structure valide même en cas d'erreur

# ... (toutes les autres fonctions comme get_quest_data, add_coins, etc. restent ici) ...

# get_quest_data doit maintenant vérifier si all_quests_data est vide
func get_quest_data(quest_id: String) -> Dictionary:
	if all_quests_data.is_empty() or not all_quests_data.has("quests"):
		printerr("GameState: Tentative d'accès aux données de quête alors qu'elles ne sont pas chargées !")
		return {}
	for quest in all_quests_data.get("quests", []):
		if quest.get("id", "") == quest_id:
			return quest
	return {}

# ... (les autres fonctions restent identiques : can_afford, add_coins, spend_coins, etc.)
# --- Fonctions pour gérer les pièces et les quêtes ---

func can_afford(cost: int) -> bool:
	return player_coins >= cost

func add_coins(amount: int):
	player_coins += amount
	coins_updated.emit()
	print("GameState: Coins ajoutés: ", amount, ". Total: ", player_coins)

func spend_coins(amount: int) -> bool:
	if can_afford(amount):
		player_coins -= amount
		coins_updated.emit()
		print("GameState: Pièces dépensées: ", amount, ". Restant: ", player_coins)
		return true
	else:
		print("GameState: Dépense échouée. Pas assez de pièces (besoin de ", amount, ", a ", player_coins, ")")
		return false

func unlock_quest(quest_id: String):
	if not quest_id in unlocked_quests:
		unlocked_quests.append(quest_id)
		print("GameState: Quête débloquée: ", quest_id)

func mark_quest_completed(quest_id: String):
	if not quest_id in completed_quests:
		completed_quests.append(quest_id)
		print("GameState: Quête marquée comme terminée: ", quest_id)

# --- Fonctions pour gérer l'état PENDANT une quête ---

func start_quest(quest_id: String):
	current_quest_id = quest_id
	var quest_definition = get_quest_data(quest_id)
	if quest_definition.is_empty():
		printerr("ERREUR: Tentative de démarrer une quête inconnue ou mal chargée: ", quest_id)
		return
	current_quest_runtime_data = quest_definition.duplicate(true)
	current_interaction_index = 0
	interacted_npcs = []
	current_quest_score = 0
	current_interaction_data = {}
	print("GameState: Démarrage de la quête: ", current_quest_id)

func get_current_quest_npcs() -> Array:
	return current_quest_runtime_data.get("npcs", [])

func get_next_interaction() -> Dictionary:
	var interactions = current_quest_runtime_data.get("interactions", [])
	if current_interaction_index < interactions.size():
		current_interaction_data = interactions[current_interaction_index]
		return current_interaction_data
	current_interaction_data = {}
	return {}

func advance_interaction():
	current_interaction_index += 1

func mark_npc_interacted(npc_role: String):
	# Ajoute le rôle à la liste seulement s'il n'y est pas déjà
	if not npc_role in interacted_npcs:
		interacted_npcs.append(npc_role)

# Vérifie si on a déjà interagi avec un PNJ ayant ce rôle pendant la quête actuelle
func has_interacted_with(npc_role: String) -> bool:
	# L'opérateur 'in' retourne true si l'élément est dans le tableau, false sinon
	return npc_role in interacted_npcs

# Ajoute des points au score de la quête en cours
func add_to_quest_score(points: int):
	current_quest_score += points

# Vérifie si toutes les interactions définies pour la quête actuelle ont été passées
func is_quest_finished() -> bool:
	# Récupère la liste des interactions pour la quête en cours
	# Le .get("interactions", []) fournit un tableau vide par défaut si la clé n'existe pas
	var interactions = current_quest_runtime_data.get("interactions", [])
	# La quête est finie si l'index courant est égal ou supérieur au nombre total d'interactions
	return current_interaction_index >= interactions.size()