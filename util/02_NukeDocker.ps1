$processNames = @("Docker Desktop", "Docker", "com.docker.backend", "com.docker.service", "vmmem", "wslhost")

foreach ($name in $processNames) {
    taskkill /F /IM "$name.exe" /T 2>$null
}
