--
-- tests/actions/vstudio/vc2010/test_item_def_group.lua
-- Check the item definition groups, containing compile and link flags.
-- Copyright (c) 2013 Jason Perkins and the Premake project
--

	local suite = test.declare("vs2010_config_props")
	local vc2010 = premake.vstudio.vc2010
	local project = premake5.project


--
-- Setup
--

	local sln, prj, cfg

	function suite.setup()
		sln = test.createsolution()
	end

	local function prepare(buildcfg)
		prj = premake.solution.getproject_ng(sln, 1)
		cfg = project.getconfig(prj, buildcfg or "Debug")
		vc2010.itemDefinitionGroup(cfg)
	end


--
-- Check generation of opening element for typical C++ project.
--

	function suite.structureIsCorrect_onDefaultValues()
		prepare()
		test.capture [[
	<ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
		]]
	end


--
-- Makefile projects omit the condition and all contents.
--

	function suite.structureIsCorrect_onMakefile()
		kind "Makefile"
		prepare()
		test.capture [[
	<ItemDefinitionGroup>
	</ItemDefinitionGroup>
		]]
	end



--
-- Because the item definition group for makefile projects is not
-- tied to a particular condition, it should only get written for
-- the first configuration.
--

	function suite.skipped_onSubsequentConfigs()
		kind "Makefile"
		prepare("Release")
		test.isemptycapture()
	end
