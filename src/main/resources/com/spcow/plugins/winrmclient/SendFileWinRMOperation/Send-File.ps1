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

        $session

	)
	process
	{
	    try
        {           
            $SecretDetailsFormatted = ConvertTo-SecureString -AsPlainText -Force -String $Password
            $CredentialObject = New-Object -typename System.Management.Automation.PSCredential -argumentlist $UserName, $SecretDetailsFormatted
            if(!($Session)){
                Write-Host "Connecting to remote host " $ComputerName "...."
                $Session_option = New-PSSessionOption -IdleTimeout 60000 
                $Session = New-PSSession -ComputerName $ComputerName -Credential $CredentialObject -SessionOption $Session_option
                Write-Host "Connected to remote host."
            }else{
                Write-Host "Already connected to remote host. Using session $Session"
            }

            foreach ($p in $Path)
            {
				if ($p.StartsWith('\\'))
				{
					Write-Host "[$($p)] is a UNC path. Copying locally first"
					Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine'))
					$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
				}
				if (Test-Path -Path $p -PathType Container)
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
							$subdirpath = $file.DirectoryName.Replace("$p\", '')
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
                    (get-item -path $p).Directory
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