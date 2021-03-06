--
-- src/project/project.lua
-- Premake project object API
-- Copyright (c) 2011-2012 Jason Perkins and the Premake project
--

	premake5.project = {}
	local project = premake5.project
	local context = premake.context
	local oven = premake5.oven
	local configset = premake.configset


--
-- Create a new project object.
--
-- @param sln
--    The solution object to contain the new project.
-- @param name
--    The new project's name.
-- @return
--    A new project object, contained by the specified solution.
--

	function project.new(sln, name)
		local prj = {}

		prj.name = name
		prj.solution = sln
		prj.script = _SCRIPT
		prj.blocks = {}

		local cwd = os.getcwd()

		local cset = configset.new(sln.configset)
		cset.basedir = cwd
		cset.location = cwd
		cset.filename = name
		cset.uuid = os.uuid(name)
		prj.configset = cset

		-- attach a type descriptor
		setmetatable(prj, {
			__type = "project",
			__index = function(prj, key)
				return prj.configset[key]
			end,
		})

		return prj
	end


--
-- Flatten out a project and all of its configurations, merging all of the
-- values contained in the script-supplied configuration blocks.
--

	function project.bake(prj, sln)
		-- make sure I've got the actual project, and not the root configurations
		prj = prj.project or prj

		-- set up an environment for expanding tokens contained by this project
		local environ = {
			sln = sln,
			prj = prj,
		}

		-- create a context to represent the project's "root" configuration; some
		-- of the filter terms may be nil, so not safe to use a list
		local ctx = context.new(prj.configset, environ)
		context.addterms(ctx, _ACTION)
		context.addterms(ctx, prj.language)

		-- allow script to override system and architecture
		ctx.system = ctx.system or premake.action.current().os or os.get()
		context.addterms(ctx, ctx.system)
		context.addterms(ctx, ctx.architecture)

		-- if a kind is specified at the project level, use that too
		context.addterms(ctx, ctx.kind)
		context.compile(ctx)

		-- attach a bit more local state
		ctx.solution = sln

		-- if no language is set for the project, default to C++
		if not ctx.language then
			ctx.language = premake.CPP
		end

		-- create a list of build cfg/platform pairs for the project
		local cfgs = table.fold(ctx.configurations or {}, ctx.platforms or {})

		-- roll up any config maps from the contained configurations
		project.bakeconfigmap(ctx, prj.configset, cfgs)

		-- apply any mappings to the project's list of configurations and platforms
		ctx._cfglist = project.bakeconfiglist(ctx, cfgs)


		-- TODO: OLD, REMOVE: build an old-style configuration to wrap context, for now
		local result = oven.merge(oven.merge({}, sln), prj)
		result.solution = sln
		result.blocks = prj.blocks
		result.baked = true

		-- prevent any default system setting from influencing configurations
		result.system = nil


		-- TODO: HACK, TRANSITIONAL, REMOVE: pass requests for missing values
		-- through to the config context. Eventually all values will be in the
		-- context and the cfg wrapper can be done away with
		setmetatable(prj, nil)

		result.context = ctx
		prj.context = ctx
		setmetatable(result, {
			__index = function(prj, key)
				return prj.context[key]
			end,
		})
		setmetatable(prj, getmetatable(result))

		-- bake all configurations contained by the project
		local configs = {}
		for _, pairing in ipairs(result._cfglist) do
			local buildcfg = pairing[1]
			local platform = pairing[2]
			local cfg = project.bakeconfig(result, buildcfg, platform)

			-- make sure this config is supported by the action; skip if not
			if premake.action.supportsconfig(cfg) then
				configs[(buildcfg or "*") .. (platform or "")] = cfg
			end
		end
		result.configs = configs

		return result
	end

