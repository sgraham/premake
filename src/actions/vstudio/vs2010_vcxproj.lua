--
-- vs2010_vcxproj.lua
-- Generate a Visual Studio 201x C/C++ project.
-- Copyright (c) 2009-2013 Jason Perkins and the Premake project
--

	premake.vstudio.vc2010 = {}
	local vc2010 = premake.vstudio.vc2010
	local vstudio = premake.vstudio
	local project = premake5.project
	local config = premake5.config
	local tree = premake.tree


--
-- Generate a Visual Studio 201x C++ project, with support for the new platforms API.
--

	function vc2010.generate(prj)
		io.eol = "\r\n"
		io.indent = "  "
		io.utf8()

		vc2010.project("Build")
		vc2010.projectConfigurations(prj)
		vc2010.globals(prj)

		_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />')

		for cfg in project.eachconfig(prj) do
			vc2010.configurationProperties(cfg)
		end

		_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.props" />')
		_p(1,'<ImportGroup Label="ExtensionSettings">')
		_p(1,'</ImportGroup>')

		for cfg in project.eachconfig(prj) do
			vc2010.propertySheets(cfg)
		end

		_p(1,'<PropertyGroup Label="UserMacros" />')

		for cfg in project.eachconfig(prj) do
			vc2010.outputProperties(cfg)
			vc2010.nmakeProperties(cfg)
		end

		for cfg in project.eachconfig(prj) do
			vc2010.itemDefinitionGroup(cfg)
		end

		vc2010.assemblyReferences(prj)
		vc2010.files(prj)
		vc2010.projectReferences(prj)

		vc2010.import(prj)

		_p('</Project>')
	end



--
-- Output the XML declaration and opening <Project> tag.
--

	function vc2010.project(target)
		_p('<?xml version="1.0" encoding="utf-8"?>')

		local defaultTargets = ""
		if target then
			defaultTargets = string.format(' DefaultTargets="%s"', target)
		end

		_p('<Project%s ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">', defaultTargets)
	end


--
-- Write out the list of project configurations, which pairs build
-- configurations with architectures.
--

	function vc2010.projectConfigurations(prj)

		-- build a list of all architectures used in this project
		local platforms = {}
		for cfg in project.eachconfig(prj) do
			local arch = vstudio.archFromConfig(cfg, true)
			if not table.contains(platforms, arch) then
				table.insert(platforms, arch)
			end
		end

		local configs = {}
		_p(1,'<ItemGroup Label="ProjectConfigurations">')
		for cfg in project.eachconfig(prj) do
			for _, arch in ipairs(platforms) do
				local prjcfg = vstudio.projectConfig(cfg, arch)
				if not configs[prjcfg] then
					configs[prjcfg] = prjcfg
					_x(2,'<ProjectConfiguration Include="%s">', vstudio.projectConfig(cfg, arch))
					_x(3,'<Configuration>%s</Configuration>', vstudio.projectPlatform(cfg))
					_p(3,'<Platform>%s</Platform>', arch)
					_p(2,'</ProjectConfiguration>')
				end
			end
		end
		_p(1,'</ItemGroup>')
	end


--
-- Write out the Globals property group.
--

	function vc2010.globals(prj)
		vc2010.propertyGroup(nil, "Globals")
		vc2010.projectGuid(prj)

		-- try to determine what kind of targets we're building here
		local isWin, isManaged, isMakefile
		for cfg in project.eachconfig(prj) do
			if cfg.system == premake.WINDOWS then
				isWin = true
			end
			if cfg.flags.Managed then
				isManaged = true
			end
			if cfg.kind == premake.MAKEFILE then
				isMakefile = true
			end
		end

		if isWin then
			if isMakefile then
				_p(2,'<Keyword>MakeFileProj</Keyword>')
			else
				if isManaged then
					_p(2,'<TargetFrameworkVersion>v4.0</TargetFrameworkVersion>')
					_p(2,'<Keyword>ManagedCProj</Keyword>')
				else
					_p(2,'<Keyword>Win32Proj</Keyword>')
				end
				_p(2,'<RootNamespace>%s</RootNamespace>', prj.name)
			end
		end

		_p(1,'</PropertyGroup>')
	end


