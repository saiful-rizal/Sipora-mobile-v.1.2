<?php
require_once __DIR__ . '/db_connect.php';

$action = $_GET['action'] ?? '';

function read_json_input(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function fail_response(string $message, int $statusCode = 400): void
{
    json_response([
        'success' => false,
        'message' => $message
    ], $statusCode);
}

function success_response(array $data = []): void
{
    json_response(array_merge(['success' => true], $data));
}

function scalar_query(mysqli $conn, string $sql)
{
    $result = $conn->query($sql);
    if (!$result) {
        fail_response('Query gagal: ' . $conn->error, 500);
    }
    $row = $result->fetch_row();
    return $row ? $row[0] : 0;
}

function find_or_create_id(mysqli $conn, string $table, string $idCol, string $nameCol, string $value): int
{
    $trimmed = trim($value);
    if ($trimmed === '') {
        return 0;
    }

    $select = $conn->prepare("SELECT $idCol FROM $table WHERE $nameCol = ? LIMIT 1");
    if (!$select) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $select->bind_param('s', $trimmed);
    $select->execute();
    $res = $select->get_result();
    if ($row = $res->fetch_assoc()) {
        return (int)$row[$idCol];
    }

    $insert = $conn->prepare("INSERT INTO $table ($nameCol) VALUES (?)");
    if (!$insert) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $insert->bind_param('s', $trimmed);
    if (!$insert->execute()) {
        fail_response('Gagal simpan data referensi: ' . $insert->error, 500);
    }

    return (int)$conn->insert_id;
}

function find_id_by_name(mysqli $conn, string $table, string $idCol, string $nameCol, string $value): ?int
{
    $trimmed = trim($value);
    if ($trimmed === '') {
        return null;
    }

    $select = $conn->prepare("SELECT $idCol FROM $table WHERE $nameCol = ? LIMIT 1");
    if (!$select) {
        fail_response('Prepare gagal: ' . $conn->error, 500);
    }
    $select->bind_param('s', $trimmed);
    $select->execute();
    $res = $select->get_result();
    $row = $res->fetch_assoc();

    return $row ? (int)$row[$idCol] : null;
}

switch ($action) {
    case 'dashboard':
        $totalDokumen = (int)scalar_query($conn, 'SELECT COUNT(*) FROM dokumen');
        $penggunaAktif = (int)scalar_query($conn, "SELECT COUNT(*) FROM users WHERE status = 'approved'");
        $uploadBaru = (int)scalar_query($conn, 'SELECT COUNT(*) FROM dokumen WHERE DATE(tgl_unggah) = CURDATE()');
        $totalPenulis = (int)scalar_query($conn, 'SELECT COUNT(*) FROM master_author');

        $recentSql = "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                DATE_FORMAT(d.tgl_unggah, '%d %b %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS kategori,
                COALESCE(u.nama_lengkap, 'Unknown') AS uploader,
                COUNT(da.author_id) AS author_count
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            LEFT JOIN dokumen_author da ON da.dokumen_id = d.dokumen_id
            GROUP BY d.dokumen_id, d.judul, tanggal, kategori, uploader
            ORDER BY d.tgl_unggah DESC
            LIMIT 5
        ";
        $recentResult = $conn->query($recentSql);
        if (!$recentResult) {
            fail_response('Gagal mengambil dokumen terbaru: ' . $conn->error, 500);
        }

        $recent = [];
        while ($row = $recentResult->fetch_assoc()) {
            $recent[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['uploader'],
                'downloads' => (int)$row['author_count'],
                'date' => $row['tanggal'] ?? '-',
                'category' => $row['kategori'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        success_response([
            'stats' => [
                'total_dokumen' => $totalDokumen,
                'pengguna_aktif' => $penggunaAktif,
                'upload_baru' => $uploadBaru,
                'total_penulis' => $totalPenulis
            ],
            'recent_documents' => $recent
        ]);
        break;

    case 'browse_documents':
        $year = trim($_GET['year'] ?? '');
        $jurusan = trim($_GET['jurusan'] ?? '');
        $prodi = trim($_GET['prodi'] ?? '');

        $sql = "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                DATE_FORMAT(d.tgl_unggah, '%d %M %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS tipe,
                COALESCE(mj.nama_jurusan, '-') AS jurusan,
                COALESCE(mp.nama_prodi, '-') AS prodi,
                COALESCE(u.nama_lengkap, 'Unknown') AS uploader,
                COUNT(da.author_id) AS downloads
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            LEFT JOIN master_jurusan mj ON mj.id_jurusan = d.id_jurusan
            LEFT JOIN master_prodi mp ON mp.id_prodi = d.id_prodi
            LEFT JOIN master_tahun mt ON mt.year_id = d.year_id
            LEFT JOIN dokumen_author da ON da.dokumen_id = d.dokumen_id
            WHERE 1=1
        ";

        if ($year !== '') {
            $safeYear = $conn->real_escape_string($year);
            $sql .= " AND mt.tahun = '$safeYear'";
        }
        if ($jurusan !== '') {
            $safeJurusan = $conn->real_escape_string($jurusan);
            $sql .= " AND mj.nama_jurusan = '$safeJurusan'";
        }
        if ($prodi !== '') {
            $safeProdi = $conn->real_escape_string($prodi);
            $sql .= " AND mp.nama_prodi = '$safeProdi'";
        }

        $sql .= "
            GROUP BY d.dokumen_id, d.judul, tanggal, tipe, jurusan, prodi, uploader
            ORDER BY d.tgl_unggah DESC
            LIMIT 40
        ";

        $result = $conn->query($sql);
        if (!$result) {
            fail_response('Gagal mengambil data jelajahi: ' . $conn->error, 500);
        }

        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['uploader'],
                'date' => $row['tanggal'] ?? '-',
                'downloads' => (int)$row['downloads'],
                'type' => $row['tipe'],
                'status' => $row['jurusan'],
                'prodi' => $row['prodi'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        success_response(['documents' => $rows]);
        break;

    case 'search_overview':
        $recent = [];
        $recentRes = $conn->query("SELECT keyword FROM search_history ORDER BY created_at DESC LIMIT 8");
        if ($recentRes) {
            while ($r = $recentRes->fetch_assoc()) {
                $recent[] = $r['keyword'];
            }
        }

        $trending = [];
        $trendingRes = $conn->query("SELECT keyword FROM trending_keywords ORDER BY search_count DESC, last_searched DESC LIMIT 8");
        if ($trendingRes) {
            while ($t = $trendingRes->fetch_assoc()) {
                $trending[] = $t['keyword'];
            }
        }

        $shortcuts = [];
        $shortcutSql = "
            SELECT COALESCE(mj.nama_jurusan, 'Lainnya') AS label, COUNT(*) AS total
            FROM dokumen d
            LEFT JOIN master_jurusan mj ON mj.id_jurusan = d.id_jurusan
            GROUP BY label
            ORDER BY total DESC
            LIMIT 6
        ";
        $shortcutRes = $conn->query($shortcutSql);
        if ($shortcutRes) {
            while ($s = $shortcutRes->fetch_assoc()) {
                $shortcuts[] = [
                    'label' => $s['label'],
                    'count' => (int)$s['total']
                ];
            }
        }

        success_response([
            'recent_searches' => $recent,
            'trending_topics' => $trending,
            'shortcuts' => $shortcuts
        ]);
        break;

    case 'search_documents':
        $input = read_json_input();
        $keyword = trim(($input['keyword'] ?? '') . '');
        if ($keyword === '') {
            fail_response('Keyword pencarian wajib diisi');
        }

        $store = $conn->prepare('INSERT INTO search_history (user_id, keyword) VALUES (?, ?)');
        if ($store) {
            $uid = 0;
            $store->bind_param('is', $uid, $keyword);
            $store->execute();
        }

        $searchLike = '%' . $keyword . '%';
        $stmt = $conn->prepare(
            "
            SELECT
                d.dokumen_id,
                d.judul,
                d.file_path,
                COALESCE(u.nama_lengkap, '-') AS author,
                DATE_FORMAT(d.tgl_unggah, '%d %M %Y') AS tanggal,
                COALESCE(msd.nama_status, 'Dokumen') AS kategori
            FROM dokumen d
            LEFT JOIN users u ON u.id_user = d.uploader_id
            LEFT JOIN master_status_dokumen msd ON msd.status_id = d.status_id
            WHERE d.judul LIKE ? OR d.abstrak LIKE ?
            ORDER BY d.tgl_unggah DESC
            LIMIT 30
            "
        );
        if (!$stmt) {
            fail_response('Gagal menyiapkan pencarian: ' . $conn->error, 500);
        }

        $stmt->bind_param('ss', $searchLike, $searchLike);
        $stmt->execute();
        $result = $stmt->get_result();

        $documents = [];
        while ($row = $result->fetch_assoc()) {
            $documents[] = [
                'id' => (int)$row['dokumen_id'],
                'title' => $row['judul'],
                'author' => $row['author'],
                'date' => $row['tanggal'],
                'category' => $row['kategori'],
                'file_path' => $row['file_path'] ?? ''
            ];
        }

        success_response(['documents' => $documents]);
        break;

    case 'lookup_options':
        $tahun = [];
        $resTahun = $conn->query('SELECT year_id, tahun FROM master_tahun ORDER BY tahun DESC');
        if ($resTahun) {
            while ($r = $resTahun->fetch_assoc()) {
                $tahun[] = $r['tahun'];
            }
        }

        $jurusan = [];
        $resJurusan = $conn->query('SELECT id_jurusan, nama_jurusan FROM master_jurusan ORDER BY nama_jurusan ASC');
        if ($resJurusan) {
            while ($r = $resJurusan->fetch_assoc()) {
                $jurusan[] = $r['nama_jurusan'];
            }
        }

        $prodi = [];
        $resProdi = $conn->query('SELECT id_prodi, nama_prodi FROM master_prodi ORDER BY nama_prodi ASC');
        if ($resProdi) {
            while ($r = $resProdi->fetch_assoc()) {
                $prodi[] = $r['nama_prodi'];
            }
        }

        $divisi = [];
        $resDivisi = $conn->query('SELECT id_divisi, nama_divisi FROM master_divisi ORDER BY nama_divisi ASC');
        if ($resDivisi) {
            while ($r = $resDivisi->fetch_assoc()) {
                $divisi[] = $r['nama_divisi'];
            }
        }

        $tema = [];
        $resTema = $conn->query('SELECT id_tema, nama_tema FROM master_tema ORDER BY nama_tema ASC');
        if ($resTema) {
            while ($r = $resTema->fetch_assoc()) {
                $tema[] = $r['nama_tema'];
            }
        }

        $statusDokumen = [];
        $resStatus = $conn->query('SELECT status_id, nama_status FROM master_status_dokumen ORDER BY nama_status ASC');
        if ($resStatus) {
            while ($r = $resStatus->fetch_assoc()) {
                $statusDokumen[] = $r['nama_status'];
            }
        }

        success_response([
            'tahun' => $tahun,
            'jurusan' => $jurusan,
            'prodi' => $prodi,
            'divisi' => $divisi,
            'tema' => $tema,
            'tipe_dokumen' => $statusDokumen
        ]);
        break;

    case 'login':
        $input = read_json_input();
        $emailOrUsername = trim(($input['email'] ?? '') . '');
        $password = trim(($input['password'] ?? '') . '');

        if ($emailOrUsername === '' || $password === '') {
            fail_response('Email/username dan password wajib diisi');
        }

        $stmt = $conn->prepare('SELECT id_user, nama_lengkap, email, username, role, status, password_hash FROM users WHERE email = ? OR username = ? LIMIT 1');
        if (!$stmt) {
            fail_response('Gagal menyiapkan login: ' . $conn->error, 500);
        }
        $stmt->bind_param('ss', $emailOrUsername, $emailOrUsername);
        $stmt->execute();
        $res = $stmt->get_result();
        $user = $res->fetch_assoc();

        if (!$user) {
            fail_response('Akun tidak ditemukan', 401);
        }

        $passwordValid = password_verify($password, $user['password_hash']) || $password === $user['password_hash'];
        if (!$passwordValid) {
            fail_response('Password salah', 401);
        }

        success_response([
            'user' => [
                'id_user' => (int)$user['id_user'],
                'nama_lengkap' => $user['nama_lengkap'],
                'email' => $user['email'],
                'username' => $user['username'],
                'role' => $user['role'],
                'status' => $user['status']
            ]
        ]);
        break;

    case 'register':
        $input = read_json_input();
        $nama = trim(($input['nama_lengkap'] ?? '') . '');
        $nim = trim(($input['nim'] ?? '') . '');
        $email = trim(($input['email'] ?? '') . '');
        $username = trim(($input['username'] ?? '') . '');
        $password = trim(($input['password'] ?? '') . '');

        if ($nama === '' || $nim === '' || $email === '' || $username === '' || $password === '') {
            fail_response('Semua field registrasi wajib diisi');
        }

        $check = $conn->prepare('SELECT id_user FROM users WHERE email = ? OR username = ? OR nim = ? LIMIT 1');
        if (!$check) {
            fail_response('Gagal menyiapkan validasi registrasi: ' . $conn->error, 500);
        }
        $check->bind_param('sss', $email, $username, $nim);
        $check->execute();
        $exists = $check->get_result()->fetch_assoc();
        if ($exists) {
            fail_response('Email/username/NIM sudah terdaftar');
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $role = 'mahasiswa';
        $status = 'pending';

        $insert = $conn->prepare('INSERT INTO users (nama_lengkap, nim, email, username, password_hash, role, status) VALUES (?, ?, ?, ?, ?, ?, ?)');
        if (!$insert) {
            fail_response('Gagal menyiapkan registrasi: ' . $conn->error, 500);
        }
        $insert->bind_param('sssssss', $nama, $nim, $email, $username, $hash, $role, $status);

        if (!$insert->execute()) {
            fail_response('Registrasi gagal: ' . $insert->error, 500);
        }

        success_response([
            'message' => 'Registrasi berhasil',
            'user_id' => (int)$conn->insert_id
        ]);
        break;

    case 'upload_document':
        $input = read_json_input();
        $judul = trim(($input['judul'] ?? '') . '');
        $abstrak = trim(($input['abstrak'] ?? '') . '');
        $filePath = trim(($input['file_path'] ?? '') . '');
        $uploaderId = (int)($input['uploader_id'] ?? 1);
        $tahun = trim(($input['tahun'] ?? '') . '');
        $jurusan = trim(($input['jurusan'] ?? '') . '');
        $prodi = trim(($input['prodi'] ?? '') . '');
        $divisi = trim(($input['divisi'] ?? '') . '');
        $tema = trim(($input['tema'] ?? '') . '');
        $statusDokumen = trim(($input['tipe_dokumen'] ?? '') . '');
        $kataKunci = is_array($input['kata_kunci'] ?? null) ? $input['kata_kunci'] : [];
        $penulis = is_array($input['penulis'] ?? null) ? $input['penulis'] : [];
        $turnitin = (int)($input['turnitin'] ?? 0);

        if ($judul === '' || $filePath === '') {
            fail_response('Judul dan file dokumen wajib diisi');
        }

        $yearId = 0;
        if ($tahun !== '') {
            $stmtYear = $conn->prepare('SELECT year_id FROM master_tahun WHERE tahun = ? LIMIT 1');
            if ($stmtYear) {
                $stmtYear->bind_param('s', $tahun);
                $stmtYear->execute();
                $resYear = $stmtYear->get_result()->fetch_assoc();
                $yearId = $resYear ? (int)$resYear['year_id'] : 0;
            }
        }

        $jurusanId = find_id_by_name($conn, 'master_jurusan', 'id_jurusan', 'nama_jurusan', $jurusan);
        $prodiId = find_id_by_name($conn, 'master_prodi', 'id_prodi', 'nama_prodi', $prodi);
        $divisiId = find_id_by_name($conn, 'master_divisi', 'id_divisi', 'nama_divisi', $divisi);
        $temaId = find_id_by_name($conn, 'master_tema', 'id_tema', 'nama_tema', $tema);
        $statusId = find_id_by_name($conn, 'master_status_dokumen', 'status_id', 'nama_status', $statusDokumen);

        $turnitinFile = trim(($input['turnitin_file'] ?? '') . '');

        $insertDoc = $conn->prepare(
            'INSERT INTO dokumen (judul, abstrak, turnitin, turnitin_file, kata_kunci, file_path, uploader_id, id_tema, id_jurusan, id_prodi, id_divisi, year_id, status_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );

        if (!$insertDoc) {
            fail_response('Gagal menyiapkan upload dokumen: ' . $conn->error, 500);
        }

        $keywordsJoined = implode(', ', array_map('trim', $kataKunci));
        $temaBind = $temaId ?: null;
        $jurBind = $jurusanId ?: null;
        $prodiBind = $prodiId ?: null;
        $divBind = $divisiId ?: null;
        $yearBind = $yearId ?: null;
        $statusBind = $statusId ?: null;

        $insertDoc->bind_param(
            'ssisssiiiiiii',
            $judul,
            $abstrak,
            $turnitin,
            $turnitinFile,
            $keywordsJoined,
            $filePath,
            $uploaderId,
            $temaBind,
            $jurBind,
            $prodiBind,
            $divBind,
            $yearBind,
            $statusBind
        );

        if (!$insertDoc->execute()) {
            fail_response('Gagal menyimpan dokumen: ' . $insertDoc->error, 500);
        }

        $dokumenId = (int)$conn->insert_id;

        foreach ($penulis as $namaPenulisRaw) {
            $namaPenulis = trim((string)$namaPenulisRaw);
            if ($namaPenulis === '') {
                continue;
            }
            $authorId = find_or_create_id($conn, 'master_author', 'author_id', 'nama_author', $namaPenulis);
            $linkAuthor = $conn->prepare('INSERT INTO dokumen_author (dokumen_id, author_id) VALUES (?, ?)');
            if ($linkAuthor) {
                $linkAuthor->bind_param('ii', $dokumenId, $authorId);
                $linkAuthor->execute();
            }
        }

        foreach ($kataKunci as $keywordRaw) {
            $keyword = trim((string)$keywordRaw);
            if ($keyword === '') {
                continue;
            }
            $keywordId = find_or_create_id($conn, 'master_keyword', 'keyword_id', 'nama_keyword', $keyword);
            $linkKeyword = $conn->prepare('INSERT INTO dokumen_keyword (dokumen_id, keyword_id) VALUES (?, ?)');
            if ($linkKeyword) {
                $linkKeyword->bind_param('ii', $dokumenId, $keywordId);
                $linkKeyword->execute();
            }
        }

        success_response([
            'message' => 'Dokumen berhasil disimpan',
            'dokumen_id' => $dokumenId
        ]);
        break;

    default:
        fail_response('Action API tidak dikenali', 404);
}
