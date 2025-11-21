-- environment.lua
-- Transforms a Div into LaTeX command or environment
--
-- With modifications, to add the pass option
-- Copyright (C) 2020 by RStudio, PBC

-- logging from https://github.com/pandoc-ext/logging
-- local logging = require 'logging'
--
-- Modified by Georgios Pappas Jr
--- Added more processing options. The pass option
--- passes its argument as a single optional argument to LaTeX
--- Adding SKIP_CLASS, a special class to turn off the conversion for Spans
--- Automatically skipping conversion for spans inside BlockQuote or LineBlock elements
---------------------------------------------------

local classEnvironments = pandoc.MetaMap({})
local classCommands = pandoc.MetaMap({})
local SKIP_CLASS = "skipspan"

-- For debugging purposes
-- require("mobdebug").start()

-- helper that identifies arrays
local function tisarray(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then
      return false
    end
  end
  return true
end

-- reads the environments
local function readEnvironments(meta)
  local env = meta["environments"]
  if env ~= nil then
    if tisarray(env) then
      -- read an array of strings
      for _, v in ipairs(env) do
        local value = pandoc.utils.stringify(v)
        classEnvironments[value] = value
      end
    else
      -- read key value pairs
      for k, v in pairs(env) do
        local key = pandoc.utils.stringify(k)
        local value = pandoc.utils.stringify(v)
        classEnvironments[key] = value
      end
    end
  end
end

-- Read the commands list from metadata
-- These would be converted by this filter
local function readCommands(meta)
  local env = meta["commands"]
  if env ~= nil then
    if tisarray(env) then
      -- read an array of strings
      for _, v in ipairs(env) do
        local value = pandoc.utils.stringify(v)
        classCommands[value] = value
      end
    else
      -- read key value pairs
      for k, v in pairs(env) do
        local key = pandoc.utils.stringify(k)
        local value = pandoc.utils.stringify(v)
        classCommands[key] = value
      end
    end
  end
end

--[[
 -   ▄┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▄
 -   ░ Reads the metadata                                           ░
 -   ▀┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▀

commands: [cmd1, cmd2]
environments: [env1, env2]

]]
local function readEnvsAndCommands(meta)
  readEnvironments(meta)
  readCommands(meta)
end

-- use the environments from metadata to
-- emit a custom environment for latex
-- This writes the LaTeX environments
local function writeEnvironments(divEl)
  if FORMAT == "beamer" or FORMAT == "latex" then
    if divEl.attr.classes:includes(SKIP_CLASS) then
      print("Skipping Div because it has class " .. SKIP_CLASS)
      return divEl
    end
    -- Iterating over the metadta registered environments
    for k, v in pairs(classEnvironments) do
      if divEl.attr.classes:includes(k) then
        -- process this into a latex environment
        local beginEnv = "\\begin" .. "{" .. v .. "}"
        local endEnv = "\n\\end{" .. v .. "}"

        -- check if custom options or arguments are present
        -- and add them to the environment accordingly
        local opts = divEl.attr.attributes["options"]
            or divEl.attr.attributes["opts"]
            or divEl.attr.attributes["opt"]
        if opts then
          beginEnv = beginEnv .. "[" .. opts .. "]"
        end

        local args = divEl.attr.attributes["arguments"]
            or divEl.attr.attributes["title"]
            or divEl.attr.attributes["args"]
            or divEl.attr.attributes["arg"]
            or ""
        --@@ Forces writing the braces, even if no arguments are given.
        --if args then
        beginEnv = beginEnv .. "{" .. args .. "}"
        --end
        -- if the first and last div blocks are paragraphs then we can
        -- bring the environment begin/end closer to the content
        if
            #divEl.content > 0
            and divEl.content[1].t == "Para"
            and divEl.content[#divEl.content].t == "Para"
        then
          table.insert(divEl.content[1].content, 1, pandoc.RawInline("tex", beginEnv .. "\n"))
          table.insert(divEl.content[#divEl.content].content, pandoc.RawInline("tex", "\n" .. endEnv))
        else
          table.insert(divEl.content, 1, pandoc.RawBlock("tex", beginEnv))
          table.insert(divEl.content, pandoc.RawBlock("tex", endEnv))
        end
        return divEl
      end
    end
  end
end

-- Helper function to write a comma-separated list
-- of commands to square bracketed items
-- opts="flag=1,fg=blue" -> [flag=1][fg=blue]
local function buildCommandArgs(opts, format, separator)
  if not separator then
    return opts
  end
  local function wrap(o)
    return string.format(format, o)
  end
  local t = pandoc.List()
  for str in string.gmatch(opts, "([^" .. separator .. "]+)") do
    t:insert(str)
  end
  return table.concat(t:map(wrap), "")
end

-- use the environments from metadata to
-- emit a custom environment for latex
-- if attributes are named
---- opts="a,b,c" then it transforms to \command[a][b][c]{...}
---- args="a,b,c" then it transforms to \command[]{a}{b}{c}
---  pass="a,b,c" then it transforms to \command[a,b,c]{...}"
local function writeCommands(spanEl)
  -- If the span contains this class, its processing is skipped
  if spanEl.attr.classes:includes(SKIP_CLASS) then
    print("Skipping Span because it has class " .. SKIP_CLASS)
    return spanEl
  end

  -- Only works for beamer or latex
  if FORMAT == "beamer" or FORMAT == "latex" then
    -- print("INSIDE writeCommands=" .. FORMAT .. "cmd=")
    for k, v in pairs(classCommands) do
      if spanEl.attr.classes:includes(k) then
        -- resolve the begin command
        local beginCommand = "\\" .. pandoc.utils.stringify(v)
        -- check if custom options or arguments are present
        -- and add them to the environment accordingly
        local opts = spanEl.attr.attributes["options"]
            or spanEl.attr.attributes["opts"]
            or spanEl.attr.attributes["opt"]
        local args = spanEl.attr.attributes["arguments"]
            or spanEl.attr.attributes["args"]
            or spanEl.attr.attributes["arg"]
        local pass = spanEl.attr.attributes["pass"]

        -- print("COMMAND: " .. k .. " = " .. v)
        if pass then
          beginCommand = beginCommand .. string.format("[%s]", pass)
        elseif opts then
          beginCommand = beginCommand .. buildCommandArgs(opts, "[%s]", ",")
        end

        if args then
          beginCommand = beginCommand .. buildCommandArgs(args, "{%s}")
        end

        local beginCommandRaw = pandoc.RawInline("latex", beginCommand .. "{")

        -- the end command
        local endCommandRaw = pandoc.RawInline("latex", "}")

        -- attach the raw inlines to the span contents
        local result = spanEl.content
        table.insert(result, 1, beginCommandRaw)
        table.insert(result, endCommandRaw)

        return result
      end
    end
  end

  -- If no transformation was applied (not latex, or no class matched),
  -- return the element unmodified.
  return spanEl
end

--[[
 -   ▄┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▄
 -   ░ Checks if a block contains a Span                            ░
 -   ▀┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▀
 If so, the SKIP_CLASS is added to it, preventing its processing by the
 writeCommands functions (the Span processor)
]]
function skipSpanInside(el)
  return el:walk({
    Span = function(span)
      -- Adding a class to mark the span to be skipped
      table.insert(span.attr.classes, SKIP_CLASS)
      return span
    end,
  })
end

--[[
 -   ▄┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▄
 -   ░ Main document processor                                      ░
 -   ▀┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈▀
Processes first the Meta elements, followed by BlockQuotes and LineBlocks
The last walk processes Divs and Spans
]]
function Pandoc(doc)
  doc = doc:walk({ Meta = readEnvsAndCommands }) -- (1)
  -- Scans BlockQuote elements, and mark them with SKIP_CLASS
  -- This disables the conversion for this element
  doc = doc:walk({ BlockQuote = skipSpanInside })
  -- Same for LineBlock
  doc = doc:walk({ LineBlock = skipSpanInside })
  -- Perform the Div/Span processing
  return doc:walk({ Div = writeEnvironments, Span = writeCommands })
end

-- Run in two passes so we process metadata
-- and then process the divs
--[[
return {
  { Meta = readEnvsAndCommands },
  { Div = writeEnvironments },
  -- The third filter now handles both Spans (which run writeCommands)
  -- and BlockQuotes (which run handleBlockQuote to prevent
  -- Spans inside them from being processed).
  {
    BlockQuote = handleBlockQuote,
    LineBlock = handleBlockQuote,
    Span = writeCommands,
  },
}
]]
--
--
