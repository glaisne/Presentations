# Not working!

$URL = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$path = "$env:TEMP\VSCode.exe"
$client = [System.Net.WebClient]::new()
$client.DownloadFile($URL, $Path)

