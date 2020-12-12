<#
.Synopsis
	Build script <https://github.com/nightroman/Invoke-Build>

.Example
	PS> ./Novell.Directory.Ldap.NetStandard.build.ps1 build -Configuration Release
#>

param(
	[Parameter(Position=0)]
	[string[]]$Tasks,
	[ValidateSet('Debug', 'Release')]
	[string]$Configuration = 'Release',
    [ValidateSet('net5', 'netcoreapp3.1')]
	[string]$Fx = 'net5'
)

# Ensure and call the module.
if ([System.IO.Path]::GetFileName($MyInvocation.ScriptName) -ne 'Invoke-Build.ps1') {
	$InvokeBuildVersion = '5.6.3'
	$ErrorActionPreference = 'Stop'
	try {
		Import-Module InvokeBuild -RequiredVersion $InvokeBuildVersion
	}
	catch {
		Install-Module InvokeBuild -RequiredVersion $InvokeBuildVersion -Scope AllUsers -Force
		Import-Module InvokeBuild -RequiredVersion $InvokeBuildVersion
	}
	Invoke-Build -Task $Tasks -File $MyInvocation.MyCommand.Path @PSBoundParameters
	return
}

task build {
	exec { 
        dotnet build -c $Configuration 
    }
}

task test-unit {
	exec { 
        dotnet test --configuration $Configuration --no-build `
            test/Novell.Directory.Ldap.NETStandard.UnitTests/Novell.Directory.Ldap.NETStandard.UnitTests.csproj -f $Fx 
    }
}

task configure-opendj {
	exec { chmod ugo+x configure-opendj.sh }

    exec { whoami }

    exec {
        # run openjd in docker
        docker run -d -h ldap-01.example.com -p 4389:1389 -p 4636:1636 -p 4444:4444 --name opendj --env-file opendj-docker-env.props openidentityplatform/opendj
    }

    exec {
        # give openldap enough time to start
        sleep 30
        docker ps -a
    }

    Test-Connection -TargetName localhost -TcpPort 4389
    Test-Connection -TargetName localhost -TcpPort 4636
}

task test-functional configure-opendj, {
    $env:TRANSPORT_SECURITY="OFF"
	exec { 
        dotnet test --configuration $CONFIGURATION  --no-build `
            test/Novell.Directory.Ldap.NETStandard.FunctionalTests/Novell.Directory.Ldap.NETStandard.FunctionalTests.csproj -f $Fx
    }

    $env:TRANSPORT_SECURITY="SSL"
	exec { 
        dotnet test --configuration $CONFIGURATION  --no-build `
            test/Novell.Directory.Ldap.NETStandard.FunctionalTests/Novell.Directory.Ldap.NETStandard.FunctionalTests.csproj -f $Fx
    }

    $env:TRANSPORT_SECURITY="TLS"
	exec { 
        dotnet test --configuration $CONFIGURATION  --no-build `
            test/Novell.Directory.Ldap.NETStandard.FunctionalTests/Novell.Directory.Ldap.NETStandard.FunctionalTests.csproj -f $Fx
    }
}

task after-test-functional -After test-functional {
    exec {
        docker kill opendj
    }
    exec {
        docker rm opendj
    }
}

task test test-unit, test-functional, {
}

task clean {
	remove bin, obj
}

task . build, test
