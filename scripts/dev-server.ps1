param(
  [int]$Port = 5173
)

$Root = Split-Path -Parent $PSScriptRoot
$Prefix = "http://localhost:$Port/"

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8" }
    ".css" { "text/css; charset=utf-8" }
    ".js" { "text/javascript; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    ".png" { "image/png" }
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".svg" { "image/svg+xml; charset=utf-8" }
    default { "application/octet-stream" }
  }
}

$Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$Listener.Start()
Write-Host "Life Dashboard preview running at $Prefix"

try {
  while ($true) {
    $Client = $Listener.AcceptTcpClient()
    $Stream = $Client.GetStream()
    $Reader = [System.IO.StreamReader]::new($Stream)
    $RequestLine = $Reader.ReadLine()

    while ($Reader.ReadLine()) {
    }

    if ([string]::IsNullOrWhiteSpace($RequestLine)) {
      $Client.Close()
      continue
    }

    $Parts = $RequestLine.Split(" ")
    $RequestPath = [Uri]::UnescapeDataString($Parts[1].Split("?")[0])

    if ($RequestPath -eq "/") {
      $RequestPath = "/index.html"
    }

    if ($RequestPath.Contains("..")) {
      $Body = [System.Text.Encoding]::UTF8.GetBytes("Bad request")
      $Header = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 400 Bad Request`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`n`r`n")
      $Stream.Write($Header, 0, $Header.Length)
      $Stream.Write($Body, 0, $Body.Length)
      $Client.Close()
      continue
    }

    $RelativePath = $RequestPath.TrimStart("/") -replace "/", [System.IO.Path]::DirectorySeparatorChar
    $FilePath = Join-Path $Root $RelativePath

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
      $Body = [System.Text.Encoding]::UTF8.GetBytes("Not found")
      $Header = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`n`r`n")
      $Stream.Write($Header, 0, $Header.Length)
      $Stream.Write($Body, 0, $Body.Length)
      $Client.Close()
      continue
    }

    $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $ContentType = Get-ContentType $FilePath
    $Header = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $ContentType`r`nContent-Length: $($Bytes.Length)`r`nConnection: close`r`n`r`n")
    $Stream.Write($Header, 0, $Header.Length)
    $Stream.Write($Bytes, 0, $Bytes.Length)
    $Client.Close()
  }
}
finally {
  $Listener.Stop()
}
