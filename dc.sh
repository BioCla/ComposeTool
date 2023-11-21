#!/usr/bin/env bash

PROJECT_NAME=$(basename $(pwd) | tr  '[:upper:]' '[:lower:]')
COMPOSE_VERSION="3.8"

echo -e "\
OS: \033[38;5;51m$(uname)\033[0m\n\
ARCHITECURE: \033[38;5;51m$(uname -m)\033[0m\n\
PROJECT_NAME: \033[38;5;51m${PROJECT_NAME}\033[0m\n\
PROJECT_PATH: \033[38;5;51m$(pwd)\033[0m\n"

ask() {
    local prompt default reply

    while true; do

        if [[ "${2:-}" = "Y" ]]; then
            prompt="Y/n"
            default=Y
        elif [[ "${2:-}" = "N" ]]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        read -p "$1 [$prompt] " reply </dev/tty

        if [[ -z "$reply" ]]; then
            reply=${default}
        fi

        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

# Check if docker is installed
if ! [ -x "$(command -v docker)" ]; then
    echo -e "\033[91mDocker is not installed.\033[0m"
    echo -e "\033[93mWould you like to install it?\033[0m"
    if ask "This will install docker and docker-compose"; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "\033[91mThis script must be run as root to install docker.\033[0m"
            exit 1
        fi

        if [[ "$(uname)" == "Darwin" ]]; then
            if [[ "$(uname -m)" == "arm64" ]]; then # Apple Silicon
                # Requires Rosetta 2
                softwareupdate --install-rosetta --agree-to-license
                echo -e "\033[93mInstalling Docker, this may take some time...\033[0m"
                curl -fsSL https://desktop.docker.com/mac/main/arm64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-arm64 > Docker.dmg
            else # Intel or whatever
                echo -e "\033[93mInstalling Docker, this may take some time...\033[0m"
                curl -fsSL https://desktop.docker.com/mac/main/amd64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-amd64 > Docker.dmg
            fi
            sudo hdiutil attach Docker.dmg
            sudo /Volumes/Docker/Docker.app/Contents/MacOS/install
            sudo hdiutil detach /Volumes/Docker
            rm Docker.dmg
            echo -e "\033[93mDocker (and docker-compose) have been installed in the Applications folder.\033[0m" 
        elif [[ "$(uname)" == "Linux" ]]; then
            echo -e "\033[93mSetting up the docker APT repository\033[0m"
            # Add Docker's official GPG key:
            sudo apt-get update
            sudo apt-get install ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            # Add the repository to Apt sources:
            echo \
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            echo -e "\033[93mDocker (and docker-compose) have been installed.\033[0m"
        else
            echo -e "\033[91mSorry, your OS is not supported.\033[0m"
            exit 1
        fi
    else
        exit 1
    fi
fi

if [ ! -d "./docker" ]; then
    echo -e "\033[91mNo docker directory found.\033[0m"
    if ask "Would you like to create a new docker directory and a docker-compose.yml file"; then
        mkdir docker && touch docker/docker-compose.yml
        echo -e "\033[93mPlease edit the docker-compose.yml file to your needs or use the generate command to start from a template.\033[0m"
        exit 0
    else
        exit 1
    fi
elif [ ! -f "docker/docker-compose.yml" ]; then
    echo -e "\033[91mNo docker-compose.yml file found.\033[0m"
    if ask "Would you like to create a new one?"; then
        touch docker/docker-compose.yml
        echo -e "\033[93mPlease edit the docker-compose.yml file to your needs or use the generate command to start from a template.\033[0m"
        exit 0
    else
        exit 1
    fi
fi

COMPOSE_OVERRIDE=
if [[ -f "docker/docker-compose.override.yml" ]]; then
    COMPOSE_OVERRIDE="--file docker/docker-compose.override.yml"
fi
DOCKER="docker compose \
        --file docker/docker-compose.yml \
        ${COMPOSE_OVERRIDE} \
        -p ${PROJECT_NAME}"
        
if [[ "$1" = "up" ]]; then

    ${DOCKER} up -d --force-recreate --remove-orphans

elif [[ "$1" = "enter" ]]; then
    shift

    COMPOSE_CONTAINERS=$(${DOCKER} \
    ps \
    --format table | grep -v "NAME" | awk '{print $1}' )
    
    if [[ "$1" = "help" ]]; then
        echo -e "\033[93;4mUsage:\033[0m"
        echo -e "\t\033[3m$0 enter <container> [fs]\033[23m"
        echo -e "\033[93;4mOptions:\033[0m"
        echo -e "\t\033[3mfs\033[23m\tEnter the container's filesystem"
        echo -e "\033[93;4mExamples:\033[0m"
        echo -e "\t\033[3m$0 enter php\033[23m"
        echo -e "\t\033[3m$0 enter php fs\033[23m"
        exit 3
    elif [[ ${COMPOSE_CONTAINERS} == "" ]]; then
        echo -e "\033[91mNo containers found, make sure the project is running.\033[0m"
        exit 126
    elif [[ "$1" != "" ]]; then
        CONTAINER=$(docker ps | grep $1 | awk '{print $1}') 
        echo -e "\033[93;4mEntering container:\033[0m \033[3m$1\033[23m\n"
        
        if [[ "$2" != "" && "$2" = "fs" ]]; then
            docker exec -it "${CONTAINER}" /bin/bash
            exit 130
        elif [[ "$2" != "" ]]; then
            echo -e "\033[91mInvalid option: $2\033[0m"
            exit 2
        else
            echo -e "\033[93;4mPress CTRL+P then CTRL+Q to detach from the container.\033[0m\n"
            docker attach ${CONTAINER}
            exit 130
        fi
    else 
        echo -e "\033[93;4mPlease specify the container name:\033[0m"
        echo -e "\n\t\033[4mAvailable containers:\033[24m"
        echo -e "\033[3m${COMPOSE_CONTAINERS}\033[23m\n"
        exit 2
    fi

elif [[ "$1" = "rebuild" ]]; then

    ${DOCKER} down
    ${DOCKER} build
    ${DOCKER} up -d --force-recreate --remove-orphans

elif [[ "$1" = "down" ]]; then

   ${DOCKER} down

elif [[ "$1" = "purge" ]]; then

    ${DOCKER} down
    docker system prune -a
    docker rmi "$(docker images -a -q)"
    docker rm "$(docker ps -a -f status=exited -q)"
    docker volume prune

elif [[ "$1" = "log" ]]; then

    ${DOCKER} logs -f --tail="100"

elif [[ "$1" = "generate" ]]; then
    shift

    TEMPLATES_DIR=$(ls -d ./templates/*/ | sed 's/\.\/templates\///g' | sed 's/\///g')

    if [[ "$1" = "help" ]]; then
        echo -e "\033[93;4mDescription:\033[0m"
        echo -e "\tGenerates a project using a template folder from the templates directory."
        echo -e "\033[93;4mUsage:\033[0m"
        echo -e "\t\033[3m$0 generate <template>\033[23m"
        echo -e "\033[93;4mTemplates:\033[0m"
        echo -e "\033[3m${TEMPLATES_DIR}\033[23m\n"

        exit 3
    elif [[ "$1" != "" ]]; then

        if [ ! -d "./templates/$1" ]; then
            echo -e "\033[91mTemplate not found.\033[0m"
            echo -e "\n\t\033[4mAvailable templates:\033[24m"
            echo -e "\033[3m${TEMPLATES_DIR}\033[23m\n"
            exit 2
        elif [ ! -f "./templates/$1/docker-compose.yml" ]; then
            echo -e "\033[91mTemplate's docker-compose.yml file missing!\033[0m"
            exit 1
        elif [ ! -f "./templates/$1/starter.sh" ]; then
            echo -e "\033[91mTemplate's starter.sh file missing.\033[0m"
            exit 1
        fi

        # Find at which line each 0th level section starts
        VERSION_LINE=$(sed -n '/^version:/=' ./docker/docker-compose.yml)
        SERVICES_LINE=$(sed -n '/^services:/=' ./docker/docker-compose.yml)
        VOLUMES_LINE=$(sed -n '/^volumes:/=' ./docker/docker-compose.yml)
        NETWORKS_LINE=$(sed -n '/^networks:/=' ./docker/docker-compose.yml)

        # if the file is empty we add a new line to give the upcoming sed commands a line to work with
        if [ ! -s "./docker/docker-compose.yml" ]; then
            echo "" >> ./docker/docker-compose.yml
        fi

        if [ -z "$VERSION_LINE" ]; then
            sed -i '' "1i\\
version: \"${COMPOSE_VERSION}\"" ./docker/docker-compose.yml
            VERSION_LINE=$(sed -n '/^version:/=' ./docker/docker-compose.yml)
        fi

        if [ -z "$SERVICES_LINE" ]; then
            sed -i '' "${VERSION_LINE}a\\
services:" ./docker/docker-compose.yml
        fi
        
        if [ -f "./docker/docker-compose.yml" ] && [ -s "./docker/docker-compose.yml" ]; then
            echo -e "\033[93mA docker-compose.yml file already exists and is correctly initialized.\033[0m"
            if ask "Would you like to add the service to it?"; then

                TEMPLATE_SERVICES_LINE=$(sed -n '/^services:/=' ./templates/$1/docker-compose.yml)
                TEMPLATE_VOLUMES_LINE=$(sed -n '/^volumes:/=' ./templates/$1/docker-compose.yml)
                TEMPLATE_NETWORKS_LINE=$(sed -n '/^networks:/=' ./templates/$1/docker-compose.yml)

                if [ -z "$TEMPLATE_SERVICES_LINE" ]; then
                    echo -e "\033[91mTemplate's docker-compose.yml file is missing the services section.\033[0m"
                    exit 1
                else
                    # Replace the first line of the TEMPLATE_SERVICES with a new line
                    TEMPLATE_SERVICES=$(sed -n "${TEMPLATE_SERVICES_LINE},/^[^ ]/p" ./templates/$1/docker-compose.yml | sed '$d' | sed 's/^services:/\n/g')
                    SERVICES_LINE=$(sed -n '/^services:/=' ./docker/docker-compose.yml)
                    # Starting from SERVICES_LINE append the TEMPLATE_SERVICES to it, replacing all the \n with § and then replacing all the § with \n
                    sed -i '' "${SERVICES_LINE}a\\
${TEMPLATE_SERVICES//$'\n'/§}" ./docker/docker-compose.yml
                    sed -i '' "s/§/\\
/g" ./docker/docker-compose.yml
                fi

                if [ ! -z "$TEMPLATE_VOLUMES_LINE" ]; then
                    if [ -z "$VOLUMES_LINE" ]; then
                        echo -e "\n\nvolumes:" >> ./docker/docker-compose.yml
                    fi
                    VOLUMES_LINE=$(sed -n '/^volumes:/=' ./docker/docker-compose.yml)
                    TEMPLATE_VOLUMES=$(sed -n "${TEMPLATE_VOLUMES_LINE},/^[^ ]/p" ./templates/$1/docker-compose.yml | sed '$d' | sed 's/^volumes:/\n/g')
                    sed -i '' "${VOLUMES_LINE}a\\
${TEMPLATE_VOLUMES//$'\n'/§}" ./docker/docker-compose.yml
                    sed -i '' "s/§/\\
/g" ./docker/docker-compose.yml
                fi

                if [ ! -z "$TEMPLATE_NETWORKS_LINE" ]; then
                    if [ -z "$NETWORKS_LINE" ]; then
                        echo -e "\n\nnetworks:" >> ./docker/docker-compose.yml
                    fi
                    NETWORKS_LINE=$(sed -n '/^networks:/=' ./docker/docker-compose.yml)
                    TEMPLATE_NETWORKS=$(sed -n "${TEMPLATE_NETWORKS_LINE},/^[^ ]/p" ./templates/$1/docker-compose.yml | sed '$d' | sed 's/^networks:/\n/g')
                    sed -i '' "${NETWORKS_LINE}a\\
${TEMPLATE_NETWORKS//$'\n'/§}" ./docker/docker-compose.yml
                    sed -i '' "s/§/\\
/g" ./docker/docker-compose.yml
                fi

            else
                echo -e "\033[93mPlease edit the docker-compose.yml file to your needs or use the generate command to start from a template.\033[0m"
                exit 130
            fi
        fi

        chmod +x ./templates/$1/starter.sh
        # ./templates/$1/starter.sh

        exit 130

    else 
        echo -e "\033[93;4mPlease specify a template!\033[0m"
        echo -e "\n\t\033[4mAvailable templates:\033[24m"
        echo -e "\033[3m${TEMPLATES}\033[23m\n"
        exit 2
    fi

else

    echo -e "\033[93;4mUsage:\033[0m"
    echo -e "\t\033[3m$0 <command>\033[23m"
    echo -e "\033[93;4mCommands:\033[0m"
    echo -e "  up    \tStart the project"
    echo -e "  down    \tStop the project"
    echo -e "  enter    \tEnter a container"
    echo -e "  log    \tView the logs"
    echo -e "  rebuild    \tRebuild the project"
    echo -e "  purge    \tPurge the project"
    echo -e "  generate    \tGenerate the project using a template"
    echo -e "  help    \tView this help"
    echo -e "\033[93;4mExamples:\033[0m"
    echo -e "  \033[3m$0 up\033[23m"
    echo -e "  \033[3m$0 enter php\033[23m"
    echo -e "  \033[3m$0 enter php fs\033[23m"
    echo -e "  \033[3m$0 log\033[23m"
    echo -e "  \033[3m$0 rebuild\033[23m"
    echo -e "  \033[3m$0 purge\033[23m"
    echo -e "  \033[3m$0 help\033[23m"

fi