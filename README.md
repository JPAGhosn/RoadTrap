

firebase emulators:start --only auth --import saved --export-on-exit saved

cd ./backend/decision_handler
python3 -m venv venv
python app.py

cd ./backend/mqtt_handler
node index.js

cd ./backend/datasyncbackend
node index.js

cd ./backend/k8s
docker-compose up -d

cd .
ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}' 

sudo lsof -i :9099 | awk 'NR!=1 {print $2}' | xargs kill

for port in 9099 5001 8080 9001 5001 8085 9199 9299 4355 ; do                           
sudo lsof -i :$port | awk 'NR!=1 {print $2}' | xargs kill;
done

docker run -it --name mosquitto1 -p 1883:1883 eclipse-mosquitto
vi /mosquitto/config/mosquitto.conf

