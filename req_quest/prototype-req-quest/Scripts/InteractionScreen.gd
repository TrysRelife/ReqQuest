# InteractionScreen.gd
# Cette scène affiche les PNJ de la quête en cours et permet de choisir avec qui interagir.

extends Control

# Références aux nœuds de l'interface utilisateur (vérifie les chemins !)
@onready var quest_title_label = $MainMargin/VerticalLayout/QuestTitleLabel
@onready var quest_topic_label = $MainMargin/VerticalLayout/QuestTopicLabel
@onready var instruction_label = $MainMargin/VerticalLayout/InstructionLabel
@onready var npc_list_container = $MainMargin/VerticalLayout/NpcScroll/NpcListContainer

# Stocke les données de la quête actuelle pour un accès facile
var current_quest_data: Dictionary = {}

# =============================================================================
# Initialisation de la Scène
# =============================================================================

func _ready():
	# Récupère les données de la quête en cours depuis le singleton GameState
	current_quest_data = GameState.current_quest_runtime_data

	# Vérification essentielle : si aucune quête n'est active, on ne peut rien afficher
	if current_quest_data.is_empty():
		printerr("InteractionScreen: ERREUR CRITIQUE - Aucune donnée de quête active ('current_quest_runtime_data' est vide). Retour à la liste des quêtes.")
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")
		return # Stop l'exécution de _ready ici

	# Met à jour les labels d'information de la quête
	quest_title_label.text = current_quest_data.get("title", "Quest Title Missing")
	quest_topic_label.text = "Topic: " + current_quest_data.get("topic", "Quest Topic Missing")
	instruction_label.text = "Select a character to interact with:"

	# Si la quête est déjà terminée selon GameState, on passe directement à l'écran de fin
	if GameState.is_quest_finished():
		print("InteractionScreen: La quête est déjà marquée comme terminée. Passage à l'écran de complétion.")
		_go_to_quest_complete()
		return # Stop l'exécution pour ne pas peupler la liste inutilement

	# Crée et affiche la liste des boutons PNJ
	populate_npc_list()

# =============================================================================
# Population de la Liste des PNJ
# =============================================================================

# Crée dynamiquement les boutons pour chaque PNJ de la quête
func populate_npc_list():
	# Nettoie la liste pour éviter les doublons si on revient sur cet écran
	for child in npc_list_container.get_children():
		child.queue_free()

	# Récupère la définition des PNJ pour cette quête
	var npcs = current_quest_data.get("npcs", [])
	if npcs.is_empty():
		var error_label = Label.new()
		error_label.text = "No characters defined for this quest."
		npc_list_container.add_child(error_label)
		printerr("InteractionScreen: Aucun PNJ défini dans les données de la quête '", current_quest_data.get("id"), "'.")
		return

	var has_active_npc = false # Drapeau pour vérifier s'il reste une interaction possible

	# Récupère l'information sur la PROCHAINE interaction prévue (sans avancer l'index)
	# Note: get_next_interaction met aussi à jour GameState.current_interaction_data
	var next_interaction = GameState.get_next_interaction()

	# Boucle sur chaque PNJ défini dans les données de la quête
	for npc_data in npcs:
		var npc_name = npc_data.get("name", "Unknown Character")
		var npc_role = npc_data.get("role", "")

		# Ignore les PNJ sans rôle défini (le rôle est essentiel pour l'identification)
		if npc_role.is_empty():
			printerr("InteractionScreen: PNJ trouvé sans 'role' dans les données de la quête, ignoré:", npc_name)
			continue

		# --- Création du Bouton pour ce PNJ ---
		var npc_button = Button.new()
		npc_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Prend toute la largeur
		npc_button.alignment = HORIZONTAL_ALIGNMENT_CENTER # Texte centré
		npc_button.add_theme_font_size_override("font_size", 18) # Taille de police
		npc_button.text = "%s\n(%s)" % [npc_name, npc_role] # Texte sur deux lignes
		npc_button.add_theme_constant_override("margin_bottom", 8) # Espacement

		# --- Détermination de l'État du Bouton (Actif ou Inactif) ---
		# Le PNJ est ACTIF si c'est lui qui est concerné par la PROCHAINE interaction
		if not next_interaction.is_empty() and next_interaction.get("npc_role") == npc_role:
			# C'est le tour de ce PNJ
			npc_button.disabled = false
			npc_button.modulate = Color(1, 1, 1) # Couleur normale
			# Connecter le clic à la fonction de sélection, en passant son rôle
			npc_button.pressed.connect(_on_npc_selected.bind(npc_role))
			has_active_npc = true # Il y a au moins un PNJ actif
		else:
			# Ce n'est pas (encore) le tour de ce PNJ
			npc_button.disabled = true
			# Vérifier si on a déjà interagi avec lui dans le passé pour le griser
			if GameState.has_interacted_with(npc_role):
				npc_button.modulate = Color(0.5, 0.5, 0.5) # Grisé foncé (déjà parlé)
				# npc_button.text += "\n(Interacted)" # Optionnel: Ajouter texte
			else:
				npc_button.modulate = Color(0.8, 0.8, 0.8) # Grisé clair (pas encore son tour)

		# Ajouter le bouton configuré à la liste visuelle
		npc_list_container.add_child(npc_button)

	# Vérification de sécurité : si aucun PNJ n'est actif, mais que la quête n'est pas
	# marquée comme finie, il y a potentiellement un problème. On force la fin.
	if not has_active_npc and not GameState.is_quest_finished():
		printerr("InteractionScreen: Aucun PNJ actif trouvé, mais la quête n'est pas finie. Fin de quête forcée.")
		_go_to_quest_complete()


