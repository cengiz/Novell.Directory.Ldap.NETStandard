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
		Install-Module InvokeBuild -RequiredVersion $InvokeBuildVersion -Scope CurrentUser -Force
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

task remove-opendj -After test-functional {
    exec {
        docker kill opendj
    }
    exec {
        docker rm opendj
    }
}

task test test-unit, test-functional, {
}

task configure-openldap {
    exec {
        sudo apt-get update
    }
    exec {
        sudo apt-get install ldap-utils gnutls-bin ssl-cert slapd -y
    }
    exec {
        bash configure-openldap.sh
    }
}

task remove-openldap -After test-stress {
    exec {
        service slapd stop
    }
    exec {
        sudo apt-get remove slapd -y
    }
    exec {
        rm /tmp/slapd -r -f
    }
}

task test-stress configure-openldap, {
    $env:TRANSPORT_SECURITY="OFF"
    exec {
        dotnet run --configuration $CONFIGURATION `
            --project test/Novell.Directory.Ldap.NETStandard.StressTests/Novell.Directory.Ldap.NETStandard.StressTests.csproj 10 30
    }
}

task clean {
	remove bin, obj
}

task . build, test
