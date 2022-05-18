LanguageManager = class()

local fallbackLanguage = sm.json.open("$CONTENT_DATA/Gui/Language/English/tags.json")
local noTagFound = "nil"

function LanguageManager.client_onCreate(self)
    g_languageManager = self
end

function language_tag(name)
    local currentLang = sm.gui.getCurrentLanguage()
    if currentLang ~= g_languageManager.language then --when language changed
        g_languageManager.language = currentLang
        g_languageManager.tags = sm.json.open("$CONTENT_DATA/Gui/Language/"..g_languageManager.language.."/tags.json")
    end

    local textInJson = g_languageManager.tags[name]
    --try to find tag in the fall back language
    if textInJson == nil then
        textInJson = fallbackLanguage[name]
    end

    --return a fallback tag if its still nil somehow
    return textInJson == nil and noTagFound or textInJson
end

