--[[ Adapted from Timed.lua DannehSC/Electricity-2.0 ]]

local ssl = require('openssl')
local timer = require("timer")
local fmt = string.format
local timing = {
	_callbacks = {},
	_timers = {},
}

function timing:on(f)
	assert(type(f)=='function','Error: X3F - callback not function')
	table.insert(self._callbacks,f)
end

function timing:fire(...)
	for _,cb in pairs(self._callbacks)do
		coroutine.wrap(cb)(...)
	end
end

function timing:load(guild)
	local timers = modules.database:get(guild, "Timers") or {}
	for id,ti in pairs(timers) do
		if ti.endTime<os.time() then
			coroutine.wrap(function() self:delete(guild,id) end)()
			if ti.stopped==true then return end
			self:fire(ti.data)
		else
			self:newTimer(guild,ti.endTime-os.time(),ti.data,true)
		end
	end
end

function timing.save(guild,id,ti)
	local timers = modules.database:get(guild, "Timers")
	timers[id] = ti
	modules.database:update(guild,'Timers',timers)
end

function timing:delete(guild,id)
	local data = modules.database:get(guild,'Timers')
	if data then
		self._timers[id] = nil
		data[id] = nil
		modules.database:update(guild,'Timers',data)
	end
end

function timing:newTimer(guild,secs,data,ign)
	if type(secs)~='number'then secs = 5 end
	local ms = secs*1000
	assert(guild~=nil,'Error 9F2 - guild nil')
	assert(type(data)=='string','Error CXT - data not string')
	local id = ssl.base64(fmt('%s|%s|%s',ssl.random(20),ms,data),true):gsub('/','')
	timer.setTimeout(ms,function()
		coroutine.wrap(function()
			if not self._timers[id] then return end
			if self._timers[id].stopped then return end
			self:fire(data)
			self:delete(guild,id)
		end)()
	end)
	local tab = {duration=secs,endTime=os.time()+secs,stopped=false,data=data}
	self._timers[id] = tab
	if not ign then self.save(guild,id,tab) end
	return id
end

function timing:endTimer(timerId)
	if self._timers[timerId]==nil then
		client:warning('Invalid timerId passed to Timer:endTimer')
	else
		self._timers[timerId].stopped=true
	end
end

function timing:getTimers(txt)
	local t={}
	for i,v in pairs(self._timers) do
		if v.data:find(txt) then
			t[i]=v
		end
	end
	return t
end

return timing
