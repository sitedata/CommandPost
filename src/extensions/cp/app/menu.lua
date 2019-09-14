--- === cp.app.menu ===
---
--- Represents an app's menu bar, providing multi-lingual access to find and
--- trigger menu items.

local require           = require
local log               = require "hs.logger".new "menu"

local fs                = require "hs.fs"

local archiver          = require "cp.plist.archiver"
local axutils           = require "cp.ui.axutils"
local localeID          = require "cp.i18n.localeID"
local plist             = require "cp.plist"
local prop              = require "cp.prop"
local rx                = require "cp.rx"
local go                = require "cp.rx.go"

local format            = string.format
local insert            = table.insert
local remove            = table.remove
local concat            = table.concat
local Observable        = rx.Observable

local Do                = go.Do
local If                = go.If
local Throw             = go.Throw
local Last              = go.Last

local menu = {}
menu.mt = {}

-- BASE_LOCALE -> string
-- Constant
-- Base Locale string.
local BASE_LOCALE = "Base"

-- STRINGS_EXT -> string
-- Constant
-- Strings File Extension.
local STRINGS_EXT = "strings"

--- cp.app.menu.ROLE -> string
--- Constant
--- The menu role
menu.ROLE = "AXMenuBar"

-- NIB_EXT -> string
-- Constant
-- NIB File Extension.
local NIB_EXT = "nib"

--- cp.app.menu.NIB_FILE -> string
--- Constant
--- Main NIB File.
menu.NIB_FILE = "NSMainNibFile"

-- STORYBOARD_EXT -> string
-- Constant
-- Storyboard folder extension
local STORYBOARD_EXT = "storyboardc"

--- cp.app.menu.STORYBOARD_NAME -> string
--- Constant
--- Main Storyboard name.
menu.STORYBOARD_FILE = "NSMainStoryboardFile"

local function isLocalizableString(value)
    if type(value) == "table" then
        local classname = value["$class"] and value["$class"]["$classname"] or nil
        return classname == "NSLocalizableString"
    end
    return false
end

local function stringValue(value)
    if type(value) == "string" then
        return value
    elseif isLocalizableString(value) then
        return value["NS.string"]
    end
end

local function stringKey(value)
    return isLocalizableString(value) and value.NSKey or nil
end

-- findLocaleFilePath(app, fileName) -> string
-- Function
-- Attempts to find the specified file name under the locale path for the provided app.
-- If the file cannot be found for the specific locale, it will try the `Base` locale instead.
--
-- Parameters:
-- * app        - The `cp.app` being searched for.
-- * fileName   - The specific file under the local folder to look for. E.g. "MainMenu.nib"
--
-- Returns:
-- * path       - The absolute path to the file name, or `nil` if not found.
local function findLocaleFilePath(app, locale, fileName)
    local resourcePath = app:resourcesPath()

    for _, alias in ipairs(locale.aliases) do
        local filePath = fs.pathToAbsolute(format("%s/%s.lproj/%s", resourcePath, alias, fileName))
        if filePath then
            return filePath
        end
    end

    return nil
end

local function findBaseFilePath(app, fileName)
    return app:baseResourcesPath() .. "/" .. fileName
end

local function findMenuNibPath(app, locale, nibName)
    return findLocaleFilePath(app, locale, nibName .. "." .. NIB_EXT)
end

local function findBaseMenuNibPath(app, nibName)
    return findBaseFilePath(app, nibName .. "." .. NIB_EXT)
end

-- findStoryboardPath(app, locale, storyboardName) -> string, string
-- Function
-- Attempts to find the Storyboard for the specified locale and storyboard name. If it can't be found
-- in the locale, it will attempt to find the `Base` locale instead.
--
-- Parameters:
-- * app            - The `cp.app` being searched.
-- * locale         - The `localeID` to search for.
-- * storyboardName - The name of the storyboard path to find.
--
-- Returns:
-- * path   - in the form `"<app path>/Contents/Resources/<locale>.lproj/<storyboardName>.storyboardc"`
local function findStoryboardPath(app, locale, storyboardName)
    local fileName = storyboardName .. "." .. STORYBOARD_EXT
    return findLocaleFilePath(app, locale, fileName) or findBaseFilePath(app, fileName)
end

local function findMenuStringsPath(app, locale, stringsFileName)
    return findLocaleFilePath(app, locale, stringsFileName .. "." .. STRINGS_EXT)
