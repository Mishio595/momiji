-- Traverses a table and returns an iterator sorted by keys
local function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

--Type checking function, useful when strict typing is needed
local function checkArgs(types, vals)
	for i,v in ipairs(types) do
		if type(v)=='table' then
			local t1=true
			if type(vals[i])~=v[1] then
				t1=false
			end
			if t1==false then
				if type(vals[i])~=v[2] then
					return false,v,i,type(vals[i])
				end
			end
		else
			if type(vals[i])~=v then
				return false,v,i,type(vals[i])
			end
		end
	end
	return true,'',#vals
end

-- This is shit, please fix
local function humanReadableTime(table)
	local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	if #tostring(table.min) == 1 then table.min = "0"..table.min end
	if #tostring(table.hour) == 1 then table.hour = "0"..table.hour end
	return days[table.wday]..", "..months[table.month].." "..table.day..", "..table.year.." at "..table.hour..":"..table.min or table
end

-- Given a Lua date time table, create a string with the values and keys
local function prettyTime(t)
	local order = {days = "day", hours = "hour", minutes = "minute", seconds = "second"}
	local out = ""
	for k,v in pairsByKeys(order) do
		if t[k] then
			if t[k]==1 then
				out = out~="" and out..", "..t[k].." "..v or t[k].." "..v
			elseif t[k]~=0 then
				out = out~="" and out..", "..t[k].." "..v.."s" or t[k].." "..v.."s"
			end
		end
	end
	return out
end

-- Tries to find a Discord snowflake in the given string, returning it if one is found. returns nil on failure
local function getIdFromString(str)
	local d = string.match(tostring(str),"<?[@#]?!?(%d+)>?")
	if d and #d>=17 then return d else return end
end

-- Used in message formatting, purely matches "$type:(capture)" and returns the capture group
local function getFormatType(str)
	local type = str:match("$type:(%S*)")
	return type
end

-- Searches a string for known replacements and replaces them
local function formatMessageSimple(str, member)
	for word, opt in string.gmatch(str, "{([^:{}]+):?([^:{}]*)}") do
		if word:lower()=='user' then
			if opt~="" then
				str = str:gsub("{[^{}]*}", tostring(member[opt]), 1)
			else
				str = str:gsub("{[^{}]*}", member.mentionString, 1)
			end
		elseif word:lower()=='guild' then
			if opt~="" then
				str = str:gsub("{[^{}]*}", tostring(member.guild[opt]), 1)
			else
				str = str:gsub("{[^{}]*}", member.guild.name, 1)
			end
		end
	end
	return str
end

-- Also black magic fuckery, but I vaguely understand how this works
local function getSwitches(str)
    local t = {}
	str = str:gsub("\\/", "—") --Use a better method to escape than substitution you dumb cunt
	t.rest = str:match("^([^/]*)/?"):trim()
    for switch, arg in str:gmatch("/%s*(%S*)%s*([^/]*)") do
        t[switch]=arg:trim()
    end
	for k,v in pairs(t) do
		t[k] = v:gsub("—", "/")
	end
    return t
end

return function()
	local functions = {
		checkArgs = checkArgs,
		humanReadableTime = humanReadableTime,
		prettyTime = prettyTime,
		pairsByKeys = pairsByKeys,
		getIdFromString = getIdFromString,
		getFormatType = getFormatType,
		formatMessageSimple = formatMessageSimple,
		getSwitches = getSwitches,
	}
	-- Load this shit to global fam
	for k,v in pairs(functions) do
		_G[k] = v
	end
	return functions
end
