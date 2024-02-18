const axios = require('axios');
const mqtt = require('mqtt');
const { MongoClient } = require('mongodb');
const tf = require('@tensorflow/tfjs-node');

const ip = "172.20.10.4"

const BROKER_URL = `http://${ip}:1883`;
const TOPIC = 'roadtrap_jp:datacollection:realtime'; // The topic you want to subscribe to
const PYTHON_BACKEND_URL = 'http://localhost:5000/data';  // URL of the Flask server

const MONGO_URL = 'mongodb://localhost:27017'; // Replace with your MongoDB URL
const DB_NAME = 'myDatabase'; // Replace with your database name
const COLLECTION = 'mqttData'; // Replace with your collection name

const mongoClient = new MongoClient(MONGO_URL);



const modelPath = 'file:///Users/jean-paulabi-ghosn/StudioProjects/roadtrap/backend/mqtt_handler/converted_roadtrap/model.json'; // Update path
let model;
tf.loadLayersModel(modelPath).then(loadedModel => {
    model = loadedModel;
});

(async () => {
    try {
        await mongoClient.connect();
        console.log('Connected to MongoDB');
    } catch (err) {
        console.error('Error connecting to MongoDB', err);
    }
})();

const client = mqtt.connect(BROKER_URL);

client.on('connect', function() {
    console.log('Connected to the MQTT broker.');

    // Subscribe to the topic
    client.subscribe(TOPIC, function(err) {
        if (err) {
            console.error('Error while subscribing to the topic:', err);
        } else {
            console.log('Successfully subscribed to the topic:', TOPIC);
        }
    });
});