--
-- Write out the configuration property group: what kind of binary it
-- produces, and some global settings.
--

	function vc2010.configurationProperties(cfg)
		vc2010.propertyGroup(cfg, "Configuration")
		vc2010.configurationType(cfg)
		vc2010.useDebugLibraries(cfg)
		vc2010.platformToolset(cfg)
		vc2010.useOfMfc(cfg)
		vc2010.clrSupport(cfg)
		vc2010.characterSet(cfg)

		if cfg.kind == premake.MAKEFILE then
			vc2010.outDir(cfg)
			vc2010.intDir(cfg)
		end

		_p(1,'</PropertyGroup>')
	end


--
-- Write out the default property sheets for a configuration.
--

	function vc2010.propertySheets(cfg)
		_p(1,'<ImportGroup Label="PropertySheets" %s>', vc2010.condition(cfg))
		_p(2,'<Import Project="$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props" Condition="exists(\'$(UserRootDir)\\Microsoft.Cpp.$(Platform).user.props\')" Label="LocalAppDataPlatform" />')
		_p(1,'</ImportGroup>')
	end


--
-- Write the output property group, which includes the output and intermediate
-- directories, manifest, etc.
--

	function vc2010.outputProperties(cfg)
		if cfg.kind ~= premake.MAKEFILE then
			vc2010.propertyGroup(cfg)
			vc2010.linkIncremental(cfg)
			vc2010.ignoreImportLibrary(cfg)
			vc2010.outDir(cfg)
			vc2010.outputFile(cfg)
			vc2010.intDir(cfg)
			vc2010.targetName(cfg)
			vc2010.targetExt(cfg)
			vc2010.imageXexOutput(cfg)
			vc2010.generateManifest(cfg)
			_p(1,'</PropertyGroup>')
		end
	end


--
-- Write the NMake property group for Makefile projects, which includes the custom
-- build commands, output file location, etc.
--

	function vc2010.nmakeProperties(cfg)
		if cfg.kind == premake.MAKEFILE then
			vc2010.propertyGroup(cfg)
			vc2010.nmakeOutput(cfg)
			_p(1,'</PropertyGroup>')
		end
	end


--
-- Write a configuration's item definition group, which contains all
-- of the per-configuration compile and link settings.
--

	function vc2010.itemDefinitionGroup(cfg)
		if cfg.kind ~= premake.MAKEFILE then
			_p(1,'<ItemDefinitionGroup %s>', vc2010.condition(cfg))
			vc2010.clCompile(cfg)
			vc2010.resourceCompile(cfg)
			vc2010.link(cfg)
			vc2010.buildEvents(cfg)
			vc2010.imageXex(cfg)
			vc2010.deploy(cfg)
			_p(1,'</ItemDefinitionGroup>')

		else
			if cfg == project.getfirstconfig(cfg.project) then
				_p(1,'<ItemDefinitionGroup>')
				_p(1,'</ItemDefinitionGroup>')
			end
		end
	end


--
-- Write the the <ClCompile> compiler settings block.
--

	function vc2010.clCompile(cfg)
		if cfg.kind ~= premake.MAKEFILE then
			_p(2,'<ClCompile>')
			vc2010.precompiledHeader(cfg)
			vc2010.warningLevel(cfg)
			vc2010.treatWarningAsError(cfg)
			vc2010.basicRuntimeChecks(cfg)
			vc2010.preprocessorDefinitions(cfg, cfg.defines)
			vc2010.additionalIncludeDirectories(cfg, cfg.includedirs)
			vc2010.forceIncludes(cfg)
			vc2010.debugInformationFormat(cfg)
			vc2010.programDataBaseFileName(cfg)
			vc2010.optimization(cfg)
			vc2010.functionLevelLinking(cfg)
			vc2010.intrinsicFunctions(cfg)
			vc2010.minimalRebuild(cfg)
			vc2010.omitFramePointers(cfg)
			vc2010.stringPooling(cfg)
			vc2010.runtimeLibrary(cfg)
			vc2010.exceptionHandling(cfg)
			vc2010.runtimeTypeInfo(cfg)
			vc2010.treatWChar_tAsBuiltInType(cfg)
			vc2010.floatingPointModel(cfg)
			vc2010.enableEnhancedInstructionSet(cfg)
			vc2010.multiProcessorCompilation(cfg)
			vc2010.additionalCompileOptions(cfg)
			vc2010.compileAs(cfg)
			_p(2,'</ClCompile>')
		end
	end


