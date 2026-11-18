# STATUS — Reactive Meets AI ("Sentinel")

> Build log, published for transparency. All addresses and transaction hashes
> below are public on the Sepolia and Lasna testnets. No private keys or
> keypair contents are recorded anywhere in this repo.

Terakhir update: 18 Nov 2026 ~18:00 WIB (TAHAP 2 SELESAI — AI GROQ IN-THE-LOOP TERBUKTI).

## Ringkasan

- Event: Reactive Omni Buildathon, deadline submit **Sabtu 5 Des 2026 20:00 UTC = Minggu 6 Des 2026 03:00 WIB**. Target internal submit: Jumat 4 Des 2026.
- Track: Reactive Meets AI, $1.000 (juara 1), dibayar REACT.
- Konsep: **Sentinel** — AI triage transfer mencurigakan (lihat CONCEPT.md). Loop: Transfer token Sepolia → reactive Lasna → AI (Groq gpt-oss-120b) klasifikasikan → callback ke Sepolia mencatat verdict on-chain.
- **KTP/KYC: TIDAK disyaratkan** di dokumen resmi mana pun (halaman DoraHacks, blog, Terms of Use — 0 hasil "KYC"). Wallet EVM syarat platform; payout REACT via wallet.
- **✅ LOOP LIVE TERBUKTI 18 Nov ~17:40 WIB** — transfer 2.000 SENT (Sepolia) → react Lasna → callback Sepolia → `VerdictRecorded` on-chain ("PENDING_AI", reasonHash = keccak(tx transfer)). Dua bug live ditemukan + diperbaiki sepanjang jalan (verdict belum didanai; gas limit callback 200k → 500k). Tahap 1 SELESAI PENUH.
- **✅ AI IN-THE-LOOP TERBUKTI 18 Nov ~17:59 WIB** — transfer 2.000 SENT ke alamat baru → watcher Groq `gpt-oss-120b` mengklasifikasi **"suspicious"** ("2000 SENT (0.2% supply) sent to a brand-new address with no prior activity, a large first-time transfer that could indicate testing or laundering.") → `submitDecision` Lasna → callback Sepolia → `VerdictRecorded` on-chain membawa label AI + reasonHash = keccak256(alasan) ✅ (terverifikasi cocok). TIDAK ADA lagi placeholder "PENDING_AI". Set aktif v3 (lihat tabel Live v3). Tahap 2 SELESAI PENUH (lebih cepat dari jadwal 20–22 Nov).

## Kemajuan tahap 1

