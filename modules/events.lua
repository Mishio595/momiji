--[[ Adapted from DannehSC/Electricity-2.0 ]]

local json = require('json')
local timer = require("timer")
local enums = discordia.enums
local colors = require('./res/colors')

--[[ Guild Events ]]

local function guildCreate(guild)
	modules.database:get(guild)
	local users = modules.database:get(guild, "Users")
	for m in guild.members:iter() do
		local roles = {}
		for role in m.roles:iter() do
			table.insert(roles, role.id)
		end
		if not users[m.id] then
			users[m.id] = {name=m.tag, nick=m.nickname, roles=roles}
		else
			users[m.id].nick = m.nickname
			users[m.id].roles = roles
			users[m.id].name = m.tag
		end
	end
	modules.database:update(guild, "Users", users)
	guild.owner:sendf("Thanks for inviting me to %s! To get started, you should read the help page with the command `m!help` and configure your settings. If you've got questions or just want to receive updates, join my support server (link is in the `m!binfo` response)", guild.name)
	client:getChannel(guildLog):send{embed={
		title = "Joined Guild",
		description = string.format("**Name:** %s\n**ID:** %s\n**Owner:** %s (%s)", guild.name, guild.id, guild.owner.tag, guild.owner.id),
		color = colors.green.value,
		timestamp = discordia.Date():toISO(),
	}}
end

local function guildDelete(guild)
	modules.database:update(guild, "Users", {})
	client:getChannel(guildLog):send{embed={
		title = "Left Guild",
		description = string.format("**Name:** %s\n**ID:** %s\n**Owner:** %s (%s)", guild.name, guild.id, guild.owner.tag, guild.owner.id),
		color = colors.red.value,
		timestamp = discordia.Date():toISO(),
	}}
end

--[[ Member Events ]]

local function memberJoin(member)
	if not _ready then return end
	--Reference Hackban list
	local hackbans = modules.database:get(member, "Hackbans")
	if table.search(hackbans, member.id) then
		return member:ban("Hackban")
	end
	--Welcome message
	local settings = modules.database:get(member, "Settings")
	if settings['welcome_message'] ~= "" and settings['welcome_channel'] and settings['welcome'] then
		local typeOf = getFormatType(settings['welcome_message'], member)
		local channel = member.guild:getChannel(settings['welcome_channel'])
		if typeOf == 'plain' or not typeOf and channel then
			channel:send(formatMessageSimple(settings['welcome_message'], member))
		elseif typeOf == 'embed' and channel then
			channel:send{
				embed = formatMessageEmbed(settings['welcome_message'], member)
			}
		end
	end
	--Auto role
	if settings.autorole then
		for _,r in ipairs(settings.autoroles) do
			member:addRole(r)
		end
	end
	local logging = modules.database:get(member, "Logging")
	local set = logging.memberJoin
	if set and not set.disable or not set then
		--Join message
		local t = timeBetween(discordia.Date.fromISO(member.timestamp))
		local desc = member.mentionString.."\n"..member.tag
		if t:toSeconds()<(60*60*24*7) then
			desc = desc.."\nCreated "..prettyTime(t:toTable()).." ago"
		end
		local channel = member.guild:getChannel(settings.audit_channel)
		if settings.audit and channel then
			channel:send {embed={
				author = {name = "Member Joined", icon_url = member.avatarURL},
				description = desc,
				thumbnail = {url = member.avatarURL},
				color = colors.green.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}}
		end
	end
	--Create user entry in DB
	if member.guild.totalMemberCount<500 then --Temporary workaround until reql fixes its shit
		local roles = {}
		for role in member.roles:iter() do
			table.insert(roles, role.id)
		end
		local users = modules.database:get(member, "Users")
		users[member.id] = {nick=member.nickname, roles=roles, name=member.tag}
		modules.database:update(member, "Users", users)
	end
end

