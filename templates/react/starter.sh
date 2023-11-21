#!/usr/bin/env bash

if ! command -v yarn &> /dev/null
then
    echo "yarn could not be found"
    exit
fi

if ! command -v npx &> /dev/null
then
    echo "npx could not be found"
    exit
fi

if [ -d "react-frontend" ]; then
    echo "react-frontend directory already exists"
    exit
fi

mkdir -p react-frontend
cd react-frontend
npx create-react-app .

sed -i '' 's/"scripts": {/"scripts": {\n    "docker-start": "npm ci \&\& react-scripts start",/g' package.json
