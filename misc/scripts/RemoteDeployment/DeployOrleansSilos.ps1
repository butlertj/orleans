# Deploys the silos defined in the Deployment.xml file.
#requires -version 2.0

param([string]$deploymentConfigFile, [switch]$noClean)

$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Definition
. $scriptDir\UtilityFunctions.ps1

$configXml = New-Object XML

if (($deploymentConfigFile -eq "/?") -or 
	($args[0] -eq "-?") -or
	($deploymentConfigFile -eq "/help") -or
	($args[0] -eq "-help") -or
	($deploymentConfigFile -eq "help") )
{
	WriteHostSafe Green -text ""
	WriteHostSafe Green -text "`tUsage:`t.\DeployOrleansSilos [deploymentConfigFile] [noClean]"
	WriteHostSafe Green -text ""
	WriteHostSafe Green -text "`t`tdeploymentConfigFile::`t[Optional] The path to the deployment configuration file. "
	WriteHostSafe Green -text "`t`t`t`t`t(i.e. ""Deployment.xml"")  Use quotes if the path has a spaces." 
	WriteHostSafe Green -text "`t`t`t`t`tDefault is Deployment.xml. "
	WriteHostSafe Green -text ""
	WriteHostSafe Green -text "`t`tnoClean::`t`t[Optional] If a value is provided, do not use robocopy /MIR option."
	WriteHostSafe Green -text "`t`t`t`t`tDefault is to mirror the source directory."
	WriteHostSafe Green -text ""
	WriteHostSafe Green -text "`tExample:`t.\DeployOrleansSilos "
	WriteHostSafe Green -text "`tExample:`t.\DeployOrleansSilos MyConfig1\config.config "
	WriteHostSafe Green -text "`tExample:`t.\DeployOrleansSilos MyConfig1\config.config -noClean "
	WriteHostSafe Green -text ""
	return
}


