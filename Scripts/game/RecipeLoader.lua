-- MIT License

-- Copyright (c) 2022 QuestionableM

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--https://github.com/QuestionableM/Modded-Craftbot-Recipes
--


dofile("$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua")

local function is_uuid_valid(uuid)
	local s_item = sm.item
	return s_item.isBlock(uuid) or s_item.isHarvestablePart(uuid) or s_item.isJoint(uuid) or s_item.isPart(uuid) or s_item.isTool(uuid)
end

local function load_recipes_and_store_in_table(path, out_table)
	local success, file_exists = pcall(sm.json.fileExists, path)
	if not (success == true and file_exists == true) then
		return
	end

	local success, json_data = pcall(sm.json.open, path)
	if success ~= true then
		return
	end

	local temp_recipe_storage = {}

	local l_table_insert = table.insert
	local l_uuid_new = sm.uuid.new

	for k, mod_recipe in ipairs(json_data) do
		if mod_recipe.craftTime == nil then
			mod_recipe.craftTime = 30
		end

		local success, item_uuid = pcall(l_uuid_new, mod_recipe.itemId)
		if success == true and is_uuid_valid(item_uuid) then
			l_table_insert(temp_recipe_storage, mod_recipe)
		else
			sm.log.warning("Found an invalid recipe in: ", path, item_uuid)
			return
		end
	end

	print("[CraftbotRecipes] Successfully loaded crafting recipes from:", path)
	for k, v in ipairs(temp_recipe_storage) do
		out_table[#out_table + 1] = v
	end
end

--this list contains the mods that already have crafting recipes, but they will most likely not be compatible with the custom game
local mod_exception_list =
{
	["df10d497-a28e-4413-a707-5a07813aec37"] = --wings mod
	{
		craftbot = "/Survival/CraftingRecipes/craftbot.json"
	}
}

cmi_merged_recipes_paths =
{
	craftbot  = "$CONTENT_DATA/Scripts/MergedRecipes.json",
	workbench = "$CONTENT_DATA/Scripts/WorkbenchMergedRecipes.json",
	hideout   = "$CONTENT_DATA/Scripts/HideoutMergedRecipes.json"
}

function merge_custom_crafting_recipes()
	ModDatabase.loadDescriptions()

	local craftbot_recipes  = {}
	local workbench_recipes = {}
	local hideout_recipes   = {}

	load_recipes_and_store_in_table("$CONTENT_DATA/CraftingRecipes/craftbot.json" , craftbot_recipes )
	load_recipes_and_store_in_table("$CONTENT_DATA/CraftingRecipes/workbench.json", workbench_recipes)
	load_recipes_and_store_in_table("$SURVIVAL_DATA/CraftingRecipes/hideout.json"  , hideout_recipes  )

	for mod_uuid, v in pairs(ModDatabase.databases.descriptions) do
		local cur_exception = mod_exception_list[mod_uuid]
		local mod_key = "$CONTENT_"..mod_uuid

		if cur_exception == nil then
			local recipe_folder = mod_key.."/CraftingRecipes/"

			load_recipes_and_store_in_table(recipe_folder.."craftbot.json", craftbot_recipes)
			load_recipes_and_store_in_table(recipe_folder.."workbench.json", workbench_recipes)
			load_recipes_and_store_in_table(recipe_folder.."hideout.json", hideout_recipes)
		else
			if cur_exception.craftbot then
				load_recipes_and_store_in_table(mod_key..cur_exception.craftbot, craftbot_recipes)
			end

			if cur_exception.workbench then
				load_recipes_and_store_in_table(mod_key..cur_exception.workbench, workbench_recipes)
			end

			if cur_exception.hideout then
				load_recipes_and_store_in_table(mod_key..cur_exception.hideout, hideout_recipes)
			end
		end
	end

	sm.json.save(craftbot_recipes, cmi_merged_recipes_paths.craftbot)
	sm.json.save(workbench_recipes, cmi_merged_recipes_paths.workbench)
	sm.json.save(hideout_recipes, cmi_merged_recipes_paths.hideout)
end