--
-- It can be useful to state "use this map if this configuration is present".
-- To allow this to happen, config maps that are specified within a project
-- configuration are allowed to "bubble up" to the top level. Currently,
-- maps are the only values that get this special behavior.
--
-- @param ctx
--    The project context information.
-- @param cset
--    The project's original configuration set, which contains the settings
--    of all the project configurations.
-- @param cfgs
--    The list of the project's build cfg/platform pairs.
--

	function project.bakeconfigmap(ctx, cset, cfgs)
		-- It can be useful to state "use this map if this configuration is present".
		-- To allow this to happen, config maps that are specified within a project
		-- configuration are allowed to "bubble up" to the top level. Currently,
		-- maps are the only values that get this special behavior.
		for _, cfg in ipairs(cfgs) do
			local terms = table.join(ctx.terms, (cfg[1] or ""):lower(), (cfg[2] or ""):lower())
			local map = configset.fetchvalue(cset, "configmap", terms)
			if map then
				for key, value in pairs(map) do
					ctx.configmap[key] = value
				end
			end
		end

	end


--
-- Builds a list of build configuration/platform pairs for a project,
-- along with a mapping between the solution and project configurations.
--
-- @param ctx
--    The project context information.
-- @param cfgs
--    The list of the project's build cfg/platform pairs.
-- @return
--     An array of the project's build configuration/platform pairs,
--     based on any discovered mappings.
--

	function project.bakeconfiglist(ctx, cfgs)
		-- run them all through the project's config map
		for i, cfg in ipairs(cfgs) do
			cfgs[i] = project.mapconfig(ctx, cfg[1], cfg[2])
		end

		-- walk through the result and remove any duplicates
		local buildcfgs = {}
		local platforms = {}

		for _, pairing in ipairs(cfgs) do
			local buildcfg = pairing[1]
			local platform = pairing[2]

			if not table.contains(buildcfgs, buildcfg) then
				table.insert(buildcfgs, buildcfg)
			end

			if platform and not table.contains(platforms, platform) then
				table.insert(platforms, platform)
			end
		end

		-- merge these de-duped lists back into pairs for the final result
		return table.fold(buildcfgs, platforms)
	end


--
-- Flattens out the build settings for a particular build configuration and
-- platform pairing, and returns the result.
--

	function project.bakeconfig(prj, buildcfg, platform)
		-- set the default system and architecture values; for backward
		-- compatibility, use platform if it would be a valid value
		local system = premake.action.current().os or os.get()
		local architecture = nil

		-- if the platform's name matches a known system or architecture, use
		-- that as the default. More than a convenience; this is required to
		-- work properly with external Visual Studio project files.
		if platform then
			system = premake.api.checkvalue(platform, premake.fields.system) or system
			architecture = premake.api.checkvalue(platform, premake.fields.architecture) or architecture
		end

		-- set up an environment for expanding tokens contained by this configuration
		local environ = {
			sln = sln,
			prj = prj,
		}

		-- create a context to represent this configuration; contains the terms
		-- that defines what belongs to this configuration, and controls access
		local ctx = context.new(prj.configset, environ)

		-- add base filters; some may be nil, so not safe to put in a list
		context.addterms(ctx, buildcfg)
		context.addterms(ctx, platform)
		context.addterms(ctx, _ACTION)
		context.addterms(ctx, prj.language)

		-- allow the project script to override the default system
		ctx.system = ctx.system or system
		context.addterms(ctx, ctx.system)

		-- allow the project script to override the default architecture
		ctx.architecture = ctx.architecture or architecture
		context.addterms(ctx, ctx.architecture)

		-- if a kind is set, allow that to influence the configuration
		context.addterms(ctx, ctx.kind)

		-- process that
		context.compile(ctx)

		-- attach a bit more local state
		ctx.project = prj
		ctx.solution = prj.solution
		ctx.buildcfg = buildcfg
		ctx.platform = platform
		ctx.action = _ACTION
		ctx.language = prj.language


		-- TODO: OLD, REMOVE: build an old-style configuration to wrap context, for now
		local filter = {
			["buildcfg"] = buildcfg,
			["platform"] = platform,
			["action"] = _ACTION,
			["system"] = ctx.system,
			["architecture"] = ctx.architecture,
		}

		local cfg = oven.bake(prj, prj.solution, filter)
		cfg.solution = prj.solution
		cfg.project = prj
		cfg.context = ctx

		-- File this under "too clever by half": I want path tokens (targetdir, etc.)
		-- to expand to relative paths, so they can be used in custom build rules and
		-- other places where it would be impractical to detect and convert them. So
		-- create a proxy object with an attached metatable that converts path fields
		-- on the fly as they are requested.
		local proxy = {}
		setmetatable(proxy, {
			__index = function(proxy, key)
				local field = premake.fields[key]
				if field and field.kind == "path" then
					return premake5.project.getrelative(cfg.project, cfg[key])
				end
				return cfg[key]
			end,
		})

		environ.cfg = proxy


		-- TODO: HACK, TRANSITIONAL, REMOVE: pass requests for missing values
		-- through to the config context. Eventually all values will be in the
		-- context and the cfg wrapper can be done away with
		setmetatable(cfg, {
			__index = function(cfg, key)
				return cfg.context[key]
			end,
			__newindex = function(cfg, key, value)
				cfg.context[key] = value
			end
		})


		-- fill in any calculated values
		premake5.config.bake(cfg)

		return cfg
	end


