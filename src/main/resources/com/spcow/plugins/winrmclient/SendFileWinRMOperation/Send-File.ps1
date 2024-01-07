function Send-File
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Destination,

		[Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Password,

        [string]$ConfigurationValue,

        $session,

        [long]$ttl = 60000,

        [string]$WinTempPath = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))" + '\WorkerFileCache'

	)
	process
	{
	    try
        {           
            if($ConfigurationValue){
            Write-Host "ConfigurationValue parameter has been depricated and will be ignored"
            }
            $SecretDetailsFormatted = ConvertTo-SecureString -AsPlainText -Force -String $Password
            $CredentialObject = New-Object -typename System.Management.Automation.PSCredential -argumentlist $UserName, $SecretDetailsFormatted
            if(!($Session)){
                Write-Host "Connecting to remote host " $ComputerName "...."
                $Session_option = New-PSSessionOption -IdleTimeout $ttl 
                $Session = New-PSSession -ComputerName $ComputerName -Credential $CredentialObject -SessionOption $Session_option
                Write-Host "Connected to remote host."
            }

            foreach ($p in $Path)
            {
				if ($p.StartsWith('\\'))
				{
					
					if(!(test-path -path $WinTempPath)){
                        New-Item -ItemType Directory -Path $WinTempPath -Force | Out-Null
                    }
					
					$dest = "$WinTempPath\$($p | Split-Path -Leaf)"

                    Write-Host "[$($p)] is a UNC path. Copying locally first to $dest"

					$src_drive_name = 'Src_Drive_' + $(Get-Random -Maximum 100000)	
					$src_drive = New-PSDrive -Name $src_drive_name -PSProvider FileSystem -Root $p -Credential $CredentialObject

                    Write-Host "UNC path [$($src_drive.root)] is now monunted as [$($src_drive.name)]" 

					$logfilePath = $WinTempPath + '\' + $src_drive_name + '.log'
                    
                    $SrcFiles = $src_drive_name + ':\'
                    Set-Location $SrcFiles

					Robocopy . *.* $dest /V /S /MIR /COPYALL /ZB /NP /R:0 /W:0 /LOG+:$logfilePath | Out-Null

                    Write-Host "Logfile [$($logfilePath)] has been created" 

                    Set-Location $WinTempPath

					Remove-PSDrive $src_drive_name

                    $sendParams = @{
							'Session' = $Session
							'Path' = $dest
                            'Destination' = $Destination
                            'ComputerName' = $ComputerName
                            'Password' = $Password
                            'UserName' = $UserName
						}
                    Send-File @sendParams
				}elseif (Test-Path -Path $p -PathType Container)
				{

					Write-Host "[$($p)] is a folder. Sending all files to [$($Destination)]"
					Copy-Item $p -Destination $Destination -ToSession $Session -Recurse -Force
					Write-Host "WinRM dircopy of [$($p)] to [$($Destination)] complete"
				}
				else
				{
					Write-Host "Starting WinRM copy of [$($p)] to [$($Destination)]"
					# Get the source file, and then get its contents
                    
                    Invoke-Command -Session $Session -ScriptBlock {
                        if(!(test-path -path $using:destination)){
                            New-Item -ItemType Directory -Path $using:destination -Force | Out-Null  
                        }
                    }
                    Copy-Item $p -Destination $Destination -ToSession $Session
					Write-Host "WinRM filecopy of [$($p)] to [$($Destination)] complete"
				}
		    }
		}
        catch
        {
            Write-Host $_.Exception.Message
            exit 1
        }
	}
}