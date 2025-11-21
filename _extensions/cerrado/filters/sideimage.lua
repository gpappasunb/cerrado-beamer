--[[
Pandoc filter, specific for LATEX or BEAMER,
 that puts its contents in two columns. The left-most
 column contains the div contents rendered as usual.
 The right column will contain an image, that is provided
 by the mandatory option: image= (or img=)

 This is LaTeX specific, because it creates a Latex TCOLORBOX
 with sidebyside orientation.

 The syntax is simply:

::: {.sideimage image=logo.png}

Content left

:::

Additional options can be provided:

  title=...   -> For the table main title. (title="This is the title")
  left=...    -> For the title of the left column. (left="Left title")
  right=...   -> For the title of the right column. (right="Right title")
  horizontal=true or hr=true -> Instead of vertical columns, use horizontal ones
  swap=true or switch=true -> Swap the left and right columns, that is place the image on the left (upper) pane
  animate=true -> Animate the image, i.e., adds a \pause before displaying the image
  leftbg or bgleft=...  -> Background color of the left column (bgleft=red!10)
  rightbg or bgright=... -> Background color of the right column (bgright=red!10)
  ratio=0.2 or leftwidth= or widthleft= -> A number between 0 and 1 indicating the percentage of the left column (width or height)
  rightwidth=0.3 or widthright=... -> A number between 0 and 1 indicating the percentage of the right column (width or height)
  scale= -> Scaling factor applied directly to the image. Ex: 0.5



::: {.sideimage image=logo.png bgright=black horizontal=true swap=true animate=true}

This creates a table with two ROWS (horizontal=true) and with the image (logo.png) on the upper panel (the default is the lower or right panel)

:::


Author: Georgios Pappas Jr
Institution: University of Brasilia (UnB) - Brazil
Version: 0.1

--]]

---- DEBUG: For debugging purposes using ZeroBrane IDE
-- require("mobdebug").start()

-- The name of the div class to trigger the filter
local DIVNAME = "sideimage"
-- This is the name of the Latex environment containing the definition of the tcolorbox.
-- The default is tcolorbox, but if the user has a custom tcolorbox environment, this can be changed by passing the attribute env=<boxenv> to the div.
local _ENVNAME = "tcolorbox"

-- The default tcolorbox style (options). This can be changed by passing the attribute style=<style> to the div. See tcolorbox - tcbset for more information.
local _BOXSTYLE = "enhanced,sidebyside,tile,sidebyside gap=5pt,right=2pt,colbacklower=white"

-- Global options for include graphics
_GRAPHICSOPTS = { scale = 1 }
-------------------
-- Helper functions
-------------------

--- Creates a raw Latex inline element.
local function latex(str)
	return pandoc.RawBlock("latex", str)
end

--- Process the attributes named align and width splitting them to a table with left and right tables, which in turn contain align and width keys, if provided.
-- @param attrs a table containing the attributes, such as in `div.attributes` propety in pandoc
local function process_attributes(attrs, ENVNAME, BOXSTYLE)
	local BOXOPTIONS = {}
	local swap = false
	local horizontal = false
	local animate = ""
	local image = nil
	local scale = 1 -- includegraphics default scale

	-- Changing the tcolorbox environment
	if attrs.env then
		ENVNAME = attrs.env
	end

	if attrs.animate or attrs.pause then
		animate = "\\pause"
	end

	-- Changing the default tcolorbox style
	if attrs.style then
		BOXSTYLE = attrs.style
	end

	if attrs.swap or attrs.switch then
		swap = true
	end
	-- Checking if orientation is horizontal (left=top and right=bottom)
	if attrs.horizontal or attrs.hr then
		table.insert(BOXOPTIONS, "sidebyside=false")
		horizontal = true
	end
	---
	--- Processing the attributes
	---
	for key, value in pairs(attrs) do
		if key == "title" or key == "main" then
			table.insert(BOXOPTIONS, "title={" .. value .. "}")
			-- Title left pane
		elseif key == "left" or key == "titleleft" then
			table.insert(BOXOPTIONS, "before upper=\\tcbsubtitle{" .. value .. "}")
			-- Right title, but takes into consideration the animate option
		elseif key == "right" or key == "titleright" then
			table.insert(BOXOPTIONS, string.format("before lower={%s\\tcbsubtitle{%s}}", animate, value))
			--back ground left pane
		elseif key == "pause" or key == "animate" then
			table.insert(BOXOPTIONS, "before lower*=\\pause")
		elseif key == "bgleft" or key == "leftbg" then
			table.insert(BOXOPTIONS, "colback=" .. value)
		elseif key == "bgright" or key == "rightbg" then
			table.insert(BOXOPTIONS, "colbacklower=" .. value)
		elseif key == "ratio" or key == "leftwidth" or key == "widthleft" then
			if horizontal then
				table.insert(BOXOPTIONS, "space=" .. value)
			else
				table.insert(BOXOPTIONS, "lefthand ratio=" .. value)
			end
		elseif key == "rightwidth" or key == "widthright" then
			local val = tostring(1.0 - tonumber(value))
			if horizontal then
				table.insert(BOXOPTIONS, "space=" .. val)
			else
				table.insert(BOXOPTIONS, "lefthand ratio=" .. val)
			end
			-- This is a special key, that inserts an image at the right panel. The image is the last content of the panel
		elseif key == "image" or key == "img" then
			image = value
		elseif key == "scale" then
			scale = value
		end
	end

	return ENVNAME, BOXSTYLE, BOXOPTIONS, image, swap, scale