# =============================================================================
# Gestion des Clics et Navigation
# =============================================================================

# Appelé UNIQUEMENT lorsqu'un bouton PNJ ACTIF est cliqué
func _on_npc_selected(selected_npc_role: String):
	print("InteractionScreen: PNJ sélectionné - ", selected_npc_role)

	# L'interaction à jouer est déjà dans GameState.current_interaction_data
	# (car elle a été mise là par get_next_interaction dans populate_npc_list)
	var interaction_data = GameState.current_interaction_data

	# Sécurité : vérifier si l'interaction correspond bien au PNJ cliqué
	if interaction_data.is_empty() or interaction_data.get("npc_role") != selected_npc_role:
		printerr("InteractionScreen: ERREUR - Incohérence entre PNJ sélectionné (%s) et interaction en cours (%s)." % [selected_npc_role, interaction_data.get("npc_role", "AUCUN")])
		populate_npc_list() # Tenter de rafraîchir l'état visuel
		return

	# MARQUER le PNJ comme interagi MAINTENANT (important pour l'état au retour)
	GameState.mark_npc_interacted(selected_npc_role)

	# Définir le chemin vers la scène qui affichera le dialogue/la question
	var npc_interaction_scene_path = "res://Scenes/NpcInteractionScene.tscn" # <-- TU DOIS CRÉER CETTE SCÈNE

	# Vérifier si la scène existe et y aller
	if FileAccess.file_exists(npc_interaction_scene_path):
		get_tree().change_scene_to_file(npc_interaction_scene_path)
	else:
		printerr("InteractionScreen: ERREUR CRITIQUE - La scène 'NpcInteractionScene.tscn' est introuvable !")
		# Plan B : Revenir à la liste des quêtes pour ne pas bloquer le joueur
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")


# Fonction utilitaire pour naviguer vers l'écran de fin de quête
func _go_to_quest_complete():
	var complete_scene_path = "res://Scenes/QuestCompleteScreen.tscn"
	if FileAccess.file_exists(complete_scene_path):
		get_tree().change_scene_to_file(complete_scene_path)
	else:
		printerr("InteractionScreen: ERREUR - Scene QuestCompleteScreen.tscn non trouvée !")
		# Plan B: Retour à la liste des quêtes
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")