-- entities/UI/markdownText.lua
-- Minimal markdown renderer that mirrors the Playdate SDK's drawTextInRect styling.
--
-- Playdate interprets *asterisks* as bold (and _underscores_ as italic) natively
-- inside drawText/drawTextInRect. LÖVE's printf has no such support, so this module
-- parses the markers, removes them, and renders styled runs with manual word-wrap.
--
-- Bold is faux-bold (the glyph is drawn twice with a 1px horizontal offset) because
-- the dialog font has no bold variant. Italic is faux-italic via a horizontal shear.
--
-- Markers (matching Playdate):
--   *bold*      → bold
--   _italic_    → italic
-- Markers toggle their style and are stripped from the output.

local markdownText = {}

local BOLD_OFFSET   = 1        -- px; faux-bold double-draw offset
local ITALIC_SHEAR  = -0.18    -- horizontal shear factor for faux-italic

-- Split a string into styled runs. Returns { {text=, bold=, italic=}, ... }
function markdownText.parse(s)
	local runs = {}
	local buf, bold, italic = {}, false, false

	local function flush()
		if #buf > 0 then
			runs[#runs + 1] = { text = table.concat(buf), bold = bold, italic = italic }
			buf = {}
		end
	end

	for i = 1, #s do
		local c = s:sub(i, i)
		if c == "*" then
			flush()
			bold = not bold
		elseif c == "_" then
			flush()
			italic = not italic
		else
			buf[#buf + 1] = c
		end
	end
	flush()
	return runs
end

-- Turn styled runs into a flat token stream for layout.
-- Tokens are: word {text, bold, italic} | space {space=true} | newline {newline=true}
local function buildTokens(runs)
	local tokens = {}
	for _, run in ipairs(runs) do
		local word = {}
		local function pushWord()
			if #word > 0 then
				tokens[#tokens + 1] = { text = table.concat(word), bold = run.bold, italic = run.italic }
				word = {}
			end
		end
		local s = run.text
		for i = 1, #s do
			local c = s:sub(i, i)
			if c == " " then
				pushWord()
				tokens[#tokens + 1] = { space = true }
			elseif c == "\n" then
				pushWord()
				tokens[#tokens + 1] = { newline = true }
			else
				word[#word + 1] = c
			end
		end
		pushWord()
	end
	return tokens
end

-- Draw a single styled word, applying faux-bold / faux-italic as needed.
local function drawWord(token, x, y, font)
	if token.italic then
		love.graphics.print(token.text, x, y, 0, 1, 1, 0, 0, ITALIC_SHEAR, 0)
		if token.bold then
			love.graphics.print(token.text, x + BOLD_OFFSET, y, 0, 1, 1, 0, 0, ITALIC_SHEAR, 0)
		end
	else
		love.graphics.print(token.text, x, y)
		if token.bold then
			love.graphics.print(token.text, x + BOLD_OFFSET, y)
		end
	end
end

-- Render markdown text with greedy word-wrapping at `limit` pixels wide.
-- Mirrors love.graphics.printf's left-aligned wrapping but supports inline styles.
--   text  : string containing *bold* / _italic_ markers
--   x, y  : top-left anchor
--   limit : wrap width in pixels
--   font  : Font to use (caller-provided; restored afterwards)
--   color : optional {r,g,b,a}
-- Returns the y position just past the last drawn line (useful for stacking).
function markdownText.draw(text, x, y, limit, font, color)
	if not text or text == "" then return y end

	local prevFont = love.graphics.getFont()
	local pr, pg, pb, pa = love.graphics.getColor()

	love.graphics.setFont(font)
	if color then love.graphics.setColor(color) end

	local spaceW = font:getWidth(" ")
	local lineH  = font:getHeight()
	local tokens = buildTokens(markdownText.parse(text))

	local cursorX, cursorY = x, y
	for _, t in ipairs(tokens) do
		if t.newline then
			cursorX = x
			cursorY = cursorY + lineH
		elseif t.space then
			cursorX = cursorX + spaceW
		else
			local w = font:getWidth(t.text) + (t.bold and BOLD_OFFSET or 0)
			-- Wrap before drawing if the word overflows (but never wrap at line start,
			-- so an over-long single word just overflows rather than looping forever).
			if cursorX > x and cursorX + w > x + limit then
				cursorX = x
				cursorY = cursorY + lineH
			end
			drawWord(t, cursorX, cursorY, font)
			cursorX = cursorX + w
		end
	end

	-- Restore previous font/color so callers are unaffected.
	love.graphics.setFont(prevFont)
	love.graphics.setColor(pr, pg, pb, pa)

	return cursorY + lineH
end

return markdownText