end

--- Transforms the div that contains the DIVNAME class.
-- @param div the pandoc.Div element to be processed.
function Div(div, attrs)
	-- Check if the div contains the DIVNAME class
	if not (div.classes:includes(DIVNAME)) then
		return nil
	end

	-- Additional options to control the box. Passed directly as options to tcolorbox. This means that they should be exactly as indicated in tcolorbox manual, otherwise there will be a compilation error in LaTeX
	-- Each option should be provided by an option=value pair, separated by a comma. For example: title="This is the title" colframe=red!10
	-- local BOXOPTIONS={}
	local ENVNAME = _ENVNAME
	local BOXSTYLE = _BOXSTYLE

	if FORMAT == "beamer" or FORMAT == "latex" then
		-- Process attributes
		local ENVNAME, BOXSTYLE, BOXOPTIONS, image_path, is_swap, scale = process_attributes(div.attributes, ENVNAME, BOXSTYLE)

		--- Right (lower) contents. It is a single pandoc Image
		local right_attrs = pandoc.Attr("", { "right-content" }, { width = "\\linewidth" })
		--pandoc.Div({},{class="right_content"})
		-- pandoc.Image({},BOXOPTIONS.image,{},{width="\\linewidth"})

		--------
		--- Creating the image element
		--------
		local img_attr = {
			width = "\\linewidth",
		}
		--- The image path is given in the img=... attribute of the DIV
		if not image_path then
			return nil
		end
		-- local img_obj = pandoc.Plain(pandoc.Image({}, image_path, "", img_attr))
		-- Creating a raw Latex block to enable insertion of scale in includegraphics
		-- https://github.com/orgs/quarto-dev/discussions/5175
		local img_obj = latex(
			string.format(
				"\\pandocbounded{\\includegraphics[keepaspectratio,scale=%s]{%s}}",
				scale,
				image_path
			)
		)

		img_obj = pandoc.Figure(img_obj, {}, { class = "figure" })

		-- Creating a string with general options that will be appended to the BOXSTYLE
		--- The allowed options are specified in process_attributes
		if #BOXOPTIONS > 0 then
			-- if table_not_empty(BOXOPTIONS) then
			local opts = table.concat(BOXOPTIONS, ",")
			BOXSTYLE = BOXSTYLE .. "," .. opts
		end

		-----------------------------
		-- Defining the two contents
		-----------------------------
		local left_content, right_content = nil, nil
		-- Left content contains the entire div.content, unless swap attribute is provided, which moves the image to the left
		left_content = is_swap and img_obj.content or div.content
		-- left_content = is_swap and img_obj or div.content
		-- Right content contains the image, unless swap attribute is provided, which moves the image to the left
		-- right_content = is_swap and div.content or img_obj
		right_content = is_swap and div.content or img_obj.content

		----------------------------------------------------------------
		-- Adding the latex environments at the left and right contents
		----------------------------------------------------------------
		-- Creating the tcolorbox environment
		local env_open = latex(string.format("\\begin{%s}[%s]", ENVNAME, BOXSTYLE))
		local env_middle = latex("\\tcblower")
		local env_close = latex(string.format("\\end{%s}", ENVNAME))
		--- Opening the latex env at left_content
		left_content:insert(1, env_open)
		-- Inserting the middle line
		left_content:insert(#left_content + 1, env_middle)
		-- Closing the latex env at right_content
		right_content:insert(#right_content + 1, env_close)

		-- 3. Set the new content of the original div.
		-- The original div will now contain the two new divs we created.
		-- div.content = { left_content, right_content }
		-- div.attributes = attrs

		----
		--- Now creating the full contents object
		----
		all_cols = left_content .. right_content

		-- local all_cols =  env_open .. left_div .. env_middle .. right_div .. env_close
		--- Parent div contains the columns as children
		local result = pandoc.Div(all_cols, attrs)

		return result
		-- return div
	end
end

-- Reading special metadata variable to change the tcolorbox environment
--- The syntax is:
--- sideimage:
---   env: ENVIRONMENT
---   style: STYLE
--- Where the keys are optional. If not provided, the default values are used.
---   env: is the name of the tcolorbox environment to be used. It can be any of the tcolorbox environments, or a custom one.
---   style: is a string containing the options to be passed to the tcolorbox environment. Or a style predifined by tcolorbox - tcbset (see tcolorbox manual)
---@param meta any
function Meta(meta)
	-- Check if 'DIVNAME' exists in metadata
	if meta[DIVNAME] then
		-- Extracting the metadata keys and storing in the global variables
		local metadata = meta[DIVNAME]
		if pandoc.utils.type(metadata) == "table" then
			for key, value in pairs(metadata) do
				if key == "env" then
					_ENVNAME = pandoc.utils.stringify(value)
				elseif key == "style" then
					_BOXSTYLE = pandoc.utils.stringify(value)
				end
			end
		end
	end
	-- Return metadata unchanged
	return meta
end

return {

	{ Meta = Meta }, -- get meta vars first
	{ Div = Div }, -- Inline elements
}
