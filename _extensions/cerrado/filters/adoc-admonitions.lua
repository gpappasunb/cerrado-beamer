--[[
--
## Introduction

:moon: Pandoc lua filter that processes asciidoc-style admonitions and encloses them in a DIV with
a specified class. Its purpose is to simplify the writing of simple admonitions (callouts) in markdown/quarto.

The filter scans the document for a specially formatted token, and if a match is found in the
configured terms, it changes the paragraph to a Div (block) containing a corresponding class, also
configurable.

### Syntax

The admonitions are words appearing in the **first column** of a paragraph followed by a
colon (:) and a space. For example:

	NOTE: this is a note

These are invalid:

	NOTE:this  (no space after the colon)

	   NOTE: this (not in the first column)


**IMPORTANT**: This markup works with a single paragraph. Put all the content in a single line

### Default admonitions

The default token names and classes are coded in the ADMONITIONS table.

	NOTE = "admonitionnote",
	TIP = "admonitiontip",
	ERROR = "admonitionerror",
	CODE = "admonitionterm",
	TERMINAL = "admonitionterm",
	QUOTE = "admonitionquote",
	WARNING = "admonitionwarn",
	WARN = "admonitionwarn",

So, it is possible to use:

	WARN: this is a warning


### What is produces

After scanning the document and finding the correctly coded token, the extension produces

* Original

		NOTE: this is a note

* transformed

		::: admonitionnote
		this is a note
		:::


### Including a title

There is a special markup that permits to include a title to the div. This is OPTIONAL, and the
the syntax is:

	TOKEN|title comes here|: text comes here

* TOKEN is one of the keys above
* |title| the default marker to indicate a title is "|" and it should be provided right after
the TOKEN, without spaces!
* ":" ending of the token pattern.


	NOTE|note title|: note text
	
	is changed to:

	::: {.admonitionnote title="note title"}
	note text
	:::

Without the title specification:

	NOTE: note text

	is changed to:

	::: {.admonitionnote}
	note text
	:::

## Configuration

### Altering/adding Token classes

It is possible to alter the class names associated with the tokens by modifying the
document metadata using the name of the filter (adoc-admonition)

    ---
    adoc-admonition:
        NOTE: mynoteclass
        TIP: mytipclass

It is also possible to include new tokens:

    ---
    adoc-admonition:
        xxx: admonitionnote
        TIP: TIPADMONITION

In this case, the default ones are still valid.

With that in place, the line:

    xxx: xxx enclosed in a admonitionnote Div

is transformed to:

   ::: admonitionnote
   xxx enclosed in a admonitionnote Div
   :::


### Changing the matching patterns

It is also possible to change the token matching regular expression by using a special key as a child of the
metadata entry for the extension. The default configuration is:

    ---
    adoc-admonition:
	config:
	  left: ""
	  right: ":"
	  title: "|"

You can change the values with:

    ---
    adoc-admonition:
        TIP: TIPADMONITION
	config:
	  left: ">"
	  right: "<"
	  title: "*"

In the case above, the new token syntax should be:

	>IMPORTANT*title*< text of div


## Usage in pandoc

    pandoc -s test.md  -t beamer --lua-filter adoc-admonitions.lua


## Author

	Author: Georgios Pappas Jr
	Institution: University of Brasilia (UnB) - Brazil
	Version: 0.1

--]]

-- For debugging purposes using ZeroBrane IDE
-- require("mobdebug").start()

-- The default filter name to appear in the metadata block
local FILTERNAME = "adoc-admonition"

-- Admonition mapping. Key is the ADMONITION name (case is considered) and the
-- value is the classname the admonition should be mapped into
local ADMONITIONS = {
	NOTE = "admonitionnote",
	TIP = "admonitiontip",
	ERROR = "admonitionerror",
	CODE = "admonitionterm",
	TERMINAL = "admonitionterm",
	QUOTE = "admonitionquote",
	WARNING = "admonitionwarn",
	WARN = "admonitionwarn",
}

-- Default configuration for admonition string matching
-- TOKEN||: text
-- left=nothing
-- title=enclosed in this character. Default is | and appearing right after the token name
-- right=:
local CONFIG = {
	left = "",
	right = ":",
	title = "|",
}

