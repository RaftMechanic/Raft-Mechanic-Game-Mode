quest_use_terminal = "be627075-4fc5-4c7d-a3b8-aec040b9776f"
quest_pickup_logbook = "bfb6e5b6-3ee3-4310-a1b3-7608eb3ecb8d"

quest_mechanic_station = "bf68d177-878c-4017-b146-39354d44d888"
quest_radio_interactive = "26ca3794-71f2-4648-a97c-997802680c95"
quest_radio_location = "45fe7b9c-4895-44a3-82aa-ed8da730de83"

quest_find_trader = "4ea21139-8366-445c-8a7c-fe08f745c7db"
quest_deliver_vegetables = "00fb3de6-6dff-4cea-801c-d3e2d6d48890"
quest_return_to_trader1 = "6eb8bcf6-6c1b-4402-a417-b32bed57fd93"
quest_sunshake = "6a729c2c-f37c-4c9d-a1ad-b8f8e8dc49a0"
quest_return_to_trader2 = "ef505702-6198-4628-a1c4-a2e761ced9c5"
quest_fruits = "9f2c2a5e-1bc7-45a4-ae25-29b5a208dcab"
quest_return_to_trader3 = "b34e1f03-bac1-4a6c-9493-ab1aed823109"
quest_scrap_city = "be20e9dd-6f2c-4648-95fd-9e9bb58fe158"
quest_return_to_trader4 = "72968d01-d685-4356-b976-1de4611754d5"
quest_warehouse = "2d876d8e-908f-47cc-8149-78bd148b1c92"
quest_return_to_trader5 = "4c815041-a4c7-4764-a5dc-0fbaffabb544"

quest_chapter2 = "9d0c78a9-e980-4a0e-b623-ec9e447ef1ae"


SurvivalQuests = {
	[quest_use_terminal] = {
		followup = quest_pickup_logbook
	},

	[quest_pickup_logbook] = {
		followup = quest_mechanic_station
	},

	[quest_mechanic_station] = {
		followup = quest_radio_interactive
	},

	[quest_radio_interactive] = {
		followup = quest_radio_location
	},

	[quest_radio_location] = {
		followup = quest_find_trader
	},

	[quest_find_trader] = {
		followup = quest_deliver_vegetables
	},

	[quest_deliver_vegetables] = {
		followup = quest_return_to_trader1
	},

	[quest_return_to_trader1] = {
		followup = quest_sunshake
	},

	[quest_sunshake] = {
		followup = quest_return_to_trader2
	},

	[quest_return_to_trader2] = {
		followup = quest_fruits
	},

	[quest_fruits] = {
		followup = quest_return_to_trader3
	},

	[quest_return_to_trader3] = {
		followup = quest_scrap_city
	},

	[quest_scrap_city] = {
		followup = quest_return_to_trader4
	},

	[quest_return_to_trader4] = {
		followup = quest_warehouse
	},

	[quest_warehouse] = {
		followup = quest_return_to_trader5
	},

	[quest_return_to_trader5] = {
		followup = quest_chapter2
	}
}