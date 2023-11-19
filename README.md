

firebase emulators:start --only auth --import saved --export-on-exit saved

cd ./backend/decision_handler
python3 -m venv venv
python app.py

cd ./backend/mqtt_handler
node index.js

docker-compose up -d
ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' 