end

-- processMenu(menuData, localeCode, menu) -> table
-- Function
-- Loads a Main Menu locale.
--
-- Parameters:
--  * menuData      - Menu data.
--  * localeCode    - The local code string being processed (eg. "en", "pt_PT")
--  * menuCache     - The table containing the menu structure.
--
-- Returns:
--  * Menu
local function processMenu(menuData, localeCode, menuCache)
    if not menuData then
        return nil
    end
    --------------------------------------------------------------------------------
    -- Process the menu items:
    --------------------------------------------------------------------------------
    menuCache = menuCache or {}
    if menuData.NSMenuItems then
        for i, itemData in ipairs(menuData.NSMenuItems) do
            local item = menuCache[i] or {}
            local value = itemData.NSTitle
            local key = nil

            if isLocalizableString(value) then
                key = stringKey(value)
                value = stringValue(value)
            end
            item[localeCode] = value
            item.key = key
            item.separator = itemData.NSIsSeparator
            --------------------------------------------------------------------------------
            -- Check if there is a submenu:
            --------------------------------------------------------------------------------
            if itemData.NSSubmenu then
                item.submenu = processMenu(itemData.NSSubmenu, localeCode, item.submenu)
            end
            menuCache[i] = item
        end
    end
    return menuCache
end

local function processNib(menuNib, localeCode, menuCache)
    --------------------------------------------------------------------------------
    -- Find the 'MenuTitles' item:
    --------------------------------------------------------------------------------
    local menuTitles = nil
    for _, item in ipairs(menuNib["IB.objectdata"].NSObjectsKeys) do
        if item.NSName == "_NSMainMenu" and item["$class"] and item["$class"]["$classname"] == "NSMenu" then
            menuTitles = item
            break
        end
    end
    if menuTitles then
        menuCache[localeCode] = true
        --log.df("processNib: menuCache: %s", menuCache)
        return processMenu(menuTitles, localeCode, menuCache)
    else
        log.ef("Unable to locate Main .nib file for %s.", localeCode)
        return nil
    end
end

-- readMenuNib(path, theLocale, menuCache) -> boolean
-- Function
-- Reads the menu `.nib` file at the specified path, if it exists, then processes it to build out
-- the items inclosed into the `menuCache` table.
--
-- Parameters:
-- * path       - the path to the menu `.nib` file
-- * locale     - The `localeID` being processed.
-- * menuCache  - The `table` containing the cached menu items for all languages.
--
-- Returns:
-- * `true` if the `.nib` could be read and was processed, otherwise `false`.
local function readMenuNib(path, localeCode, menuCache)
    if path then
        local menuNib = archiver.unarchiveFile(path)
        if menuNib then
            processNib(menuNib, localeCode, menuCache)
            return true
        else
            log.ef("Unable to process the menu .nib file in: %s", path)
            return false
        end
    end
    return false
end

local function processStrings(app, menuStrings, localeCode, theMenu)
    if not theMenu[localeCode] then
        local baseLocale = app:baseLocale()
        for _, item in ipairs(theMenu) do
            local baseValue = item[baseLocale.code]
            local key = item.key
            -- try looking it up based on the key
            item[localeCode] = menuStrings and key and menuStrings[key] or baseValue

            if item.submenu then
                processStrings(app, menuStrings, localeCode, item.submenu)
            end
        end
    end
end

local function readStringsFile(app, locale, stringsName)
    local path = findMenuStringsPath(app, locale, stringsName)
    if path then
        return plist.fileToTable(path)
    end
end

local function loadMenuTitlesFromNib(app, locale, menuCache)
    local nibName = app:info()[menu.NIB_FILE]
    if not nibName then
        return false
    end

    local nibPath = findMenuNibPath(app, locale, nibName)
    if not nibPath or not readMenuNib(nibPath, locale.code, menuCache) then
        local baseLocale = app:baseLocale()
        if not menuCache[BASE_LOCALE] then
            local baseNibPath = findBaseMenuNibPath(app, nibName)
            readMenuNib(baseNibPath, baseLocale.code, menuCache)
        end

        -- 1. If currently in the app's `baseLocale` then apply the strings from the NSLocalizableStrings
        if locale == baseLocale then
            processStrings(app, nil, locale.code, menuCache)
        end

        -- 2. could be a 'strings' file for the individual locale
        local menuStrings = readStringsFile(app, locale, nibName)
        if menuStrings then
            -- Process the locale's .strings
            processStrings(app, menuStrings, locale.code, menuCache)
        end
    end

    return true
