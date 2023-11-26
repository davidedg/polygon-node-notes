# Calculate exact size of snapshot files to download:

Powershell:
- Heimdall

      (irm https://snapshot-download.polygon.technology/heimdall-mainnet-parts.txt) -split '\n' | ? { $_.StartsWith('https') } | % { write-host $_ ; (iwr $_ -Method Head -UseBasicParsing -TimeoutSec 5).Headers.'Content-Length' } | measure-object -Sum | select Count,Sum,@{Name='SumGB';Expression={[math]::floor($_.Sum/(1024*1024*1024))}}

- BOR

      (irm https://snapshot-download.polygon.technology/bor-mainnet-parts.txt) -split '\n' | ? { $_.StartsWith('https') } | % { write-host $_ ; (iwr $_ -Method Head -UseBasicParsing -TimeoutSec 5).Headers.'Content-Length' } | measure-object -Sum | select Count,Sum,@{Name='SumGB';Expression={[math]::floor($_.Sum/(1024*1024*1024))}}




Directly in CMD (but this might be caught by AntiVirus):
- Heimdall

      powershell -ep bypass -command "(irm https://snapshot-download.polygon.technology/heimdall-mainnet-parts.txt) -split '\n' | ? { $_.StartsWith('https') } | % { write-host $_ ; (iwr $_ -Method Head -UseBasicParsing -TimeoutSec 5).Headers.'Content-Length' } | measure-object -Sum | select Count,Sum,@{Name='SumGB';Expression={[math]::floor($_.Sum/(1024*1024*1024))}}"

- Bor

      powershell -ep bypass -command "(irm https://snapshot-download.polygon.technology/bor-mainnet-parts.txt) -split '\n' | ? { $_.StartsWith('https') } | % { write-host $_ ; (iwr $_ -Method Head -UseBasicParsing -TimeoutSec 5).Headers.'Content-Length' } | measure-object -Sum | select Count,Sum,@{Name='SumGB';Expression={[math]::floor($_.Sum/(1024*1024*1024))}}"
