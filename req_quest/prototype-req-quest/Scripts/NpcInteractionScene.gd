# NpcInteractionScene.gd
# Affiche un dialogue ou une question QCM, gère la réponse,
# et enchaîne l'interaction suivante ou navigue vers l'écran approprié.

extends Control

# Références UI
@onready var npc_avatar: TextureRect = $MainMargin/VerticalLayout/NpcInfoBar/NpcAvatar
@onready var npc_name_label: Label = $MainMargin/VerticalLayout/NpcInfoBar/NpcNameLabel
@onready var interaction_text: Label = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/InteractionText
@onready var options_container: VBoxContainer = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer
@onready var option_button_1: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton1
@onready var option_button_2: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton2
@onready var option_button_3: Button = $MainMargin/VerticalLayout/InteractionPanel/PanelVBox/OptionsContainer/OptionButton3
@onready var continue_button: Button = $MainMargin/VerticalLayout/ContinueButton

# Variables d'état
var interaction_data: Dictionary = {}
var correct_option_index: int = -1
var answer_selected: bool = false

# =============================================================================
# Initialisation de la Scène
# =============================================================================
func _ready():
	interaction_data = GameState.current_interaction_data

	if interaction_data.is_empty():
		printerr("NpcInteractionScene: Aucune donnée d'interaction. Retour.")
		_go_back_to_npc_selection()
		return

	# Affiche les détails de l'interaction actuelle
	_display_interaction(interaction_data)

	# Connecte le bouton Continuer (sera rendu visible par _display_interaction si nécessaire)
	_connect_continue_button()

# =============================================================================
# Affichage et Configuration de l'Interaction Actuelle
# =============================================================================
func _display_interaction(data: Dictionary):
	# Met à jour les données locales et l'UI de base
	interaction_data = data
	_display_npc_info(interaction_data.get("npc_role", ""))
	interaction_text.text = interaction_data.get("text", "[Interaction Text Missing]")

	# Réinitialise l'état et cache les éléments
	options_container.visible = false
	continue_button.visible = false
	answer_selected = false

	# Configure l'UI selon le type d'interaction
	var interaction_type = interaction_data.get("type", "dialogue")
	match interaction_type:
		"question":
			var options = interaction_data.get("options", [])
			var raw_correct_index = interaction_data.get("correct_index", -1)
			var index_int = -1 # Variable pour stocker la version entière

			# Conversion sûre de l'index en entier
			if raw_correct_index is int:
				index_int = raw_correct_index
			elif raw_correct_index is float:
				index_int = int(raw_correct_index) # Force la conversion
			else:
				printerr("NpcInteractionScene: correct_index n'est pas un nombre valide: ", raw_correct_index)

			# Vérification finale des données de la question
			if options.size() == 3 and index_int >= 0 and index_int <= 2:
				correct_option_index = index_int # Stocke l'index correct (entier)
				_reset_option_buttons_appearance()
				# Configure et active les boutons d'option
				option_button_1.text = options[0]; option_button_1.disabled = false
				option_button_2.text = options[1]; option_button_2.disabled = false
				option_button_3.text = options[2]; option_button_3.disabled = false
				# Connecte les signaux des options
				_connect_option_button(option_button_1, 0)
				_connect_option_button(option_button_2, 1)
				_connect_option_button(option_button_3, 2)
				# Affiche le conteneur des options
				options_container.visible = true
			else: # Question invalide -> Fallback dialogue
				printerr("NpcInteractionScene: Données Question Invalides (Options:%d, Index:%d). Fallback Dialogue." % [options.size(), index_int])
				continue_button.disabled = false
				continue_button.visible = true

		"dialogue", _: # Dialogue ou type inconnu -> Afficher Continuer
			continue_button.disabled = false
			continue_button.visible = true

# =============================================================================
# Fonctions Helper (Connexion, Affichage, Recherche, Reset Style)
# =============================================================================
func _connect_option_button(button: Button, index: int):
	if button:
		var callable_func = Callable(self, "_on_option_button_pressed")
		# Déconnecte d'abord pour éviter doublons après reload potentiel (même si on évite reload maintenant)
		if button.is_connected("pressed", callable_func): button.disconnect("pressed", callable_func)
		button.pressed.connect(_on_option_button_pressed.bind(index))

func _connect_continue_button():
	if continue_button:
		var callable_func = Callable(self, "_on_continue_button_pressed")
		# Déconnecte systématiquement avant pour être sûr
		if continue_button.is_connected("pressed", callable_func): continue_button.disconnect("pressed", callable_func)
		var err = continue_button.pressed.connect(callable_func)
		if err != OK: printerr("ERREUR connexion ContinueButton! Code: ", err)

