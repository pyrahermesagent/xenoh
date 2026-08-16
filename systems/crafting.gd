class_name CraftingSystem
## Data-driven crafting: recipes come from balance.json `crafting` section.
## A recipe is craftable when every required material count is available.

var balance: Dictionary
var inventory: InventorySystem


func _init(p_balance: Dictionary, p_inventory: InventorySystem) -> void:
	balance = p_balance
	inventory = p_inventory


func recipes() -> Array[String]:
	var out: Array[String] = []
	for r in balance.get("crafting", {}):
		out.append(str(r))
	return out


func recipe_of(item: String) -> Dictionary:
	return balance.get("crafting", {}).get(item, {})


func required_materials(item: String) -> Dictionary:
	## { material: qty } for a recipe.
	return recipe_of(item)


func can_craft(item: String) -> bool:
	var rec: Dictionary = recipe_of(item)
	if rec.is_empty():
		return false
	for mat in rec:
		if not inventory.has(str(mat), int(rec[mat])):
			return false
	return true


func craft(item: String) -> bool:
	## Consume materials, add the item. Returns success (false if uncraftable).
	if not can_craft(item):
		return false
	var rec: Dictionary = recipe_of(item)
	for mat in rec:
		inventory.take(str(mat), int(rec[mat]))
	inventory.add(item, 1)
	return true