local function memberLeave(member)
	if not _ready then return end
	local settings = modules.database:get(member, "Settings")
	local logging = modules.database:get(member, "Logging")
	local set = logging.memberLeave
	if set and not set.disable or not set then
		local channel = member.guild:getChannel(settings.audit_channel)
		if settings.audit and channel then
			channel:send {embed={
				author = {name = "Member Left", icon_url = member.avatarURL},
				description = member.mentionString.."\n"..member.tag,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = colors.red.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}}
		end
	end
	--kill their entry in the DB
	local users = modules.database:get(member, "Users")
	users[member.id] = nil
	if not member.guild.me:hasPermission(discordia.enums.permission.viewAuditLog) then return end
	set = logging.memberKick
	if set and not set.disable or not set then
		--Wait a few seconds for the audit log to populate
		timer.sleep(3*1000)
		--Check if they were kicked
		local guild = member.guild
		channel = guild:getChannel(settings.modlog_channel)
		if channel and member and settings.modlog then
			local audit = guild:getAuditLogs({
				limit = 1,
				type = enums.actionType.memberKick,
			}):iter()()
			if audit and audit:getTarget().id~=member.id then
				return
			elseif audit and discordia.Date():toSeconds()-audit.createdAt>5 then
				return
			end
			local reason = audit and audit.reason or nil
			if audit then
				channel:send{embed={
					author = {name = "Member Kicked", icon_url = member.avatarURL},
					description = string.format("%s\n%s\n**Responsible Moderator: ** %s\n**Reason:** %s", member.mentionString, member.tag, audit and audit:getMember().tag or "N/A", reason or "None"),
					thumbnail = {url = member.avatarURL, height = 200, width = 200},
					color = colors.red.value,
					timestamp = discordia.Date():toISO(),
					footer = {text = "ID: "..member.id}
				}}
			end
		end
	end
end

local function memberUpdate(member)
	if not _ready then return end
	local changed = false
	local users = modules.database:get(member, "Users")
	local settings = modules.database:get(member, "Settings")
	local channel = member.guild:getChannel(settings.audit_channel)
	local newRoles = {}
	for role in member.roles:iter() do
		table.insert(newRoles, role.id)
	end
	local logging = modules.database:get(member, "Logging")
	local set = logging.nicknameChange
	if set and not set.disable or not set then
		if users[member.id] and settings.audit and channel then
			if users[member.id].nick~=member.nickname then
				changed = true
				channel:send{embed={
					title = "Nickname Changed",
					description = string.format("**User:** %s\n**Old:** %s\n**New:** %s",member.tag,users[member.id].nick or "None",member.nickname or "None"),
					thumbnail = {url=member.avatarURL},
					color = colors.blue.value,
					timestamp = discordia.Date():toISO(),
					footer = {text="ID: "..member.id},
				}}
			end
		end
	end
	set = logging.roleChange
	if set and not set.disable or not set then
		if users[member.id] and settings.audit and channel then
			local oldRoles = users[member.id].roles or {}
			local changedRoles, t = {}, ""
			local longer = #oldRoles>#newRoles and oldRoles or newRoles
			for _,v in ipairs(longer) do
				local role = member.guild:getRole(v)
				if table.search(oldRoles, v) and not table.search(newRoles, v) then
					t = "Removed"
					table.insert(changedRoles,role.name)
				elseif table.search(newRoles, v) and not table.search(oldRoles, v) then
					t = "Added"
					table.insert(changedRoles,role.name)
				end
			end
			if changedRoles[1]~=nil then
				changed = true
				local changes = table.concat(changedRoles, ", ")
				channel:send{embed={
					title = "Roles Changed",
					description = string.format("**User:** %s\n**%s:** %s", member.tag, t, changes),
					thumbnail = {url=member.avatarURL},
					color = colors.blue.value,
					timestamp = discordia.Date():toISO(),
					footer = {text="ID: "..member.id}
				}}
			end
		end
	end
	if changed then
		if member.guild.totalMemberCount<500 then
			if users[member.id] then
				users[member.id].nick = member.nickname
				users[member.id].roles = newRoles
				users[member.id].name = member.tag
			else
				users[member.id] = {nick = member.nickname, roles = newRoles, name = member.tag}
			end
			modules.database:update(member, "Users", users)
		end
	end