# Change the path to where we think it should be (see http://huddledmasses.org/powershell-power-user-tips-current-directory/).
[Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath

$configXml = Get-DeploymentConfiguration ([ref]$deploymentConfigFile) $scriptDir


# if we couldn't load the config file, the script cannot continue.
if (!$configXml -or $configXml -eq "")
{
	WriteHostSafe -foregroundColor Red -text "     Deployment configuration file required to continue."
	WriteHostSafe -foregroundColor Red -text "          Please supply the name of the configuration file, or ensure that the default"
	WriteHostSafe -foregroundColor Red -text "          Deployment.xml file is available in the script directory."
	return
}

if (!$deploymentConfigFile.Length)
{
	WriteHostSafe -foregroundColor Red -text "     Deployment configuration file name not returned from Get-DeploymentConfiguration()."
	WriteHostSafe -foregroundColor Red -text "          Specifying Deployment.xml on the command line may work around this issue."
	return
}

$configValidationError = $false

##$machineNames = @($configXml.Deployment.Nodes.Node | ForEach-Object {$_.HostName} | select-object -unique)
$machineNames = Get-UniqueMachineNames $configXml $deploymentConfigFile

$deployFileName = Split-Path -Path $deploymentConfigFile -Leaf

if(!$machineNames)
{
	WriteHostSafe -foregroundColor Red -text "     At least one target machine is required to continue."
	WriteHostSafe -foregroundColor Red -text ("")
	$configValidationError = $true
}

# Try to get the $localTargetPath from the target location node in the config file.
$localTargetPath = $configXml.Deployment.TargetLocation.Path

if (!$localTargetPath)
{
	$localTargetPath = "C:\Orleans"
	WriteHostSafe -foregroundColor Yellow -text ("     TargetLocation not found in config file; defaulting to ""{0}""." -f $localTargetPath)
	WriteHostSafe -foregroundColor Yellow -text ("")
}

## If target path is relative, convert it to absolute so it can be used by robocopy to remote machines.
#$localTargetPath = (Resolve-Path $localTargetPath).Path

# Set the remote path by changing the drive designation to a remote admin share.
$remoteTargetPath = $localTargetPath.Replace(":", "$");

# Get the path to the source files for the system
$sourceXpath = "descendant::xcg:Package[@Type=""System""]" 

$packagesNode = $configXml.Deployment.Packages
if ($packagesNode.Package) 
{
	$sourceConfig = $packagesNode | Select-Xml -Namespace @{xcg="urn:xcg-deployment"} -XPath $sourceXpath
}

if ($sourceConfig -and $sourceConfig.Node -and $sourceConfig.Node.Path)
{
	$sourcePath = $sourceConfig.Node.Path
}

if (!$sourcePath)
{
	WriteHostSafe -foregroundColor Red -text ("     *** Error: The system <Package> element was not found in $deployFileName.")
	WriteHostSafe -foregroundColor Red -text "        Please supply an element for the System package, as well as additional Application packages."
	WriteHostSafe -foregroundColor Red -text ("        Format: <Packages>")
	WriteHostSafe -foregroundColor Red -text ("                    <Package Name=""System Runtime"" Type=""System"" Path=""."" />"	)
	WriteHostSafe -foregroundColor Red -text ("                    <Package Name=""Chirper"" Type=""Application"" Path=""..\Applications\Chirper"" Filter=""Chirper*"" />"	)
	WriteHostSafe -foregroundColor Red -text ("                <Packages>")
	WriteHostSafe -foregroundColor Red -text ("")
	WriteHostSafe -foregroundColor Red -text "     A System Package is required to continue."
	WriteHostSafe -foregroundColor Red -text ("")
	$configValidationError = $true
}

# Expand out the relative directory.
if ($sourcePath -eq ".")
{
	$sourcePath = $scriptDir
}

# Convert relative path to absolute so it can be passed to jobs.
$fullBaseCfgPath = Split-Path -Parent -Resolve "$deploymentConfigFile"

# All relative paths should be relative to the directory where the deployment config file is located.
if ($sourcePath -and !(Split-Path $sourcePath -IsAbsolute))
{
	$sourcePath = Join-Path -Path $fullBaseCfgPath -ChildPath $sourcePath
}

# Get the configuration file path from the deployment configuration file.
$configFilePath = $configXml.Deployment.RuntimeConfiguration.Path

if(!$configFilePath) 
{
	$configFilePath = "{0}\{1}" -f $fullBaseCfgPath, "OrleansConfiguration.xml"
}

if (!(Test-Path $configFilePath))
{
	WriteHostSafe -foregroundColor Red -text ("     *** Error: The configuration file ""$configFilePath""")
	WriteHostSafe -foregroundColor Red -text ("         specified in $deployFileName cannot be found.")
	WriteHostSafe -foregroundColor Red -text ("")
	WriteHostSafe -foregroundColor Red -text ("         Confirm that the file name is correct in the Path attribute")
	WriteHostSafe -foregroundColor Red -text ("         of the <RuntimeConfiguration> element and that the file exists ") 
	WriteHostSafe -foregroundColor Red -text ("         at the specified location"	)
	WriteHostSafe -foregroundColor Red -text ("")
	$configValidationError = $true
}
else 
{
	if (!(Split-Path $configFilePath  -IsAbsolute))
	{
		$configFilePath = "{0}\{1}" -f $fullBaseCfgPath, $configFilePath
	}
}

if ($configValidationError)
{
	WriteHostSafe -foregroundColor Red -text "      Deployment cannot proceed with invalid configuration."
	return
}

if ($configXml.Deployment.Program)
{
	$exeName = $configXml.Deployment.Program.ExeName
	if (!$exeName)
	{
		$exeName = "OrleansHost"
	}
}
Echo "Program executable = $exeName"

# Flatten the array so we can call stop on all the machines at once.
foreach ($machineName in $machineNames) 
{
	# Build a string that contains all the the machine names so we can let 
	#	PowerShell invoke the script asynchronously on the machines.
	if ($machineList)
	{
		$machineList = "$machineList, $machineName"
	}
	else 
	{
		$machineList = $machineName
	}
}
	
# TODO: Test to see if the machine is accessible.

Echo "Stopping program executable $exeName on all machines ..."
StopOrleans $machineList $exeName

WriteHostSafe -foregroundColor Green -text "Stop operations complete."
Echo ""

if ($machineNames.Count -ne 1) {$pluralizer = "s"} else {$pluralizer = ""}
"Deploying to {0} machine{1}." -f $machineNames.Count, $pluralizer

# Create an array of objects that holds the information about each machine.
$machines = @()

# Add a marker so that we see the seperation between the different deployments.
Add-Content "copyjob.log" ("*" * 107)
Add-Content "copyjob.log" ("*** Deployment starting at {0}" -f (Get-Date))

"Copying deployment files from {0} to ..." -f $sourcePath
foreach ($machineName in $machineNames) 
{
	# Add the machine name to the path.  We already convereted <Drive Letter>: to <Drive Letter>$
	#  (i.e. C: was changed to C$).
	if ($remoteTargetPath.StartsWith("\"))
	{
		$fullHostPath = "\\$machineName{0}" -f $remoteTargetPath
	}
	else 
	{
		$fullHostPath = "\\$machineName\{0}" -f $remoteTargetPath
	}
	$machine = "" | Select-Object name,processId,copyJob,hostPath;
	$machine.name = $machineName
	$machine.hostPath = $fullHostPath
	
	"     ... target $fullHostPath" 
		

	$machine.copyJob = Start-Job -ArgumentList $fullBaseCfgPath, $sourcePath, $configFilePath, $fullHostPath, $configXml, $noClean -ScriptBlock {
		param($cfgBasePath, $sourcePath, $configFilePath, $targetPath, $configXml, $noClean) 
			Echo " "
			"*** Copy job params received: cfgBasePath={0} sourcePath={1} hostPath={2} noClean={3}" -f $cfgBasePath, $sourcePath, $targetPath, $noClean

			# Change the path to where we think it should be (see http://huddledmasses.org/powershell-power-user-tips-current-directory/).
			[Environment]::CurrentDirectory=$cfgBasePath
			"*** Current Directory: {0, -55}" -f ([Environment]::CurrentDirectory)

			if (!(Test-Path -Path "$targetPath"))
			{
				"*** Creating target directory {0}" -f $targetPath
				
				$ErrorActionPreference = 'SilentlyContinue'
				$Error.Clear();
				mkdir "$targetPath"
				$ErrorActionPreference = 'Continue'
				# Test after creating.
				if (!(Test-Path -Path "$targetPath"))
				{
					"*** ERROR: Could not create target path {0}:" -f $targetPath
					"***        {0}" -f $Error[$Error.Count - 1]
					exit 1
				}
			}
			if (!(Test-Path -Path "$targetPath" -PathType Container))
			{
				"*** ERROR: Target path {0} exists but is not a directory" -f $targetPath
				exit 1
			}
			"*** Source directory: {0, -55} Exists={1, -7} IsDirectory={2, -7}" -f $sourcePath, (Test-Path -Path "$sourcePath"), (Test-Path -Path "$sourcePath" -PathType Container)
			"*** Target directory: {0, -55} Exists={1, -7} IsDirectory={2, -7}" -f $targetPath, (Test-Path -Path "$targetPath"), (Test-Path -Path "$targetPath" -PathType Container)

			"*** Begin runtime system package copy ..."
			Echo " " 
			if ($noClean)
			{
				Echo " "
				"`t*** Robocopy without Mirror option."
				robocopy "$sourcePath" "$targetPath" /S /XF *.temp /XF *.log /XF Deployment.xml /XD src /NDL /NFL
			}
			else
			{
				Echo " "
				"`t*** Robocopy with Mirror option - target will be cleaned."
				robocopy "$sourcePath" "$targetPath" /S /XF *.temp /XF *.log /XF Deployment.xml /XD src /NDL /NFL /MIR
			}

			# Get a list of application paths.
			$appXpath = "descendant::xcg:Package[@Type=""Application""]" 
			$appConfig = $configXml.Deployment.Packages | Select-Xml -Namespace @{xcg="urn:xcg-deployment"} -XPath $appXpath
			# Now copy the applications.

			Echo " "
			"*** Begin application copy..."
			foreach ($application in $appConfig)
			{
				if (Split-Path $application.Node.Path  -IsAbsolute)
				{
					$appSourcePath = $application.Node.Path
				}
				else 
				{
					$appSourcePath = "{0}\{1}" -f $cfgBasePath, $application.Node.Path
				}
				$targetAppPath = "{0}\Applications\{1}" -f $targetPath, $application.Node.Name
				$filter = $application.Node.Filter
				Echo " "
				"*** Copying application: {0}" -f $application.Node.Name 
				"`t*** Source: {0}" -f $appSourcePath
				"`t*** Target: {0}" -f $targetAppPath
				"`t*** Filter: {0}" -f $filter
				robocopy "$appSourcePath" "$targetAppPath" "$filter" /S /XF *.temp /XF *.log /XD src /NDL /NFL
			}

			# Copy the system configuration File
##			$configFilePath = $configXml.Deployment.RuntimeConfiguration.Path
##			if (!(Split-Path $configFilePath  -IsAbsolute))
##			{
##				$configFilePath = "{0}\{1}" -f $cfgBasePath, $configFilePath
##			}
			"`t*** Copying config file: Source: {0} - Target: {1}" -f $configFilePath, $targetPath
			Copy-Item "$configFilePath" "$targetPath"
			Echo " "
			"*** Copy Operation complete to target {0}." -f $targetPath
			Echo " "

	} # End script block for job
	
	$machines = $machines + $machine
} # End for each machineName

Echo ""
WriteHostSafe -foregroundColor Green -text "Copy jobs started...beginning process start-up."
Echo ""


foreach ($machine in $machines) 
{
	# Create an XmlNamespaceManager to resolve the default namespace.
	$ns = New-Object Xml.XmlNamespaceManager $configXml.NameTable
	$ns.AddNamespace( "xcg", "urn:xcg-deployment" )
	
	# We have to build the XPath string this way because $machine.name doesn't unpack 
	#	correctly inside the string.
	$xpath = ("descendant::xcg:Node[@HostName=""{0}""]" -f $machine.name)

	# Start each silo on the machine.
	$silos = $configXml.SelectNodes($xpath, $ns)
	$siloCount = 0;
	foreach($silo in $silos)
	{
		if ($machine.copyJob.State -ne "Completed")
		{
			WriteHostSafe -foregroundColor Yellow -text ("     Waiting for copy job on machine {0} to finish before starting silo {1}." -f $machine.name, $silo.NodeName)
			# TODO: Use time out and detect condition to report and proceed (or abort) as appropriate.
			WriteHostSafe -foregroundColor Gray -text ("{4, 21} {5, -10} {0,-8} {1,-10} {2,-10} {3,-20}" -f $machine.copyJob.Id, $machine.copyJob.name, $machine.copyJob.State, $machine.copyJob.Location, "Copy Job:       ", " ")
			$waitResult = Wait-Job -Job $machine.copyJob 
			Add-Content "copyjob.log" ("*" * 107)
			$waitResultMessage = "{5,-23} {6,-16} {0,-7} {1,-10} {2,-12} {3,-14} {4,-25}" -f "ID", "Name", "State", "HasMoreData", "Location", "Date", "Machine"
			Add-Content "copyjob.log" $waitResultMessage
			$waitResultMessage = "{5,-23} {6,-16} {0,-7} {1,-10} {2,-12} {3,-14} {4,-25}`n`r`n`r" -f $waitResult.Id, $waitResult.Name, $waitResult.State, $waitResult.HasMoreData, $waitResult.Location, (Get-Date), $machine.name
			Add-Content "copyjob.log" $waitResultMessage
		}
		else 
		{
			Add-Content "copyjob.log" ("*" * 107)
			$waitResultMessage = "{5,-23} {6,-16} {0,-7} {1,-10} {2,-12} {3,-14} {4,-25}" -f "ID", "Name", "State", "HasMoreData", "Location", "Date", "Machine"
			Add-Content "copyjob.log" $waitResultMessage
			$waitResultMessage = "{5,-23} {6,-16} {0,-7} {1,-10} {2,-12} {3,-14} {4,-25}`n`r`n`r" -f $machine.copyJob.Id, $machine.copyJob.Name, $machine.copyJob.State, $machine.copyJob.HasMoreData, $machine.copyJob.Location, (Get-Date), $machine.name
			Add-Content "copyjob.log" $waitResultMessage
		}
		
		if ($machine.copyJob.HasMoreData)
		{
			$copyJobResult = Receive-Job $machine.copyJob
			Add-Content "copyjob.log" $copyJobResult			
		}
		Echo ""
		WriteHostSafe -foregroundColor Green -text ("`tCopy operation complete on machine {0}." -f $machine.name)
			
		# TODO: Add code determine if the copy job completed successfully and abort or retry if not.
		if ($machine.processId.Length -gt 0)
		{
			$machine.processId += ";"
		}
		$command = "$localTargetPath\$exeName ""{0}"" ""{1}""" -f $silo.NodeName, (Split-Path $configFilePath -Leaf)
		$process = Invoke-WmiMethod -path win32_process -name create -argumentlist $command, $localTargetPath -ComputerName $machine.name
		WriteHostSafe Green -text ("`tStarted $exeName process {0} on machine {1}." -f $process.ProcessId, $machine.name)
		
		if ($process.ProcessId)
		{
			$machine.processId += $process.ProcessId.ToString()
		}
		else 
		{
			WriteHostSafe Red -text ("`tError: $exeName not started for silo {0} on machine {1}" -f $silo.NodeName, $machine.name)
		}
		if (($siloCount -eq 0) -and
			($silos.Count -gt 1))
		{
			WriteHostSafe -foregroundColor Yellow -text "`t`tPausing for Primary silo to complete start-up" -noNewline $true 
			$pauseLength = 5
			$pauseIteration = 0
			while ($pauseIteration -lt $pauseLength)
			{
				Start-Sleep -Seconds 1
				WriteHostSafe -foregroundColor Yellow -text "." -noNewline $true 
				$pauseIteration += 1
			}
			WriteHostSafe -text " " 
		}
		
		$siloCount += 1
	}
}


# This will automatically reset the file.
$logFile = "DeployStartResults.log"
Get-Date | Out-File $logFile

Echo " "
WriteHostSafe -foregroundColor DarkCyan -text "Collecting Start-up results and saving in ""$logFile""" -noNewline $true 
# Pause for Start-up jobs to settle out.
$pauseLength = 5
$pauseIteration = 0
while ($pauseIteration -lt $pauseLength)
{
	Start-Sleep -Seconds 1
	WriteHostSafe -foregroundColor DarkCyan -text "." -noNewline $true 
	$pauseIteration += 1
}
Echo " " 
WriteHostSafe -foregroundColor Cyan -text "Preparing Start-up Results Log"
foreach ($machine in $machines) 
{
	$processIds = $machine.processId -split ";"
	foreach ($id in $processIds) 
	{
		"Machine: {0}" -f $machine.name | Out-File $logFile -Append 
		$remoteProcess = Get-Process -ComputerName $machine.name -Id $id -ErrorAction SilentlyContinue
		if (!$remoteProcess)
		{
			$remoteProcess =  ("    Error!  Could not find process {0} on machine {1}`n`r." -f $id, $machine.name)
		}
		$remoteProcess | Out-File $logFile -Append 
	}
} 
Echo " "

Get-Content $logFile
Echo ""
echo 'End of Start-up Results'

WriteHostSafe Green -text ""
WriteHostSafe Green -text "Checking for active processes"
$numProcesses = 0
foreach ($machine in $machines) 
{
	$process = Get-Process -ComputerName $machine.name -Name "$exeName" -ErrorAction SilentlyContinue
	
	if ($process)
	{
		if ($process.Count)
		{
			foreach($instance in $process)
			{
				$numProcesses++
			}
		}
		else
		{
			$numProcesses++
		}
	}
	else
	{
		WriteHostSafe -foregroundColor Red -text ("$exeName is not running on {0}" -f $machine.name)
	}
}
WriteHostSafe Green -text ("{0} processes running" -f $numProcesses)