end

-- loadMenuTitlesFromStoryboard(app, locale, menuCache) -> boolean
-- Function
-- Attempts to load the menu titles into the `menuCache` from a storyboard.
-- If the storyboard cannot be found, or some other error occurs, it returns `false`, and typically an error is logged.
-- If the menu is already loaded into the cache, it returns `true`.
--
-- Parameters:
-- * app        - The `cp.app` being processed.
-- * locale     - The `localeID` to search for.
-- * menuCache  - The table of menus for all locales loaded so far.
--
-- Returns:
-- * `true` if the menus for the specified locale have been loaded, otherwise false.
local function loadMenuTitlesFromStoryboard(app, locale, menuCache)
    -- find out if we're working with a Storyboard
    local storyboardName = app:info()[menu.STORYBOARD_FILE]
    if not storyboardName then
        return false
    end

    -- then find the actual Storyboard path for the current locale...
    local storyboardPath = findStoryboardPath(app, locale, storyboardName)
    if not storyboardPath then
        log.ef("Unable to find main storyboard for %s in either the %s or `Base` locales.", app, locale)
        return false
    end

    if menuCache[locale.code] then
        -- already loaded
        return true
    end

    -- next, read the Storyboard's `Info.plist` to discover the menu's .nib file name.
    local info = plist.fileToTable(storyboardPath .. "/Info.plist")
    if not info then
        log.ef("Unable to find the `Info.plist` for the Storyboard at %q", storyboardPath)
        return false
    end

    -- now, find the actual main menu .nib for the storyboard...
    local menuName = info["NSStoryboardMainMenu"]
    local menuFile = fs.pathToAbsolute(storyboardPath .. "/" .. menuName .. ".nib")

    -- ... and process it.
    local menuNib = archiver.unarchiveFile(menuFile)
    if menuNib then
        processNib(menuNib, locale.code, menuCache)
        return true
    end

    return false
end

-- loadMenuTitlesLocale(app, locale, menuCache) -> table
-- Method
-- Loads a Main Menu locale.
--
-- Parameters:
--  * app       - The `cp.app` we're loading for.
--  * locale    - The `localeID`.
--  * menuCache - The menu table containing the main menu structure.
--
-- Returns:
--  * The menu table.
local function loadMenuTitlesLocale(app, locale, menuCache)
    locale = localeID(locale)
    if not locale then
        -- it's not a real locale (according to our records...)
        log.ef("Unable to find requested main menu locale: %s", locale)
        return false
    end

    -- get best supported locale
    locale = app:bestSupportedLocale(locale)
    if not locale then
        -- unable to find the locale.
        return false
    elseif menuCache[locale.code] then
        -- already processed.
        return true
    end

    return loadMenuTitlesFromNib(app, locale, menuCache) or loadMenuTitlesFromStoryboard(app, locale, menuCache)
end

function menu.matches(element)
    return element and element:attributeValue("AXRole") == menu.ROLE and #element > 0
end

--- cp.app.menu.new(app) -> menu
--- Constructor
--- Constructs a new menu for the specified App.
---
--- Parameters:
---  * app - The `cp.app` instance the menu belongs to.
---
--- Returns:
---  * a new menu instance
function menu.new(app)
    local o = prop.extend({
        _app = app,
        _menuTitles = {},
        _itemFinders = {}
    }, menu.mt)

    local UI = app.UI:mutate(function(original, self)
        return axutils.cache(self, "_ui", function()
            return axutils.childMatching(original(), menu.matches)
        end, menu.matches)
    end)

    local showing = UI:ISNOT(nil)

    prop.bind(o) {
        --- cp.app.menu.UI <cp.prop:hs._asm.axuielement; read-only; live>
        --- Field
        --- Returns the `axuielement` representing the menu.
        UI = UI,
        --- cp.app.menu.showing <cp.prop: boolean; read-only; live>
        --- Field
        --- Tells you if the app's Menu Bar is visible.
        showing = showing,
    }

    -- load default locale for the menu when the local changes.
    app.currentLocale:watch(function(newLocale)
        o:getMenuTitles({newLocale})
    end)

    return o
