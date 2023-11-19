const express = require('express');
const multer = require('multer');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const createCsvWriter = require('csv-writer').createObjectCsvWriter;


const app = express();

// Set up file storage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    cb(null, file.originalname);
  }
});

const upload = multer({ storage: storage });

app.use(cors()); // Enable CORS for all routes

// File upload endpoint
app.post('/data-sync', upload.single('file'), (req, res) => {
  console.log('Received file:', req.file.originalname);

  // Path to your .db file
  const dbPath = 'uploads/' + req.file.originalname;

  // Specify the table and columns you want to export
  const tableName = 'payloads';
  const tableName2 = 'choosers';
  const columns = ['id', 'uid', 'gyro_x', 'gyro_y', 'gyro_z', 'acc_x', 'acc_y', 'acc_z', 'longitude', 'latitude', 'accuracy', 'altitude', 'altitudeAccuracy', 'timestamp', 'speedAccuracy', 'speed']; // Add your column names
  const columns2 = ['id', 'uid', 'timestamp', "type"]; // Add your column names

  // Path to the output CSV file

  // Open the database
  let db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
      console.error(err.message);
      return;
    }
    console.log('Connected to the SQLite database.');
  });

  const csvPath = 'uploads/' + req.file.originalname + '-data-' + new Date().toISOString().replace(/[-T:\.Z]/g, '') + '.csv';
  // Create a CSV Writer instance
  const csvWriter = createCsvWriter({
    path: csvPath,
    header: columns.map(col => ({id: col, uid: col, gyro_x: col, gyro_y: col, gyro_z: col, acc_x: col, acc_y: col, acc_z: col, longitude: col, latitude: col, accuracy: col, altitude: col, altitudeAccuracy: col, timestamp: col, speedAccuracy: col, speed: col})),
  });

  const csvPath2 = 'uploads/' + req.file.originalname + '-chooser-' + new Date().toISOString().replace(/[-T:\.Z]/g, '') + '.csv';
  const csvWriter2 = createCsvWriter({
    path: csvPath2,
    header: columns2.map(col => ({id: col, uid: col, timestamp: col, type: col})),
  });

  // Read data from the database and write to CSV
  db.serialize(() => {
    db.all(`SELECT ${columns.join(', ')} FROM ${tableName}`, (err, rows) => {
      if (err) {
        console.error(err.message);
        return;
      }

      csvWriter.writeRecords(rows)
        .then(() => {
          console.log('CSV file written successfully');
        });
    });

    db.all(`SELECT ${columns2.join(', ')} FROM ${tableName2}`, (err, rows) => {
      if (err) {
        console.error(err.message);
        return;
      }

      csvWriter2.writeRecords(rows)
        .then(() => {
          console.log('CSV file written successfully');
        });
    });
  });

  // Close the database connection
  db.close((err) => {
    if (err) {
      console.error(err.message);
    }
    console.log('Closed the database connection.');
  });

  res.status(200).send('File uploaded successfully');
});

const PORT = process.env.PORT || 9433;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