--
-- Returns an iterator function for the configuration objects contained by
-- the project. Each configuration corresponds to a build configuration/
-- platform pair (i.e. "Debug|x32") as specified in the solution.
--
-- @param prj
--    The project object to query.
-- @return
--    An iterator function returning configuration objects.
--

	function project.eachconfig(prj)
		-- to make testing a little easier, allow this function to
		-- accept an unbaked project, and fix it on the fly
		if not prj.baked then
			prj = project.bake(prj, prj.solution)
		end

		local configs = prj._cfglist
		local count = #configs

		local i = 0
		return function ()
			i = i + 1
			if i <= count then
				return project.getconfig(prj, configs[i][1], configs[i][2])
			end
		end
	end


--
-- Locate a project by name; case insensitive.
--
-- @param name
--    The name of the project for which to search.
-- @return
--    The corresponding project, or nil if no matching project could be found.
--

	function project.findproject(name)
		for sln in premake.solution.each() do
			for _, prj in ipairs(sln.projects) do
				if (prj.name == name) then
					return  prj
				end
			end
		end
	end


--
-- Retrieve the project's configuration information for a particular build
-- configuration/platform pair.
--
-- @param prj
--    The project object to query.
-- @param buildcfg
--    The name of the build configuration on which to filter.
-- @param platform
--    Optional; the name of the platform on which to filter.
-- @return
--    A configuration object.
--

	function project.getconfig(prj, buildcfg, platform)
		-- to make testing a little easier, allow this function to
		-- accept an unbaked project, and fix it on the fly
		if not prj.baked then
			prj = project.bake(prj, prj.solution)
		end

		-- if no build configuration is specified, return the "root" project
		-- configurations, which includes all configuration values that
		-- weren't set with a specific configuration filter
		if not buildcfg then
			return prj
		end

		-- apply any configuration mappings
		local pairing = project.mapconfig(prj, buildcfg, platform)
		buildcfg = pairing[1]
		platform = pairing[2]

		-- look up and return the associated config
		local key = (buildcfg or "*") .. (platform or "")
		return prj.configs[key]
	end


--
-- Returns a list of sibling projects on which the specified project depends.
-- This is used to list dependencies within a solution or workspace. Must
-- consider all configurations because Visual Studio does not support per-config
-- project dependencies.
--
-- @param prj
--    The project to query.
-- @return
--    A list of dependent projects, as an array of project objects.
--

	function project.getdependencies(prj)
		if not prj.dependencies then
			local result = {}
			local function add_to_project_list(cfg, depproj, result)
				local dep = premake.solution.findproject(cfg.solution, depproj)
					if dep and not table.contains(result, dep) then
						table.insert(result, dep)
					end
			end

			for cfg in project.eachconfig(prj) do
				for _, link in ipairs(cfg.links) do
					add_to_project_list(cfg, link, result)
				end
				for _, depproj in ipairs(cfg.dependson) do
					add_to_project_list(cfg, depproj, result)
				end
			end
			prj.dependencies = result
		end
		return prj.dependencies
	end


--
-- Builds a file configuration for a specific file from a project.
--
-- @param prj
--    The project to query.
-- @param filename
--    The absolute path of the file to query.
-- @return
--    A corresponding file configuration object.
--

	function project.getfileconfig(prj, filename)
		local fcfg = {}

		fcfg.abspath = filename
		fcfg.relpath = project.getrelative(prj, filename)

		local vpath = project.getvpath(prj, filename)
		if vpath ~= filename then
			fcfg.vpath = vpath
		else
			fcfg.vpath = fcfg.relpath
		end

		fcfg.name = path.getname(filename)
		fcfg.basename = path.getbasename(filename)
		fcfg.path = fcfg.relpath

		return fcfg
	end


