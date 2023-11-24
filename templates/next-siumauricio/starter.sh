# Requires npm and next

if ! command -v git &> /dev/null
then
    echo "git could not be found"
    exit
fi

if ! command -v npm &> /dev/null
then
    echo "npm could not be found"
    exit
fi

if [ -d "nextui-dashboard-template" ]; then
    echo "nextui-dashboard-template directory already exists"
    exit
fi

git clone https://github.com/Siumauricio/nextui-dashboard-template.git
cd nextui-dashboard-template

sed -i '' 's/"scripts": {/"scripts": {\n    "docker-start": "npm ci \&\& next dev -- -p 3002",/g' package.json
