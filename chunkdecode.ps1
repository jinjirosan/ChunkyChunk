# ChunkyChunk Decoder
#
# jinjirosan (2023)
# chunkdecode.ps1

# Ask for the base file characters (first 5 characters of the original file plus the time in HHMM format)
$baseFileChars = Read-Host -Prompt "Enter the base file characters (first 5 characters of the original file plus the time in HHMM format)"

# Get the current directory
$currentDirectory = Get-Location

# Find the checksum file based on the base file characters
$checksumFilePattern = "${baseFileChars}_checksum.txt"
$checksumFiles = Get-ChildItem -Path $currentDirectory -Filter $checksumFilePattern

if ($checksumFiles.Count -eq 0) {
    Write-Host "Checksum file not found in the current directory."
    return
}

$checksumFile = $checksumFiles[0]
Write-Host "Using checksum file: $($checksumFile.FullName)"

# Read the checksum and filename from the separate checksum file
$checksumContent = Get-Content $checksumFile.FullName -ErrorAction Stop
$originalFileName = ($checksumContent | Where-Object { $_ -match "^Filename:" }) -split ":" | Select-Object -Last 1 | ForEach-Object { $_.Trim() }
$originalChecksum = ($checksumContent | Where-Object { $_ -match "^Checksum \(SHA256\):" }) -split ":" | Select-Object -Last 1 | ForEach-Object { $_.Trim() }

Write-Host "Original filename: $originalFileName"
Write-Host "Original checksum: $originalChecksum"

# Define the directory for the output
$outputDirectory = Join-Path $currentDirectory $baseFileChars
if (-not (Test-Path $outputDirectory)) {
    $null = New-Item -ItemType Directory -Path $outputDirectory
}

# Find all the chunk files based on the base file characters
$chunkFiles = Get-ChildItem -Path $currentDirectory -File | 
    Where-Object { $_.Name -match "^${baseFileChars}_[a-z0-9]{8}\d{5}\..+" } |
    Sort-Object { [regex]::Match($_.Name, '\d{5}').Value }

if ($chunkFiles.Count -eq 0) {
    Write-Host "No chunk files found in the current directory."
    return
}

# Reconstruct the original file from the chunks
$outputFilePath = Join-Path $outputDirectory $originalFileName
Write-Host "Reconstructing to $outputFilePath"

$outputFileStream = [System.IO.FileStream]::new($outputFilePath, [System.IO.FileMode]::Create)
foreach ($chunkFile in $chunkFiles) {
    Write-Host "Processing chunk: $($chunkFile.Name)"
    $hybridContent = Get-Content $chunkFile.FullName -Raw
    
    # Parse hybrid format
    $parts = $hybridContent -split '\|'
    $mainBase64 = $parts[0] + $parts[2]
    $hexSection = $parts[1] -replace '[^0-9A-F]', ''
    
    # Reconstruct full Base64
    $hexBytes = for ($i=0; $i -lt $hexSection.Length; $i+=2) {
        [Convert]::ToByte($hexSection.Substring($i,2), 16)
    }
    $reconstructedBase64 = $mainBase64 + [Convert]::ToBase64String($hexBytes)
    
    # Process the compressed data
    $gzippedData = [Convert]::FromBase64String($reconstructedBase64)
    $gzippedStream = New-Object System.IO.MemoryStream(,$gzippedData)
    
    # Handle random compression levels
    $gzipReader = New-Object System.IO.Compression.GZipStream(
        $gzippedStream, 
        [System.IO.Compression.CompressionMode]::Decompress
    )
    
    # Read and remove random header
    $reader = New-Object System.IO.StreamReader($gzipReader)
    $decompressedBase64String = $reader.ReadToEnd()
    $decompressedBytes = [Text.Encoding]::UTF8.GetBytes($decompressedBase64String)
    $cleanBytes = $decompressedBytes[4..($decompressedBytes.Length-1)]
    
    # Remove random comments from Base64
    $cleanBase64 = ($cleanBytes -as [string]) -replace '#.*?\n', ''
    
    # Final decoding
    $chunkBytes = [Convert]::FromBase64String($cleanBase64)
    $outputFileStream.Write($chunkBytes, 0, $chunkBytes.Length)
    
    $reader.Close()
    $gzipReader.Close()
    $gzippedStream.Close()
}
$outputFileStream.Close()

# Calculate the checksum of the reconstructed file and compare
Write-Host "Calculating checksum for the reconstructed file..."
$reconstructedChecksum = Get-FileHash -Path $outputFilePath -Algorithm SHA256

if ($reconstructedChecksum.Hash -eq $originalChecksum) {
    Write-Host "Checksum OK - The file has been reconstructed successfully and is identical to the original."
} else {
    Write-Host "Checksum NOK - The reconstructed file does not match the original file. Expected: $originalChecksum, Got: $($reconstructedChecksum.Hash)"
}

Write-Host "Reconstruction complete. The file has been saved to: $outputFilePath"
