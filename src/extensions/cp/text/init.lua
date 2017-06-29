--- === cp.text ===
---
--- This module provides support for loading, manipulating, and comparing unicode text data.
--- It works by storing characters with their Unicode 'codepoint` value. In practice, this means that every character is a 64-bit integer, so a `text` value will use substantially more memory than the equivalent encoded `string` value.
---
--- The advantages of `text` over `string` representations for Unicode are:
---  * comparisons, equality checks, etc. actually work for Unicode text and are not encoding-dependent.
---  * direct access to codepoint values.
---
--- The advantages of `string` representations for Unicode are:
---  * compactness.
---  * reading/writing to files via the standard `io` library.
---
--- ## Strings and Unicode
---
--- LUA has limited built-in support for Unicode text. `string` values are "8-bit clean", which means it is an array of 8-bit characters. This is also how binary data from files is usually loaded, as 8-bit 'bytes'. Unicode characters can be up to 32-bits, so there are several standard ways to represent Unicode characters using 8-bit characters. Without going into detail, the most common encodings are called 'UTF-8' and 'UTF-16'. There are two variations of 'UTF-16', depending on the hardware architecture, known as 'big-endian' and 'little-endian'.
---
--- The built-in functions for `string`, such as `match`, `gsub` and even `len` will not work as expected when a string contains Unicode text. As such, this library fills some of the gaps for common operations when working with Unicode text.
---
--- ## Examples
---
--- You can convert to and from `string` and `text` values like so:
---
--- ```lua
--- local text = require("cp.text")
---
--- local simpleString		= "foobar"
--- local simpleText		= text(stringValue)
--- local utf8String		= "a丽𐐷"				-- contains non-ascii characters, defaults to UTF-8.
--- local unicodeText		= text "a丽𐐷"			-- contains non-ascii characters, converts from a UTF-8 string.
--- local utf8String		= tostring(unicodeText) -- `tostring` will default to UTF-8 encoding
--- local utf16leString		= unicodeText:encode(text.encoding.utf16le) -- or you can be more specific
--- ```
--- 
--- Note that `text` values are not in any specific encoding, since they are stored as 64-bit integer `code-points` rather than 8-bit characers.

local utf16LE				= require("cp.utf16.le")
local utf16BE				= require("cp.utf16.be")
local protect				= require("cp.protect")

local utf8char, utf8codepoint, utf8codes, utf8len, utf8offset = utf8.char, utf8.codepoint, utf8.codes, utf8.len, utf8.offset
local utf16LEchar, utf16LEcodepoint, utf16LEcodes, utf16LElen, utf16LEoffset = utf16LE.char, utf16LE.codepoint, utf16LE.codes, utf16LE.len, utf16LE.offset
local utf16BEchar, utf16BEcodepoint, utf16BEcodes, utf16BElen, utf16BEoffset = utf16BE.char, utf16BE.codepoint, utf16BE.codes, utf16BE.len, utf16BE.offset
local unpack				= table.unpack
local floor					= math.floor

local text = {}

text.mt = {}
text.mt.__index = text.mt

--- cp.text.encoding
--- Constant
--- The list of supported encoding formats:
---  * `utf8`		- UTF-8. The most common format on the web, backwards compatible with ANSI/ASCII.
---  * `utf16le`	- UTF-16 (little-endian). Commonly used in Windows and Mac text files.
---  * `utf16be`	- UTF-16 (big-endian). Alternate 16-bit format, common on Linux and PowerPC-based architectures.
text.encoding = protect {
	utf8	= "utf8",
	utf16le	= "utf16le",
	utf16be	= "utf16be",
}

local decoder = protect {
	utf8	= utf8codepoint,
	utf16le	= utf16LEcodepoint,
	utf16be	= utf16BEcodepoint,
}

local encoder = protect {
	utf8	= utf8char,
	utf16le	= utf16LEchar,
	utf16be	= utf16BEchar,
}

local function isint(n)
  return n==floor(n)
end

