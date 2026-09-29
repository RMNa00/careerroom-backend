# careerroom Backend API

Backend REST API untuk aplikasi **careerroom**, dibangun dengan **Node.js + Express.js**
dan terhubung ke database **PostgreSQL** (skema `careerroom_database.sql` yang sudah dibuat
sebelumnya, berisi 48 tabel).

---

## 📁 Struktur Folder

```
careerroom-backend/
├── server.js                     # Entry point aplikasi (start di sini)
├── package.json
├── .env.example                  # Contoh konfigurasi environment
├── .gitignore
└── src/
    ├── config/
    │   └── db.js                 # Koneksi PostgreSQL (Connection Pool)
    ├── controllers/               # Logika bisnis & query SQL
    │   ├── userController.js
    │   ├── courseController.js
    │   └── jobController.js
    ├── routes/                    # Definisi endpoint (URL) per modul
    │   ├── userRoutes.js
    │   ├── courseRoutes.js
    │   └── jobRoutes.js
    └── middleware/
        ├── authMiddleware.js      # Verifikasi token JWT (untuk route yang butuh login)
        └── errorHandler.js        # Penanganan error terpusat
```

**Alur request:** `server.js` → `routes/*.js` (menentukan endpoint mana yang dipanggil)
→ `controllers/*.js` (menjalankan query SQL ke PostgreSQL lewat `config/db.js`) → response JSON.

---

## 🚀 Cara Menjalankan

### 1. Prasyarat
- Node.js versi 18 ke atas sudah terpasang
- PostgreSQL & pgAdmin sudah terpasang
- Database `careerroom_db` sudah dibuat dan skema `careerroom_database.sql` sudah di-import
  (lihat file SQL yang sudah dikirim sebelumnya)

### 2. Ekstrak & install dependencies
```bash
cd careerroom-backend
npm install
```
Perintah ini akan mengunduh `express`, `pg`, `cors`, `dotenv`, `bcryptjs`, `jsonwebtoken`, dan `nodemon`.

### 3. Konfigurasi environment
Salin file `.env.example` menjadi `.env`:
```bash
cp .env.example .env
```
Lalu buka `.env` dan sesuaikan dengan kredensial PostgreSQL di komputer Anda (sama seperti
yang Anda pakai untuk login di pgAdmin):
```env
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=isi_password_postgresql_anda
DB_NAME=careerroom_db
JWT_SECRET=buat_kata_sandi_rahasia_bebas
JWT_EXPIRES_IN=7d
```

### 4. Jalankan server
Mode development (otomatis restart saat ada perubahan kode):
```bash
npm run dev
```
Atau mode biasa:
```bash
npm start
```

Jika berhasil, akan muncul log seperti ini di terminal:
```
✅ Berhasil terhubung ke database PostgreSQL: careerroom_db
🚀 Server careerroom berjalan di http://localhost:5000
```

Buka browser / Postman ke `http://localhost:5000` untuk memastikan API sudah aktif.

---

## 📌 Daftar Endpoint

### 👤 Modul Users (`/api/users`)
| Method | Endpoint                | Keterangan                                   |
|--------|--------------------------|-----------------------------------------------|
| POST   | `/api/users/register`   | Registrasi user baru                          |
| POST   | `/api/users/login`      | Login, mengembalikan JWT token                |
| GET    | `/api/users`            | Daftar semua user (bisa filter `?role=mentor`)|
| GET    | `/api/users/:id`        | Detail user + statistik + daftar skill        |
| PUT    | `/api/users/:id`        | Update profil user                            |
| DELETE | `/api/users/:id`        | Hapus user                                    |

**Contoh body register:**
```json
{
  "name": "Alex Rivera",
  "email": "alex.rivera@careerroom.dev",
  "password": "rahasia123",
  "role": "career_user",
  "title": "Aspiring UI/UX Designer",
  "target_role": "UI/UX Designer"
}
```

