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
# Modified evasion techniques
function Split-File {
    param ([string]$File)
    $fileStream = [System.IO.File]::OpenRead($File)
    $reader = New-Object System.IO.BinaryReader($fileStream)
    $counter = 1
    $rnd = New-Object System.Random
    
    while ($fileStream.Position -lt $fileStream.Length) {
        # More random chunk sizes with non-uniform distribution
        $chunkSize = switch ($rnd.Next(0, 100)) {
            {$_ -le 10} { $rnd.Next(1KB, 3MB) }  # 10% small chunks
            {$_ -le 90} { $rnd.Next(3MB, 6MB) }  # 80% normal range
            default     { $rnd.Next(6MB, 10MB) } # 10% large chunks
        }
        
        # Dynamic file extensions
        $extensions = @('.log', '.tmp', '.dat', '.cache')
        $fakeExt = $extensions[$rnd.Next(0, $extensions.Length)]
        
        $buffer = New-Object byte[] $chunkSize
        $bytesRead = $reader.Read($buffer, 0, $chunkSize)
        
        # Obfuscated chunk naming
        $outputPath = Join-Path $inputFileDirectory (
            "${baseFileName}_" + 
            (Get-Random -Count 8 -InputObject ('a'..'z' + '0'..'9') | ForEach-Object { [char]$_ }) -join '') +
            "{0:D5}$fakeExt" -f $counter
        )
        
        [System.IO.File]::WriteAllBytes($outputPath, $buffer[0..($bytesRead-1)])
        $counter++
    }
    $reader.Close()
    $fileStream.Close()
}

# Split the file into chunks
Split-File -File $inputFilePath

# Enhanced encoding process
Get-ChildItem $inputFileDirectory -Filter "${baseFileName}_*.???" | ForEach-Object {
    # Add random file metadata
    $_.CreationTime = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30))
    $_.LastWriteTime = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 30))
    $_.Attributes = [System.IO.FileAttributes]::Hidden

    # Multi-stage encoding with random padding
    $chunkContent = [System.IO.File]::ReadAllBytes($_.FullName)
    $encodedContent = [System.Convert]::ToBase64String($chunkContent)
    
    # Add random comments in Base64 data
    $encodedContent = $encodedContent.Insert(
        (Get-Random -Maximum $encodedContent.Length),
        "# RandomComment" + (Get-Random -Minimum 1000 -Maximum 9999)
    )
    
    # Alternative compression with random header
    $compressedFile = $_.FullName -replace '\.[^.]*$','.gzip'
    $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($encodedContent)
    
    # Add random header bytes
    $header = New-Object byte[] 4
    (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($header)
    $encodedBytes = $header + $encodedBytes
    
    # Compress with random compression level
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal,
                       [System.IO.Compression.CompressionLevel]::Fastest,
                       [System.IO.Compression.CompressionLevel]::NoCompression | Get-Random
    
    $compressedFileStream = [System.IO.File]::Create($compressedFile)
    $compressionStream = New-Object System.IO.Compression.GZipStream $compressedFileStream, $compressionLevel
    $compressionStream.Write($encodedBytes, 0, $encodedBytes.Length)
    $compressionStream.Close()
    $compressedFileStream.Close()

    # Final encoding with mixed formats
    $finalBytes = [System.IO.File]::ReadAllBytes($compressedFile)
    $finalOutput = [System.Convert]::ToBase64String($finalBytes)
    
    # Create hybrid file with partial hex representation
    $hybridContent = ($finalOutput[0..500] -join '') + "|" + 
                    (($finalBytes | Select-Object -First 100 | ForEach-Object { $_.ToString('X2') }) -join '') + "|" +
                    ($finalOutput[500..$finalOutput.Length] -join '')
    
    $finalOutputPath = $_.FullName -replace '\.[^.]*$','.txt'
    [System.IO.File]::WriteAllText($finalOutputPath, $hybridContent)
    
    # Cleanup
    Remove-Item $_.FullName
    Remove-Item $compressedFile
}

Write-Host "All chunks processed and saved to $inputFileDirectory"