end

local function presenceUpdate(member)
	if not _ready then return end
	if member.user.bot == true then return end
	-- Username logging
	local users = modules.database:get(member, "Users")
	local settings = modules.database:get(member, "Settings")
	local channel = member.guild:getChannel(settings.audit_channel)
	local changed = false
	local logging = modules.database:get(member, "Logging")
	local set = logging.useernameChange
	if set and not set.disable or not set then
		if users[member.id] and settings.audit and channel then
			if users[member.id].name~=member.tag then
				changed = true
				channel:send{embed={
					title = "Username Changed",
					description = string.format("**User:** %s\n**Old:** %s\n**New:** %s",member.tag,users[member.id].name or "None",member.tag or "None"),
					thumbnail = {url=member.avatarURL},
					color = colors.blue.value,
					timestamp = discordia.Date():toISO(),
					footer = {text="ID: "..member.id},
				}}
			end
		end
		if changed then
			if member.guild.totalMemberCount<500 then
				if users[member.id] then
					users[member.id].name = member.tag
				else
					users[member.id] = {nick = member.nickname, name = member.tag}
				end
				modules.database:update(member, "Users", users)
			end
		end
	end
	-- Now Live role on my guild
	local role = '370395740406546432'
	if member.guild.id == '348660188951216129' then
		if (member.gameType == enums.gameType.streaming) and not member:hasRole(role) then
			member:addRole(role)
		elseif member:hasRole(role) then
			member:removeRole(role)
		end
	end
end

--[[ Message Events ]]

local function messageCreate(msg)
	if not _ready then
		if msg.author.id~=client.owner.id then
			return
		end
	end
	if msg.author.bot then return end
	local private = false
	if not msg.guild then private = true end
	local data = {}
	local sender = (private and msg.author or msg.member or msg.guild:getMember(msg.author))
	local rank = getRank(sender, private)
	if not private then
		data = modules.database:get(msg)
		if data.Ignore[msg.channel.id] and rank<data.Settings.ignore_level then
			return
		end
	end
	if msg.content:lower():match("^i need a hug$") then
		msg.channel:sendf("*hugs %s*", msg.author.mentionString)
	end
	local command, rest = resolveCommand(msg.content, not private and data.Settings.prefix or "")
	if not command then return end --If the prefix isn't there, don't bother with anything else
	for _,tab in pairs(modules.commands) do
		for _,cmd in pairs(tab.commands) do
			if command:lower() == cmd:lower() then
				if tab.serverOnly and private then
					msg:reply("This command is not available in private messages.")
					return
				end
				if not private then
					if data.Commands[tab.name] then
						if data.Commands[tab.name].disable then
							if rank<data.Settings.ignore_level then
								return
							end
						end
					end
				end
				if rank>=tab.rank then
					local args
					if tab.multi then
						args = string.split(rest, ',')
						for i,v in ipairs(args) do args[i]=v:trim() end
					elseif tab.switches then
						args = getSwitches(rest)
					else
						args = rest
					end
					local a,b = pcall(tab.action, msg, args)
					if not a then
						if errLog then
							client:getChannel(errLog):send {embed = {
								description = b,
								footer = {text="ID: "..msg.id},
								timestamp = discordia.Date():toISO(),
								color = discordia.Color.fromRGB(255, 0 ,0).value,
							}}
						end
						msg:reply("OOPSIE WOOPSIE!! Uwu We made a fucky wucky!! A wittle fucko boingo! The code monkeys at our headquarters are working VEWY HAWD to fix this!")
					end
					if comLog then
						local g = not private and msg.guild or {name="Private", id=""}
						client:getChannel(comLog):send{embed={
							fields={
								{name="Guild",value=g.name.."\n"..g.id,inline=true},
								{name="Author",value=msg.author.tag.."\n"..msg.author.id,inline=true},
								{name="Channel",value=msg.channel.name.."\n"..msg.channel.id,inline=true},
								{name="Command",value=tab.name,inline=true},
								{name="Message Content",value=msg.cleanContent},
							},
							footer = {text="Message ID: "..msg.id},
							timestamp=discordia.Date():toISO(),
							color = colors.blue.value,
						}}
					end
				else
					local ranks = {"Everyone", "Mod", "Admin", "Guild Owner", "Bot Owner"}
					msg.channel:sendf("Insufficient permission to execute command: **%s**\nRank expected: **%s**\nYour Rank: **%s**", tab.name, ranks[tab.rank+1], ranks[rank+1])
				end
			end
		end
	end
