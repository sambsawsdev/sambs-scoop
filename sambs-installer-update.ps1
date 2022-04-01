Param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$branch='develop'
)

class SambsInstaller {
    [string]$version = '0.0.0'
    [string]$license = 'https://github.com/sambsawsdev/sambs-installer/blob/main/LICENSE'
    [string]$extract_dir = 'sambs-installer-main'
    [string]$url = 'https://github.com/sambsawsdev/sambs-installer/archive/main.zip'
    [string]$homepage = 'https://github.com/sambsawsdev/sambs-installer'
    [string]$hash = 'sha256:'
    [string[]]$bin = @("sambs-installer.cmd", "sambs-installer-uninstall.cmd")
    #[string]$persist = 'package'

    [string] toString() {
        return $this | ConvertTo-Json -Depth 2
    }
}

function Update-Installer {
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$branch
    )

    Process {
        try {
            Write-Log 'starting...'

            # Use env:SAMBS_HOME or the default <userHome>/.sambs
            if ([string]::IsNullOrWhiteSpace($env:SAMBS_HOME)) {
                $env:SAMBS_HOME = Join-Path -Path $HOME -ChildPath '/.sambs'
            }

            # Create the download directory
            [string]$installerUpdatePath = Join-Path -Path $env:SAMBS_HOME -ChildPath '/installer-update'
            $null = New-Item -Path $installerUpdatePath -ItemType Directory -Force
            
            # Download the sambs-installer zip file
            [string]$sambsInstallerFilePath = Join-Path -Path $installerUpdatePath -ChildPath "sambs-installer-$branch.zip"
            [System.Net.WebClient]$webClient = [System.Net.WebClient]::new()
            $webClient.DownloadFile("https://github.com/sambsawsdev/sambs-installer/archive/$branch.zip", $sambsInstallerFilePath);

            # Get the hash of the file
            [string]$installerHash = (Get-FileHash -LiteralPath $sambsInstallerFilePath -Algorithm SHA256 | Select-Object Hash).Hash

            # Remove the download directory
            Remove-Item -LiteralPath $installerUpdatePath -Recurse -Force

            # Ensure the mainfest file exists
            [string]$sambsInstallerJsonFilePath = Join-Path -Path $PSScriptroot -ChildPath '/bucket/sambs-installer.json'
            if ( -not ( Test-Path -LiteralPath $sambsInstallerJsonFilePath -PathType Leaf ) ) {
                $null = New-Item -Path $sambsInstallerJsonFilePath -ItemType File -Force
            }

            # Populate the json into a class
            [SambsInstaller]$sambsInstaller = [SambsInstaller]::new()
            $sambsInstallerJson = Get-Content -LiteralPath $sambsInstallerJsonFilePath -Raw | ConvertFrom-Json 
            # Loop through all the properties of the destination
            $sambsInstaller | Get-Member -MemberType Properties | ForEach-Object {
                # Ensure the property on the json is not null
                if (-not [string]::IsNullOrWhiteSpace($sambsInstallerJson."$($_.Name)")) {
                    # Populate the destination property with the value from the json
                    $sambsInstaller."$($_.Name)" = $sambsInstallerJson."$($_.Name)"
                }
            }

            # Only update if the hash has changed
            if ("sha256:$installerHash" -ne $sambsInstaller.hash) {
                # Update all the fields
                $sambsInstaller.extract_dir = "sambs-installer-$branch"
                $sambsInstaller.url = "https://github.com/sambsawsdev/sambs-installer/archive/$branch.zip"
                $sambsInstaller.hash = "sha256:$installerHash"
        
                # Increment the build version
                [System.Version]$version =  [System.Version]::new($sambsInstaller.version)
                $sambsInstaller.version = "$($version.Major).$($version.Minor).$($version.Build+1)"
            } 

            $sambsInstaller | ConvertTo-Json -Depth 2 | Out-File -FilePath $sambsInstallerJsonFilePath -Force
            Write-Log "$($sambsInstaller.ToString())"
            Write-Log 'completed.'
        } catch {
            Write-Log -message "failed: $_" -level 'Error' -forgroundColour 'Red'
            throw "$_"
        }
    }
}

function Write-Log {
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$message,
        [Parameter(Mandatory=$false, Position=1)]
        [string]$level = 'Info',
        [Parameter(Mandatory=$false, Position=2)]
        [string]$forgroundColour = 'White'
    )

    Process {
        try {
            # Format the message
            [string]$formattedMessage = "$(Get-Date -UFormat '%Y/%m/%d %T' ) [$($MyInvocation.MyCommand.Name)] -$level- : Sambs installer update $message"
            # Output the message
            Write-Host $formattedMessage -ForegroundColor $forgroundColour
        } catch {
            throw "Sambs installer logging failed: $_"
        }
    }
}

Update-Installer -branch $branch
