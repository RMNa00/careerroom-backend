// src/routes/courseRoutes.js
const express = require('express');
const router = express.Router();
const {
  getAllCourses,
  getCourseById,
  createCourse,
  updateCourse,
  deleteCourse,
  enrollCourse,
  getUserEnrollments,
} = require('../controllers/courseController');

// Perhatikan: route dengan path statis ('/user/:userId') diletakkan
// SEBELUM route dinamis ('/:id') agar tidak tertangkap sebagai :id

router.get('/user/:userId', getUserEnrollments);   // daftar kursus yang diikuti seorang user

router.get('/', getAllCourses);
router.get('/:id', getCourseById);
router.post('/', createCourse);
router.put('/:id', updateCourse);
router.delete('/:id', deleteCourse);

router.post('/:id/enroll', enrollCourse);           // user enroll ke kursus

module.exports = router;