end

local function messageDelete(message)
	if not _ready then return end
	for i,v in ipairs(bulkDeletes) do
		if message.id==v then
			table.remove(bulkDeletes,i)
			return
		end
	end
	local logging = modules.database:get(message, "Logging")
	local set = logging.messageDelete
	if set and not set.disable or not set then
		local member = message.member or message.guild:getMember(message.author.id) or message.author
		if message.author.bot then return end
		local settings = modules.database:get(message, "Settings")
		local channel = message.guild:getChannel(settings.audit_channel)
		if channel and member and settings.audit then
			local body = string.format("**Author:** %s (%s) - %s\n**Channel:** %s (%s) - %s\n**Content:**\n%s", member.tag, member.id, member.mentionString, message.channel.name, message.channel.id, message.channel.mentionString, message.content)
			if message.attachments then
				for i,t in ipairs(message.attachments) do
					body = body.."\n[Attachment "..i.."]("..t.url..")"
				end
			end
			channel:send {embed={
				author = {name = "Message Deleted", icon_url = member.avatarURL},
				description = body,
				color = colors.red.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..message.id}
			}}
		end
	end
end

local function messageDeleteUncached(channel, messageID)
	if not _ready then return end
	for i,v in ipairs(bulkDeletes) do
		if messageID==v then
			table.remove(bulkDeletes,i)
			return
		end
	end
	local logging = modules.database:get(channel, "Logging")
	local set = logging.messageDelete
	if set and not set.disable or not set then
		local settings = modules.database:get(channel, "Settings")
		local logChannel = channel.guild:getChannel(settings.audit_channel)
		if logChannel and settings.audit then
			logChannel:send {embed={
				author = {name = "Uncached Message Deleted", icon_url = channel.guild.iconURL},
				description = string.format("**Channel:** %s (%s) - %s", channel.name, channel.id, channel.mentionString),
				color = colors.red.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..channel.id}
			}}
		end
	end
end

local function messageUpdate(message)
	if not _ready then return end
	if message.author.bot then return end
	if not message.oldContent then return end
	local logging = modules.database:get(message, "Logging")
	local set = logging.messageEdit
	if set and not set.disable or not set then
		if message.oldContent then
			local oldContent = message.oldContent[message.editedTimestamp]
			if oldContent then
				local settings = modules.database:get(message, "Settings")
				local channel = client:getChannel(settings['audit_channel'])
				if not channel then return end
				if string.levenshtein(oldContent, message.content)>=(tonumber(settings['audit_threshold']) or 0) then
					channel:send {embed={
						title = "Message Edited",
						description = string.format("**Author:** %s (%s)\n**Channel:** %s (%s)\n**Old Content:**\n%s\n**New Content:**\n%s", message.author.tag, message.author.id, message.channel.name, message.channel.id, oldContent, message.content),
						color = colors.blue.value,
						timestamp = discordia.Date():toISO(),
						footer = {text = "ID: "..message.id}
					}}
				end
			end
		end
	end
end

--[[ User Events ]]

