--[[
Pandoc filter that creates a Div with simpler syntax for columns
 in Latex/Beamer. It works for only two columns and the delimiter for
 the columns is a HorizontalRule element (--- or * * *).
 
 The upper text goes to the left column and the lower to the right
 
 The syntax is:
 
 ::: twocol
 
 Content left
 
 * * *
 Content right
 
 Content right
 
 ::::::::::
 
 Alternatively, it is possible to pass some options controlling the columns, namely
 'width' and 'align'. For these,specify the values inside quotes and separated by commas. If
 no commas, then the value will be applied to both columns.
 
 ::: {.twocol align="top,center" width="20%,80%" .onlytextwidth}
 
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
local DIVNAME = "twocol"


-------------------
-- Helper functions
-------------------


--- Split a string at commas.
-- @param str The string to be split.
-- @return a pandoc.List with the split string at commas.
local function comma_separated_values(str)
  local acc = pandoc.List:new{}
  for substr in str:gmatch('([^,]*)') do
    acc[#acc + 1] = substr:gsub('^%s*', ''):gsub('%s*$', '') -- trim
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
    if start_idx < 0 then start_idx = n + start_idx + 1 end
    if end_idx < 0 then end_idx = n + end_idx + 1 end
    
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
local function process_attributes(attrs)
  
	columns_attrs = {
		left = {},
		right = {},
	}

	for _, attr_name in ipairs({ "align", "width" }) do

		if attrs[attr_name] then
      -- Split the attribute string. ("left,right") -> { left = "left", right = "right" }
			local split = split_attributes(attrs[attr_name], attr_name)
			table.insert(columns_attrs["left"],  {[attr_name]=split.left})
			table.insert(columns_attrs["right"],  {[attr_name]=split.right})
			-- Removing the attribute from the original table
			attrs[attr_name] = nil
		end
	end
	-- If no elements in columns_attrs then make it an empty string
	if #columns_attrs.left < 1 then columns_attrs = "" end

	return columns_attrs, attrs
end

--- Transforms the div that contains the DIVNAME class.
-- @param div the pandoc.Div element to be processed.
function Div(div,attrs)
  ---- For debugging purposes using ZeroBrane IDE
  ---- require("mobdebug").start()

	-- Check if the div contains the DIVNAME class
	if not (div.classes:includes(DIVNAME)) then
		return nil
	end
  
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
	local columns_attrs = process_attributes(div.attributes)

	-- Split content into two columns, based on the position of the ruler (HorizontalRule)
	local left_content  = split_list(div.content, 1, ruler_pos - 1)
	local right_content = split_list(div.content, ruler_pos + 1)
  
	--- Create column divs
	--local left_div  = pandoc.Div(left_content, { class = "column", attributes = columns_attrs.left })
  --- Left (upper) contents
  -- Attributes
  local left_attrs = pandoc.Attr('',{'column',"left-content"}, table.unpack(columns_attrs.left))
  -- The div wrapped in a List
  local left_div  = pandoc.List({pandoc.Div(left_content, left_attrs)})
  
  ----- Right (lower) contents
  -- Attributes
  local right_attrs = pandoc.Attr('',{'column',"right-content"}, table.unpack(columns_attrs.left))
  ---- Alternative to set the attributes
  -- right_div.attr = {id='',class="column", table.unpack(columns_attrs.right)}
	local right_div = pandoc.Div(right_content,right_attrs)
  right_div = pandoc.List({right_div})
  
  -------- Parent div is the columns
  --- Setting its attributes. Remember that align and width attributes were removed
  attrs = pandoc.Attr('', { "columns" } , div.attributes)
  -- Merging the two columns
  local all_cols = left_div .. right_div
  --- Parent div contains the columns as children
  local result = pandoc.Div( all_cols , attrs )
  
  return result
end