- [x] Riset DoraHacks (deadline pasti, syarat registrasi/payout, judging) — selesai 15:25 WIB.
- [x] Riset docs Reactive (Foundry, Solidity ^0.8.29, reactive-lib-omni, Lasna RPC 5318007, faucet, pola Omni, perangkap) — selesai 15:26 WIB.
- [x] Foundry 1.9.0 terpasang (forge + cast).
- [x] CONCEPT.md + BUILD-PLAN.md ditulis; konsep Sentinel dipilih.
- [x] Scaffold Foundry + git init + README (commit `7da5e21`, lalu commit tahap 1 lanjutan) — `contracts/` (src, script, test), `scripts/deploy.sh`.
- [x] Wallet build baru: **0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1** (keypair di `.wallet/keypair.json`, mode 600, `.wallet/` di .gitignore; HANYA alamat yang dilaporkan). Keypair terverifikasi: private key → alamat cocok (dicek independen via eth-keys).
- [x] Kontrak compile + **9/9 forge test lolos** (termasuk loop end-to-end dengan log Transfer asli + mock system contract).
- [x] Deploy script tervalidasi di anvil lokal + **loop penuh tersimulasi di anvil** (lihat bukti di bawah).
- [x] Deploy live Sepolia + Lasna — **SELESAI 18 Nov ~17:0x WIB** (dana 0,29 Sepolia ETH masuk; v1 lalu v2 setelah perbaikan gas limit; lihat tabel Live).
- [x] Bukti loop pertama live (transfer → react Lasna → callback Sepolia → VerdictRecorded) — **TERBUKTI 18 Nov ~17:40 WIB via set v2** (transfer #3, 2.000 SENT; callback dieksekusi relayer 1 blok setelah transfer). Callback #1/#2 (set v1) tidak pernah dieksekusi — lihat "Dua bug live" di tabel Live.
- [ ] Tahap 2: AI watcher Groq masuk ke loop (20–22 Nov).
  - [x] 18 Nov: reactive v3 — `react()` hanya mencatat pending + emit `TransferFlagged`; `submitDecision()` (owner-only) yang meminta callback dengan label AI. 14/14 forge test lolos (9 lama + 5 baru).
  - [x] 18 Nov: watcher Node.js tanpa dependensi (`watcher/watch.js` + `watcher/groq_classify.py` + `watcher/state.json` + `decisions.jsonl`); cron `sentinel-watcher` tiap 3 menit (run pertama ~18:02 WIB).
  - [x] 18 Nov: **E2E AI terbukti** — transfer #4 (2.000 SENT ke alamat baru) → Groq "suspicious" → `VerdictRecorded` on-chain dengan label AI (lihat tabel Live v3).
  - [ ] 22 Nov (opsional, sebelum demo): uji ketahanan — beberapa transfer berturut-turut (normal + besar + berulang), cek debt/reserves.
- [x] Tahap 3: repo GitHub publik + dokumentasi — **dipajukan ke 18 Nov**:
  repo lokal disiapkan (README, LICENSE, docs dibersihkan); pembuatan repo
  publik `guplak042-spec/reactive-meets-ai` di github.com + push menyusul
  (langkah browser).
- [ ] Tahap 4: video demo screen recording <3 menit + submit (28 Nov–4 Des).

## Kontrak

### Live (Sepolia / Lasna) — DEPLOY 18 Nov 2026 ~17:0x WIB

| Item | Nilai |
|---|---|
| SentinelToken (Sepolia) | 0x1DAF205424104F8a9249bA5F3AD5466887a9C888 — tx deploy 0x4beb45ca1e79eebe85b0a3ad61e34884f2a89bc90f74fc8fd4890b3326953207 (status 1, totalSupply 1.000.000 SENT) |
| SentinelReactive (Lasna) | 0x1daf205424104f8a9249ba5f3ad5466887a9c888 — tx deploy 0x43f1f684b0d0b1bd7df08017fe5af111a607dccf3653db81d2dfd4b9b88b4e86 (status 1, blok 0x83da84, gas 457.797). **Alamat SAMA dengan token di Sepolia** — kebetulan deterministik CREATE (sender + nonce 0 sama di kedua chain); chain berbeda, tidak konflik. Terverifikasi: token() = alamat token Sepolia, threshold() = 1000e18, owner() = wallet build. |
| SentinelVerdict (Sepolia) | 0xfb38ea2724a03f29e87874109248ed89915facd5 — tx deploy 0xdbec5cf0321f41fd74f40d74cd05f0d1b18c7fd52308f73e9f55fa7fc4ee16c4 (status 1). Callback proxy 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4, callbackSender = reactive. |
| Recipient ter-set (Lasna) | tx 0xa0ce663635ca2959e0244fea81f4079cb4abfd5c963155f4eece5681c6721988 (status 1, blok 0x83dcb3, event RecipientSet); recipient() = 0xfb38…facd5 ✅ |
| Faucet ETH→lREACT | tx 0xde466903c905357f76841da5a66597e4b33c7ca9643ec0790de1a29789f97f62 (status 1, blok 12126208): 0,1 Sepolia ETH → **10,5 lREACT** (saldo Lasna wallet, termasuk 0,5 yang sudah ada) |
| Dana reactive (lREACT) | tx 0xa25a8c85f778666c476bbdd39857b0158d2e6244228a9405cc032ede822c4db3 (status 1, blok 0x83dd9f): 1 lREACT ke reactive contract (saldo 0xde0b6b3a7640000 = 1e18 wei) |
| Tx loop pertama (transfer) | **0xbef29b7ac48578691c884d786d571b954519010d9736ad8548a29e639023d984** (status 1, blok Sepolia 12160603): 1.500 SENT dari wallet build ke tim 0x9283…87af |
| Tx loop pertama (reactive) | **0xfc5f180c8f55be37c1e5ce973495c2505739f8980c91e56e75aa6b831a37b065** (status 1, blok Lasna 0x83ddb6, gas 88.591): `TransferFlagged` ter-emit (from, to, 1500 SENT, txHash transfer) + system contract 0x8888…8888 mencatat callback (topic 0xef94dbc6…, chain 11155111, reactive 0x1daf…, recipient 0xfb38…). Debt reactive di system contract = **0**. |
| Tx callback (destination) | ⏳ **BELUM MUNCUL** — `VerdictRecorded` di SentinelVerdict masih kosong setelah ~40 menit (callback #1) dan ~7 menit (callback #2, lihat bawah). **PENYEBAB DITEMUKAN: kontrak callback (SentinelVerdict) BELUM DIDANAI di Sepolia** — menurut docs resmi Reactive (dev.reactive.network/economy), "Contracts must stay funded on both sides": callback proxy menagih biaya delivery ke kontrak callback dalam ETH chain tujuan; proxy tidak akan deliver bila kontrak tidak punya dana. Perbaikan: depositTo() 0,05 Sepolia ETH ke proxy (tx 0x5c3681c49615d6354de7b6dc7efd7470af9a1e35cc3215c168580e1f2b1165cc, blok 12160776, status 1) → reserves(verdict) = 0,05 ETH ✅. Callback #1 (yang diminta saat verdict belum didanai) tampaknya TIDAK di-retry otomatis — getCallbacks(reactTx #1) = array kosong. Transfer kedua 1.200 SENT dilakukan sebagai pemicu baru (tx 0x287dc9b7c20dbf21a61b22b40d8a31195499c07bb2fd05da517810e6256c2796, blok 12160791): react #2 ✅ (tx Lasna 0x994702c9eea0e648394a36ffc3a68dbf303e1d4b23f38449036cb2fdd8121d1b, blok 0x83e618, TransferFlagged ter-emit); callback #2 tidak pernah dieksekusi (set v1, gas limit 200k — lihat baris v1 di bawah). |
| Dana verdict (Sepolia ETH) | tx 0x5c3681c49615d6354de7b6dc7efd7470af9a1e35cc3215c168580e1f2b1165cc: depositTo() 0,05 ETH ke callback proxy 0xAa14…23b4 → reserves(SentinelVerdict) = 0,05 ETH. Proxy config: _extraGas = 150.000, _gasPriceCoeffPer1000 = 1100. |
| Tx loop kedua (transfer) | **0x287dc9b7c20dbf21a61b22b40d8a31195499c07bb2fd05da517810e6256c2796** (status 1, blok Sepolia 12160791): 1.200 SENT dari wallet build ke tim 0x9283…87af |
| Tx loop kedua (reactive) | **0x994702c9eea0e648394a36ffc3a68dbf303e1d4b23f38449036cb2fdd8121d1b** (blok Lasna 0x83e618): `TransferFlagged` ke-2 ter-emit; getCallbacks(reactTx #2) = array kosong (callback tidak pernah dieksekusi — set v1, gas limit 200k) |
| Tx callback (destination) — v1 | ❌ **TIDAK PERNAH DIEKSEKUSI.** Dua penyebab (lihat baris di atas): verdict v1 belum didanai saat callback #1 diminta, DAN gas limit 200.000 terlalu kecil (proxy menyisihkan _extraGas 150.000 + _maxChargeGas 50.000 → 0 gas tersisa untuk verdict()). Set v1 dipensiunkan; set v2 yang aktif. |

### Live v2 — SET AKTIF (deploy 18 Nov 2026 ~17:35 WIB, gas limit 500k, commit 14484fc)

| Item | Nilai |
|---|---|
| SentinelToken (Sepolia) | 0x1DAF205424104F8a9249bA5F3AD5466887a9C888 — sama seperti v1 (tidak berubah) |
| SentinelReactive v2 (Lasna) | **0x9ffaa0850bc3e2ed74dd38ceaab1d129f06e3ce3** — tx deploy 0x37334df409d0fc169342c7e2af3cf336eaf5cb669d63cf74b9731f629b4451f2 (status 1, blok 0x83e8b5, gas 457.797). Terverifikasi: token() = alamat token, threshold() = 1000e18, CALLBACK_GAS_LIMIT() = 500.000, owner() = wallet build. |
| SentinelVerdict v2 (Sepolia) | **0xe755D37713C92C58a2fb09Ffc8e75c6618bD1f82** — tx deploy 0xd54070b96505d63f00d0e468d001540eda5d7c99d0911eea4248c2894b2ca67e (status 1). Callback proxy 0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4, callbackSender = reactive v2. |
| Recipient v2 ter-set (Lasna) | tx 0x1310a7c43cdebd344548b9095760a1144985583bf4a014196f8df4182d9277a0 (status 1, blok 0x83e8f1); recipient() = 0xe755…1f82 ✅ |
| Dana reactive v2 (lREACT) | tx 0xfe246c577a50818026ce69cf1321b084acb8c7a76b92b0a9c7aae1d4761f86eb (status 1, blok 0x83e900): 1 lREACT |
| Dana verdict v2 (Sepolia ETH) | tx 0x69b07b19dc7312e86ade7cdf0641dc676da0079bf1674b3d6ab5da5227260ea9 (status 1, blok 12160857): depositTo() 0,05 ETH → reserves = 0,05 ETH |
| **LOOP LIVE TERBUKTI — transfer #3** | **0x877b6e1510b3c487e5be49002c856a35326685241cb0c9d64849a6e8f0376cd3** (status 1, blok Sepolia 12160857): 2.000 SENT dari wallet build ke tim 0x9283…87af |
| **LOOP LIVE TERBUKTI — react v2** | **0xd52ad518e508fe4d555e9274fed7c6a292b325b00d423bc2ae6d60417f97cbac** (blok Lasna 0x83e918): `TransferFlagged` ter-emit |
| **LOOP LIVE TERBUKTI — callback** | **0x046b2dc9e539fa2ddc92459147298bc486de55adc1c6a54c27cd31ce343abf04** (status 1, blok Sepolia 0xb98f5a — 1 blok setelah transfer!, gas 70.486, dari relayer 0xf7e866d7…): **`VerdictRecorded` ter-emit di SentinelVerdict v2** — from 0x361F…a3e1, to 0x9283…87af, amount 2.000 SENT, label "PENDING_AI", reasonHash 0x0496d42f0e9b82c8cabd87cc46533e74bc895478ae05122c1510bc825eaca66e = keccak256(tx transfer #3) ✅. Biaya callback: reserves verdict v2 turun 0,05 ETH → 49.999.999.996.548.948 wei (terpotong ±0,0000000035 ETH), debt 0. |
| Catatan | getCallbacks(reactTx) di system contract Lasna mengembalikan array kosong BAHKAN untuk callback yang sudah terbukti ter-deliver (dicek setelah VerdictRecorded muncul) — kemungkinan record ditulis validator dengan delay, atau query-nya butuh format lain. Bukan blocker: VerdictRecorded + receipt callback adalah bukti definitif. |

### Live v3 — SET AKTIF (deploy 18 Nov 2026 ~17:36 WIB; AI in-the-loop, commit menyusul)

Alasan v3: di v1/v2, `react()` langsung meminta callback dengan label hardcode `"PENDING_AI"` — AI hanya anotasi pasca-fakta, bukan pengambil keputusan, karena payload callback sudah terkunci saat diminta. Di v3, `react()` HANYA mencatat pending + emit `TransferFlagged`; callback baru diminta saat watcher AI memanggil `submitDecision(txHash, label, reasonHash)`. Konsekuensi yang diverifikasi dari kode: `SentinelVerdict._CALLBACK_SENDER` bersifat immutable dan terikat alamat reactive — verdict v2 (terikat reactive v2) akan menolak callback dari reactive v3 (`CallbackNotAuthorized`), jadi verdict v3 WAJIB di-deploy dengan `callbackSender` = reactive v3. Instruksi "kirim ke Verdict v2" di brief tahap 2 TIDAK BISA dipenuhi — ini koreksi desain, bukan blocker.

| Item | Nilai |
|---|---|
| SentinelReactive v3 (Lasna) | **0xe755d37713c92c58a2fb09ffc8e75c6618bd1f82** — tx deploy 0x75829d695a859a5838c02af23cf23753ad7b8902751701ab271fc077d0edc032 (status 1, blok Lasna 0x83eb7c, gas 0x90a36, nonce 6). Terverifikasi: token() = alamat token Sepolia, threshold() = 1000e18, owner() = wallet build, recipient() = verdict v3. **Alamat ini SAMA dengan verdict v2 di Sepolia** — kebetulan deterministik CREATE (sender + nonce 6 sama di kedua chain); chain berbeda, tidak konflik. |
| SentinelVerdict v3 (Sepolia) | **0x42c393834692a0c9bbb3910c34612b13e0b05f54** — tx deploy 0x58634204937de3b881805236fdc915743a7d8245360c033d2676809236c70f37 (status 1, blok 12160916, nonce 9). Terverifikasi: `_CALLBACK_SENDER()` = reactive v3 ✅, code ada. |
| Recipient v3 ter-set (Lasna) | tx 0x79a3b888844d388a1d5d7adb45c0980c21fc9c1cc7737543b673eb7da0acd02f (status 1, blok 0x83ebcf, nonce 7); recipient() = 0x42c3…05f54 ✅ |
| Dana reactive v3 (lREACT) | tx 0x4a3dce6b1939df26a0338bd0b3c1e20f6396de792e9d32b46c9e1aefcfe84c5c (status 1, blok 0x83ebda, nonce 8): 1 lREACT native → saldo reactive v3 = 1,0 lREACT ✅ |
| Dana verdict v3 (Sepolia ETH) | tx **0xfa5ab26def507a95621633979d634f30a2f110123f8f50c117cdeb945a04d491** (status 1, blok 12160920, nonce 10): depositTo(verdict v3) 0,05 ETH → reserves(verdict v3) = 0,05 ETH ✅ (hash ditemukan lewat scan blok setelah RPC putus saat broadcast — deposit terverifikasi via reserves()). |
| Reactive v2 DINONAKTIFKAN | tx 0xe2afb116498f31480f242df3ebbf677851bf8224975ec7de9084d3398ad62732 (status 1, blok Lasna 0x83ec95, nonce 9): setRecipient(0x0) → recipient() v2 = 0x0 ✅. Alasan: v2 masih subscribe ke token yang sama; tanpa ini tiap transfer memicu DUA callback (PENDING_AI dari v2 + label AI dari v3). |
| **LOOP AI TERBUKTI — transfer #4** | **0x64c2eaed6cfec22da2d9b0ab4a68f4c54ad66c1468e9e7f30966a54658989456** (status 1, blok Sepolia 12160959, nonce 11): 2.000 SENT dari wallet build ke alamat BARU 0xC325Cd173306a60e80c5846d7d31CbfE9Eb29478 (dibuat khusus untuk uji ini). |
| **LOOP AI TERBUKTI — react v3** | tx Lasna 0x99b9f10b0b2ae296169fc6e33ac894ef6dd97b472d841e51c628cffea0e7f40e (blok 0x83edcd = 8646093): `TransferFlagged` ter-emit; pending(txHash) = 2.000 SENT ✅ |
| **LOOP AI TERBUKTI — klasifikasi Groq** | Model `openai/gpt-oss-120b` (free tier), fakta on-chain: pengirim 3 transfer sebelumnya (4.700 SENT), penerima 0 tx / 0 transfer sebelumnya / saldo 0 → label **"suspicious"**, alasan: *"2000 SENT (0.2% supply) sent to a brand-new address with no prior activity, a large first-time transfer that could indicate testing or laundering."* reasonHash 0x2c40d19f2759dd36e321550e660c14ad2de58ea38e0b393ca521b4269707739f. |
| **LOOP AI TERBUKTI — submitDecision** | tx Lasna **0x01df54f5d9ee801e95ecdcc52747b16fef68d59c20ee61f0247a3cf5498751ed** (status 1, blok 0x83f0a1 = 8646817): `submitDecision(txHash, "suspicious", reasonHash)` → `DecisionSubmitted` ter-emit; pending decided = true ✅ |
| **LOOP AI TERBUKTI — callback + VerdictRecorded** | tx Sepolia **0x6c4da867f6bfda1771a546838c46538343fadc679b944cbc6dafc5fe9e93e572** (status 1, blok 12161024, dari relayer 0xf7e866d7…): **`VerdictRecorded` ter-emit di SentinelVerdict v3** — from wallet build, to 0xC325…9478, amount 2.000 SENT, label **"suspicious"**, reasonHash 0x2c40d19f… ✅. **keccak256(alasan) == reasonHash terverifikasi cocok (dihitung independen via eth_utils).** TIDAK ADA "PENDING_AI" di loop ini. |
| Watcher | `watcher/watch.js` (Node, tanpa dependensi) + `watcher/groq_classify.py` + `watcher/state.json` (checkpoint blok Lasna 8646807, processed=1, retry=0) + `watcher/decisions.jsonl` (1 keputusan). Cron `sentinel-watcher` tiap 3 menit, run pertama ~18:02 WIB 18 Nov 2026. |

### Bukti loop di anvil lokal (18 Nov 2026, chain 31337)

Deploy script tervalidasi end-to-end dengan `--unlocked`:

| Item | Nilai |
|---|---|
| SentinelToken (anvil) | 0x5FbDB2315678afecb367f032d93F642f64180aa3 (totalSupply 1.000.000 SENT) |
| SentinelReactive (anvil) | 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 (threshold 1000 SENT, recipient ter-set) |
| SentinelVerdict (anvil) | 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 |
| Transfer 1.500 SENT | tx 0x863f2161b0856da483ac2b4ae5074202775b92c72d281ae795bc6ba27267d1e1 (blok 5) |
| react() (sbg system contract) | tx 0x26145071efe6e76911e0db35747257bdfa0d64c7832559836953aa4ecd09b43e, status sukses; `TransferFlagged` ter-emit; callback tercatat di mock system (chainId 11155111, recipient = Verdict, gasLimit 200.000, payload `verdict(..., "PENDING_AI", ...)` |
| verdict() (sbg callback proxy) | tx 0xade11ac70879e150f3d4488d8d6a25cfa470f75e3eafb1f14eb220f225823115, status sukses; `VerdictRecorded` ter-emit (from, to, 1500 SENT, "PENDING_AI", reasonHash keccak(txHash)) |

Catatan: di anvil, `react()` sempat revert saat memanggil system contract tanpa code
(`call to non-contract address`) — perilaku Solidity yang benar; di Lasna system
contract 0x8888…8888 punya code, jadi tidak terjadi. Mock system di-etch di anvil
untuk membuktikannya.

## Saldo (dicek 18 Nov ~18:00 WIB, setelah loop AI terbukti)

| Wallet | Sepolia ETH | Lasna lREACT |
|---|---|---|
| Build 0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1 | ~0,04 (0,29 masuk − 0,1 faucet − 0,05×3 depositTo − deploy verdict v3 − gas) | ~7,32 (10,5 − deploy v1+v2+v3, funding 1×3, gas) |
| SentinelReactive v1 0x1daf…9c888 (Lasna, nonaktif) | — | ~0,987 (terdanai 1,0; terpotong biaya react) |
| SentinelReactive v2 0x9ffa…3ce3 (Lasna, NONAKTIF — recipient di-0-kan 18 Nov) | — | ~0,99 (terdanai 1,0) |
| SentinelReactive v3 0xe755…1f82 (Lasna, AKTIF) | — | ~0,982 (terdanai 1,0; terpotong biaya react + submitDecision) |
| SentinelVerdict v1 0xfb38…facd5 (Sepolia, nonaktif) | reserves 0,05 ETH (terdanai, tidak terpakai) | — |
| SentinelVerdict v2 0xe755…1f82 (Sepolia, nonaktif — terikat reactive v2) | reserves ~0,05 ETH (terpotong ±0,0000000035 ETH untuk 1 callback) | — |
| SentinelVerdict v3 0x42c3…05f54 (Sepolia, AKTIF) | reserves ~0,05 ETH (49.999.999.997.019.546 wei — terpotong ±0,0000000030 ETH untuk callback #4) | — |
| SentinelToken 0x1DAF…9C888 (Sepolia) | — | — (totalSupply 1.000.000 SENT; wallet build pegang 993.300 setelah 4 transfer: 1.500 + 1.200 + 2.000 + 2.000; alamat baru 0xC325…9478 pegang 2.000) |

Lasna RPC (`https://lasna-rpc.rnk.dev/`) hidup via curl (chainId 0x512577 = 5318007);
`cast` sempat timeout ke Lasna — pakai curl/forge untuk cek Lasna.

## Blocker

1. **~~TIDAK ADA Sepolia ETH~~ TERSELESAIKAN 18 Nov ~17:00 WIB — 0,29 Sepolia ETH masuk ke wallet build** (faucet tx 0xdd330e87685942f56a5a050f5cbb527116d68a5d153b33445dbf1b7c21ffce5a, blok 12160453; saldo terverifikasi via RPC 0,29 ETH). Deploy live selesai; lihat tabel Live.
   Faucet Sepolia yang dicoba via curl (18 Nov ~16:00 WIB):
   - `sepolia-faucet.pk910.de` (PoW, tanpa akun): **captcha wajib** — `POST /api/startSession`
     → `{"status":"failed","failedCode":"INVALID_CAPTCHA","failedReason":"captcha check failed: captcha token missing"}`.
   - `faucet.sepolia.dev`: respons kosong / mati.
   - `faucet.triangleplatform.com`: HTTP 503.
   - `faucet.quicknode.com`: halaman SPA hidup, tapi butuh wallet connect + captcha di browser; tidak ada API publik.
   - `faucets.chain.link/sepolia`: hidup, butuh wallet connect di browser.
   - `sepolia-faucet.com`: redirect 302 (ke Alchemy signup).
   - Google Cloud faucet: butuh sign-in akun Google di browser.
   - `allthatnode.com/faucet`: butuh akun.
   **Langkah berikut (butuh klaim faucet via browser):** buka salah satu faucet di atas
   di browser, klaim Sepolia ETH ke alamat build **0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1**
   (minimal ~0,1 ETH cukup: deploy 3 kontrak + dana callback; 0,1 ETH → 10 lREACT via faucet
   Reactive). Setelah ETH masuk, jalankan: `scripts/deploy.sh token`, lalu
   `TOKEN=... scripts/deploy.sh reactive`, `REACTIVE=... scripts/deploy.sh verdict`,
   `REACTIVE=... RECIPIENT=... scripts/deploy.sh recipient`, lalu tukar ETH→lREACT via
   `cast send 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 "request(address)" <wallet> --value 0.1ether`
   (1 ETH = 100 lREACT, maks 5 ETH/tx).
2. **Private key TIDAK BOLEH dilewatkan sebagai literal di command exec** — key
   literal di perintah akan bocor ke shell history/log. Solusi: pakai `scripts/deploy.sh`
   (baca key dari `.wallet/keypair.json` saat runtime, tanpa literal di perintah)
   atau `--unlocked` di anvil. Keypair yang tersimpan sendiri terverifikasi cocok.
   **Tambahan 18 Nov ~17:0x WIB: RPC Lasna `https://lasna-rpc.rnk.dev/` MEMUTUSKAN koneksi TLS klien Rust foundry (forge/cast) secara intermiten** — `forge script` gagal 2x, `forge create` 2x, `cast estimate`/`cast send` gagal ("peer closed connection without sending TLS close_notify"), padahal curl/urllib ke RPC yang sama mayoritas berhasil. Solusi yang BERHASIL: `scripts/send_raw.py` (baru) — sign offline via eth-account (pip, di `/tmp/ethlibs`) + broadcast raw tx via urllib (dengan retry). Dipakai untuk: deploy SentinelReactive, setRecipient, funding lREACT. Perlu diingat untuk semua write Lasna berikutnya (submitDecision watcher, dll).
3. **Repo GitHub publik** belum bisa dibuat dari sini (konektor 403; gh CLI belum login) — tidak memblokir build; tahap 3.
4. **Video demo** — video generation AI diblokir permanen; pakai screen recording di tahap 4.
5. **Tahap 2 — tiga bug/limitasi baru yang ditemukan + diperbaiki 18 Nov ~17:50–18:00 WIB:**
   - **Node `child_process` `input` tidak mengantarkan stdin secara andal di beberapa environment** — child Python menggantung selamanya menunggu EOF. Perbaikan: `groq_classify.py` menerima fakta via FILE (argv), `watch.js` menulis temp file — jangan pernah pakai opsi `input` execFile di watcher.
   - **gpt-oss memotong JSON balasan** — budget `max_tokens` 400 habis untuk reasoning tersembunyi, JSON terpotong di tengah `reason`. Perbaikan: `reasoning_effort: "low"` + `max_tokens` 800 + parsing fallback lenient (regex ekstrak label/reason bila JSON tidak lengkap).
   - **Sepolia public RPC prune riwayat log** — `eth_getLogs` window 50.000 blok → error 4444 "pruned history unavailable". Perbaikan: window menyusut otomatis 5000 → 1000 → 200 blok; kalau tetap gagal, hitungan prior = 0 (model tetap dapat saldo + tx count penerima).
   - **Koreksi desain (bukan bug): verdict v2 TIDAK BISA dipakai untuk reactive v3** — `_CALLBACK_SENDER` immutable terikat alamat reactive; callback dari reactive baru akan revert `CallbackNotAuthorized` di Sepolia. Solusi: deploy verdict v3 dengan `callbackSender` = reactive v3 (lihat tabel Live v3).

## Langkah berikut

1. ~~Klaim Sepolia ETH via browser faucet ke 0x361Ff0DE45C2Ed52f5098FBdEa4eed45b5d6a3e1.~~ SELESAI — 0,29 ETH masuk 18 Nov ~17:00 WIB.
2. ~~Tukar sebagian ke lREACT, deploy via `scripts/deploy.sh` (urutan di atas), danai reactive (lREACT) + verdict (Sepolia ETH).~~ SELESAI — loop live terbukti.
3. ~~Buktikan loop live: transfer ≥ 1000 SENT → cek `getCallbacks` di system contract Lasna → cek `VerdictRecorded` di Sepolia; catat hash di tabel atas.~~ **SELESAI 18 Nov ~17:40 WIB.**
4. ~~Tahap 2: watcher Groq (baca event reactive → klasifikasi normal/whale/suspicious → submitDecision → callback berisi verdict model).~~ **SELESAI 18 Nov ~17:59 WIB — loop AI terbukti end-to-end (label "suspicious", reasonHash terverifikasi). Watcher jalan via cron `sentinel-watcher` tiap 3 menit.**
5. Tahap 3: repo GitHub publik + dokumentasi (23–27 Nov).
6. Tahap 4: video demo screen recording <3 menit + submit (28 Nov–4 Des).

## Verifikasi independen (18 Nov 2026 ~16:59 WIB)

- `forge test` dijalankan ulang independen: **9 passed, 0 failed** — klaim builder terkonfirmasi.
- Keypair: `.wallet/keypair.json` mode 600, direktori `.wallet/` mode 700, `.gitignore` menutupinya; `git ls-files` tidak menunjukkan file key — tidak ada key yang ter-commit. Terverifikasi.
- Git lokal: 2 commit (`7da5e21`, `ba0f220`). Repo GitHub publik belum ada.
- Tahap 1 dinyatakan SELESAI kecuali deploy live (terblokir dana — Blocker 1).