### 🎓 Modul Kursus (`/api/courses`)
| Method | Endpoint                          | Keterangan                                          |
|--------|-------------------------------------|-------------------------------------------------------|
| GET    | `/api/courses`                     | Daftar kursus (filter `?category=Design&is_free=true`)|
| GET    | `/api/courses/:id`                 | Detail kursus + modul + quiz (nested JOIN)            |
| POST   | `/api/courses`                     | Buat kursus baru (bisa sertakan array `modules`)       |
| PUT    | `/api/courses/:id`                 | Update kursus                                          |
| DELETE | `/api/courses/:id`                 | Hapus kursus                                            |
| POST   | `/api/courses/:id/enroll`          | User mendaftar ke kursus. Body: `{ "user_id": "..." }`|
| GET    | `/api/courses/user/:userId`        | Daftar kursus yang diikuti seorang user                |

**Contoh body create course:**
```json
{
  "title": "Design Systems in Practice",
  "category": "Design",
  "instructor": "Dr. Maya Lin",
  "price": 199000,
  "is_free": false,
  "modules": [
    { "title": "Module 1: Design Tokens", "duration_text": "35 min" },
    { "title": "Module 2: Component Specs", "duration_text": "45 min" }
  ]
}
```

### 💼 Modul Lowongan Kerja (`/api/jobs`)
| Method | Endpoint                                      | Keterangan                                          |
|--------|--------------------------------------------------|---------------------------------------------------------|
| GET    | `/api/jobs`                                   | Daftar lowongan (filter `?work_type=Full-time&location=Jakarta`) |
| GET    | `/api/jobs/:id`                               | Detail lowongan + skill dibutuhkan + tanggung jawab      |
| POST   | `/api/jobs`                                   | Buat lowongan baru                                        |
| PUT    | `/api/jobs/:id`                               | Update lowongan                                            |
| DELETE | `/api/jobs/:id`                               | Hapus lowongan                                              |
| POST   | `/api/jobs/:id/apply`                         | User melamar. Body: `{ "user_id": "..." }`                |
| GET    | `/api/jobs/user/:userId`                      | Daftar lamaran milik seorang user                          |
| GET    | `/api/jobs/:id/applicants`                    | Daftar pelamar untuk 1 lowongan (untuk Recruiter Dashboard)|
| PATCH  | `/api/jobs/applications/:applicationId/status`| Update status lamaran. Body: `{ "status": "Interview" }`  |

**Contoh body create job:**
```json
{
  "title": "Junior UI/UX Designer",
  "company_name": "TechNova Solutions",
  "location": "Jakarta (Hybrid)",
  "work_type": "Full-time",
  "salary_text": "Rp8.000.000 - Rp12.000.000 / month",
  "required_skills": ["Figma", "UI Design", "Prototyping"],
  "responsibilities": ["Membuat prototipe high-fidelity", "Melakukan usability testing"]
}
```

---

## 🔐 Tentang Autentikasi (JWT)

Setiap kali user **register** atau **login**, server akan mengembalikan sebuah `token`.
Untuk endpoint yang nantinya ingin Anda proteksi (misalnya hanya admin yang boleh hapus data),
tinggal tambahkan middleware `protect` dari `src/middleware/authMiddleware.js`, contoh:

```js
const { protect } = require('../middleware/authMiddleware');

router.delete('/:id', protect, deleteUser); // sekarang wajib login untuk hapus user
```

Lalu di sisi client (Postman/React), sertakan header:
```
Authorization: Bearer <token_yang_didapat_dari_login>
```

---

## 🧪 Testing Cepat dengan cURL

```bash
# Cek server aktif
curl http://localhost:5000

# Registrasi user
curl -X POST http://localhost:5000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Alex Rivera","email":"alex@careerroom.dev","password":"rahasia123"}'

# Ambil semua kursus
curl http://localhost:5000/api/courses

# Ambil semua lowongan
curl http://localhost:5000/api/jobs
```

---

## ➕ Mengembangkan Modul Lain

Struktur ini modular, jadi untuk modul lain (mentors, freelance, community, dst.) yang
belum dibuatkan contohnya, Anda tinggal ikuti pola yang sama:
1. Buat `src/controllers/mentorController.js` (atau nama modul lain) berisi fungsi-fungsi query SQL.
2. Buat `src/routes/mentorRoutes.js` yang mengarahkan endpoint ke fungsi di controller.
3. Daftarkan route baru di `server.js`:
   ```js
   const mentorRoutes = require('./src/routes/mentorRoutes');
   app.use('/api/mentors', mentorRoutes);
   ```

Selamat mengembangkan careerroom! 🚀
