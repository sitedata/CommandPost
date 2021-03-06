--- === plugins.core.tangent.prefs ===
---
--- Tangent Preferences Panel

local require = require

local log         = require "hs.logger".new "tangentPref"

local dialog      = require "hs.dialog"
local image       = require "hs.image"

local html        = require "cp.web.html"
local i18n        = require "cp.i18n"

local moses       = require "moses"

local mod = {}

-- TANGENT_WEBSITE -> string
-- Constant
-- Tangent Website URL.
local TANGENT_WEBSITE = "http://www.tangentwave.co.uk/"

-- DOWNLOAD_TANGENT_HUB -> string
-- Constant
-- URL to download Tangent Hub Application.
local DOWNLOAD_TANGENT_HUB = "http://www.tangentwave.co.uk/download/tangent-hub-installer-mac/"

-- renderPanel(context) -> none
-- Function
-- Generates the Preference Panel HTML Content.
--
-- Parameters:
--  * context - Table of data that you want to share with the renderer
--
-- Returns:
--  * HTML content as string
local function renderPanel(context)
    if not mod._renderPanel then
        local errorMessage
        mod._renderPanel, errorMessage = mod._env:compileTemplate("html/panel.html")
        if errorMessage then
            log.ef(errorMessage)
            return nil
        end
    end
    return mod._renderPanel(context)
end

-- generateContent() -> string
-- Function
-- Generates the Preference Panel HTML Content.
--
-- Parameters:
--  * None
--
-- Returns:
--  * HTML content as string
local function generateContent()
    local context = {
        _                       = moses,
        webviewLabel            = mod._prefsManager.getLabel(),
        maxItems                = mod._favourites.MAX_ITEMS,
        favourites              = mod._favourites.favourites(),
        none                    = i18n("none"),
        i18n                    = i18n,
    }
    return renderPanel(context)
end

-- tangentPanelCallback() -> none
-- Function
-- JavaScript Callback for the Preferences Panel
--
-- Parameters:
--  * id - ID as string
--  * params - Table of paramaters
--
-- Returns:
--  * None
local function tangentPanelCallback(id, params)
    local injectScript = mod._prefsManager.injectScript
    if params and params["type"] then
        if params["type"] == "updateAction" then

            --------------------------------------------------------------------------------
            -- Setup Activators:
            --------------------------------------------------------------------------------
            if not mod.activator then
                --------------------------------------------------------------------------------
                -- Create new Activator:
                --------------------------------------------------------------------------------
                mod.activator = mod._actionManager.getActivator("tangentPreferences")
                mod.activator:preloadChoices()
            end

            --------------------------------------------------------------------------------
            -- Setup Activator Callback:
            --------------------------------------------------------------------------------
            mod.activator:onActivate(function(handler, action, text)

                    --------------------------------------------------------------------------------
                    -- Process Stylised Text:
                    --------------------------------------------------------------------------------
                    if text and type(text) == "userdata" then
                        text = text:convert("text")
                    end

                    local actionTitle = text

                    local handlerID = handler:id()
                    local buttonID = params.buttonID
                    mod._favourites.saveAction(buttonID, actionTitle, handlerID, action)
                    injectScript("setTangentAction(" .. buttonID .. ", '" .. actionTitle .. "')")
                end)

            --------------------------------------------------------------------------------
            -- Show Activator:
            --------------------------------------------------------------------------------
            mod.activator:show()
        elseif params["type"] == "clearAction" then
            local buttonID = params.buttonID
            mod._favourites.clearAction(buttonID)
            injectScript("setTangentAction(" .. buttonID .. ", '" .. i18n("none") .. "')")

        else
            --------------------------------------------------------------------------------
            -- Unknown Callback:
            --------------------------------------------------------------------------------
            log.df("Unknown Callback in Tangent Preferences Panel:")
            log.df("id: %s", hs.inspect(id))
            log.df("params: %s", hs.inspect(params))
        end
    end
end

