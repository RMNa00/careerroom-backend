// server.js
// Entry point utama backend careerroom (Express.js + PostgreSQL)

require('dotenv').config();
const express = require('express');
const cors = require('cors');

const userRoutes = require('./src/routes/userRoutes');
const courseRoutes = require('./src/routes/courseRoutes');
const jobRoutes = require('./src/routes/jobRoutes');
const { notFoundHandler, errorHandler } = require('./src/middleware/errorHandler');

const app = express();

// ------------------------- Global Middleware -------------------------
app.use(cors());          // mengizinkan request dari frontend (React di port lain)
app.use(express.json());  // otomatis mem-parsing body JSON dari request

// ------------------------------ Routes ---------------------------------
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚀 careerroom API berjalan dengan baik',
    modules: ['/api/users', '/api/courses', '/api/jobs'],
  });
});

app.use('/api/users', userRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/jobs', jobRoutes);

// ---------------------- 404 & Error Handler (harus di paling bawah) ----------------------
app.use(notFoundHandler);
app.use(errorHandler);

// ------------------------------ Start Server ---------------------------------
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server careerroom berjalan di http://localhost:${PORT}`);
});
