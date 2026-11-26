--[[
panclude.lua: the include attribute, as a pandoc Lua filter.

    ```{.haskell include="src/Main.hs" startLine=10 endLine=24}
    ```

    ```{include="header.tex" raw="latex"}
    ```

    ::: {include="chapters/intro.md" shift-heading-level-by=1}
    :::

The included content goes after what the element holds: a code block's
text gets the file's text, verbatim; with raw="FORMAT" the block becomes
raw content; a div gets the file's blocks, read as a document. What the
element holds is not looked at. A relative path starts at the directory of
the file holding the element. When an include fails, the element is left
as it was, with a warning in pandoc's log (so --fail-if-warnings makes it
an error).

Run it before any other filter: pandoc -L panclude.lua ...

It reads whatever pandoc's Lua can read: anything the process can.

Specification: https://github.com/ickc/panclude/blob/main/SPEC.md
License: BSD-3-Clause
]]

PANDOC_VERSION:must_be_at_least '3.2'

local path = pandoc.path

-- Nested includes deeper than this fail.
local MAX_DEPTH = 32

-- On Windows a path may use either separator.
local WINDOWS = path.separator == '\\'
local SEPARATORS = WINDOWS and '[/\\]' or '/'

------------------------------------------------------------------------
-- Small helpers

-- A whole number in decimal, as an attribute's text; nil if it is not.
local function whole(text, negative_allowed)
  local pattern = negative_allowed and '^%-?%d+$' or '^%d+$'
  if text and text:match(pattern) then return math.tointeger(tonumber(text)) end
  return nil
end

-- A URL: a scheme of two letters or more, then a colon. One letter and a
-- colon is a Windows drive.
local function is_url(p)
  return p:match('^%a[%w+.-]+:') ~= nil
end

-- The directory part of a path, as written, with '/' between its parts;
-- '' when it has none.
local function directory_of(p)
  if WINDOWS then p = p:gsub('\\', '/') end
  local dir = p:match('^(.*)/[^/]*$')
  if not dir then return '' end
  if dir == '' then return '/' end -- '/f.md'
  while dir:sub(1, 2) == './' do dir = dir:sub(3) end
  if dir == '.' then return '' end
  return dir
end

