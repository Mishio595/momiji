return function(client, modules, env)
	local fs = require('fs')
	local pathjoin = require('pathjoin')
	local splitPath, remove = pathjoin.splitPath, table.remove

	local function loadModule(path, silent)
		local name = remove(splitPath(path)):gsub(".lua","")
		local success, err = pcall(function()
			local code = assert(fs.readFileSync(path))
			local fn = assert(loadstring(code, name, 't', env))
			modules[name] = fn()
		end)
		if success then
			if not silent then
				client:info('Module online: '..name)
			end
			return true
		else
			client:error("Error loading %s (%s)", name, err)
		end
	end

	local function unloadModule(name)
		if modules[name] then
			modules[name] = nil
			client:info("Module unloaded: %s", name)
		else
			client:info("Module not found: %s", name)
		end
	end

	return {
		loadModule = loadModule,
		unloadModule = unloadModule,
	}
end
