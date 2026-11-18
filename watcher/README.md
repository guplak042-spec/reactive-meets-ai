# Sentinel watcher — Groq AI in the loop (tahap 2)

Service yang membuat AI menjadi pengambil keputusan di dalam loop Sentinel,
bukan sekadar anotasi: callback ke Sepolia baru diminta SETELAH Groq
mengklasifikasi transfer (lihat `SentinelReactive.submitDecision`).

## Alur

1. Transfer ≥ 1.000 SENT di Sepolia → `SentinelReactive` v3 (Lasna) mencatat
   pending + emit `TransferFlagged` (tidak ada callback dulu).
2. `watch.js` (polling) membaca event baru dari Lasna, mengumpulkan fakta
   on-chain dari Sepolia (riwayat pengirim/penerima SEBELUM transfer ini),
   lalu memanggil `groq_classify.py` → Groq `openai/gpt-oss-120b` (free tier)
   mengembalikan `{"label": "normal"|"whale"|"suspicious", "reason": "..."}`.
3. Watcher memanggil `submitDecision(txHash, label, reasonHash)` di Lasna,
   dengan `reasonHash = keccak256(reason)`. Baru di titik ini reactive
   meminta callback ke `SentinelVerdict` v3 di Sepolia.
4. Relayer Reactive mengantar callback → `VerdictRecorded` on-chain membawa
   label AI + reasonHash. Teks alasan lengkap ada di `decisions.jsonl` dan
   STATUS.md; siapa pun bisa memverifikasi `keccak256(reason) == reasonHash`.

## Menjalankan

```bash
node watcher/watch.js        # sekali jalan (single pass), lalu keluar
```

Dijadwalkan tiap 3 menit via cron `sentinel-watcher` (dibuat saat tahap 2
selesai dibuktikan). Single-pass + `state.json` (checkpoint blok + keputusan
yang sudah diproses) membuat service tahan restart VM: tidak ada proses
panjang yang bisa mati diam-diam, dan item yang gagal tetap ada di
`state.retry` untuk dicoba lagi di run berikutnya.

## File

- `watch.js` — poller Node.js, tanpa dependensi npm (hanya built-in).
  Membaca event Lasna via `fetch`, memanggil Groq lewat `groq_classify.py`,
  mengirim `submitDecision` lewat `scripts/send_raw.py` (key dibaca dari
  `.wallet/keypair.json` saat runtime — tidak pernah ada di perintah).
- `groq_classify.py` — memanggil Groq chat completions (kunci API via env
  `GROQ_API_KEY`, `User-Agent: curl/8.5.0` karena Cloudflare memblokir UA
  Python-urllib), `reasoning_effort: "low"`, `max_tokens` 800, temperature 0.2.
  Model yang memutuskan label; watcher hanya mengumpulkan fakta. Fakta
  dilewat via FILE (bukan stdin): pengantaran stdin dari Node `child_process`
  tidak bisa diandalkan di beberapa environment (child bisa menggantung
  menunggu EOF).
- `state.json` — checkpoint (`lastBlock`, `processed`, `retry`). Dibuat
  otomatis saat run pertama (mulai dari blok deploy reactive v3).
- `decisions.jsonl` — satu baris JSON per keputusan AI (fakta, label,
  alasan, hash tx `submitDecision`).

## Keamanan

- Testnet saja (Sepolia + Lasna). Tidak ada uang sungguhan.
- Private key tidak pernah ditulis sebagai literal di perintah mana pun.
- Groq free tier: 30 req/menit, 1.000 req/hari — watcher hanya memanggil
  Groq sekali per transfer yang di-flag, jadi jauh di bawah batas.
