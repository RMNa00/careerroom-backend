// src/middleware/authMiddleware.js
// Middleware sederhana untuk memverifikasi token JWT pada endpoint yang butuh login
// Cara pakai: tambahkan `protect` sebagai middleware di route yang ingin diproteksi

const jwt = require('jsonwebtoken');

function protect(req, res, next) {
  const authHeader = req.headers.authorization; // format: "Bearer <token>"

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Tidak ada token. Silakan login terlebih dahulu.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // berisi { id, email, role }
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Token tidak valid atau sudah kedaluwarsa.',
    });
  }
}

module.exports = { protect };