end

--- cp.app.menu:app() -> cp.app
--- Method
--- Returns the `cp.app` instance this belongs to.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `cp.app`.
function menu.mt:app()
    return self._app
end

--- cp.app.menu:getMenuTitles([locales]) -> table
--- Method
--- Returns a table with the available menus, items and sub-menu, in the specified locales (if available).
--- If no `locales` are specified, the app's current locale is loaded.
---
--- Parameters:
---  * locales       - An optional single `localeID` or a list of `localeID`s to ensure are loaded.
---
--- Returns:
---  * A table of Menu Bar Values
---
--- Notes:
--- * This menu may get added to over time if additional locales are loaded - previously loaded locales are not removed from the cache.
function menu.mt:getMenuTitles(locales)
    local app = self:app()
    if type(locales) ~= "table" then
        local locale = locales or app:currentLocale()
        locales = {locale}
    end

    local menuCache = self._menuTitles
    --log.df("getMenuTitles: before: menuCache: %s; _menuTitles: %s", menuCache, self._menuTitles)
    for _, locale in ipairs(locales) do
        loadMenuTitlesLocale(app, locale, menuCache)
    end
    --log.df("getMenuTitles: after: menuCache: %s; _menuTitles: %s", menuCache, self._menuTitles)

    return menuCache
end

--- cp.app.menu:doSelectMenu(path, options) -> cp.rx.go.Statement <boolean>
--- Method
--- Selects a Menu Item based on the provided menu path.
---
--- Parameters:
---  * path - The list of menu items you'd like to activate.
---  * options - (optional) The table of options to apply.
---
--- Returns:
---  * The `Statement`, ready to execute.
---
--- Notes:
--- * Each step on the path can be either one of:
---   * a string     - The exact name of the menu item.
---   * a number     - The menu item number, starting from 1.
---   * a function   - Passed one argument - the Menu UI to check - returning `true` if it matches.
--- * The `options` may include:
---   * locale - The `localeID` or `string` for the locale that the path values are in.
---   * pressAll - If `true`, all menu items will be pressed on the way to the final destination.
---   * plain    - Whether or not to disable the pattern matching feature. Defaults to `false`.
--- * Examples:
---   * `previewApp:menu():doSelectMenu({"File", "Take Screenshot", "From Entire Screen"}):Now()`
function menu.mt:doSelectMenu(path, options)
    options = options or {}
    local findMenu = self:doFindMenuUI(path, options)

    if not options.pressAll then
        findMenu = Last(findMenu)
    end

    return Do(findMenu)
    :Then(function(item)
        if item:attributeValue("AXEnabled") then
            item:doPress()
            return true
        else
            return Throw("Menu Item Disabled: %s", item:attributeValue("AXTitle"))
        end
    end)
    :ThenYield()
    :Label("menu:doSelectMenu")
end

--- cp.app.menu:selectMenu(path[, options]) -> boolean
--- Method
--- Selects a Menu Item based on the list of menu titles in English.
---
--- Parameters:
---  * path - The list of menu items you'd like to activate.
---  * options - (optional) The table of options to apply.
---
--- Returns:
---  * `true` if the press was successful.
---
--- Notes:
--- * Each step on the path can be either one of:
---   * a string     - The exact name of the menu item.
---   * a number     - The menu item number, starting from 1.
---   * a function   - Passed one argument - the Menu UI to check - returning `true` if it matches.
--- * The `options` may include:
---   * locale - The `localeID` or `string` for the locale that the path values are in.
---   * pressAll - If `true`, all menu items will be pressed on the way to the final destination.
---   * plain    - Whether or not to disable the pattern matching feature. Defaults to `false`.
--- * Example usage:
---   * `require("cp.app").forBundleID("com.apple.FinalCut"):menu():selectMenu({"View", "Browser", "Toggle Filmstrip/List View"})`
function menu.mt:selectMenu(path, options)
    options = options or {}

    local menuItemUI, menuPath = self:findMenuUI(path, options)

    if options.pressAll and #menuPath > 0 then
        for _, ui in ipairs(menuPath) do
            if ui:attributeValue("AXEnabled") then
                ui:performAction("AXPress")
            else
                return false
            end
        end
        return true
    elseif menuItemUI and menuItemUI:attributeValue("AXEnabled") then
        menuItemUI:performAction("AXPress")
        return true
    end
    return false
