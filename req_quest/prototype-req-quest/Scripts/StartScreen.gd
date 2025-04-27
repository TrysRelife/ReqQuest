# Dans StartScreen.gd

extends Control

# Référence au bouton (utilise le chemin correct de TA scène)
@onready var start_button = $StartButtonLayout/StartButton

# Chemin vers le fichier JSON des quêtes
const QUEST_FILE_PATH = "res://Data/quests.json"

func _ready():
	# 1. Charger les données des quêtes dès le démarrage de l'écran titre
	_load_quest_data()

	# 2. Connecter le bouton Start (s'il existe)
	if start_button:
		# S'assurer qu'on ne connecte pas plusieurs fois si déjà fait dans l'éditeur
		if not start_button.is_connected("pressed", Callable(self, "_on_start_button_pressed")):
			start_button.pressed.connect(_on_start_button_pressed)
		print("StartScreen: Bouton Start prêt.")
	else:
		printerr("ERREUR CRITIQUE : StartButton non trouvé au chemin défini dans @onready. Vérifie la structure de ta scène StartScreen !")
		# On pourrait désactiver la possibilité de démarrer ou afficher une erreur

# Fonction pour charger et parser le fichier JSON des quêtes
func _load_quest_data():
	print("StartScreen: Tentative de chargement de ", QUEST_FILE_PATH)

	# Vérifier l'existence du fichier
	if not FileAccess.file_exists(QUEST_FILE_PATH):
		printerr("ERREUR CRITIQUE : Fichier de quêtes non trouvé à ", QUEST_FILE_PATH)
		GameState.set_all_quest_data({"quests": []}) # Informer GameState qu'il n'y a pas de données
		return # Arrêter le chargement

	# Ouvrir et lire le fichier
	var file = FileAccess.open(QUEST_FILE_PATH, FileAccess.READ)
	if file == null:
		printerr("Erreur: Impossible d'ouvrir ", QUEST_FILE_PATH, " Erreur Code: ", FileAccess.get_open_error())
		GameState.set_all_quest_data({"quests": []})
		return

	var json_text = file.get_as_text()
	file.close() # Toujours fermer le fichier

	# Parser le JSON
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("Erreur de parsing JSON dans ", QUEST_FILE_PATH, ": ", json.get_error_message(), " (ligne: ", json.get_error_line(), ")")
		GameState.set_all_quest_data({"quests": []})
		return

	# Vérifier la structure de base et envoyer les données à GameState
	var loaded_data = json.get_data()
	if loaded_data is Dictionary and loaded_data.has("quests"):
		print("StartScreen: Chargement et parsing de quests.json réussi.")
		GameState.set_all_quest_data(loaded_data)
	else:
		printerr("Erreur: Le JSON chargé depuis ", QUEST_FILE_PATH, " n'a pas la structure attendue (manque la clé racine 'quests' ou n'est pas un dictionnaire).")
		GameState.set_all_quest_data({"quests": []})


# Fonction appelée quand le bouton "Start" est cliqué
func _on_start_button_pressed():
	print("StartScreen: Bouton Start pressé ! Chargement de QuestListScreen...")

	var next_scene_path = "res://Scenes/QuestListScreen.tscn"

	# Vérifier si la scène suivante existe avant de tenter de la charger
	if FileAccess.file_exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		printerr("ERREUR: Impossible de charger la scène de liste des quêtes: ", next_scene_path, " n'existe pas !")
		# Optionnel : Afficher un message d'erreur à l'utilisateur