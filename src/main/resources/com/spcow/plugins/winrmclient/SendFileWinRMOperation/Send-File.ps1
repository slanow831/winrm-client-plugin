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

        $session,

        [long]$ttl = 60000,

        [string]$WinTempPath = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))"

	)
	process
	{
	    try
        {           
            $SecretDetailsFormatted = ConvertTo-SecureString -AsPlainText -Force -String $Password
            $CredentialObject = New-Object -typename System.Management.Automation.PSCredential -argumentlist $UserName, $SecretDetailsFormatted
            if(!($Session)){
                Write-Host "Connecting to remote host " $ComputerName "...."
                $Session_option = New-PSSessionOption -IdleTimeout $ttl 
                $Session = New-PSSession -ComputerName $ComputerName -Credential $CredentialObject -SessionOption $Session_option
                Write-Host "Connected to remote host."
            }else{
                Write-Host "Already connected to remote host. Using session $Session"
            }

            foreach ($p in $Path)
            {
				if ($p.StartsWith('\\'))
				{
					
					
					#Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine'))
					$dest = "$WinTempPath\$($p | Split-Path -Leaf)"

                    Write-Host "[$($p)] is a UNC path. Copying locally first to $dest"

					$src_drive_name = 'Src_Drive_' + $(Get-Random -Maximum 100000)	

					New-PSDrive -Name "$src_drive_name" -PSProvider FileSystem -Root $p -Credential $CredentialObject
					$SrcFiles = "$src_drive_name" + ':\'
					$logfilePath = $WinTempPath + '\' + $src_drive_name + '.log'
					#Copy-Item $SrcFiles $dest -Recurse -Force

					Robocopy $SrcFiles $dest /V /S /MIR /COPYALL /ZB /NP /XO /R:0 /W:0  /LOG+:$logfilePath

					Remove-PSDrive "$src_drive_name"

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


					Write-Host $MyInvocation.MyCommand -Message "[$($p)] is a folder. Sending all files"
					$files = Get-ChildItem -Path $p -File -Recurse
					$sendFileParamColl = @()
					foreach ($file in $Files)
					{
						$sendParams = @{
							'Session' = $Session
							'Path' = $file.FullName
                            'ComputerName' = $ComputerName
                            'Password' = $Password
                            'UserName' = $UserName
						}
						if ($file.DirectoryName -ne $p) ## It's a subdirectory
						{
							$subdirpath = $Destination + '\' + $file.DirectoryName.Replace("$p\", '')
							$sendParams.Destination = "$subDirPath"
						}
						else
						{
							$sendParams.Destination = $Destination
						}
						$sendFileParamColl += $sendParams
					}
					foreach ($paramBlock in $sendFileParamColl)
					{
                        Send-File @paramBlock
					}


				}
				else
				{
					Write-Host "Starting WinRM copy of [$($p)] to [$($Destination)]"
					# Get the source file, and then get its contents
                    #(get-item -path $p).Directory
                    Invoke-Command -Session $Session -ScriptBlock {
                        if(!(test-path -path $using:destination)){
                            New-Item -ItemType Directory -Path $using:destination -Force  
                        }
                    }
                    Copy-Item $p -Destination $Destination -ToSession $Session
					Write-Host "WinRM copy of [$($p)] to [$($Destination)] complete"
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