end

-- _isMenuChecked(menu) -> boolean
-- Function
-- Is a menu item checked?
--
-- Parameters:
--  * menuItem - The `axuielementObject` of the menu
--
-- Returns:
--  * `true` if checked otherwise `false`.
local function _isMenuChecked(menuItem)
    return menuItem:attributeValue("AXMenuItemMarkChar") ~= nil
end

--- cp.app.menu:isChecked(path[, options]) -> boolean
--- Method
--- Is a menu item checked?
---
--- Parameters:
---  * path - At table containing the path to the menu bar item.
---  * options - The locale the path is in. Defaults to "en".
---
--- Returns:
---  * `true` if checked otherwise `false`.
---
--- Notes:
--- * The `options` may include:
---   * locale   - The `localeID` or `string` with the locale code. Defaults to "en".
function menu.mt:isChecked(path, options)
    local menuItemUI = self:findMenuUI(path, options)
    return menuItemUI and _isMenuChecked(menuItemUI)
end

--- cp.app.menu:isEnabled(path[, options]) -> boolean
--- Method
--- Is a menu item enabled?
---
--- Parameters:
---  * path - At table containing the path to the menu bar item.
---  * options - The optional table of options.
---
--- Returns:
---  * `true` if enabled otherwise `false`.
---
--- Notes:
--- * The `options` may include:
---   * locale   - The `localeID` or `string` with the locale code. Defaults to "en".
function menu.mt:isEnabled(path, options)
    local menuItemUI = self:findMenuUI(path, options)
    return menuItemUI and menuItemUI:attributeValue("AXEnabled")
end

--- cp.app.menu:doIsEnabled(path, options) -> cp.rx.go.Statement
--- Method
--- A [Statement](cp.rx.go.Statement.md) that returns `true` if the item at the end of the path is enabled.
---
--- Parameters:
--- * path      - The menu path to check.
--- * options   - The options.
---
--- Returns:
--- * A [Statement](cp.rx.go.Statement.md) to execute.
function menu.mt:doIsEnabled(path, options)
    return Do(Last(self:doFindMenuUI(path, options)))
    :Then(function(item)
        return item:attributeValue("AXEnabled") == true
    end)
end

