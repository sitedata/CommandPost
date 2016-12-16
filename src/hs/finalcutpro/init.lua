--- === hs.finalcutpro ===
---
--- Controls for Final Cut Pro
---
--- Thrown together by:
---   Chris Hocking (https://github.com/latenitefilms)
---   David Peterson (https://randomphotons.com/)

local finalcutpro = {}

local finalCutProBundleID 					= "com.apple.FinalCut"
local finalCutProClipboardUTI 				= "com.apple.flexo.proFFPasteboardUTI"
local finalCutProPreferencesPlistPath 		= "~/Library/Preferences/com.apple.FinalCut.plist"
local finalCutProLanguages 					= {"de", "en", "es", "fr", "ja", "zh_CN"}
local finalCutProFlexoLanguages				= {"de", "en", "es_419", "es", "fr", "id", "ja", "ms", "vi", "zh_CN"}

local ax 									= require("hs._asm.axuielement")
local plist 								= require("hs.plist")

local application 							= require("hs.application")
local fs 									= require("hs.fs")
local osascript 							= require("hs.osascript")
local json									= require("hs.json")

local App									= require("hs.finalcutpro.App")
local just									= require("hs.just")

local log									= require("hs.logger").new("fcp")
local inspect								= require("hs.inspect")

--- doesDirectoryExist() -> boolean
--- Function
--- Returns true if Directory Exists else False
---
--- Parameters:
---  * None
---
--- Returns:
---  * True is Directory Exists otherwise False
---
local function doesDirectoryExist(path)
    local attr = fs.attributes(path)
    return attr and attr.mode == 'directory'
end

--- hs.finalcutpro.currentLanguage() -> string
--- Function
--- Returns the language Final Cut Pro is currently using.
---
--- Parameters:
---  * none
---
--- Returns:
---  * Returns the current language as string (or 'en' if unknown).
---
function finalcutpro.currentLanguage()

	-- If FCPX is already run, we determine the language off the menu:
	if finalcutpro.running() then
		local fcpxElements = ax.applicationElement(finalcutpro.application())
		if fcpxElements ~= nil then
			local whichMenuBar = nil
			if fcpxElements:attributeValueCount("AXChildren") ~= nil then
				if fcpxElements:attributeValueCount("AXChildren") > 0 then
					for i=1, fcpxElements:attributeValueCount("AXChildren") do
						if fcpxElements[i]:attributeValue("AXRole") == "AXMenuBar" then
							whichMenuBar = i
						end
					end
					if fcpxElements[whichMenuBar][3] ~= nil then

						local fileValue
						fileValue = fcpxElements[whichMenuBar][3]:attributeValue("AXTitle") or nil
						--------------------------------------------------------------------------------
						-- ENGLISH:		File
						-- GERMAN: 		Ablage
						-- SPANISH: 	Archivo
						-- FRENCH: 		Fichier
						-- JAPANESE:	ファイル
						-- CHINESE:		文件
						--------------------------------------------------------------------------------
						if fileValue == "File" 		then return "en" 		end
						if fileValue == "Ablage" 	then return "de" 		end
						if fileValue == "Archivo" 	then return "es" 		end
						if fileValue == "Fichier" 	then return "fr" 		end
						if fileValue == "ファイル" 	then return "ja" 		end
						if fileValue == "文件" 		then return "zh_CN" 	end
					end
				end
			end
		end
	end

	-- If FCPX is not running, we try to determine the language using Command Line Tools:
	local result = "en"
	local finalCutProLanguage = finalcutpro.getPreference("AppleLanguages", nil)

	if finalCutProLanguage ~= nil and next(finalCutProLanguage) ~= nil then
		if finalCutProLanguage[1] ~= nil then
			result = finalCutProLanguage[1]
		end
	else
		-- Use System Default Language:
		executeResult, executeStatus = hs.execute("defaults read NSGlobalDomain AppleLanguages")
		if executeResult ~= nil then
			if string.sub(executeResult, 1, 1) == "(" then

				local first = string.find(executeResult, '"')
				local second = string.find(executeResult, '-', first + 1)

				result = string.sub(executeResult, first + 1, second - 1)

				-- Only return languages Final Cut Pro actually supports:
				local validLanguage = false
				for i=1, #finalCutProLanguages do
					if result == finalCutProLanguages[i] then validLanguage = true end
				end

				if validLanguage then
					return result
				else
					return "en"
				end

			end
		end
	end

	return result

end

--- hs.finalcutpro.getTranslation() -> string/table or nil
--- Function
--- Returns a specific translation if language is set otherwise returns
--- a table of all different translations
---
--- Parameters:
---  * value - the value you want to translate
---  * [language] - (optional) the language you want to translate to (i.e. "en" for English)
---
--- Returns:
---  * Returns either the translation as a string or table, or nil if an error has occurred.
---
function finalcutpro.getTranslation(value, language)

	local result = nil
	if value == "Playhead" then
		--------------------------------------------------------------------------------
		-- ENGLISH:		Playhead
		-- GERMAN: 		Abspielposition
		-- SPANISH: 	Cursor de reproducción
		-- FRENCH: 		Tête de lecture
		-- JAPANESE:	再生ヘッド
		-- CHINESE:		播放头
		--------------------------------------------------------------------------------
		result = {
			["en"] 		= "Playhead",					-- English
			["de"] 		= "Abspielposition", 			-- German
			["es"] 		= "Cursor de reproducción",		-- Spanish
			["fr"] 		= "Tête de lecture",			-- French
			["ja"] 		= "再生ヘッド",					-- Japanese
			["zh_CN"] 	= "播放头",						-- Chinese
		}
	end
	if value == "Command Editor" then
		--------------------------------------------------------------------------------
		-- ENGLISH:		Command Editor
		-- GERMAN: 		Befehl-Editor
		-- SPANISH: 	Editor de comandos
		-- FRENCH: 		Éditeur de commandes
		-- JAPANESE:	コマンドエディタ
		-- CHINESE:		命令编辑器
		--------------------------------------------------------------------------------
			result = {
			["en"] 		= "Command Editor",				-- English
			["de"] 		= "Befehl-Editor", 				-- German
			["es"] 		= "Editor de comandos",			-- Spanish
			["fr"] 		= "Éditeur de commandes",		-- French
			["ja"] 		= "コマンドエディタ",				-- Japanese
			["zh_CN"] 	= "命令编辑器",					-- Chinese
		}
	end
	if value == "Media Import" then
		--------------------------------------------------------------------------------
		-- ENGLISH:		Media Import
		-- GERMAN: 		Medien importieren
		-- SPANISH: 	Importación de contenido
		-- FRENCH: 		Importation des médias
		-- JAPANESE:	メディアの読み込み
		-- CHINESE:		媒体导入
		--------------------------------------------------------------------------------
			result = {
			["en"] 		= "Media Import",				-- English
			["de"] 		= "Medien importieren", 		-- German
			["es"] 		= "Importación de contenido",	-- Spanish
			["fr"] 		= "Importation des médias",		-- French
			["ja"] 		= "メディアの読み込み",			-- Japanese
			["zh_CN"] 	= "媒体导入",					-- Chinese
		}
	end

	if result ~= nil then
		if language ~= nil then
			if result[language] ~= nil then
				local temp = result[language]
				result = nil
				result = temp
			end
		else
			language = finalcutpro.currentLanguage()
			if result[language] ~= nil then
				local temp = result[language]
				result = nil
				result = temp
			end
		end
	end

	return result

end

--- hs.finalcutpro.app() -> hs.application
--- Function
--- Returns the root Final Cut Pro application.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The root Final Cut Pro application.
---
function finalcutpro.app()
	if not finalcutpro._app then
		finalcutpro._app = App:new()
	end
	return finalcutpro._app
end

--- hs.finalcutpro.applicationAX() -> hs._asm.axuielement
--- Function
--- Returns the Final Cut Pro AX
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Final Cut Pro AX.
---
function finalcutpro.applicationAX()
	local fcp = finalcutpro.application()
	return fcp and ax.applicationElement(fcp)
end

--- hs.finalcutpro.getMenuMap() -> table
--- Function
--- Returns the Final Cut Pro Menu Map
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Final Cut Pro Menu Map.
---
function finalcutpro.getMenuMap()
	if not finalcutpro._menuMap then
		local file = io.open(menuMapFile, "r")
		if file then
			local content = file:read("*all")
			file:close()
			finalcutpro._menuMap = json.decode(content)
			log.d("Loaded menu map from '"..menuMapFile.."'")
		else
			finalcutpro._menuMap = {}
		end
	end
	return finalcutpro._menuMap
end

--- hs.finalcutpro.importXML() -> boolean
--- Function
--- Imports an XML file into Final Cut Pro
---
--- Parameters:
---  * path = Path to XML File
---
--- Returns:
---  * A boolean value indicating whether the AppleScript succeeded or not
---
function finalcutpro.importXML(path)

	if finalcutpro.running() then
		local appleScriptA = 'set whichSharedXMLPath to "' .. path .. '"' .. '\n\n'
		local appleScriptB = [[
			tell application "Final Cut Pro"
				activate
				open POSIX file whichSharedXMLPath as string
			end tell
		]]
		local bool, object, descriptor = osascript.applescript(appleScriptA .. appleScriptB)
		return bool
	end

end

--- hs.finalcutpro.flexoLanguages() -> table
--- Function
--- Returns a table of languages Final Cut Pro's Flexo Framework supports
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of languages Final Cut Pro supports
---
function finalcutpro.flexoLanguages()
	return finalCutProFlexoLanguages
end

--- hs.finalcutpro.languages() -> table
--- Function
--- Returns a table of languages Final Cut Pro supports
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of languages Final Cut Pro supports
---
function finalcutpro.languages()
	return finalCutProLanguages
end

--- hs.finalcutpro.clipboardUTI() -> string
--- Function
--- Returns the Final Cut Pro Bundle ID
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Final Cut Pro Bundle ID
---
function finalcutpro.bundleID()
	return finalCutProBundleID
end

--- hs.finalcutpro.clipboardUTI() -> string
--- Function
--- Returns the Final Cut Pro Clipboard UTI
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Final Cut Pro Clipboard UTI
---
function finalcutpro.clipboardUTI()
	return finalCutProClipboardUTI
end

--- hs.finalcutpro.getPreferences() -> table or nil
--- Function
--- Gets Final Cut Pro's Preferences as a table. It checks if the preferences
--- file has been modified and reloads when necessary.
---
--- Parameters:
---  * forceReload	- (optional) if true, a reload will be forced even if the file hasn't been modified.
---
--- Returns:
---  * A table with all of Final Cut Pro's preferences, or nil if an error occurred
---
function finalcutpro.getPreferences(forceReload)
	local modified = fs.attributes(finalCutProPreferencesPlistPath, "modification")
	if forceReload or modified ~= finalcutpro._preferencesModified then
		log.d("Reloading FCPX preferences from file...")
		finalcutpro._preferences = plist.binaryFileToTable(finalCutProPreferencesPlistPath) or nil
		finalcutpro._preferencesModified = modified
	 end
	return finalcutpro._preferences
end

--- hs.finalcutpro.getPreference(preferenceName) -> string or nil
--- Function
--- Get an individual Final Cut Pro preference
---
--- Parameters:
---  * preferenceName 	- The preference you want to return
---  * default			- (optional) The default value to return if the preference is not set.
---
--- Returns:
---  * A string with the preference value, or nil if an error occurred
---
function finalcutpro.getPreference(value, default)
	local result = nil

	local preferencesTable = finalcutpro.getPreferences()
	if preferencesTable ~= nil then
		result = preferencesTable[value]
	end

	if result == nil then
		result = default
	end

	return result
end

--- hs.finalcutpro.setPreference(key, value) -> boolean
--- Function
--- Sets an individual Final Cut Pro preference
---
--- Parameters:
---  * key - The preference you want to change
---  * value - The value you want to set for that preference
---
--- Returns:
---  * True if executed successfully otherwise False
---
function finalcutpro.setPreference(key, value)

	local executeResult, executeStatus

	if type(value) == "boolean" then
		executeResult, executeStatus = hs.execute("defaults write " .. finalCutProPreferencesPlistPath .. " " .. key .. " -bool " .. tostring(value))
	elseif type(value) == "table" then
		local arrayString = ""
		for i=1, #value do
			arrayString = arrayString .. value[i]
			if i ~= #value then
				arrayString = arrayString .. ","
			end
		end
		executeResult, executeStatus = hs.execute("defaults write " .. finalCutProPreferencesPlistPath .. " " .. key .. " -array '" .. arrayString .. "'")
	elseif type(value) == "string" then
		executeResult, executeStatus = hs.execute("defaults write " .. finalCutProPreferencesPlistPath .. " " .. key .. " -string '" .. value .. "'")
	end

	if executeStatus == nil then
		return false
	else
		return true
	end

end

--- hs.finalcutpro.getActiveCommandSetPath() -> string or nil
--- Function
--- Gets the 'Active Command Set' value from the Final Cut Pro preferences
---
--- Parameters:
---  * None
---
--- Returns:
---  * The 'Active Command Set' value, or nil if an error occurred
---
function finalcutpro.getActiveCommandSetPath()
	local result = finalcutpro.getPreference("Active Command Set") or nil
	return result
end

--- hs.finalcutpro.getActiveCommandSetAsTable([optionalPath]) -> table or nil
--- Function
--- Returns the 'Active Command Set' as a Table
---
--- Parameters:
---  * optionalPath - The optional path of the Command Set
---
--- Returns:
---  * A table of the Active Command Set's contents, or nil if an error occurred
---
function finalcutpro.getActiveCommandSetAsTable(optionalPath)
	local result = nil
	local activeCommandSetPath = nil

	if optionalPath == nil then
		activeCommandSetPath = finalcutpro.getActiveCommandSetPath()
	else
		activeCommandSetPath = optionalPath
	end

	if activeCommandSetPath ~= nil then
		if fs.attributes(activeCommandSetPath) ~= nil then
			result = plist.fileToTable(activeCommandSetPath)
		end
	end

	return result
end

--- hs.finalcutpro.installed() -> boolean
--- Function
--- Is Final Cut Pro Installed?
---
--- Parameters:
---  * None
---
--- Returns:
---  * Boolean value
---
function finalcutpro.installed()
	local path = application.pathForBundleID(finalCutProBundleID)
	return doesDirectoryExist(path)
end

--- hs.finalcutpro.version() -> string or nil
--- Function
--- Version of Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * Version as string or nil if an error occurred
---
function finalcutpro.version()
	local version = nil
	if finalcutpro.installed() then
		ok,version = osascript.applescript('return version of application id "'..finalCutProBundleID..'"')
	end
	return version or nil
end

--- hs.finalcutpro.application() -> hs.application or nil
--- Function
--- Returns the Final Cut Pro application (as hs.application)
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Final Cut Pro application (as hs.application) or nil if an error occurred
---
function finalcutpro.application()
	local result = application.applicationsForBundleID(finalCutProBundleID) or nil
	if next(result) == nil then
		return nil
	else
		return result[1]
	end
	return result
end

--- hs.finalcutpro.launch() -> boolean
--- Function
--- Launches Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if Final Cut Pro was either launched or focused, otherwise false (e.g. if Final Cut Pro doesn't exist)
---
function finalcutpro.launch()

	local result = nil

	local fcpx = finalcutpro.application()

	if fcpx == nil then
		-- Final Cut Pro is Closed:
		result = application.launchOrFocusByBundleID(finalCutProBundleID)
	else
		-- Final Cut Pro is Open:
		if not fcpx:isFrontmost() then
			-- Open by not Active:
			result = application.launchOrFocusByBundleID(finalCutProBundleID)
		else
			-- Already frontmost:
			return true
		end
	end

	return result

end

--- hs.finalcutpro.running() -> boolean
--- Function
--- Is Final Cut Pro Running?
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if Final Cut Pro is running otherwise False
---
function finalcutpro.running()

	local fcpx = finalcutpro.application()
	if fcpx == nil then
		return false
	else
		return fcpx:isRunning()
	end

end

--- hs.finalcutpro.restart() -> boolean
--- Function
--- Restart Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if Final Cut Pro is running otherwise False if Final Cut Pro is not running, or fails to close or restart
---
function finalcutpro.restart()

	if finalcutpro.application() ~= nil then

		-- Kill Final Cut Pro:
		finalcutpro.application():kill()

		-- Wait until Final Cut Pro is Closed (checking every 0.1 seconds for up to 10 seconds):
		just.doWhile(function() return finalcutpro.running() end, 100000, 100)

		-- Launch Final Cut Pro:
		local result = finalcutpro.launch()

		return result

	else
		return false
	end

end

--- hs.finalcutpro.frontmost() -> boolean
--- Function
--- Is Final Cut Pro Frontmost?
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if Final Cut Pro is Frontmost otherwise false.
---
function finalcutpro.frontmost()

	local fcpx = finalcutpro.application()
	if fcpx == nil then
		return false
	else
		return fcpx:isFrontmost()
	end

end

--- hs.finalcutpro.getTimelineSplitGroup() -> axuielementObject or nil
--- Function
--- Get Timeline Split Group
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Timeline Split Group or nil if failed
---
function finalcutpro.getTimelineSplitGroup()

	-- Which Split Group:
	local whichSplitGroup = nil

	-- Define Final Cut Pro:
	local sw = ax.applicationElement(finalcutpro.application())

	-- Single Screen:
	whichSplitGroup = sw:searchPath({
		{ role = "AXWindow", Title = "Final Cut Pro"},								-- AXWindow "Final Cut Pro" (window 2)
		{ role = "AXSplitGroup", },												 	-- AXSplitGroup (splitter group 1)
		{ role = "AXGroup", },													    -- AXGroup (group 1)
		{ role = "AXSplitGroup", },												    -- AXSplitGroup (splitter group 1)
		{ role = "AXGroup", },												        -- AXGroup (group 2)
		{ role = "AXSplitGroup", },												 	-- AXSplitGroup (splitter group 1)
		{ role = "AXGroup", },														-- AXGroup (group 1)
		{ role = "AXSplitGroup", Identifier = "_NS:237"},							-- AXSplitGroup (splitter group 1)
	}, 1)

	-- Dual Screen:
	if whichSplitGroup == nil then

		whichSplitGroup = sw:searchPath({
			{ role = "AXWindow", Title = "Final Cut Pro"},							-- AXWindow "Final Cut Pro" (window 2)
			{ role = "AXSplitGroup", },											 	-- AXSplitGroup (splitter group 1)
			{ role = "AXGroup", },												    -- AXGroup (group 1)
			{ role = "AXSplitGroup", },											    -- AXSplitGroup (splitter group 1)
			{ role = "AXGroup", },											        -- AXGroup (group 2)
			{ role = "AXSplitGroup", Identifier = "_NS:237"},					 	-- AXSplitGroup (splitter group 1)
		}, 1)

	end

	return whichSplitGroup

end

--- hs.finalcutpro.getTimelineScrollArea() -> axuielementObject or nil
--- Function
--- Gets Timeline Scroll Area
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Timeline Scroll Area or nil if failed
---
function finalcutpro.getTimelineScrollArea()

	-- Which Split Group:
	local finalCutProTimelineScrollArea = nil
	local finalCutProTimelineSplitGroup = finalcutpro.getTimelineSplitGroup()

	-- Get last scroll area:
	if finalCutProTimelineSplitGroup ~= nil then

		local whichScrollArea = nil
		for i=1, finalCutProTimelineSplitGroup:attributeValueCount("AXChildren") do
			if finalCutProTimelineSplitGroup[i]:attributeValue("AXRole") == "AXScrollArea" then
				whichScrollArea = i
			end
		end
		if whichScrollArea == nil then
			return nil
		end
		finalCutProTimelineScrollArea = finalCutProTimelineSplitGroup[whichScrollArea]

	end

	return finalCutProTimelineScrollArea

end

--- hs.finalcutpro.getTimelineButtonBar() -> axuielementObject or nil
--- Function
--- Gets Timeline Button Bar
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Timeline Button Bar or nil if failed
---
function finalcutpro.getTimelineButtonBar()

	local finalCutProTimelineSplitGroup = finalcutpro.getTimelineSplitGroup()
	return finalCutProTimelineSplitGroup:attributeValue("AXParent")[2]

end

--- hs.finalcutpro.getEffectsTransitionsBrowserGroup() -> axuielementObject or nil
--- Function
--- Gets Effects/Transitions Browser Group
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Effects/Transitions Browser Group or nil if failed
---
function finalcutpro.getEffectsTransitionsBrowserGroup()

	-- Get Timeline Split Group:
	local finalCutProTimelineSplitGroup = finalcutpro.getTimelineSplitGroup()

	-- Which Group:
	for i=1, finalCutProTimelineSplitGroup:attributeValueCount("AXChildren") do
		if finalCutProTimelineSplitGroup[i]:attributeValue("AXRole") == "AXGroup" then
			return finalCutProTimelineSplitGroup[i]
		end
	end

	-- If things get to here it's failed:
	return nil

end

--- hs.finalcutpro.getBrowserSplitGroup() -> axuielementObject or nil
--- Function
--- Gets Browser Split Group
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Browser Split Group or nil if failed
---
function finalcutpro.getBrowserSplitGroup()

	-- Different Split Group Identifiers for Different Languages:
	local splitGroupIdentifier = nil
	currentLanguage = finalcutpro.currentLanguage()
	if currentLanguage == "en" then
		splitGroupIdentifier = "_NS:344"
	elseif currentLanguage == "de" then
		splitGroupIdentifier = "_NS:346"
	elseif currentLanguage == "es" then
		splitGroupIdentifier = "_NS:347"
	elseif currentLanguage == "fr" then
		splitGroupIdentifier = "_NS:345"
	elseif currentLanguage == "ja" then
		splitGroupIdentifier = "_NS:347"
	elseif currentLanguage == "zh_CN" then
		splitGroupIdentifier = "_NS:347"
	end

	-- Define Final Cut Pro:
	sw = ax.applicationElement(finalcutpro.application())

	-- Single Screen:
	local browserSplitGroup = sw:searchPath({
		{ role = "AXWindow", Title = "Final Cut Pro"},
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXSplitGroup", Identifier = splitGroupIdentifier},
	}, 1)

	-- Dual Screen:
	if browserSplitGroup == nil then
		browserSplitGroup = sw:searchPath({
			{ role = "AXWindow", },
			{ role = "AXSplitGroup", },
			{ role = "AXGroup", },
			{ role = "AXSplitGroup", Identifier = splitGroupIdentifier},
		}, 1)
	end

	return browserSplitGroup

end

--- hs.finalcutpro.getBrowserButtonBar() -> axuielementObject or nil
--- Function
--- Gets Browser Button Bar
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Browser Button Bar or nil if failed
---
function finalcutpro.getBrowserButtonBar()
	local finalCutProBrowserSplitGroup = finalcutpro.getBrowserSplitGroup()
	if finalCutProBrowserSplitGroup ~= nil then
		return finalCutProBrowserSplitGroup:attributeValue("AXParent")
	else
		return nil
	end
end

--- hs.finalcutpro.getColorBoardRadioGroup() -> axuielementObject or nil
--- Function
--- Gets the Color Board Radio Group
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Color Board Radio Group or nil if failed
---
function finalcutpro.getColorBoardRadioGroup()

	-- Define Final Cut Pro:
	sw = ax.applicationElement(finalcutpro.application())

	-- Find Color Button:
	local result = sw:searchPath({
		{ role = "AXWindow", Title = "Final Cut Pro"},
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXSplitGroup", },
		{ role = "AXGroup", },
		{ role = "AXRadioGroup", Identifier = "_NS:128"},
	}, 1)

	return result

end

--- hs.finalcutpro.getBrowserPersistentPlayhead() -> axuielementObject or nil
--- Function
--- Gets the Browser Persistent Playhead
---
--- Parameters:
---  * None
---
--- Returns:
---  * axuielementObject for the Browser Persistent Playhead or nil if failed
---
function finalcutpro.getBrowserPersistentPlayhead()

	local persistentPlayhead = nil

	--------------------------------------------------------------------------------
	-- Get Browser Split Group:
	--------------------------------------------------------------------------------
	browserSplitGroup = finalcutpro.getBrowserSplitGroup()
	if browserSplitGroup == nil then
		writeToConsole("ERROR: Failed to get Browser Split Group in finalcutpro.getBrowserPersistentPlayhead().")
		return nil
	end

	--------------------------------------------------------------------------------
	-- Which Group:
	--------------------------------------------------------------------------------
	local whichGroup = nil
	for i=1, browserSplitGroup:attributeValueCount("AXChildren") do
		if browserSplitGroup[i]:attributeValue("AXRole") == "AXGroup" then
			whichGroup = i
		end
	end
	if whichGroup == nil then
		writeToConsole("ERROR: Unable to locate Group in finalcutpro.getBrowserPersistentPlayhead().")
		return nil
	end

	--------------------------------------------------------------------------------
	-- Which Scroll Area:
	--------------------------------------------------------------------------------
	local whichScrollArea = nil
	for i=1, browserSplitGroup[whichGroup]:attributeValueCount("AXChildren") do
		if browserSplitGroup[whichGroup][i]:attributeValue("AXRole") == "AXScrollArea" then
			whichScrollArea = i
		end
	end

	if whichScrollArea == nil then

		--------------------------------------------------------------------------------
		-- LIST VIEW:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Which Split Group:
			--------------------------------------------------------------------------------
			local whichSplitGroup = nil
			for i=1, browserSplitGroup[whichGroup]:attributeValueCount("AXChildren") do
				if browserSplitGroup[whichGroup][i]:attributeValue("AXRole") == "AXSplitGroup" then
					if browserSplitGroup[whichGroup][i]:attributeValue("AXIdentifier") == "_NS:658" then
						whichSplitGroup = i
						goto exitWhichSplitGroupLoop
					end
				end
			end
			::exitWhichSplitGroupLoop::
			if whichSplitGroup == nil then
				writeToConsole("ERROR: Unable to locate Split Group in finalcutpro.getBrowserPersistentPlayhead().")
				return nil
			end

			--------------------------------------------------------------------------------
			-- Which Group 2:
			--------------------------------------------------------------------------------
			local whichGroupTwo = nil
			for i=1, browserSplitGroup[whichGroup][whichSplitGroup]:attributeValueCount("AXChildren") do
				if browserSplitGroup[whichGroup][whichSplitGroup][i]:attributeValue("AXRole") == "AXGroup" then
					if browserSplitGroup[whichGroup][whichSplitGroup][i]:attributeValue("AXIdentifier") == "_NS:590" then
						whichGroupTwo = i
						goto exitWhichGroupTwoLoop
					end
				end
			end
			::exitWhichGroupTwoLoop::
			if whichGroupTwo == nil then
				writeToConsole("ERROR: Unable to locate Group Two in finalcutpro.getBrowserPersistentPlayhead().")
				return nil
			end

			--------------------------------------------------------------------------------
			-- Which Value Indicator:
			--------------------------------------------------------------------------------
			local whichValueIndicator = nil
			whichValueIndicator = browserSplitGroup[whichGroup][whichSplitGroup][whichGroupTwo]:attributeValueCount("AXChildren") - 1
			persistentPlayhead = browserSplitGroup[whichGroup][whichSplitGroup][whichGroupTwo][whichValueIndicator]

	else

		--------------------------------------------------------------------------------
		-- FILMSTRIP VIEW:
		--------------------------------------------------------------------------------

			--------------------------------------------------------------------------------
			-- Which Group 2:
			--------------------------------------------------------------------------------
			local whichGroupTwo = nil
			for i=1, browserSplitGroup[whichGroup][whichScrollArea]:attributeValueCount("AXChildren") do
				if browserSplitGroup[whichGroup][whichScrollArea][i]:attributeValue("AXRole") == "AXGroup" then
					if browserSplitGroup[whichGroup][whichScrollArea][i]:attributeValue("AXIdentifier") == "_NS:39" then
						whichGroupTwo = i
						goto exitWhichGroupTwoLoop
					end
				end
			end
			::exitWhichGroupTwoLoop::
			if whichGroupTwo == nil then
				writeToConsole("ERROR: Unable to locate Group Two in finalcutpro.getBrowserPersistentPlayhead().")
				return nil
			end

			--------------------------------------------------------------------------------
			-- Which Value Indicator:
			--------------------------------------------------------------------------------
			local whichValueIndicator = nil
			whichValueIndicator = browserSplitGroup[whichGroup][whichScrollArea][whichGroupTwo]:attributeValueCount("AXChildren") - 1
			persistentPlayhead = browserSplitGroup[whichGroup][whichScrollArea][whichGroupTwo][whichValueIndicator]
	end

	return persistentPlayhead

end

--- hs.finalcutpro.getBrowserSearchButton() -> axuielementObject or nil
--- Function
--- Gets the Browser Search Button
---
--- Parameters:
---  * [BrowserButtonBar] - If you already know the Browser Button Bar Group,
---                         you can supply it here for a slight speed increase
---
--- Returns:
---  * axuielementObject for the Browser Search Button or nil if failed
---
function finalcutpro.getBrowserSearchButton(optionalBrowserButtonBar)

	local browserButtonBar = nil
	if optionalBrowserButtonBar == nil then
		browserButtonBar = finalcutpro.getBrowserButtonBar()
	else
		browserButtonBar = optionalBrowserButtonBar
	end

	local searchButtonID = nil
	for i=1, browserButtonBar:attributeValueCount("AXChildren") do
		if browserButtonBar[i]:attributeValue("AXRole") == "AXButton" then
			if browserButtonBar[i]:attributeValue("AXIdentifier") == "_NS:92" then
				searchButtonID = i
			end
		end
	end
	if searchButtonID == nil then
		writeToConsole("Unable to find Search Button.\n\nError occured in finalcutpro.getBrowserSearchButton().")
		return nil
	end

	local result = nil
	result = browserButtonBar[searchButtonID]

	return result

end

--- hs.finalcutpro._generateMenuMap() -> Table
--- Function
--- Generates a map of the menu bar and saves it in '/hs/finalcutpro/menumap.json'.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * True is successful otherwise Nil
---
function finalcutpro._generateMenuMap()
	return finalcutpro.app():menuBar():generateMenuMap()
end

function finalcutpro._elementAtMouse()
	return ax.systemElementAtPosition(hs.mouse.getAbsolutePosition())
end

function finalcutpro._inspectElementAtMouse()
	return inspect(finalcutpro._elementAtMouse():buildTree())
end

return finalcutpro