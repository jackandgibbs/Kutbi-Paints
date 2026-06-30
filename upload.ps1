$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1senJxZ29jdmVucndqbmFibGptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NTg5NjEsImV4cCI6MjA4OTEzNDk2MX0.kcO8daZS3KM6keSZX-PlaShP_JRxJ2U0eUS5Nmn6AWA"
$url = "https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/paint-images/brands/"

$files = @('opus.png', 'ap.png', 'opus_big.png', 'ap_big.png')

foreach ($f in $files) {
    if (Test-Path $f) {
        $headers = @{
            "apikey" = $key
            "Authorization" = "Bearer $key"
            "Content-Type" = "image/png"
        }
        $endpoint = "$url$f"
        try {
            Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -InFile $f -ErrorAction Stop
            Write-Host "Uploaded $f"
        } catch {
            try {
                Invoke-RestMethod -Uri $endpoint -Method Put -Headers $headers -InFile $f
                Write-Host "Re-uploaded (Put) $f"
            } catch {
                Write-Host "Failed $f $_"
            }
        }
    } else {
        Write-Host "File $f not found"
    }
}