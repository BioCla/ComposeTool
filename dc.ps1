# Get project name
$PROJECT_NAME = (Get-Item -Path $PSScriptRoot).BaseName.ToLower()

Write-Host "OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor DarkCyan
Write-Host "ARCHITECTURE: $([System.Environment]::Is64BitOperatingSystem)" -ForegroundColor DarkCyan
Write-Host "PROJECT_NAME: $PROJECT_NAME" -ForegroundColor DarkCyan
Write-Host "PROJECT_PATH: $PSScriptRoot" -ForegroundColor DarkCyan

function Ask {
    param (
        [string]$prompt,
        [string]$default
    )

    while ($true) {
        $choice = Read-Host "$prompt [$default]"
        if (-not $choice) {
            $choice = $default
        }

        switch ($choice.ToLower()) {
            {"Y*", "y*"} { return $true }
            {"N*", "n*"} { return $false }
        }
    }
}

# Check if Docker is installed
if (-not (Test-Path (Get-Command -Name docker -ErrorAction SilentlyContinue))) {
    Write-Host "Docker is not installed." -ForegroundColor Red
    $installChoice = Ask "Would you like to install it? (Y/n)" "Y"
    if ($installChoice) {
        $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isElevated) {
            Write-Host "Please run this script as administrator." -ForegroundColor Red
            exit 1
        }
        
        if (-not (Test-Path (Get-Command -Name wsl -ErrorAction SilentlyContinue))) {
            Write-Host "WSL 2 is not installed." -ForegroundColor Red
            exit 1
        }

        $hypervEnabled = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Where-Object { $_.State -eq "Enabled" }
        $containersEnabled = Get-WindowsOptionalFeature -Online -FeatureName Containers | Where-Object { $_.State -eq "Enabled" }
        if (-not $hypervEnabled) {
            Write-Host "Hyper-V is not enabled." -ForegroundColor Red
            exit 1
        }
        if (-not $containersEnabled) {
            Write-Host "Windows Containers feature is not installed." -ForegroundColor Red
            exit 1
        }
        
        # Download Docker Desktop Installer From the Command Line
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile "$PSScriptRoot\Docker Desktop Installer.exe"
        Start-Process -FilePath "$PSScriptRoot\Docker Desktop Installer.exe" -ArgumentList "/S" -Wait install
        # Add the current user to the docker-users group
        net localgroup docker-users $env:USERNAME /add
        Remove-Item -Path "$PSScriptRoot\Docker Desktop Installer.exe"

        Write-Host "Docker (and docker-compose) have been installed." -ForegroundColor Yellow
        Write-Host "Please open the application and follow the instructions." -ForegroundColor Yellow
    }
    else {
        exit 1
    }
}

if (-not (Test-Path "$PSScriptRoot\docker")) {
    Write-Host "No docker directory found." -ForegroundColor Red
    $createDirectoryChoice = Ask "Would you like to create a new docker directory and a docker-compose.yml file? (Y/n)" "Y"
    if ($createDirectoryChoice) {
        New-Item -ItemType Directory -Path "$PSScriptRoot\docker" | Out-Null
        New-Item -ItemType File -Path "$PSScriptRoot\docker\docker-compose.yml" | Out-Null
        Write-Host "Please edit the docker-compose.yml file to your needs." -ForegroundColor Yellow
        exit 0
    }
    else {
        exit 1
    }
}
elseif (-not (Test-Path "$PSScriptRoot\docker\docker-compose.yml")) {
    Write-Host "No docker-compose.yml file found." -ForegroundColor Red
    $createFileChoice = Ask "Would you like to create a new one? (Y/n)" "Y"
    if ($createFileChoice) {
        New-Item -ItemType File -Path "$PSScriptRoot\docker\docker-compose.yml" | Out-Null
        Write-Host "Please edit the docker-compose.yml file to your needs." -ForegroundColor Yellow
        exit 0
    }
    else {
        exit 1
    }
}

$COMPOSE_OVERRIDE = if (Test-Path "$PSScriptRoot\docker\docker-compose.override.yml") {
    "--file $PSScriptRoot\docker\docker-compose.override.yml"
} else {
    ""
}
$DOCKER = "docker compose --file $PSScriptRoot\docker\docker-compose.yml $COMPOSE_OVERRIDE -p $PROJECT_NAME"

if ($args[0] -eq "up") {
    & $DOCKER up -d --force-recreate --remove-orphans
}
elseif ($args[0] -eq "enter") {
    $containers = & $DOCKER ps --format table | Where-Object { $_ -notmatch "NAME" } | ForEach-Object { $_.Split(" ")[0] }

    if ($args[1] -eq "help") {
        Write-Host "Usage:"
        Write-Host "`t$($MyInvocation.InvocationName) enter <container> [fs]"
        Write-Host "Options:"
        Write-Host "`tfs`tEnter the container's filesystem"
        Write-Host "Examples:"
        Write-Host "`t$($MyInvocation.InvocationName) enter php"
        Write-Host "`t$($MyInvocation.InvocationName) enter php fs"
        exit 3
    }
    elseif (-not $containers) {
        Write-Host "No containers found, make sure the project is running." -ForegroundColor Red
        exit 126
    }
    elseif ($args[1]) {
        $container = $containers -contains $args[1]
        if ($container) {
            Write-Host "Entering container: $args[1]" -ForegroundColor DarkYellow

            if ($args[2] -eq "fs") {
                docker exec -it $container /bin/bash
                exit 130
            }
            elseif ($args[2]) {
                Write-Host "Invalid option: $args[2]" -ForegroundColor Red
                exit 2
            }
            else {
                Write-Host "Press CTRL+P then CTRL+Q to detach from the container." -ForegroundColor DarkYellow
                docker attach $container
                exit 130
            }
        }
        else {
            Write-Host "Container not found: $args[1]" -ForegroundColor Red
            exit 2
        }
    }
    else {
        Write-Host "Please specify the container name:" -ForegroundColor DarkYellow
        Write-Host "`n`tAvailable containers:"
        Write-Host "$containers"
        exit 2
    }
}
elseif ($args[0] -eq "rebuild") {
    & $DOCKER down
    & $DOCKER build
    & $DOCKER up -d --force-recreate --remove-orphans
}
elseif ($args[0] -eq "down") {
    & $DOCKER down
}
elseif ($args[0] -eq "purge") {
    & $DOCKER down
    docker system prune -a
    docker rmi "$(docker images -a -q)"
    docker rm "$(docker ps -a -f status=exited -q)"
    docker volume prune
}
elseif ($args[0] -eq "log") {
    & $DOCKER logs -f --tail="100"
}
elseif ($args[0] -eq "help") {
    Write-Host "Usage:" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) <command>" -ForegroundColor DarkYellow
    Write-Host "Commands:" -ForegroundColor DarkYellow
    Write-Host "`tup`tStart the project"
    Write-Host "`tdown`tStop the project"
    Write-Host "`tenter`tEnter a container"
    Write-Host "`tlog`tView the logs"
    Write-Host "`trebuild`tRebuild the project"
    Write-Host "`tpurge`tPurge the project"
    Write-Host "`thelp`tView this help"
    Write-Host "Examples:" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) up" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) enter php" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) enter php fs" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) log" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) rebuild" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) purge" -ForegroundColor DarkYellow
    Write-Host "`t$($MyInvocation.InvocationName) help" -ForegroundColor DarkYellow
    exit 0
}