func _display_npc_info(npc_role: String):
	# Sécurité si les noeuds UI n'existent pas
	if not is_instance_valid(npc_name_label) or not is_instance_valid(npc_avatar): return
	var npc_data = _find_npc_data_by_role(npc_role)
	if not npc_data.is_empty():
		npc_name_label.text = npc_data.get("name", "Unknown")
		if npc_data.has("image"):
			var image_path = npc_data.get("image", "");
			# Charge l'image seulement si le chemin est valide et le fichier existe
			if not image_path.is_empty() and FileAccess.file_exists(image_path):
				npc_avatar.texture = load(image_path)
			else: # Efface l'image précédente si non trouvée
				npc_avatar.texture = null
		else: # Efface si pas de clé "image"
			npc_avatar.texture = null
	else: # Cas où le PNJ n'est pas trouvé
		npc_name_label.text = "Narrator"
		npc_avatar.texture = null

func _find_npc_data_by_role(role_to_find: String) -> Dictionary:
	if GameState.current_quest_runtime_data.is_empty(): return {}
	var npcs = GameState.current_quest_runtime_data.get("npcs", [])
	for npc in npcs:
		if npc.get("role", "") == role_to_find: return npc
	return {}

func _reset_option_buttons_appearance():
	var buttons = [option_button_1, option_button_2, option_button_3]
	for button in buttons:
		if button: # Vérifie si le bouton existe avant d'essayer de le modifier
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("disabled")
			button.remove_theme_color_override("font_disabled_color")

# =============================================================================
# Gestion des Actions Utilisateur
# =============================================================================
func _on_option_button_pressed(selected_index: int):
	if answer_selected: return # Ignore clics si déjà répondu
	answer_selected = true

	# Désactive tous les boutons pour éviter d'autres clics
	option_button_1.disabled = true
	option_button_2.disabled = true
	option_button_3.disabled = true

	# Vérifie la réponse et ajuste le score
	var is_correct = (selected_index == correct_option_index)
	var points = interaction_data.get("points", 0)
	if is_correct:
		GameState.add_to_quest_score(points)

	# Applique le feedback visuel (vert/rouge)
	var buttons = [option_button_1, option_button_2, option_button_3]
	for i in range(buttons.size()):
		var button = buttons[i]
		if not button: continue # Sécurité

		var stylebox = StyleBoxFlat.new()
		stylebox.set_corner_radius_all(4) # Coins arrondis optionnels
		var font_disabled_color = Color.WHITE # Texte en blanc par défaut sur fond coloré

		if i == correct_option_index: # Bonne réponse
			stylebox.bg_color = Color.DARK_GREEN
		elif i == selected_index: # Mauvaise réponse cliquée
			stylebox.bg_color = Color.DARK_RED
		else: # Autres mauvaises réponses
			stylebox.bg_color = Color(0.4, 0.4, 0.4, 0.8) # Gris foncé transparent
			font_disabled_color = Color.LIGHT_GRAY # Texte plus clair

		# Applique la couleur du texte désactivé
		button.add_theme_color_override("font_disabled_color", font_disabled_color)
		# Applique le fond coloré à tous les états pour le figer
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox)
		button.add_theme_stylebox_override("disabled", stylebox)

	# Affiche et active le bouton Continuer après la réponse
	continue_button.disabled = false
	continue_button.visible = true
	_connect_continue_button() # Reconnecte le signal (par sécurité)

# Appelé quand le bouton "Continue" est cliqué
func _on_continue_button_pressed():
	# Récupère le type de l'interaction qui vient juste de se terminer
	var previous_interaction_type = interaction_data.get("type", "dialogue")

	# Avance l'état de la quête
	GameState.advance_interaction()

	# Décide de la prochaine étape basé sur l'état APRES l'avancement
	if GameState.is_quest_finished():
		# Si la quête est maintenant terminée, va à l'écran de fin
		_go_to_quest_complete()
	elif previous_interaction_type == "question":
		# Si l'interaction précédente était une question (et que la quête n'est pas finie),
		# retourne à l'écran de sélection des PNJ
		_go_back_to_npc_selection()
	else:
		# Si l'interaction précédente était un dialogue (et qu'il reste des étapes),
		# récupère la prochaine interaction et met à jour CETTE scène
		var next_interaction_data = GameState.get_next_interaction()
		_display_interaction(next_interaction_data)

# =============================================================================
# Navigation
# =============================================================================
func _go_back_to_npc_selection():
	# Navigue vers l'écran de sélection des PNJ
	var interaction_scene_path = "res://Scenes/InteractionScreen.tscn"
	if FileAccess.file_exists(interaction_scene_path):
		get_tree().change_scene_to_file(interaction_scene_path)
	else:
		printerr("NpcInteractionScene: ERREUR - Scene InteractionScreen.tscn non trouvée ! Fallback.")
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")

func _go_to_quest_complete():
	# Navigue vers l'écran de fin de quête
	var complete_scene_path = "res://Scenes/QuestCompleteScreen.tscn"
	if FileAccess.file_exists(complete_scene_path):
		get_tree().change_scene_to_file(complete_scene_path)
	else:
		printerr("NpcInteractionScene: ERREUR - Scene QuestCompleteScreen.tscn non trouvée ! Fallback.")
		get_tree().change_scene_to_file("res://Scenes/QuestListScreen.tscn")