local VERSION = 1.2 -- UPDATE description.json ASWELL!!!!!!
g_checkForUpdates = true -- delcare to check for updates

function checkRaftVersion()
	g_checkForUpdates = false -- set it here incase it errors out.
    
    local success, data = pcall(sm.json.open, '$CONTENT_3df6725e-462a-47e3-92ed-e5b66883588c/description.json' )

	if not success then return end -- If the file doesn't exist, don't bother checking the version

	local fileModVersion = data.fileModVersion
	local needsUpdate = fileModVersion ~= nil and VERSION < fileModVersion -- compare using (float) numbers
	
	if needsUpdate then
		sm.gui.chatMessage("[Raft Mechanic] You're on version " .. tostring(VERSION) .. " and version " .. tostring(fileModVersion) .. " is available, please update!" )
	end

    sm.log.info("[Raft Mechanic] You're on version: " .. tostring(VERSION) .. " and version.json is: " .. tostring(fileModVersion) )
end
