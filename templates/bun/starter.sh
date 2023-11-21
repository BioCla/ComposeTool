if ! command -v bun &> /dev/null
then
    echo "bun could not be found"
    echo "Run 'curl -fsSL https://bun.sh/install | bash' to install Bun"
    exit
fi

if [ -d "bun-backend" ]; then
    echo "bun-backend directory already exists"
    exit
fi

mkdir -p bun-backend
cd bun-backend
bun init

cat << EOF > index.ts
const server = Bun.serve({
  port: 3001,
  fetch(req) {
    return new Response("Bun!");
  },
});

console.log(\`Listening on http://localhost:\${server.port}\`);
EOF

sed -i '' 's/"devDependencies": {/"scripts": {},\n    "devDependencies": {/g' package.json
sed -i '' 's/"scripts": {/"scripts": {\n    "docker-start": "bun --hot run index.ts"\n  /g' package.json
