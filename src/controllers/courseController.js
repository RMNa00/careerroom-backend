// src/controllers/courseController.js
// Modul Kursus -> tabel: courses, course_modules, course_quiz_questions,
// course_quiz_options, course_enrollments

const pool = require('../config/db');

// ---------------------------------------------------------------------
// GET /api/courses
// Daftar semua kursus. Query opsional: ?category=Design&is_free=true
// ---------------------------------------------------------------------
async function getAllCourses(req, res, next) {
  const { category, is_free } = req.query;

  try {
    let query = 'SELECT * FROM courses';
    const conditions = [];
    const params = [];

    if (category) {
      params.push(category);
      conditions.push(`category = $${params.length}`);
    }
    if (is_free !== undefined) {
      params.push(is_free === 'true');
      conditions.push(`is_free = $${params.length}`);
    }
    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' ORDER BY created_at DESC';

    const { rows } = await pool.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/courses/:id
// Detail 1 kursus + modul-modulnya + quiz (soal & opsi jawaban)
// ---------------------------------------------------------------------
async function getCourseById(req, res, next) {
  const { id } = req.params;

  try {
    const courseResult = await pool.query('SELECT * FROM courses WHERE id = $1', [id]);
    if (courseResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kursus tidak ditemukan' });
    }
    const course = courseResult.rows[0];

    // Ambil modul-modul kursus, urut berdasarkan sort_order
    const modulesResult = await pool.query(
      'SELECT id, title, video_url, duration_text, sort_order FROM course_modules WHERE course_id = $1 ORDER BY sort_order ASC',
      [id]
    );

    // Ambil soal quiz beserta opsi jawabannya menggunakan JOIN
    const quizResult = await pool.query(
      `SELECT q.id AS question_id, q.question, q.correct_option_index,
              o.id AS option_id, o.option_index, o.option_text
       FROM course_quiz_questions q
       LEFT JOIN course_quiz_options o ON o.question_id = q.id
       WHERE q.course_id = $1
       ORDER BY q.id, o.option_index ASC`,
      [id]
    );

    // Susun ulang hasil query quiz menjadi bentuk bersarang (nested):
    // [{ id, question, options: [...] }]
    const quizMap = new Map();
    quizResult.rows.forEach((row) => {
      if (!quizMap.has(row.question_id)) {
        quizMap.set(row.question_id, {
          id: row.question_id,
          question: row.question,
          correct_option_index: row.correct_option_index,
          options: [],
        });
      }
      if (row.option_id) {
        quizMap.get(row.question_id).options.push({
          id: row.option_id,
          option_index: row.option_index,
          option_text: row.option_text,
        });
      }
    });

    course.modules = modulesResult.rows;
    course.quiz = Array.from(quizMap.values());

    res.json({ success: true, data: course });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// POST /api/courses
// Membuat kursus baru, opsional langsung menyertakan array "modules"
// ---------------------------------------------------------------------
async function createCourse(req, res, next) {
  const {
    title,
    category,
    instructor,
    duration_text,
    difficulty,
    price,
    is_free,
    thumbnail_url,
    description,
    modules, // opsional: [{ title, video_url, duration_text }]
  } = req.body;

  const client = await pool.connect();

  try {
    if (!title) {
      return res.status(400).json({ success: false, message: 'Field title wajib diisi' });
    }

    await client.query('BEGIN'); // gunakan transaksi karena ada 2 tabel yang diisi

    const insertCourseQuery = `
      INSERT INTO courses (title, category, instructor, duration_text, difficulty, price, is_free, thumbnail_url, description)
      VALUES ($1, $2, $3, $4, COALESCE($5, 'Beginner'), COALESCE($6, 0), COALESCE($7, false), $8, $9)
      RETURNING *
    `;
    const { rows } = await client.query(insertCourseQuery, [
      title,
      category || null,
      instructor || null,
      duration_text || null,
      difficulty || null,
      price || 0,
      is_free || false,
      thumbnail_url || null,
      description || null,
    ]);
    const newCourse = rows[0];

    if (Array.isArray(modules) && modules.length > 0) {
      for (let i = 0; i < modules.length; i++) {
        const m = modules[i];
        await client.query(
          `INSERT INTO course_modules (course_id, title, video_url, duration_text, sort_order)
           VALUES ($1, $2, $3, $4, $5)`,
          [newCourse.id, m.title, m.video_url || null, m.duration_text || null, i + 1]
        );
      }
    }

    await client.query('COMMIT');

    res.status(201).json({ success: true, message: 'Kursus berhasil dibuat', data: newCourse });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------
// PUT /api/courses/:id
// ---------------------------------------------------------------------
async function updateCourse(req, res, next) {
  const { id } = req.params;
  const allowedFields = [
    'title',
    'category',
    'instructor',
    'duration_text',
    'difficulty',
    'price',
    'is_free',
    'thumbnail_url',
    'description',
  ];

  try {
    const fieldsToUpdate = Object.keys(req.body).filter((key) => allowedFields.includes(key));
    if (fieldsToUpdate.length === 0) {
      return res.status(400).json({ success: false, message: 'Tidak ada field valid untuk diupdate' });
    }

    const setClauses = fieldsToUpdate.map((field, index) => `${field} = $${index + 1}`);
    const values = fieldsToUpdate.map((field) => req.body[field]);

    const query = `
      UPDATE courses SET ${setClauses.join(', ')}
      WHERE id = $${fieldsToUpdate.length + 1}
      RETURNING *
    `;
    values.push(id);

    const { rows } = await pool.query(query, values);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kursus tidak ditemukan' });
    }

    res.json({ success: true, message: 'Kursus berhasil diupdate', data: rows[0] });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// DELETE /api/courses/:id
// (course_modules, course_quiz_questions, course_enrollments ikut
//  terhapus otomatis karena ON DELETE CASCADE di database)
// ---------------------------------------------------------------------
async function deleteCourse(req, res, next) {
  const { id } = req.params;

  try {
    const { rows } = await pool.query('DELETE FROM courses WHERE id = $1 RETURNING id', [id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kursus tidak ditemukan' });
    }
    res.json({ success: true, message: 'Kursus berhasil dihapus' });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// POST /api/courses/:id/enroll
// User mendaftar (enroll) ke sebuah kursus
// Body: { user_id }
// ---------------------------------------------------------------------
async function enrollCourse(req, res, next) {
  const { id: courseId } = req.params;
  const { user_id } = req.body;

  try {
    if (!user_id) {
      return res.status(400).json({ success: false, message: 'Field user_id wajib diisi' });
    }

    const query = `
      INSERT INTO course_enrollments (user_id, course_id)
      VALUES ($1, $2)
      ON CONFLICT (user_id, course_id) DO NOTHING
      RETURNING *
    `;
    const { rows } = await pool.query(query, [user_id, courseId]);

    if (rows.length === 0) {
      return res.status(409).json({ success: false, message: 'User sudah terdaftar di kursus ini' });
    }

    res.status(201).json({ success: true, message: 'Berhasil mendaftar kursus', data: rows[0] });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/courses/user/:userId
// Daftar kursus yang diikuti seorang user (JOIN course_enrollments + courses)
// ---------------------------------------------------------------------
async function getUserEnrollments(req, res, next) {
  const { userId } = req.params;

  try {
    const query = `
      SELECT ce.id AS enrollment_id, ce.progress, ce.is_completed,
             ce.enrolled_at, ce.completed_at,
             c.id AS course_id, c.title, c.category, c.instructor,
             c.thumbnail_url, c.duration_text
      FROM course_enrollments ce
      JOIN courses c ON c.id = ce.course_id
      WHERE ce.user_id = $1
      ORDER BY ce.enrolled_at DESC
    `;
    const { rows } = await pool.query(query, [userId]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getAllCourses,
  getCourseById,
  createCourse,
  updateCourse,
  deleteCourse,
  enrollCourse,
  getUserEnrollments,
};