let dataBuffer = [];
client.on('message', async function(topic, message) {
    // Convert message (which is a Buffer) to a string
    const messageStr = message.toString();

    // console.log('Received message from', topic, ':', messageStr);


    // todo: rabbitmq,
    // todo: speed limit ...



    try {
//        const response = await axios.post(PYTHON_BACKEND_URL, {
//            data: messageStr
//        });
//        // todo: Notication for the user
//        // todo:
//        const data = response.data;
//        console.log('Data sent to Python backend:', response.data);
    } catch (error) {
        console.error('Error sending data to Python backend:', error);
    }

    try {
        // Assume the message is a JSON string; parse it
        const data = JSON.parse(messageStr);

        console.log(data);

        // Insert the data into MongoDB
        const db = mongoClient.db(DB_NAME);
        const collection = db.collection(COLLECTION);
        const newData = {
            accelero_x: data.accelerometer.x,
            accelero_y: data.accelerometer.y,
            accelero_z: data.accelerometer.z,
            gyro_x: data.gyroscope.x,
            gyro_y: data.gyroscope.y,
            gyro_z: data.gyroscope.z,
            longitude: data.position.longitude,
            latitude: data.position.latitude,
            accuracy: data.position.accuracy,
            altitude: data.position.altitude,
            altitudeAccuracy: data.altitudeAccuracy,
            speed: data.speed,
            speedAccuracy: data.speedAccuracy,
            timestamp: data.timestamp,
            type: data.type,
            uid: data.uid,
            uid: data.uid,
            userAcceptation: data.userAcceptation,
            heading: data.heading
        };

        const checkPotholes = async (latitude, longitude, direction) => {
            // Define approximate conversion factors (these are rough estimates and may need adjustment)
            const metersPerDegreeLatitude = 111320; // One degree of latitude is approximately 111.32 kilometers
            const metersPerDegreeLongitude = 111320 * Math.cos(latitude * (Math.PI / 180)); // Adjusted for latitude

            // Calculate the new latitude and longitude based on the heading
            const distance = 15; // 15 meters
            const radians = direction * (Math.PI / 180); // Convert heading to radians

            // Calculate the new coordinates
            const newLatitude = latitude + (distance * Math.cos(radians)) / metersPerDegreeLatitude;
            const newLongitude = longitude + (distance * Math.sin(radians)) / metersPerDegreeLongitude;

            try {
                const collection = mongoClient.db(DB_NAME).collection(COLLECTION);
                const query = {
                    'location.latitude': { $gte: Math.min(latitude, newLatitude), $lte: Math.max(latitude, newLatitude) },
                    'location.longitude': { $gte: Math.min(longitude, newLongitude), $lte: Math.max(longitude, newLongitude) }
                };
                return await collection.find(query).toArray();
            } catch (err) {
                console.error('Error querying MongoDB', err);
                return [];
            }
        }

        const checkBumps = async (latitude, longitude, direction) => {
            // Define approximate conversion factors (these are rough estimates and may need adjustment)
            const metersPerDegreeLatitude = 111320; // One degree of latitude is approximately 111.32 kilometers
            const metersPerDegreeLongitude = 111320 * Math.cos(latitude * (Math.PI / 180)); // Adjusted for latitude

            // Calculate the new latitude and longitude based on the heading
            const distance = 15; // 15 meters
            const radians = direction * (Math.PI / 180); // Convert heading to radians

            // Calculate the new coordinates
            const newLatitude = latitude + (distance * Math.cos(radians)) / metersPerDegreeLatitude;
            const newLongitude = longitude + (distance * Math.sin(radians)) / metersPerDegreeLongitude;

            try {
                const collection = mongoClient.db(DB_NAME).collection(COLLECTION);
                const query = {
                    'location.latitude': { $gte: Math.min(latitude, newLatitude), $lte: Math.max(latitude, newLatitude) },
                    'location.longitude': { $gte: Math.min(longitude, newLongitude), $lte: Math.max(longitude, newLongitude) }
                };
                return await collection.find(query).toArray();
            } catch (err) {
                console.error('Error querying MongoDB', err);
                return [];
            }
        }

        const sendMQTTNotification = (potholes, uid) => {
            const client = mqtt.connect(`http://${ip}:1883`);
            client.publish(`/notifications/${uid}`, message, () => {
                console.log(`Message '${message}' published to '${TOPIC}'`);
                res.send(`Message '${message}' published`);
            });
        }

        // get direction

        // check if any pothole ahead
        const potholes = await checkPotholes(newData.latitude, newData.longitude, newData.direction);
        if (potholes.length > 0) {
            // Send MQTT message if potholes are found
            sendMQTTNotification(potholes, newData.uid);
        }

        await collection.insertOne(newData);

        // Add the new data to the buffer and ensure it doesn't exceed 9 entries
        dataBuffer.push(newData);
        if (dataBuffer.length > 9) {
            // Remove the oldest entry if we exceed 9 data points
            dataBuffer.shift();
        }

        // console.log(dataBuffer.length)

        // Only proceed if we have enough data
        if (dataBuffer.length === 9) {
            try {
                const processedData = preprocessData(dataBuffer);

                // Make a prediction if the model is loaded
                if (model) {
                    const prediction = model.predict(processedData);
                    prediction.array().then(result => {
                        // console.log(`Predicted type: ${result}`);
                        // Handle the result as needed
                        const classNames = ['bump', 'none', 'pothole']
                        const resultString = classNames[result[0].indexOf(Math.max.apply(Math, result[0]))];
                        if(resultString !== "none") {
                            console.log(`found ${resultString}`);
                        }
                    });
                }
            } catch (error) {
                console.error('Error making prediction:', error);
            }
        }

        // console.log('Data saved to MongoDB:', data);
    } catch (error) {
        console.error('Error handling message or saving to MongoDB:', error);
    }

    // If you have sent a JSON, you can parse it like:
    // const data = JSON.parse(messageStr);
    // And then work with the data object.
});

function preprocessData(dataBuffer) {
    const sensorDataColumns = ['accelero_x', 'accelero_y', 'accelero_z', 'gyro_x', 'gyro_y', 'gyro_z'];
    const mean = {accelero_x: 0, accelero_y: 0, accelero_z: 0, gyro_x: 0, gyro_y: 0, gyro_z: 0};
    const std = {accelero_x: 1, accelero_y: 1, accelero_z: 1, gyro_x: 1, gyro_y: 1, gyro_z: 1};

    // Assuming dataBuffer is an array of the last 9 sets of sensor data
    if (dataBuffer.length < 9) {
        throw new Error("Not enough data to form a complete sequence.");
    }

    // Normalize each set of sensor data
    let sequence = dataBuffer.map(data => {
        return sensorDataColumns.map(column => {
            return data.hasOwnProperty(column) ? (data[column] - mean[column]) / std[column] : 0;
        });
    });

    // Ensure the sequence has the correct shape [1, 9, 6]
    const reshapedData = tf.tensor3d([sequence], [1, 9, 6]);

    return reshapedData;
}



client.on('error', function(err) {
    console.error('MQTT Error:', err);
});
