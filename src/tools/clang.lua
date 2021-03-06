--
-- clang.lua
-- Clang toolset adapter for Premake
-- Copyright (c) 2013 Jason Perkins and the Premake project
--

	premake.tools.clang = {}
	local clang = premake.tools.clang
	local gcc = premake.tools.gcc



--
-- Build a list of flags for the C preprocessor corresponding to the
-- settings in a particular project configuration.
--
-- @param cfg
--    The project configuration.
-- @return
--    An array of C preprocessor flags.
--

	function clang.getcppflags(cfg)

		-- Just pass through to GCC for now
		local flags = gcc.getcppflags(cfg)
		return flags

	end


--
-- Build a list of C compiler flags corresponding to the settings in
-- a particular project configuration. These flags are exclusive
-- of the C++ compiler flags, there is no overlap.
--
-- @param cfg
--    The project configuration.
-- @return
--    An array of C compiler flags.
--

	function clang.getcflags(cfg)

		-- Just pass through to GCC for now
		local flags = gcc.getcflags(cfg)
		return flags

	end


--
-- Build a list of C++ compiler flags corresponding to the settings
-- in a particular project configuration. These flags are exclusive
-- of the C compiler flags, there is no overlap.
--
-- @param cfg
--    The project configuration.
-- @return
--    An array of C++ compiler flags.
--

	function clang.getcxxflags(cfg)

		-- Just pass through to GCC for now
		local flags = gcc.getcxxflags(cfg)
		return flags

	end


--
-- Returns a list of defined preprocessor symbols, decorated for
-- the compiler command line.
--
-- @param defines
--    An array of preprocessor symbols to define; as an array of
--    string values.
-- @return
--    An array of symbols with the appropriate flag decorations.
--

	function clang.getdefines(defines)

		-- Just pass through to GCC for now
		local flags = gcc.getdefines(defines)
		return flags

	end


--
-- Returns a list of include file search directories, decorated for
-- the compiler command line.
--
-- @param cfg
--    The project configuration.
-- @param dirs
--    An array of include file search directories; as an array of
--    string values.
-- @return
--    An array of symbols with the appropriate flag decorations.
--

	function clang.getincludedirs(cfg, dirs)

		-- Just pass through to GCC for now
		local flags = gcc.getincludedirs(cfg, dirs)
		return flags

	end


--
-- Build a list of linker flags corresponding to the settings in
-- a particular project configuration.
--
-- @param cfg
--    The project configuration.
-- @return
--    An array of linker flags.
--

	function clang.getldflags(cfg)

		-- Just pass through to GCC for now
		local flags = gcc.getldflags(cfg)
		return flags

	end


--
-- Build a list of libraries to be linked for a particular project
-- configuration, decorated for the linker command line.
--
-- @param cfg
--    The project configuration.
-- @param systemOnly
--    Boolean flag indicating whether to link only system libraries,
--    or system libraries and sibling projects as well.
-- @return
--    A list of libraries to link, decorated for the linker.
--

	function clang.getlinks(cfg, systemOnly)

		-- Just pass through to GCC for now
		local flags = gcc.getlinks(cfg, systemOnly)
		return flags

	end


--
-- Return a list of makefile-specific configuration rules. This will
-- be going away when I get a chance to overhaul these adapters.
--
-- @param cfg
--    The project configuration.
-- @return
--    A list of additional makefile rules.
--

	function clang.getmakesettings(cfg)

		-- Just pass through to GCC for now
		local flags = gcc.getmakesettings(cfg)
		return flags

	end


--
-- Retrieves the executable command name for a tool, based on the
-- provided configuration and the operating environment. I will
-- be moving these into global configuration blocks when I get
-- the chance.
--
-- @param cfg
--    The configuration to query.
-- @param tool
--    The tool to fetch, one of "cc" for the C compiler, "cxx" for
--    the C++ compiler, or "ar" for the static linker.
-- @return
--    The executable command name for a tool, or nil if the system's
--    default value should be used.
--

	function clang.gettoolname(cfg, tool)

		-- Real simple implementation for now, buying time until I
		-- get a chance to rewrite (and possibly sufficient?)

		if tool == "ar" then
			return "ar"
		else
			return "clang"
		end

	end
