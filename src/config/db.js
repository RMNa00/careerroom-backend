require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false // Membuka kunci sertifikat SSL Supabase
  }
});

pool.connect()
  .then((client) => {
    console.log('✅ Berhasil terhubung ke database Supabase Cloud!');
    client.release();
  })
  .catch((err) => {
    console.error('❌ Gagal Detail Error:', JSON.stringify(err, null, 2));
  });

module.exports = pool;