# October 28 restart review

## Confirmed evidence

- the local workstation: Apple M4 Pro, 24 GiB unified memory, macOS 15.3.1 (24D70).
- The system rebooted at 20:43 local time. The panic report was written at 20:44.
- The panic reason was a watchdog timeout: the system watchdog had received no check-in for 90 seconds.
- The report identifies `kernel_task` as the panicked task. Its compressor section records 81% of the compressed-page limit, 90% of the segment limit, **40 swap files and low swap space**.
- Before the trial, the internal disk had roughly 5 GiB free. Putting model files on an external drive did not reserve internal swap space or provide additional RAM.
- ACE-Step generation and a Godot headless import had been launched near the restart. Neither temporary log survived the reboot. The model's output directory was empty afterward.
- After restart, internal free disk space was roughly 51 GiB. No ACE-Step process was running.

The source is the local `panic-base+socd-2026-10-28-204412.000.panic` diagnostic. The complete panic dump is intentionally not included in the public repository; it contains machine-specific identifiers and unrelated system details.

## What this establishes

There is evidence of exhausted swap headroom and a system stall. It does **not** identify which application caused the stall. There is no explicit GPU fault in the panic reason, and no surviving generation trace establishes whether ACE-Step reached inference, was still loading weights, or failed earlier.

ACE-Step cannot be cleared as a contributor. Loading the model added memory demand to an already busy machine. The first attempt should have been gated on memory and swap headroom; checking only the external drive's capacity was insufficient.

## Changes made

1. Left generation stopped after the reboot and performed only a lightweight preflight.
2. Added a parent supervisor that refuses low-headroom starts, writes persistent diagnostics, monitors resources and terminates only its own trial process when limits are exceeded.
3. Added PyTorch/MLX allocation limits, a four-thread CPU limit, one sample and a five-second default audition.
4. Kept the game's sound library independent of inference. The CC0 integration can be tested without loading a music model.

The first guarded preflight refused to launch on that workload. This was superseded by the bounded retries below. The guard is not a diagnosis of the original panic.

## Requested retry, 22:59–23:07 local

The user authorized another attempt, noting the earlier swap exhaustion. Internal disk headroom had recovered to approximately 43 GiB. Other applications were left running; no Godot test/import ran alongside inference.

The original loader holds both PyTorch and MLX decoder weights. We prepared [Audante's 8-bit MLX conversion](https://huggingface.co/Audante/ACE-Step-1.5-mlx-8bit), revision `7a59458c6a193af37a107fc2c0f6e7c03333b118`, and its reviewed patch against our exact upstream ACE-Step commit. The conversion and patched checkout are separate from the official installation. Downloaded weights were checksum-verified; initialization replaces bundled model Python with the pinned upstream source as designed by ACE-Step.

| Attempt | Result |
| --- | --- |
| 8-bit decoder, PyTorch on MPS, five seconds | Supervisor stopped loading after 18.2 s when swap growth exceeded 4 GiB. |
| 8-bit decoder, CPU conditioning, five seconds | Valid 5.12 s stereo WAV. Initialization 16.1 s; generation 5.3 s. The child exited 0; a parent `psutil` exit-accounting race was identified and fixed. |
| CPU conditioning, 30 seconds, default float32 VAE window | Supervisor stopped audio decoding after 25.4 s on critical pressure and the 12 GiB total-swap limit. No completed WAV. |
| CPU conditioning, 30 seconds, float16 VAE with 192-frame windows | **Completed**, child and supervisor exit 0. Initialization 14.5 s; generation 8.5 s; whole supervised process 28.1 s. |

The final WAV is 30.0 s, stereo, 48 kHz, with finite non-silent samples and no clipped samples. Its SHA-256 is `69010ab42741d45b34f45bbbea8db595c8749ac7a9ce70ee50bae3d2b3ac29fd`. It was opened in QuickTime for listening; musical suitability is not established by these numerical checks.

Final run measurements:

- Peak process RSS reported by the child: **6.61 GiB**. Peak MLX allocation: **4.20 GiB**. These measurements overlap and must not be added together.
- Minimum sampled available memory: **3.61 GiB**.
- macOS pressure levels sampled: normal and warning, **no critical level**.
- Maximum swap used: **11.64 GiB**, equal to the starting level; it decreased slightly by exit.
- No further restart occurred during these trials. This does not establish the cause of the earlier panic or guarantee safety for longer clips, additional models or different workloads.

The final configuration disables the planner, uses a single sample, four CPU threads, bounded MLX memory/cache, and small half-precision decode windows. Logs are persistent and each attempt has its own directory. The supervisor bounds total swap as well as growth so repeated trials cannot each consume a fresh unbounded allowance. The resulting audition remains outside the game assets.

See the [verification records](verification/music-mlx8-30s-fp16.json) and [repeatable commands](README.md#ace-step-installation).
