extends Panel
class_name CardNode

## CardNode — visual representation of a CardData in the hand.
## Creates its own child nodes programmatically (no .tscn needed).

signal card_clicked(card: CardData)

var card_data: CardData

# Child references (created in _ready)
var suit_label: Label
var name_label: Label
var type_label: Label

const CARD_WIDTH := 120
const CARD_HEIGHT := 180

const SUIT_COLORS := {
    CardData.Suit.SPADE: Color(0.6, 0.6, 0.7),
    CardData.Suit.HEART: Color(0.85, 0.15, 0.15),
    CardData.Suit.CLUB: Color(0.2, 0.5, 0.2),
    CardData.Suit.DIAMOND: Color(0.85, 0.55, 0.15),
}

const RARITY_BORDERS := {
    CardData.Rarity.COMMON: Color(0.4, 0.4, 0.4),
    CardData.Rarity.RARE: Color(0.2, 0.4, 0.9),
    CardData.Rarity.EPIC: Color(0.6, 0.15, 0.85),
    CardData.Rarity.LEGENDARY: Color(0.9, 0.7, 0.15),
}


func _ready() -> void:
    custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
    
    # Create child nodes
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    add_child(vbox)
    
    # Suit + number
    suit_label = Label.new()
    suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    suit_label.add_theme_font_size_override("font_size", 20)
    vbox.add_child(suit_label)
    
    # Card name
    name_label = Label.new()
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 18)
    vbox.add_child(name_label)
    
    # Type tag
    type_label = Label.new()
    type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    type_label.add_theme_font_size_override("font_size", 12)
    vbox.add_child(type_label)
    
    gui_input.connect(_on_gui_input)


func setup(card: CardData) -> void:
    card_data = card
    _refresh_display()


func _refresh_display() -> void:
    if card_data == null:
        return
    
    suit_label.text = "%s %s" % [card_data.suit_symbol(), card_data.number_display]
    suit_label.add_theme_color_override("font_color", SUIT_COLORS.get(card_data.suit, Color.WHITE))
    
    name_label.text = card_data.name_zh
    
    var type_names := ["", "基本", "錦囊", "裝備", "延時"]
    type_label.text = type_names[card_data.card_type]
    
    var style := StyleBoxFlat.new()
    style.bg_color = RARITY_BORDERS.get(card_data.rarity, Color.GRAY).darkened(0.6)
    style.border_width_left = 3
    style.border_width_right = 3
    style.border_width_top = 3
    style.border_width_bottom = 3
    style.border_color = RARITY_BORDERS.get(card_data.rarity, Color.GRAY)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    add_theme_stylebox_override("panel", style)


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        card_clicked.emit(card_data)
        modulate = Color(1.2, 1.2, 1.2)
        await get_tree().create_timer(0.1).timeout
        modulate = Color.WHITE


func highlight(active: bool) -> void:
    if active:
        modulate = Color(1.3, 1.3, 1.0)
        position.y -= 20
    else:
        modulate = Color.WHITE
        position.y += 20
