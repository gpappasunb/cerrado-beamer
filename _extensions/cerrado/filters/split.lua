--[[
Pandoc filter, specific for LATEX or BEAMER,
 that creates a Div that puts contents in two columns,
 but not with  traditional .column/.columns blocks.
 Instead, it creates a Latex TCOLORBOX with sidebyside
 orientation. The contents of the two columns are separated
 by a HorizontalRule element (--- or * * *).

 The upper text goes to the left column and the lower to the right

 The syntax is:

 ::: split

 Content left

 * * *
 Content right

 ::::::::::

 It is possible to pass some options controlling the columns, namely
 'width' and 'align'. For these,specify the values inside quotes and separated by commas. If no commas, then the value will be applied to both columns.

 ::: {.split align="top,center" width="20%,80%" .onlytextwidth}

 Content left

 1. asd
 2. sdf sdffds

 * * *
 Content right

 date
 :  sdfkj skdfjfskd

 :::



Author: Georgios Pappas Jr
Institution: University of Brasilia (UnB) - Brazil
Version: 0.1

--]]

-- The name of the div class to trigger the filter
local DIVNAME = "split"
-- This is the name of the Latex environment containing the definition of the tcolorbox.
-- The default is tcolorbox, but if the user has a custom tcolorbox environment, this can be changed by passing the attribute env=<boxenv> to the div.
local _ENVNAME = "tcolorbox"

-- The default tcolorbox style (options). This can be changed by passing the attribute style=<style> to the div. See tcolorbox - tcbset for more information.
local _BOXSTYLE = "enhanced,sidebyside,tile,bicolor,height fill=maximum,frame hidden,sidebyside gap=5pt,right=2pt"

-------------------
-- Helper functions
-------------------

--- Creates a raw Latex inline element.
local function latex(str)
	return pandoc.RawBlock("latex", str)
end

