--
-- tests/actions/vstudio/vc200x/test_external_compiler.lua
-- Validate generation the VCCLCompiler element for external tools in VS 200x C/C++ projects.
-- Copyright (c) 2011-2012 Jason Perkins and the Premake project
--

	T.vs200x_external_compiler = { }
	local suite = T.vs200x_external_compiler
	local vc200x = premake.vstudio.vc200x


--
-- Setup/teardown
--

	local sln, prj, cfg

	function suite.setup()
		_ACTION = "vs2008"
		sln, prj = test.createsolution()
		system "PS3"
	end

	local function prepare()
		cfg = premake5.project.getconfig(prj, "Debug")
		vc200x.VCCLCompilerTool(cfg)
	end


--
-- Verify the basic structure with no extra flags or settings.
--

	function suite.checkDefaults()
		prepare()
		test.capture [[
			<Tool
				Name="VCCLCompilerTool"
				AdditionalOptions="-Xc+=exceptions -Xc+=rtti"
				UsePrecompiledHeader="0"
				ProgramDataBaseFileName="$(OutDir)\MyProject.pdb"
				DebugInformationFormat="0"
				CompileAs="0"
			/>
		]]
	end


--
-- Make sure that include directories are project relative.
--

	function suite.includeDirsAreProjectRelative()
		includedirs { "../include", "include" }
		prepare()
		test.capture [[
			<Tool
				Name="VCCLCompilerTool"
				AdditionalOptions="-Xc+=exceptions -Xc+=rtti"
				AdditionalIncludeDirectories="..\include;include"
				UsePrecompiledHeader="0"
		]]
	end


--
-- Check handling of forced includes.
--

	function suite.forcedIncludeFiles()
		forceincludes { "stdafx.h", "include/sys.h" }
		prepare()
		test.capture [[
			<Tool
				Name="VCCLCompilerTool"
				AdditionalOptions="-Xc+=exceptions -Xc+=rtti"
				UsePrecompiledHeader="0"
				ProgramDataBaseFileName="$(OutDir)\MyProject.pdb"
				DebugInformationFormat="0"
				CompileAs="0"
				ForcedIncludeFiles="stdafx.h;include\sys.h"
		]]
	end