--
-- Write out the resource compiler block.
--

	function vc2010.resourceCompile(cfg)
		if cfg.kind ~= premake.MAKEFILE and cfg.system ~= premake.XBOX360 then
			_p(2,'<ResourceCompile>')
			vc2010.preprocessorDefinitions(cfg, table.join(cfg.defines, cfg.resdefines))
			vc2010.additionalIncludeDirectories(cfg, table.join(cfg.includedirs, cfg.resincludedirs))
			_p(2,'</ResourceCompile>')
		end
	end


--
-- Write out the linker tool block.
--

	function vc2010.link(cfg)
		if cfg.kind ~= premake.MAKEFILE then
			local explicit = vstudio.needsExplicitLink(cfg)

			_p(2,'<Link>')

			vc2010.subSystem(cfg)
			vc2010.generateDebugInformation(cfg)
			vc2010.optimizeReferences(cfg)

			if cfg.kind ~= premake.STATICLIB then
				vc2010.linkDynamic(cfg, explicit)
			end

			_p(2,'</Link>')

			if cfg.kind == premake.STATICLIB then
				vc2010.linkStatic(cfg)
			end

			vc2010.linkLibraryDependencies(cfg, explicit)
		end
	end

	function vc2010.linkDynamic(cfg, explicit)
		vc2010.additionalDependencies(cfg, explicit)
		vc2010.additionalLibraryDirectories(cfg)
		vc2010.importLibrary(cfg)
		vc2010.entryPointSymbol(cfg)
		vc2010.moduleDefinitionFile(cfg)
		vc2010.additionalLinkOptions(cfg)
	end

	function vc2010.linkStatic(cfg)
		_p(2,'<Lib>')
		vc2010.additionalLinkOptions(cfg)
		_p(2,'</Lib>')
	end


--
-- Write out the pre- and post-build event settings.
--

	function vc2010.buildEvents(cfg)
		function write(group, list)
			if #list > 0 then
				_p(2,'<%s>', group)
				_x(3,'<Command>%s</Command>', table.implode(list, "", "", "\r\n"))
				_p(2,'</%s>', group)
			end
		end
		write("PreBuildEvent", cfg.prebuildcommands)
		write("PreLinkEvent", cfg.prelinkcommands)
		write("PostBuildEvent", cfg.postbuildcommands)
	end


--
-- Reference any managed assemblies listed in the links()
--

	function vc2010.assemblyReferences(prj)
		-- Visual Studio doesn't support per-config references; use
		-- whatever is contained in the first configuration
		local cfg = project.getfirstconfig(prj)

		local refs = config.getlinks(cfg, "system", "fullpath", "managed")
		 if #refs > 0 then
		 	_p(1,'<ItemGroup>')
		 	table.foreachi(refs, function(value)

				-- If the link contains a '/' then it is a relative path to
				-- a local assembly. Otherwise treat it as a system assembly.
				if value:find('/', 1, true) then
					_x(2,'<Reference Include="%s">', path.getbasename(value))
					_x(3,'<HintPath>%s</HintPath>', path.translate(value))
					_p(2,'</Reference>')
				else
					_x(2,'<Reference Include="%s" />', path.getbasename(value))
				end

		 	end)
		 	_p(1,'</ItemGroup>')
		 end
	end