--
-- Returns the file name for this project. Also works with solutions.
--
-- @param prj
--    The project object to query.
-- @param ext
--    An optional file extension to add, with the leading dot. If provided
--    without a leading dot, it will treated as a file name.
-- @return
--    The absolute path to the project's file.
--

	function project.getfilename(prj, ext)
		local fn = project.getlocation(prj)
		if ext and not ext:startswith(".") then
			fn = path.join(fn, ext)
		else
			fn = path.join(fn, prj.filename)
			if ext then
				fn = fn .. ext
			end
		end
		return fn
	end


--
-- Returns a unique object file name for a project source code file.
--
-- @param prj
--    The project object to query.
-- @param filename
--    The name of the file being compiled to the object file.
--

	function project.getfileobject(prj, filename)
		-- make sure I have the project, and not it's root configuration
		prj = prj.project or prj

		-- create a list of objects if necessary
		prj.fileobjects = prj.fileobjects or {}

		-- look for the corresponding object file
		local basename = path.getbasename(filename)
		local uniqued = basename
		local i = 0

		while prj.fileobjects[uniqued] do
			-- found a match?
			if prj.fileobjects[uniqued] == filename then
				return uniqued
			end

			-- check a different name
			i = i + 1
			uniqued = basename .. i
		end

		-- no match, create a new one
		prj.fileobjects[uniqued] = filename
		return uniqued
	end


--
-- Return the first configuration of a project, which is used in some
-- actions to generate project-wide defaults.
--
-- @param prj
--    The project object to query.
-- @return
--    The first configuration in a project, as would be returned by
--    eachconfig().
--

	function project.getfirstconfig(prj)
		local iter = project.eachconfig(prj)
		local first = iter()
		return first
	end


--
-- Retrieve the project's file system location. Also works with solutions.
--
-- @param prj
--    The project object to query.
-- @param relativeto
--    Optional; if supplied, the project location will be made relative
--    to this path.
-- @return
--    The path to the project's file system location.
--

	function project.getlocation(prj, relativeto)
		local location = prj.location
		if not location and prj.solution then
			location = prj.solution.location
		end
		if not location then
			location = prj.basedir
		end
		if relativeto then
			location = path.getrelative(relativeto, location)
		end
		return location
	end


--
-- Return the relative path from the project to the specified file.
--
-- @param prj
--    The project object to query.
-- @param filename
--    The file path, or an array of file paths, to convert.
-- @return
--    The relative path, or array of paths, from the project to the file.
--

	function project.getrelative(prj, filename)
		if type(filename) == "table" then
			local result = {}
			for i, name in ipairs(filename) do
				result[i] = project.getrelative(prj, name)
			end
			return result
		else
			if filename then
				return path.getrelative(project.getlocation(prj), filename)
			end
		end
	end


--
-- Create a tree from a project's list of source files.
--
-- @param prj
--    The project to query.
-- @return
--    A tree object containing the source file hierarchy. Leaf nodes
--    representing the individual files contain the fields:
--      abspath  - the absolute path of the file
--      relpath  - the relative path from the project to the file
--      vpath    - the file's virtual path
--    All nodes contain the fields:
--      path     - the node's path within the tree
--      realpath - the node's file system path (nil for virtual paths)
--      name     - the directory or file name represented by the node
--

	function project.getsourcetree(prj)
		-- make sure I have the project, and not it's root configuration
		prj = prj.project or prj

		-- check for a previously cached tree
		if prj.sourcetree then
			return prj.sourcetree
		end

		-- find *all* files referenced by the project, regardless of configuration
		local files = {}
		for cfg in project.eachconfig(prj) do
			for _, file in ipairs(cfg.files) do
				files[file] = file
			end
		end

		-- create a file config lookup cache
		prj.fileconfigs = {}

		-- create a tree from the file list
		local tr = premake.tree.new(prj.name)

		for file in pairs(files) do
			local fcfg = project.getfileconfig(prj, file)

			-- The tree represents the logical source code tree to be displayed
			-- in the IDE, not the physical organization of the file system. So
			-- virtual paths are used when adding nodes.
			local node = premake.tree.add(tr, fcfg.vpath, function(node)
				-- ...but when a real file system path is used, store it so that
				-- an association can be made in the IDE
				if fcfg.vpath == fcfg.relpath then
					node.realpath = node.path
				end
			end)

			-- Store full file configuration in file (leaf) nodes
			for key, value in pairs(fcfg) do
				node[key] = value
			end

			prj.fileconfigs[node.abspath] = node
		end

		premake.tree.trimroot(tr)
		premake.tree.sort(tr)

		-- cache result and return
		prj.sourcetree = tr
		return tr
	end


