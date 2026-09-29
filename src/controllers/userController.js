// src/controllers/userController.js
// Modul Autentikasi & Users -> berhubungan dengan tabel: users, user_stats, user_skills, skills

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// Helper: buat token JWT
function generateToken(user) {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

// Helper: hilangkan password_hash sebelum data dikirim ke client
function sanitizeUser(user) {
  const { password_hash, ...safeUser } = user;
  return safeUser;
}

// ---------------------------------------------------------------------
// POST /api/users/register
// Registrasi user baru (career_user / mentor / recruiter / admin)
// ---------------------------------------------------------------------
async function registerUser(req, res, next) {
  const { name, email, password, role, title, target_role } = req.body;

  try {
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Field name, email, dan password wajib diisi',
      });
    }

    // Cek apakah email sudah terdaftar
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'Email sudah terdaftar' });
    }

    // Hash password sebelum disimpan
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const insertUserQuery = `
      INSERT INTO users (name, email, password_hash, role, title, target_role)
      VALUES ($1, $2, $3, COALESCE($4, 'career_user')::user_role, $5, $6)
      RETURNING id, name, email, role, avatar_url, title, experience_level,
                target_role, overall_progress, plan, bio, created_at
    `;
    const { rows } = await pool.query(insertUserQuery, [
      name,
      email,
      passwordHash,
      role || null,
      title || null,
      target_role || null,
    ]);

    const newUser = rows[0];

    // Buat baris user_stats default untuk user baru (1-to-1 dengan users)
    await pool.query('INSERT INTO user_stats (user_id) VALUES ($1)', [newUser.id]);

    const token = generateToken(newUser);

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil',
      data: { user: newUser, token },
    });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// POST /api/users/login
// Login menggunakan email & password
// ---------------------------------------------------------------------
async function loginUser(req, res, next) {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email dan password wajib diisi' });
    }

    const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = rows[0];

    if (!user) {
      return res.status(401).json({ success: false, message: 'Email atau password salah' });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Email atau password salah' });
    }

    const token = generateToken(user);

    res.json({
      success: true,
      message: 'Login berhasil',
      data: { user: sanitizeUser(user), token },
    });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/users
// Ambil daftar semua user (untuk admin dashboard, dsb)
// Query opsional: ?role=career_user
// ---------------------------------------------------------------------
async function getAllUsers(req, res, next) {
  const { role } = req.query;

  try {
    let query = `
      SELECT id, name, email, role, avatar_url, title, experience_level,
             target_role, overall_progress, plan, created_at
      FROM users
    `;
    const params = [];

    if (role) {
      params.push(role);
      query += ` WHERE role = $${params.length}`;
    }

    query += ' ORDER BY created_at DESC';

    const { rows } = await pool.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/users/:id
// Detail 1 user beserta statistik (JOIN users + user_stats)
// dan daftar skill-nya (JOIN user_skills + skills)
// ---------------------------------------------------------------------
async function getUserById(req, res, next) {
  const { id } = req.params;

  try {
    const userQuery = `
      SELECT u.id, u.name, u.email, u.role, u.avatar_url, u.title,
             u.experience_level, u.target_role, u.overall_progress,
             u.plan, u.bio, u.created_at,
             s.courses_completed, s.learning_hours, s.projects_built,
             s.jobs_applied, s.interviews_scheduled, s.freelance_earned,
             s.mentor_sessions_completed
      FROM users u
      LEFT JOIN user_stats s ON s.user_id = u.id
      WHERE u.id = $1
    `;
    const userResult = await pool.query(userQuery, [id]);

    if (userResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    const skillsQuery = `
      SELECT sk.id, sk.name, sk.category, us.level, us.verified
      FROM user_skills us
      JOIN skills sk ON sk.id = us.skill_id
      WHERE us.user_id = $1
      ORDER BY us.level DESC
    `;
    const skillsResult = await pool.query(skillsQuery, [id]);

    const user = userResult.rows[0];
    user.skills = skillsResult.rows;

    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// PUT /api/users/:id
// Update profil user (partial update / dynamic query)
// ---------------------------------------------------------------------
async function updateUser(req, res, next) {
  const { id } = req.params;
  const allowedFields = [
    'name',
    'title',
    'avatar_url',
    'experience_level',
    'target_role',
    'overall_progress',
    'plan',
    'bio',
  ];

  try {
    const fieldsToUpdate = Object.keys(req.body).filter((key) => allowedFields.includes(key));

    if (fieldsToUpdate.length === 0) {
      return res.status(400).json({
        success: false,
        message: `Tidak ada field valid untuk diupdate. Field yang diizinkan: ${allowedFields.join(', ')}`,
      });
    }

    // Bangun query UPDATE secara dinamis, contoh:
    // UPDATE users SET name = $1, title = $2, updated_at = now() WHERE id = $3 RETURNING *
    const setClauses = fieldsToUpdate.map((field, index) => `${field} = $${index + 1}`);
    const values = fieldsToUpdate.map((field) => req.body[field]);

    const query = `
      UPDATE users
      SET ${setClauses.join(', ')}, updated_at = now()
      WHERE id = $${fieldsToUpdate.length + 1}
      RETURNING id, name, email, role, title, experience_level,
                target_role, overall_progress, plan, bio, updated_at
    `;
    values.push(id);

    const { rows } = await pool.query(query, values);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    res.json({ success: true, message: 'Profil berhasil diupdate', data: rows[0] });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// DELETE /api/users/:id
// ---------------------------------------------------------------------
async function deleteUser(req, res, next) {
  const { id } = req.params;

  try {
    const { rows } = await pool.query('DELETE FROM users WHERE id = $1 RETURNING id', [id]);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    res.json({ success: true, message: 'User berhasil dihapus' });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  registerUser,
  loginUser,
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser,
};
