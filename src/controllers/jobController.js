// src/controllers/jobController.js
// Modul Lowongan Kerja -> tabel: jobs, job_required_skills, job_responsibilities,
// job_applications, companies

const pool = require('../config/db');

// ---------------------------------------------------------------------
// GET /api/jobs
// Daftar semua lowongan. Query opsional: ?work_type=Full-time&location=Jakarta
// ---------------------------------------------------------------------
async function getAllJobs(req, res, next) {
  const { work_type, location } = req.query;

  try {
    let query = `
      SELECT j.*, c.name AS company_full_name
      FROM jobs j
      LEFT JOIN companies c ON c.id = j.company_id
      WHERE j.is_active = true
    `;
    const params = [];

    if (work_type) {
      params.push(work_type);
      query += ` AND j.work_type = $${params.length}`;
    }
    if (location) {
      params.push(`%${location}%`);
      query += ` AND j.location ILIKE $${params.length}`;
    }

    query += ' ORDER BY j.posted_date DESC';

    const { rows } = await pool.query(query, params);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/jobs/:id
// Detail 1 lowongan + skill yang dibutuhkan + tanggung jawab (JOIN 3 tabel)
// serta jumlah pelamar (COUNT dari job_applications)
// ---------------------------------------------------------------------
async function getJobById(req, res, next) {
  const { id } = req.params;

  try {
    const jobResult = await pool.query(
      `SELECT j.*, c.name AS company_full_name
       FROM jobs j
       LEFT JOIN companies c ON c.id = j.company_id
       WHERE j.id = $1`,
      [id]
    );

    if (jobResult.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Lowongan tidak ditemukan' });
    }
    const job = jobResult.rows[0];

    const skillsResult = await pool.query(
      'SELECT skill_name FROM job_required_skills WHERE job_id = $1',
      [id]
    );

    const responsibilitiesResult = await pool.query(
      'SELECT description FROM job_responsibilities WHERE job_id = $1 ORDER BY sort_order ASC',
      [id]
    );

    const applicantCountResult = await pool.query(
      'SELECT COUNT(*)::int AS total FROM job_applications WHERE job_id = $1',
      [id]
    );

    job.required_skills = skillsResult.rows.map((r) => r.skill_name);
    job.responsibilities = responsibilitiesResult.rows.map((r) => r.description);
    job.applicant_count = applicantCountResult.rows[0].total;

    res.json({ success: true, data: job });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// POST /api/jobs
// Membuat lowongan baru, opsional menyertakan array skills & responsibilities
// ---------------------------------------------------------------------
async function createJob(req, res, next) {
  const {
    company_id,
    title,
    company_name,
    logo_url,
    location,
    work_type,
    salary_text,
    description,
    required_skills,    // opsional: ["Figma", "UI Design"]
    responsibilities,   // opsional: ["Tugas 1", "Tugas 2"]
  } = req.body;

  const client = await pool.connect();

  try {
    if (!title || !company_name) {
      return res.status(400).json({
        success: false,
        message: 'Field title dan company_name wajib diisi',
      });
    }

    await client.query('BEGIN');

    const insertJobQuery = `
      INSERT INTO jobs (company_id, title, company_name, logo_url, location, work_type, salary_text, description)
      VALUES ($1, $2, $3, $4, $5, COALESCE($6, 'Full-time'), $7, $8)
      RETURNING *
    `;
    const { rows } = await client.query(insertJobQuery, [
      company_id || null,
      title,
      company_name,
      logo_url || null,
      location || null,
      work_type || null,
      salary_text || null,
      description || null,
    ]);
    const newJob = rows[0];

    if (Array.isArray(required_skills)) {
      for (const skill of required_skills) {
        await client.query(
          'INSERT INTO job_required_skills (job_id, skill_name) VALUES ($1, $2)',
          [newJob.id, skill]
        );
      }
    }

    if (Array.isArray(responsibilities)) {
      for (let i = 0; i < responsibilities.length; i++) {
        await client.query(
          'INSERT INTO job_responsibilities (job_id, description, sort_order) VALUES ($1, $2, $3)',
          [newJob.id, responsibilities[i], i + 1]
        );
      }
    }

    await client.query('COMMIT');

    res.status(201).json({ success: true, message: 'Lowongan berhasil dibuat', data: newJob });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------
// PUT /api/jobs/:id
// ---------------------------------------------------------------------
async function updateJob(req, res, next) {
  const { id } = req.params;
  const allowedFields = [
    'title',
    'company_name',
    'logo_url',
    'location',
    'work_type',
    'salary_text',
    'description',
    'is_active',
  ];

  try {
    const fieldsToUpdate = Object.keys(req.body).filter((key) => allowedFields.includes(key));
    if (fieldsToUpdate.length === 0) {
      return res.status(400).json({ success: false, message: 'Tidak ada field valid untuk diupdate' });
    }

    const setClauses = fieldsToUpdate.map((field, index) => `${field} = $${index + 1}`);
    const values = fieldsToUpdate.map((field) => req.body[field]);

    const query = `
      UPDATE jobs SET ${setClauses.join(', ')}
      WHERE id = $${fieldsToUpdate.length + 1}
      RETURNING *
    `;
    values.push(id);

    const { rows } = await pool.query(query, values);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Lowongan tidak ditemukan' });
    }

    res.json({ success: true, message: 'Lowongan berhasil diupdate', data: rows[0] });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// DELETE /api/jobs/:id
// ---------------------------------------------------------------------
async function deleteJob(req, res, next) {
  const { id } = req.params;

  try {
    const { rows } = await pool.query('DELETE FROM jobs WHERE id = $1 RETURNING id', [id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Lowongan tidak ditemukan' });
    }
    res.json({ success: true, message: 'Lowongan berhasil dihapus' });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// POST /api/jobs/:id/apply
// User melamar ke sebuah lowongan
// Body: { user_id }
// ---------------------------------------------------------------------
async function applyToJob(req, res, next) {
  const { id: jobId } = req.params;
  const { user_id } = req.body;

  const client = await pool.connect();

  try {
    if (!user_id) {
      return res.status(400).json({ success: false, message: 'Field user_id wajib diisi' });
    }

    await client.query('BEGIN');

    const insertQuery = `
      INSERT INTO job_applications (user_id, job_id)
      VALUES ($1, $2)
      ON CONFLICT (user_id, job_id) DO NOTHING
      RETURNING *
    `;
    const { rows } = await client.query(insertQuery, [user_id, jobId]);

    if (rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, message: 'User sudah pernah melamar lowongan ini' });
    }

    // Update statistik user: tambah jumlah jobs_applied
    await client.query(
      'UPDATE user_stats SET jobs_applied = jobs_applied + 1, updated_at = now() WHERE user_id = $1',
      [user_id]
    );

    await client.query('COMMIT');

    res.status(201).json({ success: true, message: 'Lamaran berhasil dikirim', data: rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------
// GET /api/jobs/user/:userId
// Daftar lamaran milik seorang user (JOIN job_applications + jobs)
// ---------------------------------------------------------------------
async function getApplicationsByUser(req, res, next) {
  const { userId } = req.params;

  try {
    const query = `
      SELECT ja.id AS application_id, ja.status, ja.applied_at,
             j.id AS job_id, j.title, j.company_name, j.logo_url,
             j.location, j.work_type, j.salary_text
      FROM job_applications ja
      JOIN jobs j ON j.id = ja.job_id
      WHERE ja.user_id = $1
      ORDER BY ja.applied_at DESC
    `;
    const { rows } = await pool.query(query, [userId]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// GET /api/jobs/:id/applicants
// Daftar pelamar untuk 1 lowongan (dipakai Company/Recruiter Dashboard)
// JOIN job_applications + users
// ---------------------------------------------------------------------
async function getApplicantsForJob(req, res, next) {
  const { id: jobId } = req.params;

  try {
    const query = `
      SELECT ja.id AS application_id, ja.status, ja.applied_at,
             u.id AS user_id, u.name, u.email, u.title,
             u.experience_level, u.avatar_url
      FROM job_applications ja
      JOIN users u ON u.id = ja.user_id
      WHERE ja.job_id = $1
      ORDER BY ja.applied_at DESC
    `;
    const { rows } = await pool.query(query, [jobId]);
    res.json({ success: true, count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
}

// ---------------------------------------------------------------------
// PATCH /api/jobs/applications/:applicationId/status
// Update status lamaran (Applied, In Review, Interview, Offered, Rejected...)
// ---------------------------------------------------------------------
async function updateApplicationStatus(req, res, next) {
  const { applicationId } = req.params;
  const { status } = req.body;

  try {
    if (!status) {
      return res.status(400).json({ success: false, message: 'Field status wajib diisi' });
    }

    const { rows } = await pool.query(
      `UPDATE job_applications
       SET status = $1, updated_at = now()
       WHERE id = $2
       RETURNING *`,
      [status, applicationId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Lamaran tidak ditemukan' });
    }

    res.json({ success: true, message: 'Status lamaran berhasil diupdate', data: rows[0] });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getAllJobs,
  getJobById,
  createJob,
  updateJob,
  deleteJob,
  applyToJob,
  getApplicationsByUser,
  getApplicantsForJob,
  updateApplicationStatus,
};
