from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/data', methods=['POST'])
def receive_data():
    data = request.json
    print("Received data:", data)
    # Process the data as necessary
    return jsonify({"message": "Data received successfully!"})


if __name__ == "__main__":
    app.run(port=5001, debug=True)
