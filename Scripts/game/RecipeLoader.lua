dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")
ModDatabase.loadShapesets()

local sv_mod_uuid_table = ModDatabase.getAllLoadedMods()

local function load_recipes_and_store_in_table(path, out_table)
	if sm.json.fileExists(path) then
		local success, json_data = pcall(sm.json.open, path)
		if success == true then
			print("Loading modded crafting recipes:", path)

			for k, mod_recipe in ipairs(json_data) do
				out_table[#out_table + 1] = mod_recipe
			end
		end
	end
end

--this list contains the mods that already have crafting recipes, but they will most likely not be compatible with the custom game
local mod_exception_list =
{
	["f5452069-d631-422c-a1dc-2957c935cbaa"] =
	{
		craftbot = "/CraftingRecipes/nomad_default.json"
	},
	["df10d497-a28e-4413-a707-5a07813aec37"] =
	{
		craftbot = "/Survival/CraftingRecipes/craftbot.json"
	}
}

local function load_modded_crafting_recipes(out_table, file_name)
	for k, mod_uuid in ipairs(sv_mod_uuid_table) do
		local cur_exception = mod_exception_list[mod_uuid]
		local mod_key = "$CONTENT_"..mod_uuid

		if cur_exception == nil then
			local full_path = mod_key.."/CraftingRecipes/"..file_name..".json"

			load_recipes_and_store_in_table(full_path, out_table)
		else
			local cur_exc_path = cur_exception[file_name]
			if cur_exc_path ~= nil then
				local full_path = mod_key..cur_exc_path

				load_recipes_and_store_in_table(full_path, out_table)
			end
		end
	end
end

cmi_merged_recipes_paths =
{
	craftbot = "$CONTENT_DATA/Scripts/MergedRecipes.json",
	workbench = "$CONTENT_DATA/Scripts/WorkbenchMergedRecipes.json",
	hideout = "$CONTENT_DATA/Scripts/HideoutMergedRecipes.json"
}

local function merge_craftbot_recipes(game_path, name)
	local merged_recipes = {}

	load_recipes_and_store_in_table(game_path, merged_recipes)
	load_modded_crafting_recipes(merged_recipes, name)

	sm.json.save(merged_recipes, cmi_merged_recipes_paths[name])
end

function merge_custom_crafting_recipes()
	merge_craftbot_recipes("$SURVIVAL_DATA/CraftingRecipes/craftbot.json", "craftbot")
	merge_craftbot_recipes("$SURVIVAL_DATA/CraftingRecipes/workbench.json", "workbench")
	merge_craftbot_recipes("$SURVIVAL_DATA/CraftingRecipes/hideout.json", "hideout")
end