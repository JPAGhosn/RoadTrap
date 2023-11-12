firebase emulators:start --only auth --import saved --export-on-exit saved

ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' 

python3 -m venv venv
python app.py

node index.js

docker-compose up -d