--- plugins.core.tangent.prefs.init() -> none
--- Function
--- Initialise Module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.init(deps, env)
    --------------------------------------------------------------------------------
    -- Inter-plugin Connectivity:
    --------------------------------------------------------------------------------
    mod._actionManager  = deps.actionManager
    mod._prefsManager   = deps.prefsManager
    mod._tangentManager = deps.tangentManager
    mod._favourites     = deps.favourites
    mod._env            = env

    --------------------------------------------------------------------------------
    -- Setup Tangent Preferences Panel:
    --------------------------------------------------------------------------------
    mod._panel = mod._prefsManager.addPanel({
        priority    = 2032.1,
        id          = "tangent",
        label       = i18n("tangentPanelLabel"),
        image       = image.imageFromPath(env:pathToAbsolute("/images/tangent.icns")),
        tooltip     = i18n("tangentPanelTooltip"),
        height      = 750,
    })
        :addContent(1, html.style ([[
            .tangentButtonOne {
                float:left;
                width: 192px;
            }
            .tangentButtonTwo {
                float:left;
                margin-left: 5px;
                width: 192px;
            }
            .tangentButtonThree {
                clear:both;
                float:left;
                margin-top: 5px;
                width: 192px;
            }
            .tangentButtonFour {
                float:left;
                margin-top: 5px;
                margin-left: 5px;
                width: 192px;
            }
        ]], true))
        :addHeading(2, i18n("tangentPanelSupport"))
        :addParagraph(3, i18n("tangentPreferencesInfo"), false)
        :addParagraph(3.2, html.br())
        --------------------------------------------------------------------------------
        -- Enable Tangent Support:
        --------------------------------------------------------------------------------
        :addCheckbox(4,
            {
                label = i18n("enableTangentPanelSupport"),
                onchange = function(_, params)
                    if params.checked and not mod._tangentManager.tangentHubInstalled() then
                        dialog.webviewAlert(mod._prefsManager.getWebview(), function()
                            mod._tangentManager.enabled(false)
                            mod._prefsManager.injectScript([[
                                document.getElementById("enableTangentSupport").checked = false;
                            ]])
                        end, i18n("tangentPanelSupport"), i18n("mustInstallTangentMapper"), i18n("ok"))
                    else
                        mod._tangentManager.enabled(params.checked)
                    end
                end,
                checked = mod._tangentManager.enabled,
                id = "enableTangentSupport",
            }
        )
        :addParagraph(5, html.br())
        --------------------------------------------------------------------------------
        -- Open Tangent Mapper:
        --------------------------------------------------------------------------------
        :addButton(6,
            {
                label = i18n("openTangentMapper"),
                onclick = function()
                    if mod._tangentManager.tangentMapperInstalled() then
                        mod._tangentManager.launchTangentMapper()
                    else
                        dialog.webviewAlert(mod._prefsManager.getWebview(), function() end, i18n("tangentMapperNotFound"), i18n("tangentMapperNotFoundMessage"), i18n("ok"))
                    end
                end,
                class = "tangentButtonOne",
            }
        )
        --------------------------------------------------------------------------------
        -- Download Tangent Hub:
        --------------------------------------------------------------------------------
        :addButton(8,
            {
                label = i18n("downloadTangentHub"),
                onclick = function()
                    os.execute('open "' .. DOWNLOAD_TANGENT_HUB .. '"')
                end,
                class = "tangentButtonTwo",
            }
        )
        --------------------------------------------------------------------------------
        -- Visit Tangent Website:
        --------------------------------------------------------------------------------
        :addButton(9,
            {
                label = i18n("visitTangentWebsite"),
                onclick = function()
                    os.execute('open "' .. TANGENT_WEBSITE .. '"')
                end,
                class = "tangentButtonTwo",
            }
        )
        :addParagraph(10, html.br())
        :addParagraph(11, html.br())
        :addHeading(12, i18n("tangent") .. " " .. i18n("favourites"))
        :addParagraph(13, i18n("tangentFavouriteDescription"), false)
        :addContent(14, generateContent, false)

        --------------------------------------------------------------------------------
        -- Setup Callback Manager:
        --------------------------------------------------------------------------------
        :addHandler("onchange", "tangentPanelCallback", tangentPanelCallback)

    return mod

end

local plugin = {
    id              = "core.tangent.prefs",
    group           = "core",
    dependencies    = {
        ["core.controlsurfaces.manager"]        = "prefsManager",
        ["core.tangent.manager"]                = "tangentManager",
        ["core.tangent.commandpost.favourites"] = "favourites",
        ["core.action.manager"]                 = "actionManager",
    }
}

function plugin.init(deps, env)
    return mod.init(deps, env)
end

return plugin