local function userBan(user, guild)
	if not _ready then return end
	if guild.me and not guild.me:hasPermission(discordia.enums.permission.viewAuditLog) then return end
	local logging = modules.database:get(guild, "Logging")
	local set = logging.userBan
	if set and not set.disable or not set then
		--Wait a few seconds for the audit log to populate
		timer.sleep(3*1000)
		--End wait
		local member = guild:getMember(user) or user
		local settings = modules.database:get(guild, "Settings")
		local channel = guild:getChannel(settings.modlog_channel)
		if channel and member and settings.modlog then
			local audit = guild:getAuditLogs({
				limit = 1,
				type = enums.actionType.memberBanAdd,
			}):iter()()
			if audit and audit:getTarget().id ~= user.id then audit = nil end
			local reason = audit and audit.reason or nil
			channel:send{embed={
				author = {name = "Member Banned", icon_url = member.avatarURL},
				description = string.format("%s\n%s\n**Responsible Moderator: ** %s\n**Reason:** %s", member.mentionString, member.tag, audit and audit:getMember().tag or "N/A", reason or "None"),
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = colors.red.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}}
		end
	end
end

local function userUnban(user, guild)
	if not _ready then return end
	local logging = modules.database:get(guild, "Logging")
	local set = logging.userUnban
	if set and not set.disable or not set then
		local member = guild:getMember(user) or user
		local settings = modules.database:get(guild, "Settings")
		local channel = guild:getChannel(settings.modlog_channel)
		if channel and member and settings.modlog then
			channel:send {embed={
				author = {name = "Member Unbanned", icon_url = member.avatarURL},
				description = member.mentionString.."\n"..member.tag,
				thumbnail = {url = member.avatarURL, height = 200, width = 200},
				color = colors.green.value,
				timestamp = discordia.Date():toISO(),
				footer = {text = "ID: "..member.id}
			}}
		end
	end
end

--[[ Other Events ]]

local function timing(data)
	local args = string.split(data,'||')
	if args[1]=='REMINDER' then
		local g = client:getGuild(args[2])
		if g then
			local m = g:getMember(args[3])
			local time = args[4]
			if m then
				m:send{embed={
					title='Reminder from '..time..' ago',
					description=args[5],
					color=colors.blue.value,
				}}
			end
		end
	elseif args[1]=='UNMUTE' then
		local g = client:getGuild(args[2])
		if g then
			local settings = modules.database:get(g, "Settings")
			local m = g:getMember(args[3])
			local time = args[4]
			if m then
				local s = m:removeRole(g.roles:find(function(r) return r.name=='Muted' end))
				if s and settings.modlog and settings.modlog_channel then
					g:getChannel(settings.modlog_channel):send{embed={
						title = "Member Unmuted Automatically",
						fields = {
							{name = "Member", value = m.mentionString.."\n"..m.tag, inline = true},
							{name = "Moderator", value = client.user.mentionString.."\n"..client.user.tag, inline = true},
							{name = "Duration", value = time, inline = true},
						}
					}}
				end
			end
		end
	end
end

local function raw(r)
	if not _ready then return end
	local payload = json.parse(r)
	if payload.t == 'MESSAGE_DELETE_BULK' then
		bulkDeletes = payload.d.ids or {}
	end
end

local function ready()
	modules.api.misc.DBots_Stats_Update({server_count=#client.guilds})
	modules.timing:on(timing)
	for g in client.guilds:iter() do
		modules.database:get(g)
		modules.timing:load(g)
	end
	client:setGame({
		name = string.format("%s guilds | m!help", #client.guilds),
		type = 2,
	})
	clock:start()
	uptime:start()
	_ready = true
	client:info("Logged in as %s", client.user.tag)
end

return {
	guildCreate = guildCreate,
	guildDelete = guildDelete,
	memberJoin = memberJoin,
	memberLeave = memberLeave,
	memberUpdate = memberUpdate,
	messageCreate = messageCreate,
	messageDelete = messageDelete,
	messageDeleteUncached = messageDeleteUncached,
	messageUpdate = messageUpdate,
	userBan = userBan,
	userUnban = userUnban,
	presenceUpdate = presenceUpdate,
	raw = raw,
	ready = ready,
	timing = timing
}
