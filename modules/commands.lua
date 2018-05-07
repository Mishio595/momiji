local uv = require("uv")
local pprint = require("pretty-print")
local ffi = require("ffi")
local fs = require('fs')
local colors = require('./res/colors')
local enums = discordia.enums
local commands = {}

-- addCommand adapted from DannehSC/Electricity-2.0
function addCommand(name, desc, cmds, usage, rank, multiArg, switches, serverOnly, func)
	local bool,expected,number,got = checkArgs({'string', 'string', {'table','string'}, 'string', 'number', 'boolean', 'boolean', 'boolean', 'function'}, {name,desc,cmds,usage,rank,multiArg,switches,serverOnly,func})
	if not bool then
		client:error("<COMMAND LOADING> Unable to load %s (Expected: %s, Number: %s, Got: %s)", name,expected,number,got)
		return
	end
	commands[name] = {name=name, description=desc,commands=(type(cmds)=='table' and cmds or {cmds}),usage=usage,rank=rank,multi=multiArg,switches=switches,serverOnly=serverOnly,action=func}
end

-- [[ Rank 0 Commands ]]

addCommand('Bot Info', 'Info on the bot', {'binfo','botinfo','bi'}, '', 0, false, false, false, function(message)
	message:reply{embed={
		thumbnail = {url=client.user.avatarURL},
		timestamp = discordia.Date():toISO(),
		description = "Hi! I'm Momiji, a general purpose bot created in the [Lua](http://www.lua.org/) scripting language using the [Discordia](https://github.com/SinisterRectus/Discordia) framework.",
		fields = {
			{name="Guilds",value=#client.guilds,inline=true},
			{name="Shards",value=client.shardCount,inline=true},
			{name="Owner",value=client.owner.tag,inline=true},
			{name="Support Server",value="[Momiji's House](https://discord.gg/YYdpsNc)",inline=true},
			{name="Invite me!",value="[Invite](https://discordapp.com/oauth2/authorize/?permissions=335670488&scope=bot&client_id=345316276098433025)",inline=true},
			{name="Contribute",value="[Github](https://github.com/Mishio595/momiji)\n[Patreon](https://www.patreon.com/momijibot)",inline=true},
		},
		color = colors.blue.value
	}}
end)

addCommand('Cat', 'Meow', 'cat', '', 0, false, false, false, function(message)
	local data = modules.api.misc.Cats()
	if data then
		message:reply{embed={
			image={url=data}
		}}
	end
end)

addCommand('Color', 'Display the closest named color to a given hex value', {'color','colour'}, '<hexcolor>', 0, false, false, false, function(message,args)
	local hex = args:match("#?([0-9a-fA-F]*)")
	local ntc = require('./res/ntc')
	if #hex==6 then
		local color,name = ntc.name(hex)
		local image1, image2 = "http://www.colorhexa.com/"..hex:lower()..".png", "http://www.colorhexa.com/"..color:lower()..".png"
		message.channel:broadcastTyping()
		-- easiest way to pull the images to local
		os.execute("wget "..image1)
		os.execute("wget "..image2)
		os.execute("montage -geometry 150x200 "..hex:lower()..".png".. " "..color:lower()..".png".." final.png")
		fs.exists("final.png", function(err)
			if not err then
				message:reply{
					file="final.png",
					embed = {
						image = { url = "attachment://final.png" },
						fields = {
							{ name = "Input Color", value = "#"..hex:upper(), inline = true},
							{ name = name, value = "#"..color, inline = true},
						},
					}
				}
				os.execute("rm *.png")
			else
				message:reply{
					content = "Unable to generate montage",
					embed = {
						image = { url = "http://www.colorhexa.com/"..color:lower()..".png"},
						fields = {
							{ name = name, value = "#"..color},
						},
					}
				}
				os.execute("rm *.png")
			end
		end)
	else
		message:reply("Invalid Hex Color")
	end
end)

addCommand('Danbooru', 'Posts a random image from danbooru with optional tags', {'danbooru', 'db'}, '[input]', 0, false, false, true, function(message, args)
	if not message.channel.nsfw then
		message:reply("This command can only be used in NSFW channels.")
		return
	end
	local blacklist = {} --make the blacklist
	for _,v in ipairs(blacklist) do
		if args:match(v) then
			message:reply("A tag you searched for is blacklisted: "..v)
			return
		end
	end
	message.channel:broadcastTyping()
	local data
	local count = 0
	while not data do
		local try = modules.api.misc.Booru(args)
		local bl = false
		for _,v in ipairs(blacklist) do
			if try and try.tags:match(v) then
				bl = true
			end
		end
		if try and not bl then
			data=try[1]
		end
		count = count+1
		if count >= 5 then
			message:reply("Unable to find results after "..count.." attempts")
			return
		end
	end
	message:reply{embed={
		image={url=data.file_url:startswith("http") and data.file_url or "https://danbooru.donmai.us"..data.file_url},
		description=string.format("**Tags:** %s\n**Post:** [%s](%s)\n**Uploader:** %s\n**Score:** %s", data.tag_string:gsub('%_','\\_'):gsub(' ',', '), data.id, "https://danbooru.donmai.us/posts/"..data.id, data.uploader_name, data.up_score-data.down_score)
	}}
end)

addCommand('Dog', 'Bork', 'dog', '', 0, false, false, false, function(message)
	local data = modules.api.misc.Dogs()
	if data then
		message:reply{embed={
			image={url=data}
		}}
	end
end)

addCommand('E621', 'Posts a random image from e621 with optional tags', 'e621', '[input]', 0, false, false, true, function(message, args)
	if not message.channel.nsfw then
		message:reply("This command can only be used in NSFW channels.")
		return
	end
	local blacklist = {'cub', 'young', 'small_cub'}
	for _,v in ipairs(blacklist) do
		if args:match(v) then
			message:reply("A tag you searched for is blacklisted: "..v)
			return
		end
	end
	message.channel:broadcastTyping()
	local data
	local count = 0
	while not data do
		local try = modules.api.misc.Furry(args)
		local bl = false
		for _,v in ipairs(blacklist) do
			if try and try.tags:match(v) then
				bl = true
			end
		end
		if try and try.file_ext~='swf' and try.file_ext~='webm' and not bl then
			data=try
		end
		count = count+1
		if count >= 5 then
			message:reply("Unable to find results after "..count.." attempts")
			return
		end
	end
	message:reply{embed={
		image={url=data.file_url},
		description=string.format("**Tags:** %s\n**Post:** [%s](%s)\n**Author:** %s\n**Score:** %s", data.tags:gsub('%_','\\_'):gsub(' ',', '), data.id, "https://e621.net/post/show/"..data.id, data.author, data.score)
	}}
end)

addCommand('Help', 'Display help information', {'help', 'cmds', 'commands'}, '[command]', 0, false, false, false, function(message, args)
	local cmds = commands
	local order = {
		"Everyone", "Mod", "Admin", "Guild Owner", "Bot Owner",
	}
	if args == "" then
		local help = {}
		for _,tbl in pairsByKeys(cmds) do
			if not help[tbl.rank+1] then help[tbl.rank+1] = "" end
			if type(tbl.commands)=='string' then
				help[tbl.rank+1] = help[tbl.rank+1].."`"..tbl.name.." "..tbl.usage.."` - "..tbl.description.."\n"
			elseif type(tbl.commands)=='table' then
				names = ""
				for _,v in pairs(tbl.commands) do
					if names == "" then names = v else names = names.."|"..v end
				end
				help[tbl.rank+1] = help[tbl.rank+1].."`"..names.." "..tbl.usage.."` - "..tbl.description.."\n"
			end
		end
		local sorted,c = {},1
		for i,v in ipairs(order) do
			if sorted[c] and #sorted[c]+string.len("**"..v.."**\n"..help[i]) >= 2000 then
				c = c+1
			end
			if not sorted[c] then
				sorted[c] = ""
			end
			sorted[c] = sorted[c].."**"..v.."**\n"..help[i]
		end
		local reply = message.author:send("**How to read this doc:**\nWhen reading the commands, arguments in angle brackets (`<>`) are mandatory\nwhile arguments in square brackets (`[]`) are optional.\nA pipe character `|` means or, so `a|b` means a **or** b.\nNo brackets should be included in the commands")
		if reply then
			for _,v in ipairs(sorted) do message.author:send(v) end
			message:reply("I've DM'd you the help page!")
		else
			message:reply("I couldn't DM you. Please check your privacy settings.")
		end
	else
		local cmd = nil
		for _,v in pairs(cmds) do
			if args == v.name then
				cmd = v
				break
			end
			for _,j in pairs(v.commands) do
				if j == args then
					cmd = v
					break
				end
			end
		end
		if cmd then
			names = ""
			for _,v in pairs(cmd.commands) do
				if names == "" then names = v else names = names.."|"..v end
			end
			message:reply {embed={
				title = cmd.name,
				description = cmd.description,
				fields = {
					{name = "Usage", value = names.." "..cmd.usage},
					{name = "Rank required", value = order[cmd.rank+1]},
				},
			}}
		end
	end
end)

addCommand('Joke', 'Tell a joke', 'joke', '', 0, false, false, false, function(message)
	local data, err = modules.api.misc.Joke()
	message:reply(data or err)
end)

addCommand('MAL Anime Search', "Search MyAnimeList for an anime", 'anime', '<search>', 0, false, false, true, function(message, args)
	local substitutions = require('../res/htmlsubs')
	local data, err = modules.api.misc.Anime(args)
	if data then
		local t={}
		t.color = colors.blue.value
		local result = data.anime:children()[1]
		if result then
			local syn = result.synopsis:value():gsub("<br />",""):gsub("%[/?i%]","*"):gsub("%[/?b%]","**")
			for k,v in pairs(substitutions) do
				syn = string.gsub(syn,k,v)
			end
			t.description=string.format("**[%s](https://myanimelist.net/anime/%s)**\n%s\n\n**Episodes:** %s\n**Score:** %s\n**Status: ** %s",result.title:value(),result.id:value(),syn,result.episodes:value(),result.score:value(),result.status:value())
			t.thumbnail={url=result.image:value()}
		else
			t.title="No results found for search "..args
		end
		message:reply{embed=t}
	else
		message:reply(err)
	end
end)

addCommand('MAL Manga Search', "Search MyAnimeList for a manga", 'manga', '<search>', 0, false, false, true, function(message, args)
	local substitutions = require('../res/htmlsubs')
	local data, err = modules.api.misc.Manga(args)
	if data then
		local t={}
		t.color = colors.blue.value
		local result = data.manga:children()[1]
		if result then
			local syn = result.synopsis:value():gsub("<br />",""):gsub("%[/?i%]","*"):gsub("%[/?b%]","**")
			for k,v in pairs(substitutions) do
				syn = string.gsub(syn,k,v)
			end
			t.description=string.format("**[%s](https://myanimelist.net/manga/%s)**\n%s\n\n**Volumes:** %s\n**Chapters:** %s\n**Score:** %s\n**Status: ** %s",result.title:value(),result.id:value(),syn,result.volumes:value(),result.chapters:value(),result.score:value(),result.status:value())
			t.thumbnail={url=result.image:value()}
		else
			t.title="No results found for search "..args
		end
		message:reply{embed=t}
	else
		message:reply(err)
	end
end)

--Command adapted from DannehSC/Electricity-2.0
addCommand('Nerdy info', 'Info for nerds.', {'ninfo','ni','nerdyinfo'}, '', 0, false, false, false, function(message)
	local ts = tostring
	local cpu = uv.cpu_info()
	local threads = #cpu
	local cpumodel = cpu[1].model
	local mem = math.floor(collectgarbage('count')/1000)
	local uptime = prettyTime(uptime:getTime():toTable())
	message:reply{embed={
		title = 'Nerdy Info',
		color = colors.blue.value,
		fields = {
			{name = 'OS', value = ts(ffi.os)},
			{name = 'CPU Threads', value = ts(threads)},
			{name = 'CPU Model', value = ts(cpumodel)},
			{name = 'Memory usage', value = ts(mem)..' MB '.."("..ts(math.round(mem/#client.guilds*100)/100).." MB/guild)"},
			{name = 'Uptime', value = uptime}
		},
	}}
end)

addCommand('Ping', 'Ping!', 'ping', '', 0, false, false, false, function(message)
	local response = message:reply("Pong!")
	if response then
		response:setContent("Pong!".."`"..math.abs(math.round((response.createdAt - message.createdAt)*1000)).." ms`")
	end
end)

addCommand('Prefix', 'Show the prefix for the guild', 'prefix', '', 0, false, false, true, function(message)
	local settings = modules.database:get(message, "Settings")
	message:reply("The prefix for "..message.guild.name.." is `"..settings.prefix.."`")
end)

addCommand('Remind Me', 'Make a reminder!', {'remindme', 'remind'}, '<reminder text> </t time>', 0, false, true, false, function(message, args)
	if not args.t then return message:reply("Time entered incorrectly. Be sure to include it after /t in your message.") end
	local reminder, time = args.rest, args.t
	local t = timeUntil(parseTime(time))
	local parsedTime, strTime = t:toSeconds(), prettyTime(t:toTable())
	if reminder and time then
		modules.timing:newTimer(message.guild,parsedTime,string.format('REMINDER||%s||%s||%s||%s',message.guild.id,message.author.id,strTime,reminder))
		message.channel:sendf("Got it! I'll remind %s to %s in %s.",message.author.name,reminder,strTime)
	else
		message:reply("I was unable to process your input. Please check the syntax.")
	end
end)

addCommand('Add Self Role', 'Add role(s) to yourself from the self role list', {'role', 'asr'}, '<role[, role, ...]>', 0, true, false, true, function(message, args)
	local member = message.member or message.guild:getMember(message.author.id)
	local selfRoles = modules.database:get(message, "Roles")
	if not selfRoles then return end
	local roles = args
	local rolesToAdd, rolesFailed = {}, {}
	for _,role in ipairs(roles) do
		for k,l in pairs(selfRoles) do
			for r,a in pairs(l) do
				if string.lower(role) == string.lower(r)  or (table.search(a, string.lower(role))) then
					--This section is only relevant to my guild unless you somehow got a role with the same snowflake
					if member:hasRole(member.guild:getRole('348873284265312267')) and (k == 'Opt-In Roles') then
						if (r == 'Gamer') or (r == '18+') or (r == 'Mafia') then
							rolesToAdd[#rolesToAdd+1] = r
						else rolesFailed[#rolesFailed+1] = r.." is only available after cooldown" end
					elseif (member:hasRole(member.guild:getRole('349051015758348289')) or member:hasRole(member.guild:getRole('349051017226354729'))) and (k == 'Opt-In Roles') then
						if not (r == 'NSFW-Selfies' or r == 'NSFW-Nb' or r == 'NSFW-Fem' or r == 'NSFW-Masc') then
							rolesToAdd[#rolesToAdd+1] = r
						else rolesFailed[#rolesFailed+1] = r.." is not available to cis people" end
					else
						rolesToAdd[#rolesToAdd+1] = r
					end
				end
			end
		end
	end
	local rolesAdded = {}
	for _,role in ipairs(rolesToAdd) do
		local r = member.guild.roles:find(function(r) return r.name == role end)
		if not member:hasRole(r) then
			if member:addRole(r) then
				rolesAdded[#rolesAdded+1] = role
			end
		else rolesFailed[#rolesFailed+1] = "You already have "..role end
	end
	local desc = ""
	if #rolesAdded > 0 then
		desc = desc.."**Added "..member.mentionString.." to the following roles** \n"..table.concat(rolesAdded,"\n")
	end
	if #rolesFailed > 0 then
		local val = "**Failed to add "..member.mentionString.." to the following roles**\n"..table.concat(rolesFailed,"\n")
		desc = desc~="" and desc.."\n\n"..val or val
	end
	if desc~="" then
		message.channel:send{embed={
			author = {name = "Add Self Role Summary", icon_url = member.avatarURL},
			description = desc,
			color = member:getColor().value,
			timestamp = discordia.Date():toISO(),
			footer = {text = "ID: "..member.id}
		}}
	else
		message:reply("I was unable to match any of the following requests to existing self roles: "..table.concat(roles, "\n"))
	end
end)

addCommand('Remove Self Role', 'Remove role(s) from the self role list from yourself', {'derole','rsr'}, '<role[, role, ...]>', 0, true, false, true, function(message, args)
	local roles = args
	local member = message.member or message.guild:getMember(message.author.id)
	local selfRoles = modules.database:get(message, "Roles")
	if not selfRoles then return end
	local rolesToRemove = {}
	for _,l in pairs(selfRoles) do
		for r,a in pairs(l) do
			for _,role in pairs(roles) do
				if (string.lower(role) == string.lower(r)) or (table.search(a, string.lower(role))) then
					rolesToRemove[#rolesToRemove+1] = r
				end
			end
		end
	end
	local roleList = ""
	for _,role in ipairs(rolesToRemove) do
		local r = member.guild.roles:find(function(r) return r.name == role end)
		if member:removeRole(r) then
			roleList = roleList..role.."\n"
		end
	end
	if #rolesToRemove > 0 then
		message.channel:send {
			embed = {
				author = {name = "Roles Removed", icon_url = member.avatarURL},
				description = "**Removed "..member.mentionString.." from the following roles** \n"..roleList,
				color = member:getColor().value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}
		}
	else
		message:reply("I was unable to match any of the following requests to existing self roles: "..table.concat(roles, "\n"))
	end
end)

addCommand('List Self Roles', 'List all roles in the self role list', 'roles', '[category]', 0, false, false, true, function(message, args)
	local roleList, cats = {},{}
	local selfRoles = modules.database:get(message, "Roles")
	if next(selfRoles)==nil then return message:reply("Role list is empty!") end
	if args~="" then
		local found = false
		for k,v in pairs(selfRoles) do
			if args:lower()==k:lower() then
				for r in pairsByKeys(v) do
					if not roleList[k] then
						roleList[k] = r.."\n"
					else
						roleList[k] = roleList[k]..r.."\n"
					end
				end
				table.insert(cats, {name = k, value = roleList[k], inline = true})
				found = true
			end
		end
		if not found then
			message.channel:sendf("None of those matched a category. Did you mean to do `role %s`?", args)
			return
		end
	else
		for k,v in pairs(selfRoles) do
			for r in pairsByKeys(v) do
				if not roleList[k] then
					roleList[k] = r.."\n"
				else
					roleList[k] = roleList[k]..r.."\n"
				end
			end
			table.insert(cats, {name = k, value = roleList[k], inline = true})
		end
	end
	message.channel:send {
		embed = {
			author = {name = "Self-Assignable Roles", icon_url = message.guild.iconURL},
			fields = cats,
		}
	}
end)

addCommand('Role Info', "Get information on a role", {'roleinfo', 'ri', 'rinfo'}, '<roleName>', 0, false, false, true, function(message, args)
	local role = message.guild.roles:find(function(r) return r.name:lower() == args:lower() end)
	if role then
		local roles = modules.database:get(message, "Roles")
		local aliases, selfAssignable
		if roles then
			for _,t in pairs(roles) do
				for r,a in pairs(t) do
					if role.name == r then
						aliases = a
						selfAssignable = "Yes"
					end
				end
			end
		end
		selfAssignable = not selfAssignable and "No" or selfAssignable
		aliases = aliases and table.concat(aliases, ", ") or nil
		local hex = string.match(role:getColor():toHex(), "%x+")
		local count = 0
		for m in message.guild.members:iter() do
			if m:hasRole(role) then count = count + 1 end
		end
		local hoisted, mentionable
		if role.hoisted then hoisted = "Yes" else hoisted = "No" end
		if role.mentionable then mentionable = "Yes" else mentionable = "No" end
		local embed = {
			thumbnail = {url = "http://www.colorhexa.com/"..hex:lower()..".png", height = 150, width = 150},
			fields = {
				{name = "Name", value = role.name, inline = true},
				{name = "ID", value = role.id, inline = true},
				{name = "Hex", value = role:getColor():toHex(), inline = true},
				{name = "Hoisted", value = hoisted, inline = true},
				{name = "Mentionable", value = mentionable, inline = true},
				{name = "Position", value = role.position, inline = true},
				{name = "Members", value = count, inline = true},
				{name = "Self Assignable", value = selfAssignable, inline = true},
			},
			color = role:getColor().value,
		}
		if selfAssignable=="Yes" and aliases~=nil and aliases~="" then
			table.insert(embed.fields, {name = "Self Role Aliases", value = aliases, inline = false})
		end
		message.channel:send{embed=embed}
	end
end)

addCommand('Roll', 'Roll X N-sided dice', 'roll', '<XdN>', 0, false, false, false, function(message, args)
	local count, sides = args:match("(%d+)d(%d+)")
	count,sides = tonumber(count) or 0, tonumber(sides) or 0
	if count>0 and sides>0 then
		local roll, pretty = 0,{}
		for i=1,count do
			local cur = math.round(math.random(1,sides))
			pretty[i]=tostring(cur)
			roll = roll+cur
		end
		message.channel:send{embed={
			fields={
				{name=string.format("%d 🎲 [1—%d]",count, sides), value=string.format("You rolled **%s** = **%d**",table.concat(pretty,","),roll)},
			},
			color = colors.blue.value,
		}}
	end
end)

addCommand('Server Info', "Get information on the server", {'serverinfo','si', 'sinfo'}, '[serverID]', 0, false, true, true, function(message, args)
	local guild = message.guild
	local g = client:getGuild(args.g)
	if g then
		guild = g
	end
	if args.roles then
		local roles = {}
		for _,r in pairs(guild.roles:toArray("position")) do
			table.insert(roles, r.name)
		end
		local result, count = {}, 1
		for _,v in ipairs(roles) do
			if not result[count] then result[count] = "" end
			if #result[count] < 1950 then
				result[count] = result[count]=="" and result[count]..v or result[count]..", "..v
			else
				count = count+1
				result[count] = ""
				result[count] = result[count]=="" and result[count]..v or result[count]..", "..v
			end
		end
		message:reply{embed={
			title = "Roles for "..guild.name..". Count: "..#guild.roles,
			description = result[1] or "None"
		}}
		for i in pairs(result) do
			if i>1 then
				message:reply{embed={
					description = result[i]
				}}
			end
		end
		return
	end
	local humans, bots, online = 0,0,0
	for member in guild.members:iter() do
		if member.bot then
			bots = bots+1
		else
			humans = humans+1
		end
		if not (member.status == 'offline') then
			online = online+1
		end
	end
	local timestamp = humanReadableTime(parseISOTime(guild.timestamp):toTable())
	fields = {
		{name = 'ID', value = guild.id, inline = true},
		{name = 'Name', value = guild.name, inline = true},
		{name = 'Owner', value = guild.owner.mentionString, inline = true},
		{name = 'Region', value = guild.region, inline = true},
		{name = 'Channels ['..#guild.textChannels+#guild.voiceChannels+#guild.categories..']', value = "Text: "..#guild.textChannels.."\nVoice: "..#guild.voiceChannels.."\nCategories: "..#guild.categories, inline = true},
		{name = 'Members ['..online.."/"..#guild.members..']', value = "Humans: "..humans.."\nBots: "..bots, inline = true},
		{name = 'Roles', value = #guild.roles, inline = true},
		{name = 'Emojis', value = #guild.emojis, inline = true},
	}
	message:reply {
		embed = {
			author = {name = guild.name, icon_url = guild.iconURL},
			fields = fields,
			thumbnail = {url = guild.iconURL, height = 200, width = 200},
			color = colors.blue.value,
			footer = { text = "Server Created : "..timestamp }
		}
	}
end)

--TODO add timezone ability
addCommand('Time', 'Get the current time', 'time', '', 0, false, false, false, function(message)
	local time = discordia.Date()
	message:reply(humanReadableTime(time:toTableUTC()).." UTC")
end)

addCommand('Urban', 'Search for a term on Urban Dictionary', {'urban', 'ud'}, '<search term>', 0, false, false, false, function(message, args)
	local data, err = modules.api.misc.Urban(args)
	if data then
		local t={}
		if data.list[1] then
			local tags = data.tags
			for i,v in ipairs(tags) do tags[i]="#"..v end
			tags = data.tags and table.concat(data.tags, ", ")
			t.description = string.format('**Definition of "%s" by %s**\n%s',data.list[1].word,data.list[1].author,data.list[1].permalink)
			t.fields = {
				{name = "Thumbs up", value = data.list[1].thumbs_up or "0", inline=true},
				{name = "Thumbs down", value = data.list[1].thumbs_down or "0", inline=true},
				{name = "Definition", value = #data.list[1].definition<1000 and data.list[1].definition or string.sub(data.list[1].definition,1,1000).."..."},
				{name = "Example", value = data.list[1].example~='' and data.list[1].example or "No examples"},
				{name = "Tags", value = tags~="" and tags or "No tags"},
			}
			t.color = colors.blue.value
		else
			t.title = 'No definitions found.'
		end
		message:reply{embed=t}
	else
		message:reply(err)
	end
end)

addCommand('User Info', "Get information on a user", {'userinfo','ui', 'uinfo'}, '[@user|userID]', 0, false, false, true, function(message, args)
	local member = resolveMember(message.guild, args)
	if args=="" then
		member = message.member
	end
	if member then
		local roles = ""
		for i in member.roles:iter() do
			if roles == "" then roles = i.name else roles = roles..", "..i.name end
		end
		if roles == "" then roles = "None" end
		local joinTime = humanReadableTime(parseISOTime(member.joinedAt):toTableUTC())
		local createTime = humanReadableTime(parseISOTime(member.timestamp):toTableUTC())
		local users = modules.database:get(message, "Users")
		local registerTime = "N/A"
		if users[member.id] then
			if users[member.id].registered and users[member.id].registered ~= "" then
				registerTime = humanReadableTime(parseISOTime(users[member.id].registered):toTableUTC())
			end
		end
		local fields = {
			{name = 'ID', value = member.id, inline = true},
			{name = 'Mention', value = member.mentionString, inline = true},
			{name = 'Nickname', value = member.name, inline = true},
			{name = 'Status', value = member.status, inline = true},
			{name = 'Joined', value = joinTime, inline = false},
			{name = 'Created', value = createTime, inline = false},
		}
		if message.guild.id==knownGuilds.TRANSCEND or message.guild.id=='407926063281209344' then table.insert(fields, {name = 'Registered', value = registerTime, inline = false}) end
		table.insert(fields, {name = 'Extras', value = "[Fullsize Avatar]("..member.avatarURL..")", inline = false})
		table.insert(fields, {name = 'Roles ('..#member.roles..')', value = roles, inline = false})
		message.channel:send {
			embed = {
				author = {name = member.username.."#"..member.discriminator, icon_url = member.avatarURL},
				fields = fields,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = member:getColor().value,
				timestamp = discordia.Date():toISO()
			}
		}
	else
		message.channel:send("Sorry, I couldn't find that user.")
	end
end)

addCommand('Weather', 'Get weather information on a given city', 'weather', '<city, country> | <zipcode> | <id>', 0, false, true, false, function(message, args)
	local type, val
	if args.zip then
		type = "zip"
		val = args.zip
	elseif args.id then
		type = "id"
		val = args.id
	else
		type = "q"
		val = args.q or args.rest
	end
	local data, err = modules.api.misc.Weather(type, val)
	if data then
		if data.cod~=200 then
			return nil,data.message:sub(0,1):upper()..data.message:sub(2)
		end
		local t={}
		local tempC, tempF = tostring(math.round(data.main.temp)), tostring(math.round(data.main.temp*1.8+32))
		local windImperial, windMetric = tostring(math.round(data.wind.speed*0.62137)), tostring(math.round(data.wind.speed))
		local deg = data.wind.deg
		local windDir
		if (deg>10 and deg<80) then
			windDir = "NE"
		elseif (deg>=80 and deg<=100) then
			windDir = "E"
		elseif (deg>100 and deg<170) then
			windDir = "SE"
		elseif (deg>=170 and deg<=190) then
			windDir = "S"
		elseif (deg>190 and deg<260) then
			windDir = "SW"
		elseif (deg>=260 and deg<=280) then
			windDir = "W"
		elseif (deg>280 and deg<370) then
			windDir = "NW"
		elseif (deg>=370 and deg<=10) then
			windDir = "N"
		end
		t.title=string.format("**Weather for %s, %s (ID: %s)**",data.name, data.sys.country, data.id)
		t.description=string.format("**Condition:** %s\n**Temperature:** %s °C (%s °F)\n**Humidity:** %s%%\n**Barometric Pressure:** %s Torr\n**Wind:** %s kmph (%s mph) %s\n**Coordinates:** %s, %s",data.weather[1].description:sub(0,1):upper()..data.weather[1].description:sub(2),tempC,tempF,data.main.humidity,math.round(data.main.pressure*0.750062),windMetric,windImperial,windDir,data.coord.lat,data.coord.lon)
		t.color = colors.blue.value
		t.footer={text="Weather provided by OpenWeatherMap"}
		message:reply{embed=t}
	else
		message:reply(err)
	end
end)

--[[ Rank 1 Commands ]]

addCommand('Mod Info', "Get mod-related information on a user", {'mi','modinfo', 'minfo'}, '<@user|userID>', 1, false, false, true, function(message, args)
	local m = resolveMember(message.guild, args)
	if m then
		local users, cases = modules.database:get(message, "Users"), modules.database:get(message, "Cases")
		if users[m.id] then
			local watchlisted = users[m.id].watchlisted
			if watchlisted then watchlisted = 'Yes' else watchlisted = 'No' end
			local caseList = {}
			if cases[m.id] then
				for i,case in ipairs(cases[m.id]) do
					table.insert(caseList, {name = string.format("Case %d: %s",i,case.type), value = string.format("**Reason:** %s\n**Moderator:** %s\n**Time:** %s", case.reason, case.moderator, humanReadableTime(discordia.Date.fromISO(case.timestamp):toTableUTC())), inline = true})
				end
			end
			table.insert(caseList, 1, {name = "Watchlisted", value = watchlisted, inline = false})
			message:reply {embed={
				author = {name = m.username.."#"..m.discriminator, icon_url = m.avatarURL},
				fields = caseList,
				color = m:getColor().value,
				timestamp = discordia.Date():toISO()
			}}
		end
	end
end)

addCommand('Mute', 'Mutes a user', 'mute', '<@user|userID> [/t time] [/r reason]', 1, false, true, true, function(message, args)
	local settings, cases = modules.database:get(message, "Settings"), modules.database:get(message, "Cases")
	if not settings.mute_setup then
		return message:reply("Mute cannot be used until `setup` has been run.")
	end
	local member = resolveMember(message.guild, args.rest)
	if member then
		local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
		if not member:hasRole(role) then
			if not member:addRole(role) then
				return message:reply("Unable to mute. Please check permissions and role positions.")
			end
		else
			return message:reply("Member already muted.")
		end
		local time
		if args.t then
			local t = timeUntil(parseTime(args.t))
			local parsedTime = t:toSeconds()
			time = prettyTime(t:toTable())
			modules.timing:newTimer(message.guild,parsedTime,string.format('UNMUTE||%s||%s||%s',message.guild.id,member.id,time))
		end
		message.channel:sendf("Muting %s", member.mentionString)
		if settings.modlog and settings.modlog_channel then
			local reason = args.r or "None"
			if cases==nil or cases[member.id]==nil then
				cases[member.id] = {}
				table.insert(cases[member.id], {type="mute", reason=reason, moderator=message.author.id, timestamp=discordia.Date():toISO()})
			else
				table.insert(cases[member.id], {type="mute", reason=reason, moderator=message.author.id, timestamp=discordia.Date():toISO()})
			end
			message.guild:getChannel(settings.modlog_channel):send{embed={
				title = "Member Muted",
				fields = {
					{name = "User", value = member.mentionString.."\n"..member.tag, inline = true},
					{name = "Moderator", value = message.author.mentionString.."\n"..message.author.tag, inline = true},
					{name = "Reason", value = reason, inline = true},
					{name = "Duration", value = time or "Indefinite", inline = true},
				},
			}}
		end
		modules.database:update(message, "Cases", cases)
	end
end)

addCommand('Unmute', 'Unmutes a user', 'unmute', '<@user|userID>', 1, false, false, true, function(message, args)
	local settings = modules.database:get(message, "Settings")
	if not settings.mute_setup then
		message:reply("Unmute cannot be used until `setup` has been run.")
		return
	end
	local member = resolveMember(message.guild, args)
	if member then
		local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
		if member:hasRole(role) then
			if not member:removeRole(role) then
				return message:reply("Unable to unmute. Please check permissions and role positions.")
			end
		else
			return message:reply("Member is not muted.")
		end
		message.channel:sendf("Unmuting %s", member.mentionString)
		if settings.modlog and settings.modlog_channel then
			message.guild:getChannel(settings.modlog_channel):send{embed={
				title = "Member Unmuted",
				fields = {
					{name = "User", value = member.mentionString, inline = true},
					{name = "Moderator", value = message.author.mentionString, inline = true},
				},
			}}
		end
	end
end)

addCommand('Notes', 'Add the note to, delete a note from, or view all notes for the mentioned user', 'note', '<add|del|view> [@user|userID] [note|index]', 1, false, false, true, function(message, args)
	local a = message.member or message.guild:getMember(message.author.id)
	local m = resolveMember(message.guild, args)
	if (args == "") or not m then return end
	args = args:gsub("<@!?%d+>",""):gsub(m.id,""):trim()
	local notes = modules.database:get(message, "Notes")
	if args:startswith("add") then
		args = args:gsub("^add",""):trim()
		if args and args ~= "" then
			if notes==nil or notes[m.id]==nil then
				notes[m.id] = {
					{note=args, moderator=a.username, timestamp=discordia.Date():toISO()}
				}
			else
				notes[m.id][#notes[m.id]+1] = {note=args, moderator=a.tag, timestamp=discordia.Date():toISO()}
			end
			message.channel:sendf("Added note `%s` to %s", args, m.name)
		end
		modules.database:update(message, "Notes", notes)
	elseif args:startswith("del") then
		args = tonumber(args:gsub("^del",""):trim())
		if args and args ~= "" then
			if notes[m.id] then
				message.channel:sendf("Removed note `%s` from %s", notes[m.id][args].note, m.name)
				table.remove(notes[m.id], args)
			end
		end
		modules.database:update(message, "Notes", notes)
	elseif args:startswith("view") then
		local notelist = ""
		if notes[m.id] then
			for i,v in ipairs(notes[m.id]) do
				notelist = notelist..string.format("**%d)** %s (Added by %s)\n",i,v.note,v.moderator)
			end
		end
		message:reply {embed={
			title = "Notes for "..m.tag,
			description = notelist,
		}}
	else
		message:reply("Please specify add, del, or view")
	end
end)

-- This command is completely restricted to my guild and one other that I allow it on. It will not run for anyone else
addCommand('Register', 'Register a given user with the listed roles', {'reg', 'register'}, '<@user|userID> <role[, role, ...]>', 1, false, false, true, function(message, args)
	if message.guild.id~=knownGuilds.TRANSCEND and message.guild.id~='407926063281209344' then message:reply("This command is not available in this guild");return end
	local users, settings, roles = modules.database:get(message, "Users"), modules.database:get(message, "Settings"), modules.database:get(message, "Roles")
	local channel = message.guild:getChannel(settings.modlog_channel)
	local member = resolveMember(message.guild, args)
	if member then
		args = args:gsub("<@!?%d+>",""):gsub(member.id,""):trim()
		args = string.split(args, ",")
		local rolesToAdd = {}
		for _,role in ipairs(args) do
			for k,l in pairs(roles) do
				for r,a in pairs(l) do
					role=role:trim()
					if string.lower(role) == string.lower(r) or table.search(a, string.lower(role)) then
						if r=='Gamer' or r=='18+' or k== 'Mafia' or k~='Opt-In Roles' then
							rolesToAdd[#rolesToAdd+1] = r
							if (k == 'Gender Identity' or k == 'Gender') then
								hasGender = true
							end
							if (k == 'Pronouns') then
								hasPronouns = true
							end
						end
					end
				end
			end
		end
		if hasGender and hasPronouns then
			local roleList = ""
			for _,role in pairs(rolesToAdd) do
				function fn(r) return r.name == role end
				if member:addRole(member.guild.roles:find(fn)) then
					roleList = roleList..role.."\n"
				end
			end
			if message.guild.id==knownGuilds.TRANSCEND then
				member:addRole('348873284265312267')
			elseif message.guild.id == '407926063281209344' then
				member:addRole('409109782612672513')
			end
			if #rolesToAdd > 0 then
				if channel then
					channel:send {
						embed = {
							author = {name = "Registered", icon_url = member.avatarURL},
							description = "**Registered "..member.mentionString.." with the following roles** \n"..roleList,
							color = member:getColor().value,
							timestamp = discordia.Date():toISO(),
							footer = {text = "ID: "..member.id}
						}
					}
				end
				if settings.introduction_message ~= "" and settings.introduction_channel and settings.introduction then
					local introChannel = member.guild:getChannel(settings.introduction_channel)
					if introChannel then
						introChannel:send(formatMessageSimple(settings.introduction_message, member))
					end
				end
				if not users[member.id] then
					users[member.id] = { registered=discordia.Date():toISO() }
				else
					users[member.id].registered = discordia.Date():toISO()
				end
				modules.database:update(message, "Users", users)
			end
		else
			message:reply("Invalid registration command. Make sure to include at least one of gender identity and pronouns.")
		end
	end
end)

addCommand('Add Role', 'Add role(s) to the given user', 'ar', '<@user|userID> <role[, role, ...]>', 1, false, false, true, function(message, args)
	local member = resolveMember(message.guild, args)
	if member then
		args = args:gsub("<@!?%d+>",""):gsub(member.id,""):trim()
		args = string.split(args, ",")
		local rolesToAdd = {}
		for _,role in ipairs(args) do
			role=role:trim()
			local r = resolveRole(message.guild, role)
			if r then
				if not member:hasRole(r) then
					if member:addRole(r) then
						rolesToAdd[#rolesToAdd+1] = r.name
					end
				else
					rolesToAdd[#rolesToAdd+1] = member.tag.." already has "..r.name
				end
			end
		end
		if #rolesToAdd > 0 then
			message.channel:send {
				embed = {
					author = {name = "Roles Added", icon_url = member.avatarURL},
					description = "**Added "..member.mentionString.." to the following roles** \n"..table.concat(rolesToAdd,"\n"),
					color = member:getColor().value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}
			}
		else
			message:reply("I was unable to match any of the following requests to existing roles: "..table.concat(args, "\n"))
		end
	end
end)

addCommand('Remove Role', 'Removes role(s) from the given user', 'rr', '<@user|userID> <role[, role, ...]>', 1, false, false, true, function(message, args)
	local member = resolveMember(message.guild, args)
	if member then
		args = args:gsub("<@!?%d+>",""):gsub(member.id,""):trim()
		args = string.split(args, ",")
		local rolesToRemove = {}
		for _,role in ipairs(args) do
			role=role:trim()
			local r = resolveRole(message.guild, role)
			if r then
				if member:hasRole(r) then
					if member:removeRole(r) then
						rolesToRemove[#rolesToRemove+1] = r.name
					end
				else
					rolesToRemove[#rolesToRemove+1] = member.tag.." does not have "..r.name
				end
			end
		end
		if #rolesToRemove > 0 then
			message.channel:send {
				embed = {
					author = {name = "Roles Removed", icon_url = member.avatarURL},
					description = "**Removed "..member.mentionString.." from the following roles** \n"..table.concat(rolesToRemove,"\n"),
					color = member:getColor().value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}
			}
		else
			message:reply("I was unable to find any of those roles")
		end
	end
end)

addCommand('Role Color', 'Change the color of a role', {'rolecolor', 'rolecolour', 'rc'}, '<roleName|roleID> <#hexcolor>', 1, false, false, true, function(message, args)
	local color = args:match("%#([0-9a-fA-F]*)")
	local role = resolveRole(message.guild,args:gsub("%#"..color,""):trim())
	if #color==6 then
		if type(role)=='table' then
			role:setColor(discordia.Color.fromHex(color))
			message.channel:sendf("Changed the color of %s to #%s",role.name,color)
		else
			message:reply("Invalid role provided")
		end
	else
		message:reply("Invalid color provided")
	end
end)

addCommand('Watchlist', "Add/remove someone from the watchlist or view everyone on it", "wl", '<add|remove|list> [@user|userID]', 1, false, false, true, function(message, args)
	local users = modules.database:get(message, "Users")
	local member = resolveMember(message.guild, args)
	args = args:gsub("<@!?%d+>",""):gsub(member and member.id or "",""):trim():split(' ')
	if args[1] == 'add' then
		if member and users[member.id] then
			users[member.id].watchlisted = true
		elseif member then
			users[member.id] = {watchlisted = true}
		end
		message.channel:sendf("Added %s to the watchlist",member.mentionString)
		modules.database:update(message, "Users", users)
	elseif args[1] == 'remove' then
		local oldS = false
		if member and users[member.id] then
			if users[member.id].watchlisted==true then
				users[member.id].watchlisted = false
				oldS = true
			end
		end
		if oldS then
			message.channel:sendf("Removed %s from the watchlist",member.mentionString)
		else
			message.channel:sendf("%s was not on the watchlist",member.mentionString)
		end
		modules.database:update(message, "Users", users)
	elseif args[1] == 'list' then
		local list, mention = ""
		for id,v in pairs(users) do
			if v and v.watchlisted then
				mention = message.guild:getMember(id) or client:getUser(id)
				list = type(mention)=='table' and list..string.format("%s (%s)\n", mention.tag, mention.id) or list..id.."\n"
			end
		end
		if list ~= "" then
			message:reply {embed={
				title="Watchlist",
				description=list,
			}}
		end
	end
end)

--[[ Rank 2 Commands ]]

addCommand('Config', 'Update configuration for the current guild', 'config', 'section </o operation> [/v value]', 2, false, true, true, function(message, args)
	local settings = modules.database:get(message, "Settings")
	local switches = {
		roles = {'admin', 'mod'},
		channels = {'audit', 'modlog', 'welcome', 'introduction'},
	}
	local section, operation, value
	local s,o,val = args.rest,args.o,args.v
	for _,v in pairs(switches.roles) do
		if s==v then
			section = v
			if o=='add' then
				local r = resolveRole(message.guild, val)
				if table.search(settings[v..'_roles'], r.id) then
					return message:reply("Role already configured")
				end
				table.insert(settings[v..'_roles'], r~=nil and r.id or nil)
				operation = "add"
				value = string.format("%s (%s)", r.name, r.id)
			elseif o=='remove' then
				local r = resolveRole(message.guild, val)
				local name, id = table.search(settings[v..'_roles'], r.name), table.search(settings[v..'_roles'], r.id)
				local removed = false
				if name then
					table.remove(settings[v..'_roles'], name)
					removed = true
				elseif id then
					table.remove(settings[v..'_roles'], id)
					removed = true
				end
				if removed then
					operation = "remove"
					value = string.format("%s (%s)", r.name, r.id)
				end
			end
		end
	end
	for _,v in pairs(switches.channels) do
		if s==v then
			section = v
			if o=='enable' then
				settings[v] = true
				operation = "enable"
			elseif o=='disable' then
				settings[v] = false
				operation = "disable"
			elseif o=='set' then
				local channel = resolveChannel(message.guild, val)
				settings[v..'_channel'] = channel.id or ''
				operation = "set channel"
				value = val
			elseif o=='message' and (v=='welcome' or v=='introduction') then
				settings[v..'_message'] = val --table.concat(table.slice(args, 3, #args, 1), ' ')
				operation = "set message"
				value = val --table.concat(table.slice(args, 3, #args, 1), ' ')
			elseif o=='threshold' and v=='audit' then
				settings[v..'_threshold'] = val
				operation = "set threshold"
				value = val
			end
		end
	end
	if s=='prefix' then
		settings['prefix'] = val or settings['prefix']
		section = "prefix"
		operation = "set prefix"
		value = val
	elseif s=='autorole' then
		section = "autorole"
		if o=='enable' then
			settings['autorole'] = true
			operation = "enable"
		elseif o=='disable' then
			settings['autorole'] = true
			operation = "disable"
		elseif o=='add' then
			local r = resolveRole(message.guild, val)
			if table.search(settings['autoroles'], r.id) then
				return message:reply("Role already configured")
			end
			table.insert(settings['autoroles'], r~=nil and r.id or nil)
			operation = "add"
			value = string.format("%s (%s)", r.name, r.id)
		elseif o=='remove' then
			local r = resolveRole(message.guild, val)
			local name, id = table.search(settings['autoroles'], r.name), table.search(settings['autoroles'], r.id)
			local removed = false
			if name then
				table.remove(settings['autoroles'], name)
				removed = true
			elseif id then
				table.remove(settings['autoroles'], id)
				removed = true
			end
			if removed then
				operation = "remove"
				value = string.format("%s (%s)", r.name, r.id)
			end
		end
	elseif s=='help' then
		local fields,roles,chans = {
			{name="prefix", value="Usage: config prefix /v <newPrefix>"},
			{name="autorole", value="Operations:\n\tenable\n\tdisable\n\tadd </v role>\n\tremove </v role>"},
		},"",""
		for _,v in pairs(switches.roles) do
			if roles == "" then roles=v else roles=roles..", "..v end
		end
		table.insert(fields, {name = roles, value = "Operations:\n\tadd </v role>\n\tremove </v role>"})
		for _,v in pairs(switches.channels) do
			if chans == "" then chans=v else chans=chans..", "..v end
		end
		table.insert(fields, {name = chans, value = "Operations:\n\tenable\n\tdisable\n\tset </v channel>\n\tthreshold </v value>\n\tmessage </v message>\n\n**Notes:** message only works for welcome and introduction.\n{user} is replaced with the member's mention\n{guild} is replace with the guild name.\nThe threshold option only works for audit and specifies the levenshtein distance required in a message edit for the message to log."})
		message:reply{embed={
			fields = fields,
		}}
	elseif s=='command' then
		local command = modules.database:get(message, "Commands")
		local name
		for _,tab in pairs(commands) do
			if val:lower()==tab.name:lower() then
				name = tab.name
				break
			end
			for _,cmd in pairs(tab.commands) do
				if val==cmd then
					name = tab.name
					break
				end
			end
		end
		if not name then
			return message:reply("Unknown command")
		end
		if not command[name] then
			command[name] = {}
		end
		if name=="Config" then
			return message:reply("Cannot disable config command")
		end
		section = "commands"
		value = name
		if o=='enable' then
			command[name].disable = false
			operation = "enable"
		elseif o=='disable' then
			command[name].disable = true
			operation = "disable"
		end
		modules.database:update(message, "Commands", command)
	elseif s=='logging' then
		local logging = modules.database:get(message, "Logging")
		local names = {
			"memberJoin",
			"memberLeave",
			"memberKick",
			"nicknameChange",
			"usernameChange",
			"roleChange",
			"messageDelete",
			"messageEdit",
			"userBan",
			"userUnban",
		}
		local index = table.search(names, val)
		if not index then
			return message:reply("Unrecognized option. Valid options are:\n"..table.concat(names, "\n"))
		end
		if not logging[names[index]] then
			logging[names[index]] = {}
		end
		section = "logging"
		value = names[index]
		if o=='enable' then
			logging[names[index]].disable = false
			operation = "enable"
		elseif o=='disable' then
			logging[names[index]].disable = true
			operation = "disable"
		end
		modules.database:update(message, "Logging", logging)
	elseif not s or s=="" then
		local list = ""
		for k,v in pairsByKeys(table.deepcopy(settings)) do
			if type(v)=='table' and k:match('roles') then
				for i,j in ipairs(v) do
					local r = resolveRole(message.guild, j)
					v[i] = r and r.name or j
				end
			end
			if type('v')=='string' and k:match('channel') then
				local c = resolveChannel(message.guild, v)
				v = c and c.mentionString or v
			end
			local out = type(v)=='table' and table.concat(v,', ') or tostring(v)
			list = list.."**"..k.."**: "..out.."\n"
		end
		message:reply{embed={
			description = list.."\n".."For details on config usage, run `"..settings.prefix.."config help`"
		}}
	end
	if operation then
		message.channel:sendf("**Operation:** %s\n%s%s", operation, section and "**Section:** "..section.."\n" or "",value and "**Value:** "..value or "")
		if s~="logging" and s~="commands" and s~="help" then
			modules.database:update(message, "Settings", settings)
		end
	end
end)

addCommand('Hackban', 'Ban a user by ID before they even join', {'hackban', 'hb'}, '<userID>', 2, false, false, true, function(message, args)
	local hackbans = modules.database:get(message, "Hackbans")
	if args=="list" then
		message.channel:send({embed={
			title = "Hackbans",
			description = table.concat(hackbans, "\n"),
			color = colors.blue.value,
		}})
		return
	end
	local id = getIdFromString(args)
	if id then
		local found = table.search(hackbans, id)
		if not found then
			table.insert(hackbans, id)
		else
			table.remove(hackbans, found)
		end
		message.channel:sendf("%s the hackban list. %s", found and "Removed ID "..id.." from" or "Added ID "..id.." to", not found and "If someone joins with this ID, they will be banned with reason \"Hackban.\"" or "")
		modules.database:update(message, "Hackbans", hackbans)
	else
		message:reply("Unable to resolve ID from input.")
	end
end)

addCommand('Ignore', 'Ignores the given channel', 'ignore', '<channelID|link>', 2, false, false, true, function(message, args)
	local ignores, settings = modules.database:get(message, 'Ignore'), modules.database:get(message, 'Settings')
	local digit = tonumber(args:match('^%d$'))
	local channel = resolveChannel(message.guild, args)
	if digit then
		if digit>=0 and digit<=4 then
			settings.ignore_level = digit
			message.channel:sendf("Ignore level set to %s.", digit)
			modules.database:update(message, "Settings", settings)
		end
		return
	elseif channel and not ignores[channel.id] then
		ignores[channel.id] = true
	elseif channel then
		ignores[channel.id] = nil
	else
		local r,c
		for k,v in pairs(ignores) do
			c = client:getChannel(k)
			if not c then
				ignores[k] = nil
			else
				r = string.format(r and r.."%s\n" or "".."%s\n",v and c.mentionString)
			end
		end
		message:reply(r)
		return
	end
	if channel then
		message.channel:sendf("I will %s for commands in %s",ignores[channel.id] and "no longer listen" or "now listen",channel.mentionString)
		modules.database:update(message, 'Ignore', ignores)
	end
end)

addCommand('Make Role', 'Make a role for the rolelist', {'makerole','mr'}, 'roleName [/c category] [/a aliases]', 2, false, true, true, function(message, args)
	local roles = modules.database:get(message, "Roles")
	local r = resolveRole(message.guild, args.rest)
	if r then
		for cat,v in pairs(roles) do
			if v[r.name] then
				return message:reply(r.name.." already exists in "..cat)
			end
		end
		local cat = args.c or "Default"
		if roles[cat] then
			if not roles[cat][r.name] then roles[cat][r.name] = {} end
		else
			roles[cat] = {
				[r.name] = {}
			}
		end
		local aliases = args.a and args.a:split(",%s*") or {}
		if type(aliases)=='table' then
			for _,v in ipairs(aliases) do
				table.insert(roles[cat][r.name], string.lower(v))
			end
		end
		if next(aliases)==nil then
			message:reply("Added "..r.name.." to "..cat)
		else
			message:reply("Added "..r.name.." to "..cat.." with aliases "..table.concat(aliases,', '))
		end
		modules.database:update(message, "Roles", roles)
	else
		message:reply(args.rest.." is not a role. Please make it first.")
	end
end)

addCommand('Delete Role', 'Remove a role from the rolelist', {'delrole','dr'}, '<roleName>', 2, false, false, true, function(message, args)
	local roles = modules.database:get(message, "Roles")
	local removed = false
	for cat,v in pairs(roles) do
		if v[args] then
			v[args]=nil
			removed = true
		end
		if next(v)==nil then
			roles[cat]=nil
		end
	end
	if removed then
		message.channel:sendf("Removed %s from the rolelist", args)
		modules.database:update(message, "Roles", roles)
	else
		message:reply("I couldn't find that role.")
	end
end)

addCommand('Prune', 'Bulk deletes messages', 'prune', '<count> [filter]', 2, false, false, true, function(message, args)
	local settings = modules.database:get(message, "Settings")
	local author = message.member or message.guild:getMember(message.author.id)
	local guild,channel=message.guild,message.channel
	local count, fsel = args:match("(%d+)%s*(.*)")
	if not count then
		return message:reply("Please specify an amount.")
	end
	local filter
	if fsel=="bot" then
		filter = function(m) return m.author.bot==true end
	elseif getIdFromString(fsel) then
		local member = resolveMember(guild, fsel)
		filter = function(m) return m.author.id==member.id end
	end
	if fsel~="" and not filter then
		return message:reply("The following filter is not valid: "..fsel)
	end
	count = tonumber(count)
	local numDel = 0
	if count > 0 then
		message:delete()
		local xHun, rem = math.floor(count/100), count%100
		local deletions
		if not filter then
			if xHun > 0 then
				for i=1, xHun do --luacheck: ignore i
					deletions = message.channel:getMessages(100)
					local success = message.channel:bulkDelete(deletions)
					if success then numDel = numDel+#deletions end
				end
			end
			if rem > 0 then
				deletions = message.channel:getMessages(rem)
				local success = message.channel:bulkDelete(deletions)
				if success then numDel = numDel+#deletions end
			end
		else
			deletions = channel:getMessages(100):toArray("createdAt", filter)
			while count>0 do
				local len = #deletions
				if len>count then
					deletions = table.slice(deletions, len-count+1, len, 1)
					len = count
				end
				count = count - len
				local nextDeletions = channel:getMessagesBefore(deletions[1], 100):toArray("createdAt", filter)
				local success = channel:bulkDelete(deletions)
				if success then
					numDel = numDel+len
				else
					break
				end
				deletions = nextDeletions
			end
		end
		if settings.modlog and settings.modlog_channel then
			guild:getChannel(settings.modlog_channel):send{embed={
				title = "Messages Pruned",
				description = string.format("**Count:** %s\n**Moderator:** %s (%s)\n**Channel:** %s (%s)", numDel, author.mentionString, author.tag, message.channel.mentionString, message.channel.name),
				color = colors.red.value,
				timestamp = discordia.Date():toISO()
			}}
		else
			channel:sendf("Deleted %s messages", numDel)
		end
	end
end)

addCommand('Test', 'Test an automated message', {'test'}, '<option>', 2, false, false, true, function(message, args)
	local settings = modules.database:get(message, "Settings")
	local op = type(args)=="string" and args:lower()
	if settings[op] and settings[op.."_channel"] then
		local channel = client:getChannel(settings[op.."_channel"])
		local member = message.member
		if op=='audit' or op=='modlog' then
			channel:send{embed={
				author = {name = "Test", icon_url = member.avatarURL},
				description = "This is a test message",
				thumbnail = {url = member.avatarURL},
				color = colors.blue.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}}
		elseif op=='welcome' or op=='introduction' then
			local typeOf = getFormatType(settings[op..'_message'], member)
			if typeOf == 'plain' or not typeOf and channel then
				channel:send(formatMessageSimple(settings[op..'_message'], member))
			elseif typeOf == 'embed' and channel then
				channel:send{
					embed = formatMessageEmbed(settings[op..'_message'], member)
				}
			end
		end
	end
end)

--[[ Rank 3 Commands ]]

addCommand('Setup Mute', 'Sets up mute', 'setup', '', 3, false, false, true, function(message)
	local settings = modules.database:get(message, "Settings")
	local role = message.guild.roles:find(function(r) return r.name == 'Muted' end)
	if not role then
		role = message.guild:createRole("Muted")
	end
	local count, status = 0
	for c in message.guild.textChannels:iter() do
		status = c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.sendMessages, enums.permission.addReactions)
		count = status and count+1 or count
	end
	for c in message.guild.voiceChannels:iter() do
		status = c:getPermissionOverwriteFor(role):denyPermissions(enums.permission.speak)
		count = status and count+1 or count
	end
	message.channel:sendf("Set up %s channels. If mute still doesn't work, please make sure your permissions are not overriding the Muted role.", count)
	settings.mute_setup = true
	modules.database:update(message, "Settings", settings)
end)

--[[ Rank 4 Commands ]]

addCommand('Git', 'Run a git command', 'git', '<option>', 4, false, false, false, function(message, args)
	local com
	if args=='pull' then
		com = "pull origin master"
	end
	if com then
		local stat = os.execute(string.format("git %s", com))
		if stat then
			message:reply("Command completed successfully")
		else
			message.channel:sendf("Error: %s", stat)
		end
	else
		message:reply("Invalid command")
	end
end)

addCommand('Lua', "Execute arbitrary lua code", "lua", '<code>', 4, false, false, false, function(message, args)
	if args:startswith("```") then
		args = args:sub(4,-4)
		if args:startswith("lua") then
			args = args:sub(4)
		end
	elseif args:startswith("`") then
		args = args:sub(2,-2)
	end
	local tx = ""
	local env = setmetatable({
		require = require, --luvit custom require
		discordia = discordia,
		client = client,
		enums = enums,
		modules = modules,
		uptime = uptime,
		clock = clock,
		colors = colors,
		message = message,
		channel = message.channel,
		guild = message.guild,
		json = require("json"),
		http = require("coro-http"),
		uv = uv,
		fs = fs,
		ffi = ffi,
		timer = require("timer"),
		print = function(...)
			local arguments = {...}
			for k,v in pairs(arguments) do arguments[k] = tostring(v) end
			local txt = table.concat(arguments, "\t").."\n"
			tx = tx..txt
		end,
		p = function(...)
			local n = select('#', ...)
			local arguments = {...}
			for i = 1, n do
				arguments[i] = pprint.dump(arguments[i],nil,true)
			end
			local txt=table.concat(arguments, "\t").."\n"
			tx=tx..txt
		end
	}, {__index = _G})
	for k,v in pairs(modules) do
		env[k]=v
	end
	local a = loadstring(args)
	if a then
		setfenv(a, env)
		local s,ret = pcall(a)
		if ret==nil then
			ret = tx
		else
			ret = tostring(ret).."\n"..tx
		end
		if #ret > 1950 then
			message:reply{
				content = "Output too large for Discord. Uploaded as attachment",
				file = {'output.txt', ret}
			}
		elseif #ret > 0 then
			message:reply{
				content = ret,
				code = "lua"
			}
		end
	else
		message:reply("Error loading function")
	end
end)

addCommand('Reload', 'Reload a module', 'reload', '<module>', 4, false, false, false, function(message, args)
	local env = setmetatable({
		require = require, --luvit custom require
		discordia = discordia,
		client = client,
		modules = modules,
		uptime = uptime,
		clock = clock,
		ready = ready
	}, {__index = _G})

	local loader = require('./res/loader')(client, modules, env)
	local loadModule,unloadModule = loader.loadModule, loader.unloadModule
	local loaded = false
	local path = "./modules/"
	if args~="" then
		path = path..args..".lua"
		unloadModule(args)
		loaded = loadModule(path)
	end
	if loaded then
		if path=="./modules/events.lua" then
			unregisterAllEvents()
			registerAllEvents()
		end
		message:reply("Module successfully reloaded from "..path)
	else
		message:reply("Unable to locate module at "..path)
	end
end)

addCommand('Restart', 'Restart the bot', 'restart', '[true|false]', 4, false, false, false, function(message, args)
	if args=="" then args="true" end
	message:reply("Restarting bot script...")
	client:setStatus("invisible")
	client:setGame(nil)
	client:stop()
	if args == 'true' then
		os.exit()
	end
end)

addCommand('Log', 'Upload the log as a txt file', 'log', '', 4, false, false, false, function(message)
	local f = fs.readFileSync("log")
	message:reply{file={"log.txt", f}}
end)

return commands