-- A path with '.' and '..' resolved by its text alone, to tell whether
-- two paths name the same file.
local function lexical(p)
  local parts = {}
  local absolute = p:match('^' .. SEPARATORS) and true or false
  for part in p:gmatch('[^' .. (WINDOWS and '/\\' or '/') .. ']+') do
    if part == '..' and #parts > 0 and parts[#parts] ~= '..' then
      table.remove(parts)
    elseif part ~= '.' then
      parts[#parts + 1] = part
    end
  end
  return (absolute and '/' or '') .. table.concat(parts, '/')
end

-- An image's or link's target that is a relative path: not empty, not a
-- fragment or query, not absolute, and no URL (a Windows drive included).
local function is_relative_target(target)
  return target ~= ''
    and not target:match('^[#?/\\]')
    and not target:match('^%a[%w+.-]*:')
end

local function rebase_target(target, prefix)
  if not is_relative_target(target) then return target end
  local separator = prefix:sub(-1) == '/' and '' or '/'
  return prefix .. separator .. (target:gsub('^%./', ''))
end

------------------------------------------------------------------------
-- Where the document is

-- The context of the elements of one file: the directory its relative
-- paths start at, its name in messages, how deep it is, and the files
-- including it (for cycles).
local function main_context()
  -- Quarto runs pandoc on a temporary copy of the page it renders, and
  -- names the page itself in quarto.doc.input_file.
  local first = (quarto and quarto.doc and quarto.doc.input_file) or PANDOC_STATE.input_files[1]
  local cwd = pandoc.system.get_working_directory()
  if not first or first == '-' then
    return { dir = '.', name = 'standard input', depth = 0, chain = {}, cwd = cwd }
  end
  if is_url(first) then
    return { url = true, name = first, depth = 0, chain = {}, cwd = cwd }
  end
  local key = lexical(path.is_absolute(first) and first or path.join({ cwd, first }))
  return {
    dir = path.directory(first), name = first, depth = 0,
    chain = { [key] = true }, cwd = cwd,
  }
end

------------------------------------------------------------------------
-- Reading a file

-- The file an element names: where to open it, and its key for cycles.
-- Returns nil and the reason when it names none.
local function locate(include, ctx)
  if include == '' then return nil, 'the path is empty' end
  if is_url(include) then return nil, 'a URL is not a path' end
  if ctx.url then return nil, 'the document is a URL, so no file is included' end
  if ctx.depth >= MAX_DEPTH then
    return nil, 'more than ' .. MAX_DEPTH .. ' nested includes'
  end
  local open
  if path.is_absolute(include) or ctx.dir == '.' or ctx.dir == '' then
    open = include
  else
    open = path.join({ ctx.dir, include })
  end
  local key = lexical(path.is_absolute(open) and open or path.join({ ctx.cwd, open }))
  return { open = open, key = key }
end

-- A file's text: UTF-8 checked, a byte order mark dropped, line endings
-- as '\n'. Returns nil and the reason when it cannot. Errors from the
-- system are not passed on: the reason is one of a few fixed phrases.
local function read_text(open)
  local f, _, code = io.open(open, 'rb')
  if not f then
    return nil, code == 2 and 'not found' or 'cannot be read'
  end
  local text = f:read('a')
  f:close()
  if not text then return nil, 'cannot be read' end
  if not utf8.len(text) then return nil, 'not UTF-8' end
  text = text:gsub('^\239\187\191', '')
  text = text:gsub('\r\n?', '\n')
  return text
end

local function warn(include, ctx, reason)
  pandoc.log.warn(('panclude: cannot include "%s" in %s: %s')
    :format(include, ctx.name, reason))
end

------------------------------------------------------------------------
-- A code block: the file's text

-- The lines of a text whose final newline, if any, ends the last line.
local function split_lines(text)
  local lines = {}
  if text == '' then return lines end
  if text:sub(-1) ~= '\n' then text = text .. '\n' end
  for line in text:gmatch('([^\n]*)\n') do lines[#lines + 1] = line end
  return lines
end

-- The attributes the step reads from a code block, checked. Returns nil
-- and the reason when one is not a whole number.
local function code_options(attrs)
  local opts = {}
  -- Both spellings: the hyphenated one wins, as in include-code-files.
  for _, name in ipairs({ 'startLine', 'endLine' }) do
    local hyphenated = name:gsub('%u', function(c) return '-' .. c:lower() end)
    local written = attrs[hyphenated] and hyphenated or name
    local text = attrs[written]
    if text then
      local n = whole(text)
      if not n or n < 1 then
        return nil, ('%s="%s" is not a whole number from 1'):format(written, text)
      end
      opts[name] = n
    end
  end
  if attrs.dedent then
    opts.dedent = whole(attrs.dedent)
    if not opts.dedent then
      return nil, ('dedent="%s" is not a whole number'):format(attrs.dedent)
    end
  end
  if attrs.raw == '' then return nil, 'raw="" names no format' end
  return opts
end

local function include_code(cb, ctx)
  local attrs = cb.attributes
  local include = attrs.include
  local opts, reason = code_options(attrs)
  local file
  if opts then file, reason = locate(include, ctx) end
  local text
  if file then text, reason = read_text(file.open) end
  if not text then
    warn(include, ctx, reason)
    return nil
  end

  local lines = split_lines(text)
  local first = opts.startLine or 1
  local last = math.min(opts.endLine or #lines, #lines)
  if (opts.startLine or opts.endLine) and first > last then
    warn(include, ctx, ('the range selects none of the file\'s %d lines'):format(#lines))
    return nil
  end
  local selected = {}
  for i = first, last do
    local line = lines[i]
    if opts.dedent then
      local spaces = #line:match('^ *')
      line = line:sub(math.min(spaces, opts.dedent) + 1)
    end
    selected[#selected + 1] = line
  end

  -- Appended to the block's own text: its lines, then the file's. An
  -- empty text has no lines, and neither has an empty file.
  local own = cb.text
  if own == '' then
    text = table.concat(selected, '\n')
  elseif #selected == 0 then
    text = own
  else
    text = own .. '\n' .. table.concat(selected, '\n')
  end

  if attrs.raw then return pandoc.RawBlock(attrs.raw, text) end
  cb.text = text
  for _, name in ipairs({ 'include', 'startLine', 'endLine', 'start-line',
                          'end-line', 'dedent' }) do
    attrs[name] = nil
  end
  -- The source's numbers, when the file's lines are the block's first.
  if opts.startLine and own == '' and not attrs.startFrom then
    attrs.startFrom = tostring(opts.startLine)
  end
  return cb
end

------------------------------------------------------------------------
-- A div: the file as a document

-- The format to read a div's file with: the div's own; else the one the
-- file's extension names, if not markdown; else the main document's.
local function reader_format(format, include)
  if format then return format end
  local by_extension = pandoc.format.from_path(include)
  if by_extension and by_extension ~= 'markdown' then return by_extension end
  -- A libpandoc host names the main reader, with its extensions.
  local main = os.getenv('PANDOC_INPUT_FORMAT')
  if main and main ~= '' then return main end
  -- Stock pandoc does not: assume markdown, with the document's
  -- extensions when markdown has them all (it is then most likely
  -- markdown), else markdown's own.
  local known = {}
  for _, ext in ipairs(pandoc.format.all_extensions('markdown')) do known[ext] = true end
  local extensions = {}
  for _, ext in ipairs(PANDOC_READER_OPTIONS.extensions) do
    if not known[ext] then return 'markdown' end
    extensions[#extensions + 1] = ext
  end
  return { format = 'markdown', extensions = extensions }
end

-- The main document's reader options, but for standalone: the file is
-- read as a part of a document, so that a reader such as rst's does not
-- take its first heading for the title (which would then be dropped,
-- with the rest of the file's metadata).
local function part_options()
  local options = pandoc.ReaderOptions(PANDOC_READER_OPTIONS)
  options.standalone = false
  return options
end

local function shift_headings(blocks, shift)
  if shift == 0 then return blocks end
  return blocks:walk({
    Header = function(h)
      local level = h.level + shift
      if level < 1 then return pandoc.Para(h.content) end
      h.level = level
      return h
    end,
  })
end

-- The included content's relative paths, rewritten to name the same
-- files from the including file's directory: an image's, a link's, and
-- the include of an element whose include failed. Applied at each level
-- of nesting, they name the files from the main document's directory.
local function rebase(blocks, prefix)
  if prefix == '' then return blocks end
  local function rebase_include(el)
    if el.attributes.include then
      el.attributes.include = rebase_target(el.attributes.include, prefix)
      return el
    end
  end
  return blocks:walk({
    Image = function(img) img.src = rebase_target(img.src, prefix); return img end,
    Link = function(link) link.target = rebase_target(link.target, prefix); return link end,
    CodeBlock = rebase_include,
    Div = rebase_include,
  })
end

local expand -- function(blocks, ctx): the blocks with their includes done

local function include_div(div, ctx)
  local attrs = div.attributes
  local include = attrs.include
  local shift, reason = 0, nil
  local shift_text = attrs['shift-heading-level-by']
  if shift_text then
    shift = whole(shift_text, true)
    if not shift then
      reason = ('shift-heading-level-by="%s" is not a whole number'):format(shift_text)
    end
  end
  local file
  if not reason then file, reason = locate(include, ctx) end
  if file and ctx.chain[file.key] then
    file, reason = nil, 'a cycle: the file is already being included'
  end
  local text
  if file then text, reason = read_text(file.open) end
  local doc
  if text then
    local format = reader_format(attrs.format, include)
    local ok, result = pcall(pandoc.read, text, format, part_options())
    if ok then
      doc = result
    else
      -- pandoc's message can quote the file, so it is not passed on.
      reason = ('pandoc cannot read it as "%s"'):format(
        type(format) == 'table' and format.format or format)
    end
  end
  if not doc then
    warn(include, ctx, reason)
    return nil
  end

  local chain = {}
  for key in pairs(ctx.chain) do chain[key] = true end
  chain[file.key] = true
  local inner = {
    dir = path.directory(file.open), name = file.open,
    depth = ctx.depth + 1, chain = chain, cwd = ctx.cwd,
  }
  local blocks = expand(doc.blocks, inner)
  blocks = shift_headings(blocks, shift)
  blocks = rebase(blocks, directory_of(include))

  -- Appended to the div's own blocks, whose includes are this file's.
  local own = expand(div.content, ctx)
  own:extend(blocks)
  div.content = own
  attrs.include = nil
  attrs.format = nil
  attrs['shift-heading-level-by'] = nil
  return div
end

------------------------------------------------------------------------
-- The walk

-- Top down, so that a div's included content, already done, is not
-- walked again. A div's own blocks are walked like any others: by
-- include_div when its include succeeds, by the walk going on into the
-- div when it fails.
local function include_filter(ctx)
  return {
    traverse = 'topdown',
    CodeBlock = function(cb)
      if cb.attributes.include then return include_code(cb, ctx) end
    end,
    Div = function(div)
      if div.attributes.include then
        local done = include_div(div, ctx)
        if done then return done, false end
      end
    end,
  }
end

expand = function(blocks, ctx)
  return blocks:walk(include_filter(ctx))
end

return {
  {
    Pandoc = function(doc)
      return doc:walk(include_filter(main_context()))
    end,
  },
}
