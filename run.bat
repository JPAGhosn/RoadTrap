@echo on
start cmd /k "firebase emulators:start --only auth --import saved --export-on-exit saved"
start cmd /k "cd backend\decision_handler & python3 -m venv venv & call venv\Scripts\activate & python app.py"
start cmd /k "cd backend\mqtt_handler & node index.js"
start cmd /k "cd backend\datasyncbackend & node index.js"