local function constrain(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end

-- gets the 'codes' value for a text value
local function getCodes(text)
	return rawget(text, "codes")
end

-- sets the 'codes' value for a text value.
local function setCodes(text, value)
	rawset(text, "codes", protect(value))
end

--- cp.text.new(value[, encoding]) -> text
--- Constructor
--- Returns a new `text` instance representing the string value of the specified value.
---
--- Parameters:
---  * `value`		- The value to turn into a unicode text instance.
---  * `encoding`	- One of the falues from `text.encoding`: `utf8`, `utf16le`, or `utf16be`. Defaults to `utf8`.
---
--- Returns:
---  * A new `text` instance.
---
--- Notes:
---  * Calling `text.new(...)` is the same as calling `text(...)`, so text can be initialized via `local x = text "foo"`
function text.new(value, encoding)
	encoding = encoding or text.encoding.utf8
	local decoder = decoder[encoding]
	if not decoder then
		error(string.format("unsupported encoding: %s", encoding))
	end
	return text.fromCodepoints({decoder(tostring(value), 1, -1)})
end

--- cp.text.fromCodepoints(codepoints[, i[, j]]) -> text
--- Constructor
--- Returns a new `text` instance representing the specified array of codepoints. Since `i` and `j` default to the first
--- and last indexes of the array, simply passing in the array will convert all codepoints in that array.
---
--- Parameters:
---  * `codepoints`	- The array of codepoint integers.
---  * `i`			- The starting index to read from codepoints. Defaults to `1`.
---  * `j`			- The ending index to read from codepoints. Default to `-1`.
---
--- Returns:
---  * A new `text` instance.
---
--- Notes:
---  * You can use a *negative* value for `i` and `j`. If so, it will count back from then end of the `codepoints` array.
function text.fromCodepoints(codepoints, i, j)
	local result = {}
	local len = #codepoints
	
	if len > 0 then
		i = i or 1
		j = j or -1
		if type(i) ~= "number" then
			error("bad argument #2 (integer expected, got "..type(i)..")")
		end
		if type(j) ~= "number" then
			error("bad argument #3 (integer expected, got "..type(i)..")")
		end
		if not isint(i) then
			error(string.format("bad argument #2 (number has no integer representation: %s)", i))
		end
		if not isint(j) then
			error(string.format("bad argument #3 (number has no integer representation: %s)", j))
		end
	
		if i < 0 then i = len + 1 + i end
		if j < 0 then j = len + 1 + j end

		i = constrain(i, 1, len)
		j = constrain(j, 1, len)
	
		for x = i,j do
			local cp = codepoints[x]
			if type(cp) ~= "number" then
				error("bad argument #1 for 'fromCodepoints (integer expected, got "..type(cp).." for codepoint #"..x..")")
			end
			result[x-i+1] = cp
		end
	end
	
	local o = {}
	setmetatable(o, text.mt)
	setCodes(o, result)
	return o
end

--- cp.text.is(value) -> boolean
--- Function
--- Checks if the provided value is a `text` instance.
---
--- Parameters:
---  * `value`	- The value to check
---
--- Returns:
---  * `true` if the value is a `text` instance.
function text.is(value)
	return value and getmetatable(value) == text.mt
end

--- cp.text:sub(i [, j]) -> cp.text
--- Method
--- Returns the substring of this text that starts at `i` and continues until `j`; `i` and `j` can be negative.
--- If `j` is absent, then it is assumed to be equal to `-1` (which is the same as the string length).
--- In particular, the call `cp.text:sub(1,j)` returns a prefix of `s` with length `j`, and `cp.text:sub(-i)` (for a positive `i`) returns a suffix of s with length i.
function text.mt:sub(i, j)
	j = j or -1
	return text.fromCodepoints(getCodes(self), i, j)
end

-- provides access to the internal codes array
function text.mt:__index(key)
	if type(key) == "number" then
		local codes = getCodes(self)
		return codes[key]
	elseif key ~= codesKey then
		return rawget(text.mt, key)
	end
	return nil
end

-- prevents codes getting updated directly.
function text.mt:__newindex(k, v)
	error("read-only text value", 2)
end

function text.mt:__len()
	local codes = getCodes(self)
	return #codes
end

--- cp.text:len() -> number
--- Method
--- Returns the number of codepoints in the text.
--- 
--- Parameters:
---  * None
---
--- Returns:
---  * The number of codepoints.
text.mt.len = text.mt.__len

-- concatenates the left and right values into a single text value.
function text.mt.__concat(left, right)
	return text.new(tostring(left) .. tostring(right))
end

--- cp.text:encode([encoding]) -> string
--- Method
--- Returns the text as an encoded `string` value.
---
--- Parameters:
---  * `encoding`	- The encoding to use when converting. Defaults to `cp.text.encoding.utf8`.
--
-- Returns:
--  * The `string` version of the `cp.text` value with the specified encoding..
function text.mt:encode(encoding)
	encoding = encoding or text.encoding.utf8
	local encoder = encoder[encoding]
	if not encoder then
		error(string.format("Unsupported encoding: %s", encoding))
	end
	return encoder(unpack(self))
end

-- cp.text:__tostring() -> string
-- Method
-- Returns the text as an `string` value encoded as UTF-8.
--
-- Parameters:
--  * None
--
-- Returns:
--  * The `string` version of the `cp.text` value.
function text.mt:__tostring()
	return self:encode(text.encoding.utf8)
end

-- cp.text:__eq(other) -> boolean
-- Method
-- Checks if `other` is a `cp.text` instance, and if so, all codepoints are present in the same order.
--
-- Parameters:
--  * `other`	- The other value to compare to.
--
-- Returns:
--  * `true` if `other` is a `cp.text` and all codepoints are present in the same order.
function text.mt:__eq(other)
	if text.is(other) then
		local localCodes, otherCodes = getCodes(self), getCodes(other)
		local len = #localCodes
		if len == #otherCodes then
			for i = 1,len do
				if not localCodes[i] == otherCodes[i] then
					return false
				end
			end
			return true
		end
	end
	return false
end

function text.__call(_, ...)
	return text.new(...)
end

return setmetatable(text, text)