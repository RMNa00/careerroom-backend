// src/middleware/errorHandler.js
// Middleware terpusat untuk menangani error di seluruh aplikasi
// Setiap controller cukup memanggil next(error) untuk sampai ke sini

function notFoundHandler(req, res, next) {
  res.status(404).json({
    success: false,
    message: `Endpoint tidak ditemukan: ${req.method} ${req.originalUrl}`,
  });
}

function errorHandler(err, req, res, next) {
  console.error('🔥 Error:', err.message);

  // Error dari 'pg' biasanya punya kode PostgreSQL, contoh:
  // 23505 = unique_violation (misal email sudah terdaftar)
  // 23503 = foreign_key_violation (misal course_id / user_id tidak ada)
  if (err.code === '23505') {
    return res.status(409).json({
      success: false,
      message: 'Data sudah ada (duplikat). Cek kembali data unik seperti email.',
    });
  }

  if (err.code === '23503') {
    return res.status(400).json({
      success: false,
      message: 'Referensi data tidak valid (ID terkait tidak ditemukan).',
    });
  }

  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    success: false,
    message: err.message || 'Terjadi kesalahan pada server',
  });
}

module.exports = { notFoundHandler, errorHandler };
