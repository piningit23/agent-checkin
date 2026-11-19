# Agent Check-in — Binance Agent ID Hackathon

Check-in harian khusus pemegang **Binance Agent ID** (`name.ai`). Check-in pertama
mint badge NFT **soulbound gratis**; check-in harian beruntun menaikkan streak.
Use case: **access control** — disebut eksplisit di pengumuman hackathon.

- Pengumuman: https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf
- Total hadiah: **60.000 USDC** (Project Awards 29.000 + Innovation Award 29.000 + Promotion 2.000)
- Periode submit: **18 Nov 2026 08:00 UTC — 9 Des 2026 08:00 UTC**
- Kontrak Agent ID (SPACE ID, BSC mainnet): `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (ERC-721, non-transferable)

## Cara kerja kontrak

`src/AgentCheckin.sol` (Solidity 0.8.20, OpenZeppelin ERC721):

| Fungsi | Keterangan |
|---|---|
| `checkIn()` | Check-in hari ini. Syarat: `balanceOf(msg.sender) > 0` di kontrak Agent ID. Sekali per hari (hari UTC). Check-in pertama mint badge soulbound. |
| `streak(address)` | Streak hari beruntun. +1 kalau kemarin juga check-in, reset ke 1 kalau ada hari bolong. |
| `badgeOf(address)` | Token id badge user (0 = belum punya). Satu badge per user. |
| `canCheckInToday(address)` | Apakah user bisa check-in hari ini. |
| `tokenURI(tokenId)` | Metadata on-chain (JSON base64 + SVG) dengan atribut streak live. |
| `currentDay()` / `totalCheckins` | Hari UTC saat ini / total check-in semua user. |

Soulbound: `_update()` hanya mengizinkan mint (`from == address(0)`); semua
transfer / burn revert. Kontrak **tidak** memegang dana, tidak minta approval,
tidak ada fungsi admin/owner, dan hanya membaca `balanceOf()` dari kontrak
Agent ID. Sesuai safety red lines hackathon: tanpa QR login, tanpa bypass
konfirmasi user, tanpa transfer tanpa izin, tanpa kumpul seed/key.

## Test

```bash
cd ~/workspace/agent-hackathon
forge test
```

Hasil (19 Nov 2026): **10/10 PASS** — non-holder revert, mint badge pertama,
revert check-in ganda di hari yang sama, streak naik hari berikut, reset streak
kalau bolong sehari, soulbound (transfer revert), badge unik per user, event,
`tokenURI` data URI.

Audit statis: `slither src/AgentCheckin.sol` — **0 temuan di atas INFO**.
Yang muncul hanya INFO by-design: perbandingan hari (memang fitur) dan
"reentrancy" via `_safeMint` (semua state di-update SEBELUM mint, jadi
reentrancy tidak bisa dieksploitasi — check-in ulang di hari sama pasti revert).

## Test lokal (anvil)

```bash
anvil --port 8545 --chain-id 31337   # terminal 1
forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 \
  --broadcast --private-key <ANVIL_DEV_KEY>   # kunci dev anvil saja, BUKAN kunci Bos
```

Terverifikasi 19 Nov 2026 di anvil: deploy sukses, check-in hari 1 mint badge #1
(streak 1), check-in hari 2 streak 2.

## Deploy mainnet (BUTUH PERSETUJUAN EKSPLISIT BOS — belum dilakukan)

```bash
export RPC_URL="https://bsc-dataseed.binance.org/"
export PRIVATE_KEY="<kunci deployer — jangan pernah tempel di chat>"
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
# Verifikasi source di BscScan (wajib hackathon):
forge verify-contract <ALAMAT_KONTRAK> src/AgentCheckin.sol:AgentCheckin \
  --chain-id 56 --etherscan-api-key $BSCSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address)" 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)
```

## Estimasi gas (diukur di anvil, 19 Nov 2026)

Harga BNB saat ukur: **~$592,53** (Finnhub, 19 Nov 2026 13:07 UTC).

| Aksi | Gas | @1 gwei | @3 gwei | @5 gwei |
|---|---|---|---|---|
| Deploy `AgentCheckin` | 1.678.099 | 0,001678 BNB (~$0,99) | 0,005034 BNB (~$2,98) | 0,008390 BNB (~$4,97) |
| Check-in pertama (mint badge) | 194.571 | 0,000195 BNB (~$0,12) | 0,000584 BNB (~$0,35) | 0,000973 BNB (~$0,58) |
| Check-in harian berikutnya | 52.482 | 0,000052 BNB (~$0,03) | 0,000157 BNB (~$0,09) | 0,000262 BNB (~$0,16) |

Gas BSC mainnet bisa berbeda sedikit dari anvil; angka di atas patokan kasar.

## Frontend

`frontend/index.html` — halaman statis, tanpa backend, tanpa simpan session:

- Connect wallet via MetaMask (user yang klik sendiri, tanpa QR).
- Cek `balanceOf()` Agent ID, tampilkan streak + badge (gambar dari `tokenURI`).
- Tombol check-in → kirim `checkIn()`; user konfirmasi sendiri di wallet.
- Isi alamat kontrak setelah deploy (atau override test: `index.html?contract=0x...`).
- Butuh hosting statis sebelum submit (mis. GitHub Pages / IPFS / Vercel).

## Checklist submit hackathon

- [ ] Deploy `AgentCheckin` ke **BNB Chain mainnet** (butuh gas Bos, tunggu persetujuan).
- [ ] Verifikasi source + open-source di **BscScan**.
- [ ] Hosting frontend (website proyek) — wajib diisi saat submit.
- [ ] Submit: nama proyek, website, alamat kontrak, deskripsi penggunaan Agent ID.
- [ ] **Innovation Award**: produk live + minimal **30 alamat Agent ID** sudah berinteraksi selama periode submit — ini syarat paling berat; butuh promosi ke komunitas Agent ID (badge gratis + streak adalah umpannya).
- [ ] **Project Awards**: ranking dari data on-chain (jumlah alamat Agent ID berinteraksi, volume/tx) — sama, butuh user nyata.
- [ ] Patuhi red lines: tanpa QR login, tanpa bypass konfirmasi, tanpa janji return, tanpa pakai nama "Binance"/"BNB" di nama proyek/domain.
- [ ] Jalur Promotion (terpisah): posting X dengan `#BinanceWalletHackathon` + `#AgenticWallet`, submit link via survei Binance — 20 pemenang @ 100 USDC.

## Yang masih kurang sebelum submit

1. **Belum deploy mainnet** — butuh persetujuan + gas Bos.
2. **Belum ada website live** — frontend sudah jadi, belum di-hosting.
3. **0 interaktor Agent ID** — butuh minimal 30 untuk Innovation Award; perlu promosi.
4. **Nama proyek final** — saat ini "Agent Check-in"; jangan pakai kata "Binance"/"BNB" di nama/domain.
5. **Jalur Promotion X** — dikerjakan terpisah dari dApp ini.
