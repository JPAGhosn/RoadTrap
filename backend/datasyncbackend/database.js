const { Pool } = require('pg');

const pool = new Pool({
    user: 'user',
    host: 'localhost',
    database: 'potbump',
    password: 'user',
    port: 5432, // default PostgreSQL port
});

module.exports = pool;
