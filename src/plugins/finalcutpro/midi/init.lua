--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                          M I D I     P L U G I N                           --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === plugins.finalcutpro.midi ===
---
--- MIDI Plugin for Final Cut Pro.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log										= require("hs.logger").new("streamDeck")

local fcp										= require("cp.apple.finalcutpro")

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id = "finalcutpro.midi",
	group = "finalcutpro",
	dependencies = {
		["core.midi.manager"]		= "manager",
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

	--------------------------------------------------------------------------------
	-- Update Touch Bar Buttons when FCPX is active:
	--------------------------------------------------------------------------------
	fcp:watch({
		active		= function() deps.manager.groupStatus("fcpx", true) end,
		inactive	= function() deps.manager.groupStatus("fcpx", false) end,
	})

end

return plugin