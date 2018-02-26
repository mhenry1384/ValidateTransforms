# Used by the builds to make sure all the web.config and nant.config transforms are good.  Otherwise, we won't catch a bad transform until we go to deploy to a particular environment.
# Use the -SaveInCurrentDir to save the transforms to the current directory instead of the temp folder
param(
	[Parameter(Mandatory=$true)]
	[ValidateScript({ Test-Path $_ })]
	[string]$dir, # Dir to start the search at, the solution or project dir.
	[switch]$SaveInCurrentDir = $false
)

echo "Validating transforms in $dir"
$ErrorActionPreference = 'Stop'

$ALTERNATE_WEB_CONFIG = "web.base.config" # Transform against this if it exists.  We use it for some projects.
$cala = join-path $PSScriptRoot calamari.exe
$webxml = join-path $PSScriptRoot microsoft.web.xmltransform.dll

[Reflection.assembly]::loadfile($cala) | out-null
[Reflection.assembly]::loadfile($webxml) | out-null

$transformer = new-object Calamari.Integration.ConfigurationTransforms.ConfigurationTransformer($false, $true)

function transform($configPath, $transformPath) {
	$tempFilePath = [io.path]::GetTempFileName()
	try
	{
		$transformer.PerformTransform($configPath, $transformPath, $tempFilePath)
		if ($SaveInCurrentDir)
		{
			Copy-Item $tempFilePath -Destination "$($transformPath).transformed"
		}
	}
	finally
	{
		Remove-Item $tempFilePath
	}
}

function getTransforms($config) {
	$filter = if ($_.name -like "web*") {
		"web.*.config"
	} elseif ($_.name -like "nlog*") {
		"nlog.*.config"
	}
	else {
		"*.exe.*.config"
	}

	ls -path $config.directory.fullname -filter $filter | ? { $_.name -ne $ALTERNATE_WEB_CONFIG }
}

$configFiles = ls -path $dir -filter *.config -recurse | ? { $_.name -eq "web.config" -or $_.name -eq $ALTERNATE_WEB_CONFIG -or $_.name -eq "nlog.config" -or $_.name -eq "app.config"} | ? { $_.fullname -notlike "*\packages\*" } 
$configFiles | % {
	$config = $_
	if ($config.name -eq "web.config" -and  ($configFiles | ? { $_.fullname -eq ("$($config.directory.fullname)\$ALTERNATE_WEB_CONFIG")})) {
		echo "$ALTERNATE_WEB_CONFIG exists so skipping $_.fullname"
	}
	else {
		$transforms = getTransforms($config)
		$transforms | % {
			echo "Test transform $($_.fullname) ==> $($config.fullname)"
			transform $config.fullname $_.fullname
		}
	}
}
