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
ModDatabase.unloadDescriptions()
ModDatabase.loadDescriptions()

if not cmi_hideout_trader_storage then
	cmi_hideout_trader_storage = {}
end

if not cmi_crafter_object_storage then
	cmi_crafter_object_storage = {}
end

local _sm_shape_uuidExists = sm.shape.uuidExists
local _sm_tool_uuidExists  = sm.tool.uuidExists
local function is_uuid_valid(uuid)
	return _sm_shape_uuidExists(uuid) or _sm_tool_uuidExists(uuid)
end

local _sm_json_open   = sm.json.open
local _sm_uuid_new    = sm.uuid.new
local _sm_log_warning = sm.log.warning
local function is_recipe_file_valid(path, table, uuid_check)
	local success, json_data = pcall(_sm_json_open, path)
	if success ~= true then
		return
	end

	if uuid_check == true then
		for k, mod_recipe in ipairs(json_data) do
			if mod_recipe.craftTime == nil then
				mod_recipe.craftTime = 27
			end

			local success, item_uuid = pcall(_sm_uuid_new, mod_recipe.itemId)
			if not (success == true and is_uuid_valid(item_uuid)) then
				_sm_log_warning("Found an invalid recipe in: ", path, item_uuid)
				return
			end
		end
	end

	print("Found a valid file:", path)
	table[#table + 1] = path
end

--this list contains the mods that already have crafting recipes, but they will most likely not be compatible with the custom game
local mod_exception_list =
{
	["df10d497-a28e-4413-a707-5a07813aec37"] = --wings mod
	{
		craftbot = "/Survival/CraftingRecipes/craftbot.json"
	}
}

cmi_valid_crafting_recipes =
{
	craftbot  = {},
	workbench = {},
	hideout   = {}
}

local function sort_valid_recipe_files(out_table_ref, input_table)
	for k, v in ipairs(input_table) do
		is_recipe_file_valid(v, out_table_ref, true)
	end
end

local function clean_valid_recipes()
	cmi_valid_crafting_recipes.craftbot  = {}
	cmi_valid_crafting_recipes.workbench = {}
	cmi_valid_crafting_recipes.hideout   = {}
end

local _sm_exists = sm.exists
local _sm_event_sendToInteractable = sm.event.sendToInteractable
local function cmi_update_crafters(crafter_array, callback)
	for k, inter in pairs(crafter_array) do
		if inter and _sm_exists(inter) then
			_sm_event_sendToInteractable(inter, callback)
		end
	end
end

function cmi_update_all_crafters()
	cmi_update_crafters(cmi_hideout_trader_storage, "cl_updateTradeGrid")
	cmi_update_crafters(cmi_crafter_object_storage, "cl_updateRecipeGrid")
end

local _json_file_exists = sm.json.fileExists
function initialize_crafting_recipes()
	local l_craftbot_recipes  = { "$CONTENT_DATA/CraftingRecipes/craftbot.json" }
	local l_workbench_recipes = { "$CONTENT_DATA/CraftingRecipes/workbench.json" }
	local l_hideout_recipes   = { "$CONTENT_DATA/CraftingRecipes/hideout.json" }
 
	for mod_uuid, v in pairs(ModDatabase.databases.descriptions) do
		local mod_key = "$CONTENT_"..mod_uuid

		local success, fileExists = pcall(_json_file_exists, mod_key)
		if success == true and fileExists == true then
			local cur_exception = mod_exception_list[mod_uuid]

			if cur_exception == nil then
				local recipe_folder = mod_key.."/CraftingRecipes/"

				is_recipe_file_valid(recipe_folder.."craftbot.json" , l_craftbot_recipes )
				is_recipe_file_valid(recipe_folder.."workbench.json", l_workbench_recipes)
				is_recipe_file_valid(recipe_folder.."hideout.json"  , l_hideout_recipes  )
			else
				local exc_craftbot  = cur_exception.craftbot
				local exc_workbench = cur_exception.workbench
				local exc_hideout   = cur_exception.hideout

				if exc_craftbot then
					is_recipe_file_valid(mod_key..exc_craftbot, l_craftbot_recipes)
				end

				if exc_workbench then
					is_recipe_file_valid(mod_key..exc_workbench, l_workbench_recipes)
				end

				if exc_hideout then
					is_recipe_file_valid(mod_key..exc_hideout, l_hideout_recipes)
				end
			end
		end
	end

	--clean before setting new data
	clean_valid_recipes()

	--set new data
	sort_valid_recipe_files(cmi_valid_crafting_recipes.craftbot , l_craftbot_recipes )
	sort_valid_recipe_files(cmi_valid_crafting_recipes.workbench, l_workbench_recipes)
	sort_valid_recipe_files(cmi_valid_crafting_recipes.hideout  , l_hideout_recipes  )
end