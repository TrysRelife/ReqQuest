# QuestCompleteScreen.gd
# Affiche les résultats de la quête terminée et permet de revenir à la liste.

extends Control

# Références UI
@onready var title_label: Label = $MainMargin/VerticalLayout/TitleLabel
@onready var results_label: Label = $MainMargin/VerticalLayout/ResultsLabel
@onready var back_button: Button = $MainMargin/VerticalLayout/BackButton

# =============================================================================
# Initialisation
# =============================================================================
func _ready():
    
	# 1. Récupérer l'ID et les données de la quête qui vient de se terminer
	print("--- QuestCompleteScreen._ready() EXÉCUTÉ ---") # Log critique
	var completed_quest_id = GameState.current_quest_id
	var quest_data = GameState.get_quest_data(completed_quest_id)

	# 2. Récupérer le score et calculer la récompense
	var final_score = GameState.current_quest_score
	var coins_reward = quest_data.get("reward_coins", 0) # Récupère la récompense définie dans le JSON

	# 3. Mettre à jour les labels
	if title_label:
		title_label.text = "'%s' Complete!" % quest_data.get("title", "Quest")

	if results_label:
		results_label.text = "Final Score: %d\nCoins Earned: +%d" % [final_score, coins_reward]

	# 4. Donner les pièces au joueur et marquer la quête comme terminée
	#    (On le fait ici pour être sûr que ça arrive seulement à la fin)
	if not completed_quest_id.is_empty() and not completed_quest_id in GameState.completed_quests:
		GameState.add_coins(coins_reward)
		GameState.mark_quest_completed(completed_quest_id)
		print("QuestCompleteScreen: Récompense (%d pièces) ajoutée et quête '%s' marquée comme terminée." % [coins_reward, completed_quest_id])

	# 5. Connecter le bouton retour
	if back_button and not back_button.is_connected("pressed", Callable(self, "_on_back_button_pressed")):
		back_button.pressed.connect(_on_back_button_pressed)

# =============================================================================
# Navigation
# =============================================================================
func _on_back_button_pressed():
	# Réinitialiser l'état de la quête en cours dans GameState pour être propre
	GameState.current_quest_id = ""
	GameState.current_quest_runtime_data = {}
	GameState.current_interaction_data = {}
	GameState.current_interaction_index = -1 # Remettre à -1 ou 0 selon préférence
	GameState.interacted_npcs = []
	GameState.current_quest_score = 0

	# Retourner à la liste des quêtes
	var quest_list_path = "res://Scenes/QuestListScreen.tscn"
	if FileAccess.file_exists(quest_list_path):
		get_tree().change_scene_to_file(quest_list_path)
	else:
		printerr("QuestCompleteScreen: ERREUR - Scene QuestListScreen.tscn non trouvée ! Fallback vers StartScreen.")
		# Fallback ultime vers l'écran titre si la liste des quêtes est aussi manquante
		get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")