--
-- Write out the list of source code files, and any associated configuration.
--

	function vc2010.files(prj)
		vc2010.simplefilesgroup(prj, "ClInclude")
		vc2010.compilerfilesgroup(prj)
		vc2010.simplefilesgroup(prj, "None")
		vc2010.simplefilesgroup(prj, "ResourceCompile")
		vc2010.customBuildFilesGroup(prj)
	end


	function vc2010.simplefilesgroup(prj, group)
		local files = vc2010.getfilegroup(prj, group)
		if #files > 0  then
			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				_x(2,'<%s Include=\"%s\" />', group, path.translate(file.relpath))
			end
			_p(1,'</ItemGroup>')
		end
	end


	function vc2010.compilerfilesgroup(prj)
		local files = vc2010.getfilegroup(prj, "ClCompile")
		if #files > 0  then
			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				_x(2,'<ClCompile Include=\"%s\">', path.translate(file.relpath))
				for cfg in project.eachconfig(prj) do
					local condition = vc2010.condition(cfg)

					local filecfg = config.getfileconfig(cfg, file.abspath)
					vc2010.excludedFromBuild(cfg, filecfg)
					if filecfg then
						vc2010.objectFileName(filecfg)
						vc2010.forceIncludes(filecfg, condition)
						vc2010.precompiledHeader(cfg, filecfg, condition)
						vc2010.additionalCompileOptions(filecfg, condition)
					end

				end
				_p(2,'</ClCompile>')
			end
			_p(1,'</ItemGroup>')
		end
	end


	function vc2010.customBuildFilesGroup(prj)
		local files = vc2010.getfilegroup(prj, "CustomBuild")
		if #files > 0  then
			_p(1,'<ItemGroup>')
			for _, file in ipairs(files) do
				_x(2,'<CustomBuild Include=\"%s\">', path.translate(file.relpath))
				_p(3,'<FileType>Document</FileType>')

				for cfg in project.eachconfig(prj) do
					local condition = vc2010.condition(cfg)
					local filecfg = config.getfileconfig(cfg, file.abspath)
					if filecfg and filecfg.buildrule then
						local commands = table.concat(filecfg.buildrule.commands,'\r\n')
						_p(3,'<Command %s>%s</Command>', condition, premake.esc(commands))

						local outputs = table.concat(filecfg.buildrule.outputs, ' ')
						_p(3,'<Outputs %s>%s</Outputs>', condition, premake.esc(outputs))
					end
				end

				_p(2,'</CustomBuild>')
			end
			_p(1,'</ItemGroup>')
		end
	end


	function vc2010.getfilegroup(prj, group)
		-- check for a cached copy before creating
		local groups = prj.vc2010_file_groups
		if not groups then
			groups = {
				ClCompile = {},
				ClInclude = {},
				None = {},
				ResourceCompile = {},
				CustomBuild = {},
			}
			prj.vc2010_file_groups = groups

			local tr = project.getsourcetree(prj)
			tree.traverse(tr, {
				onleaf = function(node)
					-- if any configuration of this file uses a custom build rule,
					-- then they all must be marked as custom build
					local hasbuildrule = false
					for cfg in project.eachconfig(prj) do
						local filecfg = config.getfileconfig(cfg, node.abspath)
						if filecfg and filecfg.buildrule then
							hasbuildrule = true
							break
						end
					end

					if hasbuildrule then
						table.insert(groups.CustomBuild, node)
					elseif path.iscppfile(node.name) then
						table.insert(groups.ClCompile, node)
					elseif path.iscppheader(node.name) then
						table.insert(groups.ClInclude, node)
					elseif path.isresourcefile(node.name) then
						table.insert(groups.ResourceCompile, node)
					else
						table.insert(groups.None, node)
					end
				end
			})
		end

		return groups[group]
	end


--
-- Generate the list of project dependencies.
--

	function vc2010.projectReferences(prj)
		local deps = project.getdependencies(prj)
		if #deps > 0 then
			local prjpath = project.getlocation(prj)

			_p(1,'<ItemGroup>')
			for _, dep in ipairs(deps) do
				local relpath = path.getrelative(prjpath, vstudio.projectfile(dep))
				_x(2,'<ProjectReference Include=\"%s\">', path.translate(relpath))
				_p(3,'<Project>{%s}</Project>', dep.uuid)
				_p(2,'</ProjectReference>')
			end
			_p(1,'</ItemGroup>')
		end
	end