--- Split a string at commas.
-- @param str The string to be split.
-- @return a pandoc.List with the split string at commas.
local function comma_separated_values(str)
	local acc = pandoc.List:new({})
	for substr in str:gmatch("([^,]*)") do
		acc[#acc + 1] = substr:gsub("^%s*", ""):gsub("%s*$", "") -- trim
	end
	return acc
end

--- Splits a pandoc.List based on start and end indexes.
-- Takes a table or List and extracts the element.
-- @param lst The original table or List.
-- @param start_idx The start index.
-- @param end_idx The end index.
-- @return a pandoc.List containing the elements from start_idx to end_idx.
local function split_list(lst, start_idx, end_idx)
	-- Handle negative indices (count from end) and default values
	local n = #lst
	start_idx = start_idx or 1
	end_idx = end_idx or n

	-- Convert negative indices to positive
	if start_idx < 0 then
		start_idx = n + start_idx + 1
	end
	if end_idx < 0 then
		end_idx = n + end_idx + 1
	end

	-- Clamp indices to valid range
	start_idx = math.max(1, math.min(start_idx, n))
	end_idx = math.max(1, math.min(end_idx, n))

	-- Return empty list if indices are invalid
	if start_idx > end_idx then
		return pandoc.List:new()
	end

	-- Create sliced list
	local sliced = pandoc.List:new()
	for i = start_idx, end_idx do
		sliced:insert(lst[i])
	end

	return sliced
end

--- Given an attribute string, splits it at a comma, creating a table with left and right keys containing the split strings.
-- @param attr The string to be split
-- @return a table with left and right keys containing the split strings.
-- @see comma_separated_values
local function split_attributes(attr)
	-- splits the attribute string
	local attrs = comma_separated_values(attr)
	local left = attrs[1]
	local right = #attrs > 1 and attrs[2] or left
	return { left = left, right = right }
end

--- Process the attributes named align and width splitting them to a table with left and right tables, which in turn contain align and width keys, if provided.
-- @param attrs a table containing the attributes, such as in `div.attributes` propety in pandoc
local function process_attributes(attrs, ENVNAME, BOXSTYLE, BOXOPTIONS)
	columns_attrs = {
		left = {},
		right = {},
	}
	local titles = { "", "", "" }
	local horizontal = false

	-- Changing the tcolorbox environment
	if attrs.env then
		ENVNAME = attrs.env
	end

	-- Changing the default tcolorbox style
	if attrs.style then
		BOXSTYLE = attrs.style
	end

	for _, attr_name in ipairs({ "align", "width" }) do
		if attrs[attr_name] then
			-- Split the attribute string. ("left,right") -> { left = "left", right = "right" }
			local split = split_attributes(attrs[attr_name], attr_name)
			table.insert(columns_attrs["left"], { [attr_name] = split.left })
			table.insert(columns_attrs["right"], { [attr_name] = split.right })
			-- Removing the attribute from the original table
			attrs[attr_name] = nil
		end
	end
	-- If no elements in columns_attrs then make it an empty string
	if #columns_attrs.left < 1 then
		columns_attrs = {
			left = { "" },
			right = { "" },
		}
	end

	---
	--- Processing the titles attributes
	---
	for key, value in pairs(attrs) do
		if key == "title" or key == "main" then
			table.insert(BOXOPTIONS, "title={" .. value .. "}")
		end
		-- Title left pane
		if key == "left" or key == "titleleft" then
			table.insert(BOXOPTIONS, "before upper=\\tcbsubtitle{" .. value .. "}")
		end
		if key == "right" or key == "titleright" then
			table.insert(BOXOPTIONS, "before lower=\\tcbsubtitle{" .. value .. "}")
		end
		--back ground left pane
		if key == "bgleft" then
			table.insert(BOXOPTIONS, "colback=" .. value)
		end
		if key == "bgright" then
			table.insert(BOXOPTIONS, "colbacklower=" .. value)
		end
		--[[ /tcb/lefthand ratio=⟨fraction⟩
Sets the width of the left-handed part to the given ⟨fraction⟩ of the available space.
⟨fraction⟩ is a value between 0 and 1.
			]]
		--
		-- TODO: horizontal has to be placed before ratio parameter
		if key == "ratio" then
			if horizontal then
				table.insert(BOXOPTIONS, "space=" .. value)
			else
				table.insert(BOXOPTIONS, "lefthand ratio=" .. value)
			end
		end

		-- Forcing to be horizontal, Instead of sidebyside
		if key == "horizontal" or key == "hr" then
			table.insert(BOXOPTIONS, "sidebyside=false,height fill")
			horizontal = true
		end
		-- This is a special key, that inserts an image at the right panel. The image is the last content of the panel
		if key == "image" then
			table.insert(BOXOPTIONS, "after lower={" .. "\\includegraphics[width=\\linewidth]{" .. value .. "}}")
		end
	end

	return columns_attrs, attrs, ENVNAME, BOXSTYLE
end

--- Transforms the div that contains the DIVNAME class.
-- @param div the pandoc.Div element to be processed.
function Div(div, attrs)
	---- For debugging purposes using ZeroBrane IDE
	--  require("mobdebug").start()

	-- Check if the div contains the DIVNAME class
	if not (div.classes:includes(DIVNAME)) then
		return nil
	end

	-- Additional options to control the box. Passed directly as options to tcolorbox. This means that they should be exactly as indicated in tcolorbox manual, otherwise there will be a compilation error in LaTeX
	-- Each option should be provided by an option=value pair, separated by a comma. For example: title="This is the title" colframe=red!10
	local BOXOPTIONS = {}
	local ENVNAME = _ENVNAME
	local BOXSTYLE = _BOXSTYLE

	if FORMAT == "beamer" or FORMAT == "latex" then
		--- Finding the position of the HorizontalRule, that is the marker that splits the columns
		-- The HorizontalRule is the marker that divides the columns inside DIVNAME
		local ruler_pos
		for i, el in ipairs(div.content) do
			if el.t == "HorizontalRule" then
				ruler_pos = i
				break
			end
		end

		if not ruler_pos then
			return nil
		end

		-- Process attributes
		local columns_attrs, _, ENVNAME, BOXSTYLE = process_attributes(div.attributes, ENVNAME, BOXSTYLE, BOXOPTIONS)

		-- Split content into two columns, based on the position of the ruler (HorizontalRule)
		local left_content = split_list(div.content, 1, ruler_pos - 1)
		local right_content = split_list(div.content, ruler_pos + 1)

		--- Create column divs
		--local left_div  = pandoc.Div(left_content, { class = "column", attributes = columns_attrs.left })
		--- Left (upper) contents
		-- Attributes
		local left_attrs = pandoc.Attr("", { "left-content" }, table.unpack(columns_attrs.left))
		-- The div wrapped in a List
		local left_div = pandoc.List({ pandoc.Div(left_content, left_attrs) })

		----- Right (lower) contents
		-- Attributes
		local right_attrs = pandoc.Attr("", { "right-content" }, table.unpack(columns_attrs.left))
		---- Alternative to set the attributes
		-- right_div.attr = {id='',class="column", table.unpack(columns_attrs.right)}
		local right_div = pandoc.Div(right_content, right_attrs)
		right_div = pandoc.List({ right_div })

		-------- Parent div is the columns
		--- Setting its attributes. Remember that align and width attributes were removed
		attrs = pandoc.Attr("", { DIVNAME }, div.attributes)

		if #BOXOPTIONS > 0 then
			-- if table_not_empty(BOXOPTIONS) then
			local opts = table.concat(BOXOPTIONS, ",")
			-- BOXSTYLE = string.format("[%s]", string.join(",", table.unpack(BOXOPTIONS)))
			BOXSTYLE = BOXSTYLE .. "," .. opts
		end

		-- Creating the tcolorbox environment
		local env_open = latex(string.format("\\begin{%s}[%s]", ENVNAME, BOXSTYLE))
		local env_middle = latex("\\tcblower")
		local env_close = latex(string.format("\\end{%s}", ENVNAME))

		-- Adding the contents
		--- Opening the latex env at left_content
		left_content:insert(1, env_open)
		-- Inserting the middle line
		right_content:insert(1, env_middle)
		-- Closing the latex env at right_content
		right_content:insert(#right_content + 1, env_close)

		-- 3. Set the new content of the original div.
		-- The original div will now contain the two new divs we created.
		div.content = { left_content, right_content }
		div.attributes = attrs

		local all_cols = left_content .. right_content
		-- local all_cols =  env_open .. left_div .. env_middle .. right_div .. env_close
		--- Parent div contains the columns as children
		local result = pandoc.Div(all_cols, attrs)

		return result
		-- return div
	end
end

return {
	{ Div = Div }, -- Inline elements
}
