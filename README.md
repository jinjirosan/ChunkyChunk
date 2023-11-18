# ChunkyChunk
Powershell encode-decode to exfiltrate files through DLP over mail.

## PowerShell File Encode and Decode Scripts

This repository contains two PowerShell scripts for encoding and decoding files. The encode script splits a file into multiple chunks of random sizes between 3 and 6 Mb, performs double Base64 encoding and gzip compression on each chunk, and saves them with a unique naming scheme. The decode script reverses this process, reconstructing the original file from the chunks.

## Scripts

chunkencode.ps1: Splits a file into chunks, double encodes and compresses each chunk.

chunkdecode.ps1: Reassembles the original file from the chunks, decoding and decompressing them.

## Usage

### Encoding a File
- Run chunkencode.ps1.
- Enter the full path of the file you want to encode. If the file is in the current directory, you can enter just the filename.

The script will place the encoded chunks and a checksum file for verification in the current directory.

![encoding](https://github.com/jinjirosan/ChunkyChunk/blob/main/_images/chunkencode.png)

### Decoding a File
- Run chunkdecode.ps1.
- Enter the base file characters (the first 5 characters of the original file name plus the time in HHMM format when the file was encoded).

The script will search for the chunks and the checksum file in the current directory, reassemble the original file, and verify its integrity.

![decoding](https://github.com/jinjirosan/ChunkyChunk/blob/main/_images/chunkdecode.png)

## Script Details

### chunkencode.ps1
Splits the input file into random-sized chunks between 3MB and 6MB.
Each chunk undergoes Base64 encoding, gzip compression, and then another round of Base64 encoding.
Generates a unique base filename using the first 5 characters of the file's name followed by the current time in HHMM format.
Saves a checksum file and encoded chunks in the same directory.

### chunkdecode.ps1
Requires the unique base filename to find the encoded chunks and the checksum file.
Decodes and decompresses each chunk, reversing the process done by the encode script.
Reassembles the chunks back into the original file.
Verifies the integrity of the reconstructed file using the checksum.

## Requirements

PowerShell 5.1 or higher.
Sufficient disk space for storing encoded chunks and the reconstructed file.

## Notes

The scripts are designed to handle large files by breaking them down into manageable chunks without using a discernible pattern (different sizes).