---------------------------------------------------------------------------
--
-- Handlers for individual project elements
--
---------------------------------------------------------------------------

	function vc2010.additionalDependencies(cfg, explicit)
		local links

		-- check to see if this project uses an external toolset. If so, let the
		-- toolset define the format of the links
		local toolset = premake.vstudio.vc200x.toolset(cfg)
		if toolset then
			links = toolset.getlinks(cfg, not explicit)
		else
			local scope = iif(explicit, "all", "system")
			links = config.getlinks(cfg, scope, "fullpath")
		end

		if #links > 0 then
			links = path.translate(table.concat(links, ";"))
			_x(3,'<AdditionalDependencies>%s;%%(AdditionalDependencies)</AdditionalDependencies>', links)
		end
	end


	function vc2010.additionalIncludeDirectories(cfg, includedirs)
		if #includedirs > 0 then
			local dirs = project.getrelative(cfg.project, includedirs)
			dirs = path.translate(table.concat(dirs, ";"))
			_x(3,'<AdditionalIncludeDirectories>%s;%%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>', dirs)
		end
	end


	function vc2010.additionalLibraryDirectories(cfg)
		if #cfg.libdirs > 0 then
			local dirs = project.getrelative(cfg.project, cfg.libdirs)
			dirs = path.translate(table.concat(dirs, ";"))
			_x(3,'<AdditionalLibraryDirectories>%s;%%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>', dirs)
		end
	end


	function vc2010.additionalCompileOptions(cfg, condition)
		if #cfg.buildoptions > 0 then
			local opts = table.concat(cfg.buildoptions, " ")
			vc2010.element(3, "AdditionalOptions", condition, '%s %%(AdditionalOptions)', opts)
		end
	end


	function vc2010.additionalLinkOptions(cfg)
		if #cfg.linkoptions > 0 then
			local opts = table.concat(cfg.linkoptions, " ")
			_x(3, '<AdditionalOptions>%s %%(AdditionalOptions)</AdditionalOptions>', opts)
		end
	end


	function vc2010.basicRuntimeChecks(cfg)
		if cfg.flags.NoRuntimeChecks then
			_p(3,'<BasicRuntimeChecks>Default</BasicRuntimeChecks>')
		end
	end


	function vc2010.characterSet(cfg)
		if cfg.kind ~= premake.MAKEFILE then
			_p(2,'<CharacterSet>%s</CharacterSet>', iif(cfg.flags.Unicode, "Unicode", "MultiByte"))
		end
	end


	function vc2010.clrSupport(cfg)
		if cfg.flags.Managed then
			_p(2,'<CLRSupport>true</CLRSupport>')
		end
	end


	function vc2010.compileAs(cfg)
		if cfg.project.language == "C" then
			_p(3,'<CompileAs>CompileAsC</CompileAs>')
		end
	end


	function vc2010.configurationType(cfg)
		local types = {
			SharedLib = "DynamicLibrary",
			StaticLib = "StaticLibrary",
			ConsoleApp = "Application",
			WindowedApp = "Application",
			Makefile = "Makefile",
		}
		_p(2,'<ConfigurationType>%s</ConfigurationType>', types[cfg.kind])
	end


	function vc2010.debugInformationFormat(cfg)
		local value
		if cfg.flags.Symbols then
			if cfg.debugformat == "c7" then
				value = "OldStyle"
			elseif cfg.architecture == "x64" or
			       cfg.flags.Managed or
				   premake.config.isoptimizedbuild(cfg) or
				   cfg.flags.NoEditAndContinue
			then
				value = "ProgramDatabase"
			else
				value = "EditAndContinue"
			end
		end
		if value then
			_p(3,'<DebugInformationFormat>%s</DebugInformationFormat>', value)
		end
	end


	function vc2010.deploy(cfg)
		if cfg.system == premake.XBOX360 then
			_p(2,'<Deploy>')
			_p(3,'<DeploymentType>CopyToHardDrive</DeploymentType>')
			_p(3,'<DvdEmulationType>ZeroSeekTimes</DvdEmulationType>')
			_p(3,'<DeploymentFiles>$(RemoteRoot)=$(ImagePath);</DeploymentFiles>')
			_p(2,'</Deploy>')
		end
	end


	function vc2010.enableEnhancedInstructionSet(cfg)
		if cfg.flags.EnableSSE2 then
			_p(3,'<EnableEnhancedInstructionSet>StreamingSIMDExtensions2</EnableEnhancedInstructionSet>')
		elseif cfg.flags.EnableSSE then
			_p(3,'<EnableEnhancedInstructionSet>StreamingSIMDExtensions</EnableEnhancedInstructionSet>')
		end
	end


	function vc2010.entryPointSymbol(cfg)
		if (cfg.kind == premake.CONSOLEAPP or cfg.kind == premake.WINDOWEDAPP) and
		   not cfg.flags.WinMain and
		   not cfg.flags.Managed and
		   cfg.system ~= premake.XBOX360
		then
			_p(3,'<EntryPointSymbol>mainCRTStartup</EntryPointSymbol>')
		end
	end


	function vc2010.exceptionHandling(cfg)
		if cfg.flags.NoExceptions then
			_p(3,'<ExceptionHandling>false</ExceptionHandling>')
		elseif cfg.flags.SEH then
			_p(3,'<ExceptionHandling>Async</ExceptionHandling>')
		end
	end


	function vc2010.excludedFromBuild(cfg, filecfg)
		if not filecfg or filecfg.flags.ExcludeFromBuild then
			_p(3,'<ExcludedFromBuild %s>true</ExcludedFromBuild>', vc2010.condition(cfg))
		end
	end


	function vc2010.floatingPointModel(cfg)
		if cfg.flags.FloatFast then
			_p(3,'<FloatingPointModel>Fast</FloatingPointModel>')
		elseif cfg.flags.FloatStrict and not cfg.flags.Managed then
			_p(3,'<FloatingPointModel>Strict</FloatingPointModel>')
		end
	end


	function vc2010.forceIncludes(cfg, condition)
		if #cfg.forceincludes > 0 then
			local includes = path.translate(project.getrelative(cfg.project, cfg.forceincludes))
			vc2010.element(3, "ForcedIncludeFiles", condition, table.concat(includes, ';'))
		end
		if #cfg.forceusings > 0 then
			local usings = path.translate(project.getrelative(cfg.project, cfg.forceusings))
			_x(3,'<ForcedUsingFiles>%s</ForcedUsingFiles>', table.concat(usings, ';'))
		end
	end


	function vc2010.functionLevelLinking(cfg)
		if premake.config.isoptimizedbuild(cfg) then
			_p(3,'<FunctionLevelLinking>true</FunctionLevelLinking>')
		end
	end


	function vc2010.generateDebugInformation(cfg)
		_p(3,'<GenerateDebugInformation>%s</GenerateDebugInformation>', tostring(cfg.flags.Symbols ~= nil))
	end


	function vc2010.generateManifest(cfg)
		if cfg.flags.NoManifest then
			_p(2,'<GenerateManifest>false</GenerateManifest>')
		end
	end


	function vc2010.ignoreImportLibrary(cfg)
		if cfg.kind == premake.SHAREDLIB and cfg.flags.NoImportLib then
			_p(2,'<IgnoreImportLibrary>true</IgnoreImportLibrary>');
		end
	end


	function vc2010.imageXex(cfg)
		if cfg.system == premake.XBOX360 then
			_p(2,'<ImageXex>')
			_p(3,'<ConfigurationFile>')
			_p(3,'</ConfigurationFile>')
			_p(3,'<AdditionalSections>')
			_p(3,'</AdditionalSections>')
			_p(2,'</ImageXex>')
		end
	end


	function vc2010.imageXexOutput(cfg)
		if cfg.system == premake.XBOX360 then
			_x(2,'<ImageXexOutput>$(OutDir)$(TargetName).xex</ImageXexOutput>')
		end
	end


	function vc2010.import(prj)
		_p(1,'<Import Project="$(VCTargetsPath)\\Microsoft.Cpp.targets" />')
		_p(1,'<ImportGroup Label="ExtensionTargets">')
		_p(1,'</ImportGroup>')
	end


	function vc2010.importLibrary(cfg)
		if cfg.kind == premake.SHAREDLIB then
			_x(3,'<ImportLibrary>%s</ImportLibrary>', path.translate(cfg.linktarget.relpath))
		end
	end


	function vc2010.intDir(cfg)
		local objdir = project.getrelative(cfg.project, cfg.objdir)
		_x(2,'<IntDir>%s\\</IntDir>', path.translate(objdir))
	end


	function vc2010.intrinsicFunctions(cfg)
		if premake.config.isoptimizedbuild(cfg) then
			_p(3,'<IntrinsicFunctions>true</IntrinsicFunctions>')
		end
	end


	function vc2010.linkIncremental(cfg)
		if cfg.kind ~= premake.STATICLIB then
			_p(2,'<LinkIncremental>%s</LinkIncremental>', tostring(premake.config.canincrementallink(cfg)))
		end
	end


	function vc2010.linkLibraryDependencies(cfg, explicit)
		-- Left to its own devices, VS will happily link against a project dependency
		-- that has been excluded from the build. As a workaround, disable dependency
		-- linking and list all siblings explicitly
		if explicit then
			_p(2,'<ProjectReference>')
			_p(3,'<LinkLibraryDependencies>false</LinkLibraryDependencies>')
			_p(2,'</ProjectReference>')
		end
	end


	function vc2010.minimalRebuild(cfg)
		if premake.config.isoptimizedbuild(cfg) or
		   cfg.flags.NoMinimalRebuild or
		   cfg.flags.MultiProcessorCompile or
		   cfg.debugformat == premake.C7
		then
			_p(3,'<MinimalRebuild>false</MinimalRebuild>')
		end
	end


	function vc2010.moduleDefinitionFile(cfg)
		local df = config.findfile(cfg, ".def")
		if df then
			_p(3,'<ModuleDefinitionFile>%s</ModuleDefinitionFile>', df)
		end
	end


	function vc2010.multiProcessorCompilation(cfg)
		if cfg.flags.MultiProcessorCompile then
			_p(3,'<MultiProcessorCompilation>true</MultiProcessorCompilation>')
		end
	end


	function vc2010.nmakeOutput(cfg)
		_p(2,'<NMakeOutput>$(OutDir)%s</NMakeOutput>', cfg.buildtarget.name)
	end


	function vc2010.objectFileName(filecfg)
		local objectname = project.getfileobject(filecfg.project, filecfg.abspath)
		if objectname ~= path.getbasename(filecfg.abspath) then
			_p(3,'<ObjectFileName %s>$(IntDir)\\%s.obj</ObjectFileName>', vc2010.condition(filecfg.config), objectname)
		end
	end


	function vc2010.omitFramePointers(cfg)
		if cfg.flags.NoFramePointer then
			_p(3,'<OmitFramePointers>true</OmitFramePointers>')
		end
	end


	function vc2010.optimizeReferences(cfg)
		if premake.config.isoptimizedbuild(cfg) then
			_p(3,'<EnableCOMDATFolding>true</EnableCOMDATFolding>')
			_p(3,'<OptimizeReferences>true</OptimizeReferences>')
		end
	end


	function vc2010.optimization(cfg)
		local result = "Disabled"
		for _, flag in ipairs(cfg.flags) do
			if flag == "Optimize" then
				result = "Full"
			elseif flag == "OptimizeSize" then
				result = "MinSpace"
			elseif flag == "OptimizeSpeed" then
				result = "MaxSpeed"
			end
		end
		_p(3,'<Optimization>%s</Optimization>', result)
	end


	function vc2010.outDir(cfg)
		local outdir = project.getrelative(cfg.project, cfg.buildtarget.directory)
		_x(2,'<OutDir>%s\\</OutDir>', path.translate(outdir))
	end


	function vc2010.outputFile(cfg)
		if cfg.system == premake.XBOX360 then
			_p(2,'<OutputFile>$(OutDir)%s</OutputFile>', cfg.buildtarget.name)
		end
	end


	function vc2010.platformToolset(cfg)
		if _ACTION == "vs2012" then
			_p(2,'<PlatformToolset>v110</PlatformToolset>')
		end
	end


	function vc2010.precompiledHeader(cfg, filecfg, condition)
		if filecfg then
			if cfg.pchsource == filecfg.abspath and not cfg.flags.NoPCH then
				vc2010.element(3, 'PrecompiledHeader', condition, 'Create')
			end
		else
			if not cfg.flags.NoPCH and cfg.pchheader then
				_p(3,'<PrecompiledHeader>Use</PrecompiledHeader>')
				_x(3,'<PrecompiledHeaderFile>%s</PrecompiledHeaderFile>', path.getname(cfg.pchheader))
			else
				_p(3,'<PrecompiledHeader>NotUsing</PrecompiledHeader>')
			end
		end
	end


	function vc2010.preprocessorDefinitions(cfg, defines)
		if #defines > 0 then
			defines = table.concat(defines, ";")
			_x(3,'<PreprocessorDefinitions>%s;%%(PreprocessorDefinitions)</PreprocessorDefinitions>', defines)
		end
	end


	function vc2010.programDataBaseFileName(cfg)
		if cfg.flags.Symbols and cfg.debugformat ~= "c7" then
			local filename = cfg.buildtarget.basename
			_p(3,'<ProgramDataBaseFileName>$(OutDir)%s.pdb</ProgramDataBaseFileName>', filename)
		end
	end


	function vc2010.projectGuid(prj)
		_p(2,'<ProjectGuid>{%s}</ProjectGuid>', prj.uuid)
	end


	function vc2010.propertyGroup(cfg, label)
		local cond
		if cfg then
			cond = string.format(' %s', vc2010.condition(cfg))
		end

		if label then
			label = string.format(' Label="%s"', label)
		end

		_p(1,'<PropertyGroup%s%s>', cond or "", label or "")
	end


	function vc2010.runtimeLibrary(cfg)
		local runtimes = {
			StaticDebug = "MultiThreadedDebug",
			StaticRelease = "MultiThreaded",
		}
		local runtime = runtimes[config.getruntime(cfg)]
		if runtime then
			_p(3,'<RuntimeLibrary>%s</RuntimeLibrary>', runtime)
		end
	end


	function vc2010.runtimeTypeInfo(cfg)
		if cfg.flags.NoRTTI and not cfg.flags.Managed then
			_p(3,'<RuntimeTypeInfo>false</RuntimeTypeInfo>')
		end
	end


	function vc2010.stringPooling(cfg)
		if premake.config.isoptimizedbuild(cfg) then
			_p(3,'<StringPooling>true</StringPooling>')
		end
	end


	function vc2010.subSystem(cfg)
		if cfg.system ~= premake.XBOX360 then
			local subsystem = iif(cfg.kind == premake.CONSOLEAPP, "Console", "Windows")
			_p(3,'<SubSystem>%s</SubSystem>', subsystem)
		end
	end


	function vc2010.targetExt(cfg)
		_x(2,'<TargetExt>%s</TargetExt>', cfg.buildtarget.extension)
	end


	function vc2010.targetName(cfg)
		_x(2,'<TargetName>%s%s</TargetName>', cfg.buildtarget.prefix, cfg.buildtarget.basename)
	end


	function vc2010.treatWChar_tAsBuiltInType(cfg)
		if cfg.flags.NativeWChar then
			_p(3,'<TreatWChar_tAsBuiltInType>true</TreatWChar_tAsBuiltInType>')
		elseif cfg.flags.NoNativeWChar then
			_p(3,'<TreatWChar_tAsBuiltInType>false</TreatWChar_tAsBuiltInType>')
		end
	end


	function vc2010.treatWarningAsError(cfg)
		if cfg.flags.FatalWarnings and not cfg.flags.NoWarnings then
			_p(3,'<TreatWarningAsError>true</TreatWarningAsError>')
		end
	end


	function vc2010.useDebugLibraries(cfg)
		local runtime = config.getruntime(cfg)
		_p(2,'<UseDebugLibraries>%s</UseDebugLibraries>', tostring(runtime:endswith("Debug")))
	end


	function vc2010.useOfMfc(cfg)
		if cfg.flags.MFC then
			_p(2,'<UseOfMfc>%s</UseOfMfc>', iif(cfg.flags.StaticRuntime, "Static", "Dynamic"))
		end
	end


	function vc2010.warningLevel(cfg)
		local w = 3
		if cfg.flags.NoWarnings then
			w = 0
		elseif cfg.flags.ExtraWarnings then
			w = 4
		end
		_p(3,'<WarningLevel>Level%d</WarningLevel>', w)
	end




---------------------------------------------------------------------------
--
-- Support functions
--
---------------------------------------------------------------------------

--
-- Format and return a Visual Studio Condition attribute.
--

	function vc2010.condition(cfg)
		return string.format('Condition="\'$(Configuration)|$(Platform)\'==\'%s\'"', premake.esc(vstudio.projectConfig(cfg)))
	end


--
-- Output an individual project XML element, with an optional configuration
-- condition.
--
-- @param depth
--    How much to indent the element.
-- @param name
--    The element name.
-- @param condition
--    An optional configuration condition, formatted with vc2010.condition().
-- @param value
--    The element value, which may contain printf formatting tokens.
-- @param ...
--    Optional additional arguments to satisfy any tokens in the value.
--

	function vc2010.element(depth, name, condition, value, ...)
		if select('#',...) == 0 then
			value = premake.esc(value)
		end

		local format
		if condition then
			format = string.format('<%s %s>%s</%s>', name, condition, value, name)
		else
			format = string.format('<%s>%s</%s>', name, value, name)
		end

		_x(depth, format, ...)
	end
