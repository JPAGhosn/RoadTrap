const express = require('express');
const multer = require('multer');
const cors = require('cors');

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
  res.status(200).send('File uploaded successfully');
});

const PORT = process.env.PORT || 9433;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
