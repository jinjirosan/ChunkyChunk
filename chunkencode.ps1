# ChunkyChunk Encoder
#
# jinjirosan (2023)
# chunkencode.ps1

# Ask for the input file path
$inputFilePath = Read-Host -Prompt "Enter the path to the input file (or just the filename to use the current directory)"
if (-not [System.IO.Path]::IsPathRooted($inputFilePath)) {
    $inputFilePath = Resolve-Path $inputFilePath
}

$inputFileDirectory = Split-Path -Parent $inputFilePath
$inputFileName = [System.IO.Path]::GetFileName($inputFilePath)

# Get the current time in HHMM format
$currentTime = Get-Date -Format "HHmm"

# Generate a base file name using the first 5 letters of the input file name and the current time
$baseFileName = if ($inputFileName.Length -le 5) { $inputFileName } else { $inputFileName.Substring(0, 5) }
$baseFileName += $currentTime

Write-Host "Calculating checksum for the input file..."
$checksum = Get-FileHash -Path $inputFilePath -Algorithm SHA256
$checksumString = $checksum.Hash

# Save the checksum and file name to a separate text file with the base file name
$checksumFilePath = [System.IO.Path]::Combine($inputFileDirectory, "${baseFileName}_checksum.txt")
$checksumInfo = "Filename: $inputFileName`r`nChecksum (SHA256): $checksumString"
[System.IO.File]::WriteAllText($checksumFilePath, $checksumInfo)
Write-Host "Checksum and filename saved to: $checksumFilePath"

Write-Host "Preparing to split the file into chunks..."
# Function to split the file into chunks and process them
function Split-File {
    param (
        [string]$File
    )
    $fileStream = [System.IO.File]::OpenRead($File)
    $reader = New-Object System.IO.BinaryReader($fileStream)
    $counter = 1
    while ($fileStream.Position -lt $fileStream.Length) {
        # Randomize chunk size between 3MB and 6MB
        $chunkSize = Get-Random -Minimum 3MB -Maximum 6MB
        $buffer = New-Object byte[] $chunkSize
        $bytesRead = $reader.Read($buffer, 0, $chunkSize)
        $outputPath = Join-Path $inputFileDirectory ("${baseFileName}_chunk" + $counter.ToString("000") + ".bin")
        [System.IO.File]::WriteAllBytes($outputPath, $buffer[0..($bytesRead-1)])
        Write-Host "Created chunk: $outputPath"
        $counter++
    }
    $reader.Close()
    $fileStream.Close()
}

# Split the file into chunks
Split-File -File $inputFilePath

# Process each chunk file
Get-ChildItem $inputFileDirectory -Filter "${baseFileName}_chunk*.bin" | ForEach-Object {
    $chunkContent = [System.IO.File]::ReadAllBytes($_.FullName)
    $encodedContent = [System.Convert]::ToBase64String($chunkContent)
    Write-Host "Base64 encoded chunk: $($_.Name)"

    # Compress the encoded content
    $compressedFile = $_.FullName.Replace(".bin", ".gzip")
    $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($encodedContent)
    $compressedFileStream = [System.IO.File]::Create($compressedFile)
    $compressionStream = New-Object System.IO.Compression.GZipStream $compressedFileStream, ([System.IO.Compression.CompressionMode]::Compress)
    $compressionStream.Write($encodedBytes, 0, $encodedBytes.Length)
    $compressionStream.Close()
    $compressedFileStream.Close()
    Write-Host "Compressed Base64 encoded chunk: $compressedFile"

    # Additional Base64 encoding
    $doubleEncodedContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($compressedFile))
    $finalOutputPath = $_.FullName.Replace(".bin", ".txt")
    [System.IO.File]::WriteAllText($finalOutputPath, $doubleEncodedContent)
    Write-Host "Double Base64 encoded and compressed chunk saved as: $finalOutputPath"

    # Optionally, delete the original chunk file and compressed file
    Remove-Item $_.FullName
    Remove-Item $compressedFile
}

Write-Host "All chunks processed and saved to $inputFileDirectory"
