LanguageManager = class()

function LanguageManager.client_onCreate(self)
    g_languageManager = self
end

function language_tag(name)
    if sm.gui.getCurrentLanguage() ~= g_languageManager.language then --when language changed
        g_languageManager.language = sm.gui.getCurrentLanguage()
        local languageFile = "$CONTENT_DATA/Gui/Language/" .. g_languageManager.language .. "/tags.json"
        g_languageManager.tags = sm.json.open(languageFile)
    end

    local textInJson = g_languageManager.tags[name]
    return textInJson == nil and "null" or textInJson
end

