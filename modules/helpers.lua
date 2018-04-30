--Given a member and a guild (or false/nil), get the rank of the member
local function getRank(member, private)
	if not member then return 0 end
	local rank = 0
	if not private then
		local settings = modules.database:get(member, "Settings")
		if type(settings.mod_roles)=='table' then
			for _,v in ipairs(settings['mod_roles']) do
				if member:hasRole(v) then
					rank = 1
				end
			end
		end
		if type(settings.admin_roles)=='table' then
			for _,v in ipairs(settings['admin_roles']) do
				if member:hasRole(v) then
					rank = 2
				end
			end
		end
		if member.id == member.guild.owner.id then
			rank = 3
		end
	end
	if member.id == member.client.owner.id then
		rank = 4
	end
	return rank
end

-- Used to wrap and post errors in all events
local function dispatcher(name, ...)
	local b,e,n,g = checkArgs({'string'}, {name})
	if not b then
		client:error("<DISPATCHER> Unable to load %s (Expected: %s, Number: %s, Got: %s)", name,e,n,g)
		return
	end
	local args = {...}
	local ret, err = pcall(modules.events[name], ...)
	if not ret then
		if errLog then
			client:getChannel(errLog):send {embed = {
				description = err,
				footer = {text="DISPATCHER: "..name.." "..tostring(args[1])},
				timestamp = discordia.Date():toISO(),
				color = discordia.Color.fromRGB(255, 0 ,0).value,
			}}
		end
	end
end

local function unregisterAllEvents()
	if not modules.events then return end
	for k,_ in pairs(modules.events) do
		if k~="Timing" and k~="ready" then
			client:removeAllListeners(k)
		end
	end
end

local function registerAllEvents()
	if not modules.events then return end
	for k,_ in pairs(modules.events) do
		if k~="Timing" and k~="ready" then
			client:on(k,function(...) dispatcher(k,...) end)
		end
	end
end

-- attemps to resolve a guild known to the client from a provided object or ID. Do not rely on  this
local function resolveGuild(guild)
	local ts=tostring
	if not guild then error"No ID/Guild/Message provided" end
	local id
	if type(guild)=='table'then
		if guild['guild']then
			id=ts(guild.guild.id)
		else
			id=ts(guild.id)
		end
	else
		id=ts(guild)
		guild=client:getGuild(id)
	end
	return id,guild
end

-- Resolves a channel object given a guild and a string. Will match with ID or name
local function resolveChannel(guild,name)
	local this=getIdFromString(name)
	local c
	if this then
		c=guild:getChannel(this)
	else
		c=guild.textChannels:find(function(ch)
			return string.lower(ch.name)==string.lower(name)
		end)
	end
	return c
end

-- Resolves a member object given a guild and a string. Will match with ID or name
local function resolveMember(guild,name)
	local this = getIdFromString(name)
	local m
	if this then
		m = guild:getMember(this)
	else
		m = guild.members:find(function(mem)
			return string.lower(mem.name)==string.lower(name)
		end)
	end
	return m
end

-- Resolves a role object given a guild and a string. Will match with ID or name
local function resolveRole(guild,name)
	local this = getIdFromString(name)
	local r
	if this then
		r = guild:getRole(this)
	else
		r = guild.roles:find(function(ro)
			return string.lower(ro.name)==string.lower(name)
		end)
	end
	return r
end

-- Black magic fuckery. Don't mess with this or everything breaks
local function resolveCommand(str, prefix)
	local command,rest
	if string.match(str, "^<@!?"..client.user.id..">") then
		command, rest = str:sub(#client.user.mentionString+2):match('(%S+)%s*(.*)')
	elseif (prefix~="" and string.match(str,"^%"..prefix)) or prefix=="" then
		command, rest = str:sub(#prefix+1):match('(%S+)%s*(.*)')
	end
	return command, rest
end

-- Takes a (hopefully) ISO date string and turns it into a Date object, if not ISO formatted, returns the input
local function parseISOTime(time)
	if string.match(time or "", '(%d+)-(%d+)-(%d+).(%d+):(%d+):(%d+)(.*)') then return discordia.Date.fromISO(time) else return time end
end

-- Takes a string and attempts to build a time out from the current based on the input (i.e. 5m 20 seconds will build an Date object that time in the future)
local function parseTime(message)
	assert(type(message)=='string', "Invalid argument to parseTime. String expected, got "..type(message))
	local t = discordia.Date():toTableUTC()
	for time,unit in message:gmatch('(%d+)%s*(%D+)') do
		local u = unit:lower()
		if u:startswith('d') then
			t.day = t.day+time
		elseif u:startswith('h') then
			t.hour = t.hour+time
		elseif u:startswith('m') then
			t.min = t.min+time
		elseif u:startswith('s') then
			t.sec = t.sec+time
		end
	end
	return discordia.Date.fromTableUTC(t)
end

-- Converts a string into an embed table
local function formatMessageEmbed(str, member)
	local embed = {}
	for word in string.gmatch(str, "$[^$]*") do
		local field, val = string.match(word, "$(%S+):(.*)")
		if field=='title' then
			embed['title'] = formatMessageSimple(val, member)
		elseif field=='description' then
			embed['description'] = formatMessageSimple(val, member)
		elseif field=='thumbnail' then
			if val:startswith('member') then
				embed['thumbnail'] = {url=member.avatarURL}
			elseif val=='guild' then
				embed['thumbnail'] = {url=member.guild.iconURL}
			end
		elseif field=='color' then
			local color = val:match("#([0-9a-fA-F]*)")
			if #color==6 then
				embed['color'] = discordia.Color.fromHex(color).value
			end
		end
	end
	return embed
end

-- Takes a Date object and returns a new Time object representing the time between the given one and the current
local function timeBetween(time)
	return discordia.Time.fromSeconds(discordia.Date():toSeconds()-time:toSeconds())
end

-- Takes a Date object and returns a new Time object representing the time between the given one and the current
local function timeUntil(time)
	return discordia.Time.fromSeconds(time:toSeconds()-discordia.Date():toSeconds())
end

local t = {
	dispatcher = dispatcher,
	registerAllEvents = registerAllEvents,
	unregisterAllEvents = unregisterAllEvents,
	getRank = getRank,
	resolveCommand = resolveCommand,
	resolveGuild = resolveGuild,
	resolveChannel = resolveChannel,
	resolveMember = resolveMember,
	resolveRole = resolveRole,
	parseISOTime = parseISOTime,
	parseTime = parseTime,
	timeBetween = timeBetween,
	timeUntil = timeUntil,
	formatMessageEmbed = formatMessageEmbed,
}

-- Load this shit to global fam
for k,v in pairs(t) do
	_G[k] = v
end

return t
