--[[ Adapted from DannehSC/Electricity-2.0 ]]

local json = require('json')
local ssl = require('openssl')
local query = require('querystring')
local http = require('coro-http')
local xml = require("../res/xmlSimple").newParser()
local settings = require('../res/settings')

local api={
	data=settings.api,
	endpoints={
		['DBots_Stats']='https://discordbots.org/api/bots/%s/stats', --id: the bot ID
		['Meow']='http://aws.random.cat/meow',
		['Bork']='https://dog.ceo/api/breeds/image/random',
		['Urban']='https://api.urbandictionary.com/v0/define?term=%s', --term: a search term
		['dadjoke']='https://icanhazdadjoke.com/',
		['e621']='https://e621.net/post/index.json?limit=1&tags=%s', --limit: a number, tags: a tag string
		['Animu']='https://myanimelist.net/api/anime/search.xml?q=%s', --q: a search query
		['Mango']='https://myanimelist.net/api/manga/search.xml?q=%s', --q: a search query
		['Weather']='http://api.openweathermap.org/data/2.5/weather?units=Metric&%s=%s&appid=%s', --s: a city, country code listing
		['Danbooru']='https://danbooru.donmai.us/posts.json?limit=1&random=true&tags=%s' --limit: a number, random: true or false, tags: a tag string
	},
	misc={},
}

function api.post(endpoint,fmt,...)
	local uri
	local url=api.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('POST',uri,...)
end

function api.get(endpoint,fmt,...)
	local uri
	local url=api.endpoints[endpoint]
	if url then
		if fmt then
			uri=url:format(unpack(fmt))
		else
			uri=url
		end
	end
	return http.request('GET',uri,...)
end

function api.misc.DBots_Stats_Update(info)
	return api.post('DBots_Stats',{client.user.id},{{"Content-Type","application/json"},{"Authorization",api.data.DBotsToken}},json.encode(info))
end

function api.misc.Cats()
	local _,request=api.get('Meow')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [api.misc.Cats]'
	end
	return json.decode(request).file
end

function api.misc.Dogs()
	local _,request=api.get('Bork')
	if not json.decode(request)then
		return nil,'ERROR: Unable to decode JSON [api.misc.Dogs]'
	end
	return json.decode(request).message
end

function api.misc.Joke()
	local _,data=api.get('dadjoke',nil,{{'User-Agent','luvit'},{'Accept','text/plain'}})
	return data
end

function api.misc.Weather(type,input)
	local request = query.urlencode(input)
	if request then
		local _,data = api.get('Weather', {type,request,api.data.WeatherKey})
		local jdata = json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to url encode"
	end
end

function api.misc.Urban(input)
	local request=query.urlencode(input:trim())
	if request then
		local _,data=api.get('Urban',{request}, {{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function api.misc.Furry(input)
	input = input.." order:random"
	local request=query.urlencode(input:trim())
	if request then
		local _,data=api.get('e621',{request},{{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata[1]
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function api.misc.Booru(input)
	local request=query.urlencode(input:trim())
	if request then
		local _,data=api.get('Danbooru',{request}, {{'User-Agent','luvit'}})
		local jdata=json.decode(data)
		if jdata then
			return jdata
		else
			return nil,"ERROR: unable to json decode"
		end
	else
		return nil,"ERROR: unable to urlencode"
	end
end

function api.misc.Anime(input)
	local request = query.urlencode(input)
	if request then
		local _, data = api.get('Animu',{request}, {{'Authorization', "Basic "..ssl.base64(api.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.anime then
			return xdata
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end

function api.misc.Manga(input)
	local request = query.urlencode(input)
	if request then
		local _, data = api.get('Mango',{request}, {{'Authorization', "Basic "..ssl.base64(api.data.MALauth)}})
		local xdata = xml:ParseXmlText(data)
		if xdata.manga then
			return xdata
		else
			return nil, "ERROR: unable to decode XML"
		end
	else
		return nil, "ERROR: unable to urlencode"
	end
end

return api