--
-- Given a source file path, return a corresponding virtual path based on
-- the vpath entries in the project. If no matching vpath entry is found,
-- the original path is returned.
--

	function project.getvpath(prj, filename)
		-- if there is no match, return the input filename
		local vpath = filename

		for replacement,patterns in pairs(prj.vpaths or {}) do
			for _,pattern in ipairs(patterns) do

				-- does the filename match this vpath pattern?
				local i = filename:find(path.wildcards(pattern))
				if i == 1 then
					-- yes; trim the pattern out of the target file's path
					local leaf
					i = pattern:find("*", 1, true) or (pattern:len() + 1)
					if i < filename:len() then
						leaf = filename:sub(i)
					else
						leaf = path.getname(filename)
					end
					if leaf:startswith("/") then
						leaf = leaf:sub(2)
					end

					-- check for (and remove) stars in the replacement pattern.
					-- If there are none, then trim all path info from the leaf
					-- and use just the filename in the replacement (stars should
					-- really only appear at the end; I'm cheating here)
					local stem = ""
					if replacement:len() > 0 then
						stem, stars = replacement:gsub("%*", "")
						if stars == 0 then
							leaf = path.getname(leaf)
						end
					else
						leaf = path.getname(leaf)
					end

					vpath = path.join(stem, leaf)
				end
			end
		end

		return vpath
	end


--
-- Determines if a project contains a particular build configuration/platform pair.
--

	function project.hasconfig(prj, buildcfg, platform)
		if buildcfg and not prj.configurations[buildcfg] then
			return false
		end
		if platform and not prj.platforms[platform] then
			return false
		end
		return true
	end


--
-- Determines if a project contains a particular source code file.
--
-- @param prj
--    The project to query.
-- @param filename
--    The absolute path to the source code file being checked.
-- @return
--    True if the file belongs to the project, in any configuration.
--

	function project.hasfile(prj, filename)
		-- make sure I have the project, and not it's root configuration
		prj = prj.project or prj

		-- TODO: the file cache should be built during the baking process;
		-- I shouldn't need to fetch the tree to get it.
		project.getsourcetree(prj)

		return prj.fileconfigs[filename] ~= nil
	end


--
-- Returns true if the project uses the C (and not C++) language.
--

	function project.isc(prj)
		return prj.language == premake.C
	end


--
-- Returns true if the project uses a C/C++ language.
--

	function project.iscpp(prj)
		return prj.language == premake.C or prj.language == premake.CPP
	end


--
-- Returns true if the project uses a .NET language.
--

	function project.isdotnet(prj)
		return prj.language == premake.CSHARP
	end


--
-- Given a build config/platform pairing, applies any project configuration maps
-- and returns a new (or the same) pairing.
--

	function project.mapconfig(prj, buildcfg, platform)
		local pairing = { buildcfg, platform }

		local testpattern = function(pattern, pairing, i)
			local j = 1
			while i <= #pairing and j <= #pattern do
				if pairing[i] ~= pattern[j] then
					return false
				end
				i = i + 1
				j = j + 1
			end
			return true
		end

		for pattern, replacements in pairs(prj.configmap or {}) do
			if type(pattern) ~= "table" then
				pattern = { pattern }
			end

			-- does this pattern match any part of the pair? If so,
			-- replace it with the corresponding values
			for i = 1, #pairing do
				if testpattern(pattern, pairing, i) then
					if #pattern == 1 and #replacements == 1 then
						pairing[i] = replacements[1]
					else
						pairing = { replacements[1], replacements[2] }
					end
				end
			end
		end

		return pairing
	end

