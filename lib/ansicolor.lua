-- http://lua-users.org/wiki/AnsiTerminalColors
-- With minor modifications/additions.
local pairs = pairs
local tostring = tostring
local setmetatable = setmetatable
local schar = string.char

local _M = {}

-- Setup meta table for concatenation of attributes
local colormt = {}

function colormt:__tostring()
   return self.value
end

function colormt:__concat(other)
   return tostring(self) .. tostring(other)
end

function colormt:__call(s)
   return self .. s .. _M.reset
end

colormt.__metatable = {}

local function makecolor(value)
    return setmetatable({ value = schar(27) .. '[' .. tostring(value) .. 'm' }, colormt)
end

-- Setup colors/attributes
local colors = {
    -- attributes
    reset = 0,
    clear = 0,
    bright = 1,
    bold = 1,
    dim = 2,
    italic = 3,
    underscore = 4,
    underline = 4,
    blink = 5,
    reverse = 7,
    hidden = 8,
    normal = 22,

    -- foreground
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    default = 39,

    -- background
    onblack = 40,
    onred = 41,
    ongreen = 42,
    onyellow = 43,
    onblue = 44,
    onmagenta = 45,
    oncyan = 46,
    onwhite = 47,
    ondefault = 49,
}


-- Load module
for c, v in pairs(colors) do
    _M[c] = makecolor(v)
end

return _M
