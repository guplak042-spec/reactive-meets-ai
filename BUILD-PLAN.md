# BUILD PLAN — Reactive Meets AI ("Sentinel")

> Build plan, published for transparency. All addresses and transaction hashes
> are public on the Sepolia and Lasna testnets.

- Deadline submit: **Sabtu 5 Des 2026 20:00 UTC = Minggu 6 Des 2026 03:00 WIB**.
- Target internal: **submit Jumat 4 Des 2026** (buffer 1 hari).
- Sisa waktu per 18 Nov 2026: ~17 hari.
- Track: Reactive Meets AI, $1.000 (juara 1), dibayar REACT.
- Repo: `~/workspace/reactive-meets-ai/` (lokal dulu; publik GitHub `guplak042-spec` menyusul — konektor GitHub tidak bisa create_repository, perlu jalur browser/gh).

## Milestone

### Tahap 1 — Plumbing terbukti (18–19 Nov)
- [x] 18 Nov: riset DoraHacks + docs Reactive selesai (deadline pasti, KTP tidak disyaratkan, toolchain Foundry, Lasna RPC/faucet, pola Omni).
- [x] 18 Nov: Foundry 1.9.0 terpasang; CONCEPT.md ditulis; konsep Sentinel dipilih.
- [x] 18 Nov: scaffold Foundry project + git init + README; clone repo demo resmi sebagai referensi (bukan copy-paste mentah — pola Omni terbaru).
- [x] 18 Nov: wallet EVM baru untuk build (generate lokal, keypair mode 600, catat HANYA alamat).
- [x] 18 Nov: kontrak compile + 9/9 forge test lolos + loop penuh tersimulasi di anvil (transfer → react → callback → VerdictRecorded). Deploy script tervalidasi di anvil.
- [ ] 18–19 Nov: dapatkan Sepolia ETH (cek saldo wallet yang ada dulu; faucet Sepolia tanpa KTP) → tukar ke lREACT via faucet contract (maks 5 ETH/tx, 1 ETH = 100 lREACT). **TERBLOKIR 18 Nov ~16:00 WIB: semua wallet 0 ETH; 8 faucet dicoba via curl — pk910 butuh captcha, sisanya mati/503/butuh browser+akun. Butuh klaim faucet via browser ke 0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1 (lihat STATUS.md).**
- [ ] 19 Nov: deploy SentinelToken (Sepolia) + SentinelReactive (Lasna) + SentinelVerdict (Sepolia); danai keduanya. (Script siap: `scripts/deploy.sh`.)
- [ ] 19 Nov: **bukti loop pertama**: kirim transfer ≥ ambang → `react()` terpanggil di Lasna → callback ke Sepolia → `VerdictRecorded` (placeholder dulu). Catat alamat kontrak + hash tx di STATUS.md.

### Tahap 2 — AI masuk ke loop (20–22 Nov) — SELESAI LEBIH AWAL 18 Nov 2026
- [x] 18 Nov: watcher Node.js — baca event dari reactive contract, panggil Groq gpt-oss-120b (free tier), kirim keputusan via `submitDecision()`. (Desain berubah: reactive v3, `react()` hanya pending + event; `submitDecision()` owner-only yang meminta callback. Verdict v3 baru karena `_CALLBACK_SENDER` immutable terikat reactive v3. Watcher: `watcher/watch.js` + `groq_classify.py`, jalan tiap 3 menit via cron.)
- [x] 18 Nov: end-to-end penuh dengan AI: transfer 2.000 SENT ke alamat baru → klasifikasi model **"suspicious"** + alasan → callback berisi verdict model → tercatat on-chain (`VerdictRecorded`, blok Sepolia 12161024, reasonHash = keccak(alasan) terverifikasi). 14/14 forge test lolos.
- [ ] 22 Nov: uji ketahanan: beberapa transfer berturut-turut (normal + besar + berulang), pastikan tidak ada revert di `react()` (revert tetap ditagih!), cek debt/reserves, pastikan gas callback ≥100.000.

### Tahap 3 — Repo publik + dokumentasi (23–27 Nov) — DIPAJUKAN KE 18 Nov
- [x] 18 Nov: repo lokal disiapkan — README lengkap (arsitektur, cara run, alamat + tx hash), LICENSE MIT, docs dibersihkan dari catatan internal, `groq_classify.py` kini mendukung `GROQ_API_KEY` env (reproducible untuk publik).
- [ ] Repo GitHub publik `guplak042-spec/reactive-meets-ai` — dibuat di github.com (langkah browser) lalu push.
- [ ] 26–27 Nov: bersih-bersih kode (readability = kriteria Craft), verifikasi kontrak di explorer (Sourcify).

### Tahap 4 — Demo video + submit (28 Nov–4 Des)
- [ ] 28–30 Nov: skrip demo; rekam layar (ffmpeg/screen recording) — video <3 menit: transfer → AI memutuskan → verdict on-chain.
- [ ] 1–2 Des: review akhir (QC visual + cek semua syarat submit: repo publik, alamat kontrak, hash tx, video).
- [ ] 3 Des: isi form submit DoraHacks (butuh wallet connect — langkah browser).
- [ ] 4 Des: **SUBMIT**. Simpan bukti submit (screenshot/ID).

## Aturan selama build

- Tanpa KTP/data pribadi. Registrasi/payout hanya email/GitHub/wallet. Kalau DoraHacks minta dokumen identitas: STOP, laporkan.
- Tanpa uang sungguhan. Lasna testnet + faucet saja. Jangan deploy mainnet berbayar, jangan beli REACT.
- Private key/seed TIDAK PERNAH masuk chat, file yang dibagikan, atau repo. Keypair mode 600 di workspace.
- AI harus tetap di dalam sistem yang berjalan (watcher Groq), bukan sekadar alat tulis kode.
- Setiap deploy + loop dicatat: alamat kontrak, hash tx, explorer link — di STATUS.md.

## Blocker yang diketahui (18 Nov)

1. **Faucet lREACT butuh Sepolia ETH** — belum ada Sepolia ETH yang terverifikasi di wallet tim. Solusi: cek saldo wallet EVM yang ada (0x9283…87af dkk); kalau kosong, faucet Sepolia tanpa akun/KTP.
2. **Repo GitHub publik belum bisa dibuat dari sini** (konektor 403; gh CLI belum login) — tidak memblokir build; diselesaikan tahap 3.
3. **Video demo <3 menit** — video generation AI diblokir permanen; pakai screen recording di tahap 4.