--- cp.app.menu:addMenuFinder(finder) -> nothing
--- Method
--- Registers an `AXMenuItem` finder function. The finder's job is to take an individual 'find'
--- step and return either the matching child, or `nil` if it can't be found.
--- It is used by the [addMenuFinder](#addMenuFinder) function.
---
--- Parameters:
---  * `finder`     - The finder function
---
--- Returns:
---  * The `AXMenuItem` found, or `nil`.
---
--- Notes:
--- * The `finder` should have the following signature:
---   * `function(parentItem, path, childName, locale) -> childItem`
--- * The elements are:
---   * parentItem    - The `AXMenuItem` containing the children. E.g. the `Go To` menu under `Window`.
---   * path          - An array of strings in the specified locale leading to the parent item. E.g. `{"Window", "Go To"}`.
---   * childName     - The name of the next child to find, in the specified locale. E.g. `"Libraries"`.
---   * locale        - The `cp.i18n.localeID` that the menu titles are in.
---   * childItem     - The `AXMenuItem` that was found, or `nil` if not found.

function menu.mt:addMenuFinder(finder)
    self._itemFinders[#self._itemFinders + 1] = finder
end

-- _translateTitle(menuTitles, title, sourceLocale, targetLocale) -> string
-- Function
-- Looks through the `menuTitles` to find a matching title in the source locale,
-- and returns the equivalent in the target locale, or the original title if it can't be found.
--
-- Parameters:
--  * menuTitles - A table containing the menu map.
--  * title - The title
--  * sourceLocale - Source `cp.i18n.localeID`
--  * targetLocale - Target `cp.i18n.localeID`
--
-- Returns:
--  * The translated title as a string.
local function _translateTitle(menuTitles, title, sourceLocale, targetLocale)
    if menuTitles then
        local sourceCode, targetCode = sourceLocale.code, targetLocale.code
        for _,item in ipairs(menuTitles) do
            if item[sourceCode] == title then
                return item[targetCode]
            end
        end
    end
    return title
end

local function exactMatch(value, pattern, plain)
    if value and pattern then
        local s,e = value:find(pattern, nil, plain)
        return s == 1 and e == value:len()
    end
    return false
end

--- cp.app.menu:doFindMenuUI(path[, options]) -> cp.rx.go.Statement <hs._asm.axuielement>
--- Method
--- Returns a `Statement` that when executed will emit each of the menu items along the path.
---
--- Parameters:
---  * path         - the table of path items.
---  * options      - (optional) table of additional configuration options.
---
--- Returns:
---  * The `Statement`, ready to be executed.
---
--- Notes:
--- * Each step on the path can be either one of:
---   * a string     - The exact name of the menu item.
---   * a number     - The menu item number, starting from 1.
---   * a function   - Passed one argument - the Menu UI to check - returning `true` if it matches.
--- * The `options` may contain:
---   * locale   - The locale that any strings in the path are in. Defaults to "en".
---   * plain    - Whether or not to disable the pattern matching feature. Defaults to `false`.
--- * Examples:
---   * `myApp:menu():doFindMenuUI({"Edit", "Copy"}):Now(function(item) print(item:title() .. " enabled: ", item:enabled()) end, error)`
function menu.mt:doFindMenuUI(path, options)
    if type(path) ~= "table" or #path == 0 then
        return Observable.throw("Please provide a table array of menu steps.")
    end
    options = options or {}

    -- make sure the app is active.
    return If(self.UI):Then(function(ui)
        local en = localeID("en")
        local pathLocale = localeID(options.locale) or en
        local appLocale = self:app():currentLocale()

        local menuTitles = self:getMenuTitles({pathLocale, appLocale, en})
        local currentPath = {}

        local menuItemName
        local menuUI = ui

        return Do(Observable.fromTable(path, ipairs)):Then(
            function(step)
                local menuItemUI
                local currentMenuTitles = menuTitles
                if type(step) == "number" then
                    menuItemUI = menuUI[step]
                    menuItemName = _translateTitle(menuTitles, menuItemUI, appLocale, pathLocale)
                elseif type(step) == "function" then
                    for _, child in ipairs(menuUI) do
                        if step(child) then
                            menuItemUI = child
                            menuItemName = _translateTitle(menuTitles, menuItemUI, appLocale, pathLocale)
                            break
                        end
                    end
                else
                    menuItemName = step
                    --------------------------------------------------------------------------------
                    -- Check with the finder functions:
                    --------------------------------------------------------------------------------
                    for _, finder in ipairs(self._itemFinders) do
                        menuItemUI = finder(menuUI, currentPath, step, en)
                        if menuItemUI then
                            break
                        end
                    end

                    if not menuItemUI and menuTitles then
                        --------------------------------------------------------------------------------
                        -- See if the menu is in the map:
                        --------------------------------------------------------------------------------
                        for _, item in ipairs(menuTitles) do
                            local pathItemTitle = item[pathLocale.code]
                            if exactMatch(pathItemTitle, step, options.plain) then
                                menuItemUI = item.ui
                                if not axutils.isValid(menuItemUI) then
                                    local currentTitle = item[appLocale.code]
                                    if currentTitle then
                                        currentTitle = currentTitle:gsub("%%@", ".*")
                                        menuItemUI = axutils.childMatching(menuUI, function(child)
                                            local title = child:attributeValue("AXTitle")
                                            if title == nil then
                                                error(format("Unexpected `nil` menu item title while searching for '%s'", currentTitle))
                                            end
                                            return exactMatch(title, currentTitle, options.plain)
                                        end)
                                        --------------------------------------------------------------------------------
                                        -- Cache the menu item, since getting children can be expensive:
                                        --------------------------------------------------------------------------------
                                        item.ui = menuItemUI
                                    else
                                        return Throw("Unable to find '%s' in '%s' with %s.", pathItemTitle, (#currentPath > 0 and concat(currentPath, " > ") or self:app():displayName()), appLocale.code)
                                    end
                                end
                                menuTitles = item.submenu
                                break
                            end
                        end
                    end
                end

                if menuItemUI then

                    if #menuItemUI == 1 then
                        -- the item is a sub-menu. Find the next values.
                        menuUI = menuItemUI[1]
                        for _, item in ipairs(menuTitles) do
                            local mapTitle = item[appLocale.code]
                            if mapTitle and exactMatch(menuItemUI:attributeValue("AXTitle"), mapTitle:gsub("%%@", ".*"), options.plain) then
                                menuTitles = item
                                break
                            end
                        end
                    end

                    -- translate the item name to English for use in finders.
                    local menuItemNameEn = _translateTitle(currentMenuTitles, menuItemName, pathLocale, en)
                    insert(currentPath, menuItemNameEn)

                    return menuItemUI
                else
                    return Throw("Unable to find '%s' in '%s' while in '%s'.", step, (#currentPath > 0 and concat(currentPath, " > ") or self:app():displayName()), appLocale.code)
                end
            end
        )
    end)
    :Otherwise(
        If(self:app().running):Then(
            Throw("Unable to find the menu for %s.", self:app():displayName())
        ):Otherwise(
            Throw("%s is not curently running.", self:app():displayName())
        )
    )
    :TimeoutAfter(5000, "Took too long.")
    :Label("menu:doFindMenuUI")
end

--- cp.app.menu:findMenuUI(path[, options]) -> Menu UI, table
--- Method
--- Finds a specific Menu UI element for the provided path.
--- E.g. `findMenuUI({"Edit", "Copy"})` returns the 'Copy' menu item in the 'Edit' menu.
---
--- Parameters:
---  * path         - The path list to search for.
---  * options      - (Optional) The table of options.
---
--- Returns:
---  * The Menu UI, or `nil` if it could not be found.
---  * The full list of Menu UIs for the path in a table.
---
--- Notes:
--- * Each step on the path can be either one of:
---   * a string     - The exact name of the menu item.
---   * a number     - The menu item number, starting from 1.
---   * a function   - Passed one argument - the Menu UI to check - returning `true` if it matches.
--- * The `options` can contain:
---   * locale   - The `localeID` or `string` with the locale code. Defaults to "en".
---   * plain    - Whether or not to disable the pattern matching feature. Defaults to `false`.
function menu.mt:findMenuUI(path, options)
    assert(type(path) == "table" and #path > 0, "Please provide a table array of menu steps.")
    options = options or {}

    --------------------------------------------------------------------------------
    -- Start at the top of the menu bar list:
    --------------------------------------------------------------------------------
    local locale = options and localeID(options.locale) or localeID("en")
    local appLocale = self:app():currentLocale()

    local menuTitles = self:getMenuTitles({locale, appLocale})
    local menuUI = self:UI()
    if not menuUI then
        return nil
    end

    local menuItemUI = nil
    local menuItemName = nil
    local currentPath = {}
    local menuPath = {}

    --------------------------------------------------------------------------------
    -- Step through the path:
    --------------------------------------------------------------------------------
    for _, step in ipairs(path) do
        menuItemUI = nil
        --------------------------------------------------------------------------------
        -- Check what type of step it is:
        --------------------------------------------------------------------------------
        if type(step) == "number" then
            --------------------------------------------------------------------------------
            -- Access it by index:
            --------------------------------------------------------------------------------
            menuItemUI = menuUI[step]
            menuItemName = _translateTitle(menuTitles, menuItemUI, appLocale, locale)
        elseif type(step) == "function" then
            --------------------------------------------------------------------------------
            -- Check each child against the function:
            --------------------------------------------------------------------------------
            for _, child in ipairs(menuUI) do
                if step(child) then
                    menuItemUI = child
                    menuItemName = _translateTitle(menuTitles, menuItemUI, appLocale, locale)
                    break
                end
            end
        else
            --------------------------------------------------------------------------------
            -- Look it up by name:
            --------------------------------------------------------------------------------
            menuItemName = step
            --------------------------------------------------------------------------------
            -- Check with the finder functions:
            --------------------------------------------------------------------------------
            for _, finder in ipairs(self._itemFinders) do
                menuItemUI = finder(menuUI, currentPath, step, locale)
                if menuItemUI then
                    break
                end
            end

            if not menuItemUI and menuTitles then
                --------------------------------------------------------------------------------
                -- See if the menu is in the map:
                --------------------------------------------------------------------------------
                for _, item in ipairs(menuTitles) do
                    local pathItemTitle = item[locale.code]
                    if exactMatch(pathItemTitle, step, options.plain) then
                        menuItemUI = item.ui
                        if not axutils.isValid(menuItemUI) then
                            local currentTitle = item[appLocale.code]
                            if currentTitle then
                                currentTitle = currentTitle:gsub("%%@", ".*")
                                menuItemUI = axutils.childMatching(menuUI, function(child)
                                    local title = child:attributeValue("AXTitle")
                                    if title == nil then
                                        error(format("Unexpected `nil` menu item title while searching for '%s'", currentTitle))
                                    end
                                    --log.df("checking menu item: %s", title)
                                    return exactMatch(title, currentTitle, options.plain)
                                end)
                                --------------------------------------------------------------------------------
                                -- Cache the menu item, since getting children can be expensive:
                                --------------------------------------------------------------------------------
                                item.ui = menuItemUI
                            else
                                error(format("Unable to find '%s' in '%s' with %s.", pathItemTitle, concat(currentPath, " > ", appLocale)))
                            end
                        end
                        menuTitles = item.submenu
                        break
                    end
                end
            end
        end

        if menuItemUI then
            insert(menuPath, menuItemUI)
            if #menuItemUI == 1 then
                --------------------------------------------------------------------------------
                -- Assign the contained AXMenu to the menuUI,
                -- it contains the next set of AXMenuItems.
                --------------------------------------------------------------------------------
                menuUI = menuItemUI[1]
            end
            insert(currentPath, menuItemName)
        else
            --local value = type(step) == "string" and '"' .. step .. '" (' .. locale.code .. ")" or tostring(step)
            --log.wf("Unable to match step #%d in %s, a %s with a value of %s with the app in %s", i, inspect(path), type(step), value, appLocale)
            return nil
        end
    end

    return menuItemUI, menuPath
end

--- cp.app.menu:visitMenuItems(visitFn[, options]]) -> nil
--- Method
--- Walks the menu tree, calling the `visitFn` on all the 'item' values - that is,
--- `AXMenuItem`s that don't have any sub-menus.
---
--- Parameters:
---  * visitFn - The function called for each menu item.
---  * options - (optional) The table of options.
---
--- Returns:
---  * Nothing
---
--- Notes:
--- * The `options` may include:
---   * locale   - The `localeID` or `string` with the locale code. Defaults to "en".
---   * startPath - The path to the menu item to start at.
--- * The `visitFn` will be called on each menu item with the following parameters:
---   * `function(path, menuItem)`
--- * The `menuItem` is the AXMenuItem object, and the `path` is an array with the path to that menu item. For example, if it is the "Copy" item in the "Edit" menu, the path will be `{ "Edit" }`.
function menu.mt:visitMenuItems(visitFn, options)
    local menuUI
    local path = options and options.startPath or {}
    if #path > 0 then
        menuUI = self:findMenuUI(path, options)
        remove(path)
    else
        menuUI = self:UI()
    end
    if menuUI then
        self:_visitMenuItems(visitFn, path, menuUI, options)
    end
end

-- cp.app.menu:_visitMenuItems(visitFn, path, menuUI[, options]) -> hs._asm.axuielement
-- Method
-- Returns the set of menu items in the provided path. If the path contains a menu, the children are returned.
--
-- Parameters:
--  * visitFn - A function that is called on all the item values.
--  * path - Table containing the path to the menu
--  * menuUI - The `axuielement` of the menu item.
--  * options - The table of options.
--
-- Returns:
--  * An `axuielementObject` for the menu items.
function menu.mt:_visitMenuItems(visitFn, path, menuUI, options)
    local role = menuUI:attributeValue("AXRole")
    local children = menuUI:attributeValue("AXChildren")
    if role == "AXMenuBar" or role == "AXMenu" then
        if children then
            for _, item in ipairs(children) do
                self:_visitMenuItems(visitFn, path, item, options)
            end
        end
    elseif role == "AXMenuBarItem" or role == "AXMenuItem" then
        local title = menuUI:attributeValue("AXTitle")
        if #children == 1 then
            --------------------------------------------------------------------------------
            -- Add the title:
            --------------------------------------------------------------------------------
            insert(path, title)
            self:_visitMenuItems(visitFn, path, children[1], options)
            --------------------------------------------------------------------------------
            -- Drop the extra title:
            --------------------------------------------------------------------------------
            remove(path)
        else
            if title ~= nil and title ~= "" then
                visitFn(path, menuUI)
            end
        end
    end
end

function menu.mt:__tostring()
    return format("cp.app.menu: %s", self:app():bundleID())
end

return menu