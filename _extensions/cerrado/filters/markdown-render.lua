-- Pandoc Lua filter that captures a Div with class 'coderender'
-- and nests two new Divs inside it: one with the verbatim source code,
-- and one with the rendered content.
-- This works only for latex or beamer formats because it uses a latex tcolorbox to encapsulate the rendered code
local DIVNAME = "markdownrender"
local ENVNAME = "markdownrender"

local function latex(str)
	return pandoc.RawInline("latex", str)
end

-- require("mobdebug").start()

-- Accepted attrubutes are title (main title), titleleft or left and titleright or right, for the inner pane titles
local function get_attributes(attrs)
	local titles = { "", "", "" }

	if attrs and #attrs == 0 then
		return nil
	end
	for key, value in pairs(attrs) do
		if key == "title" or key == "main" then
			titles[1] = value
		end

		if key == "left" or key == "titleleft" then
			titles[2] = value
		end
		if key == "right" or key == "titleright" then
			titles[3] = value
		end

		return string.format("[%s][%s][%s]", table.unpack(titles))
	end
end

function Div(div)
	-- Check if the div has the class 'markdownrender'
	if not (div.classes:includes(DIVNAME)) then
		return nil
	end

	if FORMAT == "beamer" or FORMAT == "latex" then
		-- IMPORTANT: Preserve the original content before modifying the div.
		local original_content = div.content

		-- 1. Create the 'markdownrender' div.
		-- This div will contain the original markdown source in a code block.

		-- Convert the original content (a Pandoc AST) back to a markdown string.
		local source_markdown = pandoc.write(pandoc.Pandoc(original_content), "markdown")

		-- Create a CodeBlock element containing the source string.
		-- We add the 'markdown' class for potential syntax highlighting.
		local code_block = pandoc.CodeBlock(source_markdown, { class = "markdown" })
		-- local code_block = pandoc.Div(div.content, {class = 'markdown'})

		-- Create the parent Div for the code block.
		local code_div = pandoc.Div({ code_block }, { class = "coderendercode" })

		-- 2. Create the 'coderenderrender' div.
		-- This div will contain the original, parsed content, which Pandoc will render.
		local render_div = pandoc.Div(original_content, { class = "coderenderrender" })

		-- Checking the attributes
		local attrs = get_attributes(div.attributes) or ""
		local env_open = latex(string.format("\\begin{%s}%s", ENVNAME, attrs))
		local env_middle = latex("\\tcblower")
		local env_close = latex(string.format("\\end{%s}", ENVNAME))

		--
		-- 3. Set the new content of the original div.
		-- The original div will now contain the two new divs we created.
		-- div.content = {code_div, render_div}
		div.content = { env_open, code_div, env_middle, render_div, env_close }

		-- 4. Return the modified div itself.
		return div
	end
end

-- Reading special metadata variable to change the tcolorbox environment
function Meta(meta)
	-- Check if 'DIVNAME' exists in metadata
	if meta[DIVNAME] then
		-- Store the value in a global variable for later use
		ENVNAME = pandoc.utils.stringify(meta[DIVNAME])
	end
	-- Return metadata unchanged (unless you want to modify it)
	return meta
end

-- Enforcing that Meta block is processed before
return {
	{ Meta = Meta }, -- get meta vars first
	{ Div = Div }, -- Inline elements
}
