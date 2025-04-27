# Dans QuestListScreen.gd

extends Control

# Références aux éléments UI (Assure-toi que ces chemins correspondent à ta scène !)
# Si tu as suivi la structure précédente, ces chemins sont corrects.
@onready var coins_label = $MainMargin/VerticalLayout/CoinDisplay/CoinsLabel
@onready var quest_list_container = $MainMargin/VerticalLayout/QuestScroll/QuestListContainer

# =============================================================================
# Cycle de vie du Nœud
# =============================================================================

func _ready():
	# Vérifie si GameState a les données. Idéalement, StartScreen les a déjà chargées.
	if GameState.all_quests_data.is_empty():
		printerr("QuestListScreen: ATTENTION - GameState n'a pas de données de quêtes au moment du _ready(). Vérifie que StartScreen les charge bien avant.")
		# On continue quand même, populate_quest_list affichera un message d'erreur.

	# Peuple la liste avec les boutons de quêtes
	populate_quest_list()
	# Met à jour l'affichage des pièces initial
	update_coins_label()

	# Connecte le signal de GameState pour mettre à jour l'UI si les pièces changent
	if not GameState.is_connected("coins_updated", Callable(self, "update_coins_label")):
		GameState.coins_updated.connect(update_coins_label)

func _exit_tree():
	# Déconnecte le signal quand la scène est quittée pour éviter les erreurs
	if GameState.is_connected("coins_updated", Callable(self, "update_coins_label")):
		GameState.coins_updated.disconnect(update_coins_label)

# =============================================================================
# Mise à jour de l'UI
# =============================================================================

# Met à jour le texte du label affichant les pièces
func update_coins_label():
	if coins_label: # Petite sécurité pour vérifier que le nœud existe
		coins_label.text = str(GameState.player_coins)

# Fonction principale qui crée/met à jour la liste visuelle des quêtes
func populate_quest_list():
	# 1. Nettoyer le contenu précédent pour éviter les doublons
	for child in quest_list_container.get_children():
		child.queue_free() # Enlève et supprime les anciens boutons

	# 2. Récupérer les données de toutes les quêtes depuis GameState
	var all_quests = GameState.all_quests_data.get("quests", [])

	# 3. Vérifier s'il y a des quêtes à afficher
	if all_quests.is_empty():
		var error_label = Label.new()
		error_label.text = "No quests available to display."
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quest_list_container.add_child(error_label)
		printerr("QuestListScreen: Aucune quête trouvée dans GameState.all_quests_data.")
		return

	# 4. Boucler sur chaque définition de quête pour créer un bouton
	for quest_data in all_quests:
		# --- Récupération des infos de la quête ---
		var quest_id = quest_data.get("id", "")
		# Si une quête n'a pas d'ID, on l'ignore pour éviter les problèmes
		if quest_id.is_empty():
			printerr("QuestListScreen: Quête sans ID trouvée dans quests.json, ignorée.")
			continue

		var title = quest_data.get("title", "Untitled Quest")
		var cost = quest_data.get("cost", 0)
		# Assurer que la difficulté est en minuscule pour le match
		var difficulty = quest_data.get("difficulty", "Unknown").to_lower()
		var is_unlocked = quest_id in GameState.unlocked_quests
		var is_completed = quest_id in GameState.completed_quests

		# --- Création du Bouton pour cette quête ---
		var quest_button = Button.new()
		# Fait en sorte que le bouton prenne toute la largeur disponible
		quest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# --- Style du Bouton ---
		# Pas de 'flat = true' pour un look de bouton normal
		quest_button.alignment = HORIZONTAL_ALIGNMENT_CENTER # Centrer le texte
		quest_button.add_theme_font_size_override("font_size", 18) # Taille de police

		# Appliquer la couleur du texte selon la difficulté
		match difficulty:
			"easy":
				quest_button.add_theme_color_override("font_color", Color.SPRING_GREEN)
			"medium":
				quest_button.add_theme_color_override("font_color", Color.ORANGE)
			"high":
				quest_button.add_theme_color_override("font_color", Color.RED)
			_: # Difficulté inconnue ou non spécifiée
				quest_button.add_theme_color_override("font_color", Color.WHITE) # Couleur par défaut

		# --- Définition du Texte et de l'État (Activé/Désactivé) ---
		var button_text = "%s (%s)" % [title, difficulty.capitalize()] # Met la première lettre en majuscule

		if is_completed:
			# Quête terminée : désactivée et grisée
			quest_button.disabled = true
			quest_button.modulate = Color(0.5, 0.5, 0.5) # Grisé foncé
			button_text += "\n- Completed -"
		elif is_unlocked:
			# Quête débloquée : activée, prête à être lancée
			quest_button.disabled = false
			quest_button.pressed.connect(_on_start_quest_pressed.bind(quest_id))
		else:
			# Quête verrouillée : afficher le coût, vérifier si achetable
			button_text += "\nBuy (%d Coins)" % cost
			var can_buy = GameState.can_afford(cost)
			quest_button.disabled = not can_buy # Désactivée si pas assez de pièces
			if can_buy:
				# Connecter pour acheter si assez de pièces
				quest_button.pressed.connect(_on_buy_quest_pressed.bind(quest_id, cost))
			else:
				# Griser légèrement si inachetable
				quest_button.modulate = Color(0.7, 0.7, 0.7)

		# Assigner le texte formaté au bouton
		quest_button.text = button_text

		# Ajouter une marge en bas pour l'espacement visuel entre les boutons
		quest_button.add_theme_constant_override("margin_bottom", 8)

		# --- Ajout du bouton à la liste ---
		quest_list_container.add_child(quest_button)


# =============================================================================
# Callbacks des Signaux (réactions aux clics)
# =============================================================================

# Appelé quand un bouton "Start" (ou un bouton de quête débloquée) est cliqué
func _on_start_quest_pressed(quest_id: String):
	print("QuestListScreen: Starting quest: ", quest_id)
	GameState.start_quest(quest_id) # Prépare GameState

	# Chemin vers la scène de SÉLECTION des PNJ (celle qu'on vient de créer)
	var interaction_scene_path = "res://Scenes/InteractionScreen.tscn" # <-- Vérifier que c'est bien ce chemin

	# Vérifier l'existence et changer de scène
	if FileAccess.file_exists(interaction_scene_path):
		get_tree().change_scene_to_file(interaction_scene_path)
	else:
		printerr("ERROR: Cannot load InteractionScreen. Scene not found at: ", interaction_scene_path)


# Appelé quand un bouton "Buy" (ou un bouton de quête verrouillée achetable) est cliqué
func _on_buy_quest_pressed(quest_id: String, cost: int):
	print("QuestListScreen: Attempting to buy quest: ", quest_id, " for ", cost, " coins.")

	# Tente de dépenser les pièces via GameState
	if GameState.spend_coins(cost):
		# Achat réussi !
		GameState.unlock_quest(quest_id) # Débloque la quête dans GameState
		# Rafraîchit toute la liste pour mettre à jour l'apparence du bouton acheté
		populate_quest_list()
	else:
		# Achat échoué
		print("QuestListScreen: Purchase failed for ", quest_id, ". Not enough coins.")
		# Idéalement, afficher un message "Not enough coins!" à l'utilisateur
