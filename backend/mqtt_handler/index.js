const axios = require('axios');
const mqtt = require('mqtt');

const BROKER_URL = 'mqtt://test.mosquitto.org';
const TOPIC = 'roadtrap_jp:datacollection:realtime'; // The topic you want to subscribe to
const PYTHON_BACKEND_URL = 'http://localhost:5000/data';  // URL of the Flask server


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

client.on('message', async function(topic, message) {
    // Convert message (which is a Buffer) to a string
    const messageStr = message.toString();

    console.log('Received message from', topic, ':', messageStr);

    // todo: rabbitmq, 
    // todo: speed limit ...

    try {
        const response = await axios.post(PYTHON_BACKEND_URL, {
            data: messageStr
        });
        // todo: Notication for the user
        // todo: 
        const data = response.data;
        console.log('Data sent to Python backend:', response.data);
    } catch (error) {
        console.error('Error sending data to Python backend:', error);
    }

    // If you have sent a JSON, you can parse it like:
    // const data = JSON.parse(messageStr);
    // And then work with the data object.
});

client.on('error', function(err) {
    console.error('MQTT Error:', err);
});