--
-- getting the document metadata. This is executed only once.
-- It gets the variable from markdown metadata and merges it with the
-- default ADMONITIONS table.
--
local function merge_metadata(_ADMONITIONS, meta)
	if not _ADMONITIONS then
		_ADMONITIONS = {}
	end
	local user_admonitions = meta[FILTERNAME]
	--if user_admonitions and user_admonitions.t == "MetaMap" then
	if user_admonitions and pandoc.utils.type(user_admonitions) == "table" then
		for key, value in pairs(user_admonitions) do
			_ADMONITIONS[key] = pandoc.utils.stringify(value)
		end
	end
	return _ADMONITIONS
end

--
-- Tries to find in the paragraphs words starting with the defined ADMONITIONS
-- defined. Then strips the admonition keyword and encloses the remaing text
-- in a DIV with the class given by the value of the keyword in the ADMONITIONS table.
--
function Para(p)
	-- Getting the text
	local text = pandoc.utils.stringify(p)

	-- Skip empty lines
	if text == "" then
		return nil
	end

	-- Getting the first word and the rest of the content
	-- local keyword, content = text:match("^([%w_]+): (.*)")
	local token_regex = "^"
		.. CONFIG.left
		.. "([%w_]+)"
		.. CONFIG.title
		.. "?(.*)"
		.. CONFIG.title
		.. "?"
		.. CONFIG.right
		.. "(.*)"
	local keyword, title, content = text:match(token_regex)

	-- Check if the found keyword is a defined admonition
	if keyword and ADMONITIONS[keyword] then
		local classname = ADMONITIONS[keyword]
		-- Trimming the spaces in content
		if content then
			content = content:gsub("^%s*", "")
		end
		local new_para = pandoc.Para(pandoc.Str(content))

		-- Creating a RawBlock with a Latex environment
		-- if FORMAT:match("latex") or FORMAT:match("beamer") then
		-- 	return {
		-- 		pandoc.RawBlock("\\begin{" .. classname .. "}{}", "tex"),
		-- 		new_para,
		-- 		pandoc.RawBlock("\\end{" .. classname .. "}", "tex"),
		-- 	}
		-- end

		-- The attributes
		local attrs = { class = classname }
		-- Adding the title attribute if provided
		if title and string.len(title) > 0 then
			-- Removing the last title delimiter character
			title = title:gsub(CONFIG.title .. "$", "")
			-- attrs = pandoc.Attr("", { class = classname }, { title = title })
			attrs = { class = classname, title = title }
		end
		-- Create the resulting Div
		local div = pandoc.Div(new_para, attrs)
		return div
	end

	-- If no admonition is found, return the paragraph unchanged
	return p
end

-- Reading metadata variables to change the latex environment
--- The syntax is:
--- adoc-admonition:
---   TOKEN_NAME: ENVIRONMENT_NAME
---   VERB: "verbatim"
---   config:
---     left: ">"
---     right: "<"
---     title: "*"
--- The text "VERB: test verbatim" will be changed and wrapped in a div named verbatim
--- If the config key is provided, then it will change the token regex
--- In the case above, it should be written in markdown as:  >VERB*title*< text of div
---@param meta any
function Meta(metadata)
	-- Merges the ADMONITIONS to include/override the values present in FILTERNAME metadata
	-- ADMONITIONS is a global variable in this extension
	ADMONITIONS = merge_metadata(ADMONITIONS, metadata)
	-- Intercepts the special config key
	local data = metadata[FILTERNAME] -- ["config"] or nil
	if data then
		local data_table = data.config and metamap_to_luatable(data)
		CONFIG = merge_tables(CONFIG, data_table)
	end
	-- Return metadata
	return metadata
end

-- Helper function to merge two map-like tables into a new table.
-- The values in the second table override same key in the first table
-- @oaram t1 table
-- @oaram t2 table
-- @return table The merged table
function merge_tables(t1, t2)
	local result = {}
	for k, v in pairs(t1) do
		result[k] = v
	end
	if type(t2) == "table" then
		for k, v in pairs(t2) do
			result[k] = v
		end
	end
	return result
end

-- Helper function to convert a Pandoc MetaMap from the YAML
-- into a plain Lua table that's easier to work with.
function metamap_to_luatable(m)
	local T = {}
	if m then
		for k, v in pairs(m) do
			T[k] = pandoc.utils.stringify(v)
		end
	end
	return T
end

--
-- The filter to be exported
return {
	{ Meta = Meta },
	{ Para = Para },
}
