#Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

function Get-MSBuildToolsPath
{
    param(
        $Version = "14.0"
    )

    return (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\$Version").MSBuildToolsPath32
}

function Add-MSBuildAssembly
{
    param(
        $Version = "14.0"
    )

    $assembly = Join-Path (Get-MSBuildToolsPath $Version) "Microsoft.Build.dll"

    Add-Type -Path $assembly
}

function Get-VSWherePath
{
    $localPath = "$PSScriptRoot\tools\vswhere.exe"

    if (-not (Test-Path $localPath))
    {
        mkdir (Split-Path $localPath -Parent) -ErrorAction SilentlyContinue | Out-Null

        Invoke-WebRequest -OutFile $localPath -Uri "https://github.com/Microsoft/vswhere/releases/download/2.2.3/vswhere.exe" | Out-Null
    }

    return $localPath
}

function Get-MSBuildExePath
{
    param(
        $Version = "15.0"
    )

    $path = & (Get-VSWherePath) -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if ($path) {
      $path = join-path $path 'MSBuild\15.0\Bin\MSBuild.exe'
      if (test-path $path) {
        return $path
      }
    }

    return "MSBuild.exe"
}


function Invoke-MSBuild
{
    param(
        $Project,
        [hashtable]$Properties
    )

    $msBuildExe = Get-MSBuildExePath
    $propertyArgs = Format-MSBuildCommandLineProperties $Properties

    $arguments = @($propertyArgs) + @((Resolve-Path $Project)) + "/v:q" + "/nologo" + "/t:Clean;Build"

    Write-Verbose "Invoking MSBuild: $msBuildExe $arguments"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $msBuildExe
    $pinfo.RedirectStandardError = $true
    #$pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    #$stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()

    Write-Host $stderr

    if ($p.ExitCode -ne 0) {
        throw $stderr
    }

    return $stdout

}

function Format-MSBuildCommandLineProperties
{
    param(
        [hashtable]$Properties
    )

    return @($Properties.GetEnumerator() | % { "/P:$($_.Key)=$($_.Value)" })
}

function ConvertTo-Dictionary
{
    param(
        [hashtable]$InputObject
    )

    $outputObject = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

    foreach ($entry in $InputObject.GetEnumerator())
    {
        $key = [string]$entry.Key
        $value = [string]$entry.Value

        $outputObject.Add($key, $value)
    }

    return $outputObject
}