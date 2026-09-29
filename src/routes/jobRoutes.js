// src/routes/jobRoutes.js
const express = require('express');
const router = express.Router();
const {
  getAllJobs,
  getJobById,
  createJob,
  updateJob,
  deleteJob,
  applyToJob,
  getApplicationsByUser,
  getApplicantsForJob,
  updateApplicationStatus,
} = require('../controllers/jobController');

// Route statis diletakkan sebelum route dinamis ('/:id')
router.get('/user/:userId', getApplicationsByUser);              // lamaran milik seorang user
router.patch('/applications/:applicationId/status', updateApplicationStatus);

router.get('/', getAllJobs);
router.get('/:id', getJobById);
router.post('/', createJob);
router.put('/:id', updateJob);
router.delete('/:id', deleteJob);

router.post('/:id/apply', applyToJob);                           // user melamar ke lowongan
router.get('/:id/applicants', getApplicantsForJob);               // pelamar untuk 1 lowongan

module.exports = router;
