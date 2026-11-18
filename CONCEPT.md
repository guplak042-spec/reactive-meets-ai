# CONCEPT — Reactive Meets AI ($1.000, DoraHacks Reactive Omni Buildathon)

- Event: Reactive Omni Buildathon, 5 Nov – 5 Des 2026 (deadline submit: **Sabtu 5 Des 2026 20:00 UTC = Minggu 6 Des 2026 03:00 WIB**).
- Track: Reactive Meets AI — hadiah $1.000 (juara 1 saja), dibayar REACT.
- Aturan kunci: AI harus bagian dari sistem yang BERJALAN, bukan sekadar alat bantu coding. Judging: Execution (gate — tanpa reactive tx + callback on-chain, tidak dinilai), Integration, Usefulness, Craft — masing-masing skala 1–5, bobot sama.
- Jaringan: Lasna testnet (RPC https://lasna-rpc.rnk.dev/, chain ID 5318007) sebagai reactive layer; Sepolia (11155111) sebagai origin + destination. Faucet lREACT: kirim Sepolia ETH ke 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 (1 ETH → 100 lREACT, maks 5 ETH/tx).
- Toolchain: Foundry (forge/cast), Solidity ^0.8.29, library reactive-lib-omni (AbstractReactive / AbstractCallback / AbstractPayer). Pola Omni terbaru: system contract 0x8888888888888888888888888888888888888888, `onlySystem`, `SYSTEM.requestCallbackV_1_0` (bukan `emit Callback` yang sudah deprecated).
- AI runtime: Groq `openai/gpt-oss-120b` (free tier, 30 req/menit, 1.000 req/hari, tanpa kartu) sebagai model yang memutuskan di dalam loop.

## Ide 1 — "Sentinel: AI triage untuk transfer mencurigakan" ✅ DIPILIH

**Alur loop (origin event → callback):**
1. Origin: kontrak token ERC-20 demo di Sepolia (`SentinelToken`) — setiap `Transfer` di atas ambang (mis. ≥ 1.000 token) adalah event yang dipantau.
2. Reactive contract di Lasna (`SentinelReactive`) subscribe `Transfer` token itu. Saat event cocok, `react()` menyimpan data event (from, to, amount, txHash) dan menandai ada keputusan yang dibutuhkan.
3. AI watcher (service Node.js kecil, jalan terus selama demo): membaca event dari reactive contract, memanggil Groq gpt-oss-120b dengan konteks (jumlah, alamat pengirim/penerima, riwayat transfer sebelumnya yang dibaca dari chain) dan meminta klasifikasi + aksi: `normal` / `whale` / `suspicious`, beserta alasan singkat.
4. Watcher mengirim keputusan itu on-chain lewat `submitDecision()` di reactive contract (hanya watcher wallet yang diotorisasi). Reactive contract lalu memanggil `SYSTEM.requestCallbackV_1_0` dengan payload berisi verdict.
5. Callback contract di Sepolia (`SentinelVerdict`) menerima callback (guard `onlyServiceProvider` + `onlyCallbackSender`), mencatat verdict on-chain lewat event `VerdictRecorded(from, to, amount, label, reasonHash)`.

**Kenapa AI benar-benar "in the loop":** tanpa model, tidak ada verdict dan tidak ada callback — isi payload callback (label + aksi) diproduksi model saat runtime, bukan hardcode. Reactive contract melakukan kerja nyata (filter ambang + routing), AI memutuskan isinya.

**Kenapa dipilih:**
- Paling mudah dieksekusi: origin adalah token yang kita deploy sendiri (kontrol penuh, tanpa dependensi DEX/testnet pihak ketiga); pola dasarnya = Basic Demo resmi (origin → reactive → callback) yang sudah terbukti.
- AI-in-the-loop paling jelas dan paling mudah dijelaskan ke juri dalam 1 kalimat.
- Paling mudah didemo: kirim satu transfer besar → verdict muncul on-chain dalam hitungan detik; video demo <3 menit sangat memungkinkan.
- Usefulness nyata: triase transfer besar / deteksi pola mencurigakan adalah masalah nyata (AML, whale alert), bukan mainan.

**Risiko & mitigasi:**
- Faucet lREACT butuh Sepolia ETH dulu — cek saldo wallet yang sudah ada; kalau kosong, cari faucet Sepolia yang hanya butuh alamat (tanpa KTP). Blocker ini ditangani tahap 1.
- Watcher off-chain harus jalan saat demo — repo menyertakan kode watcher + instruksi run; juri menilai dari tx hash + video, bukan uptime 24/7.
- Groq free tier rate limit — klasifikasi per event hanya 1 request; jauh di bawah 30 req/menit.

## Ide 2 — "AI rebalancer: penjaga vault" (cadangan)

Reactive contract memantau event `Sync` pair Uniswap V2 di Base Sepolia; AI memutuskan rebalance (buy/sell/hold) berdasarkan pergerakan harga + prompt strategi; callback mengeksekusi rebalance mock di vault contract.
**Tidak dipilih:** butuh DEX di testnet + kontrak mock lebih banyak; eksekusi "rebalance" di testnet terlihat seperti mainan; lebih sulit didemo dengan meyakinkan dalam 2 minggu.

## Ide 3 — "AI moderation: filter deposit vault komunitas" (cadangan)

Reactive contract memantau deposit ke vault di Sepolia; AI mengklasifikasi pola deposan (baru vs berulang, anomali jumlah); deposit normal masuk vault, yang ter-flag masuk kontrak karantina dengan alasan tercatat.
**Tidak dipilih:** tumpang tindih besar dengan Ide 1, tapi dengan permukaan serangan/narasi yang lebih lemah (karantina dana pengguna lebih sulit dibenarkan sebagai "berguna" dibanding triase informatif).

## Struktur repo (rencana)

```
reactive-meets-ai/
  contracts/        # Foundry project: SentinelToken, SentinelReactive, SentinelVerdict
  watcher/          # Node.js service: baca event -> Groq -> submitDecision
  docs/             # arsitektur, cara run, alamat + tx hash
  demo/             # skrip demo + rekaman layar (akhir)
  CONCEPT.md  BUILD-PLAN.md  STATUS.md  README.md
```

## Keputusan

**Membangun Ide 1 (Sentinel).** Target tahap 1 (18 Nov): scaffold + loop dasar tanpa AI terbukti on-chain (transfer → react → callback → verdict placeholder). Tahap 2 (19–21 Nov): sambungkan AI watcher Groq sebagai pengambil keputusan. Tahap 3 (22 Nov–4 Des): polish, demo video, submit.
