# systolic-array-int8-accelerator
# INT8 Systolic Array Matmul Accelerator

A weight-stationary systolic array accelerator for INT8 matrix multiplication, implemented in SystemVerilog with a planned cycle-accurate Python performance model. Built to demonstrate RTL implementation skill alongside microarchitectural reasoning and hardware/software co-design for AI/ML accelerator workloads (e.g., dense matmuls in transformer FFN layers).

## Status

| Component | Status |
|---|---|
| Microarchitecture spec | ✅ Complete |
| RTL implementation | 🔧 In progress (FSM, activation buffer, PE, array wiring drafted) |
| Testbench / verification | ⬜ Not started |
| Python performance model | ⬜ Not started |

This is a work in progress, updated as design and debug decisions are made — see the [Design & Debug Log](#design--debug-log) below for issues caught and fixed along the way.

## Architecture

### Top-level I/O

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Active-low reset |
| `start` | in | 1 | Begin a tile pass |
| `weight_data` | in | 128 | Weight load bus |
| `weight_valid` | in | 1 | Weight data valid |
| `act_data` | in | 128 | Activation bus — 16 lanes × 8b, one full activation vector per cycle |
| `act_valid` | in | 1 | Activation data valid |
| `act_last` | in | 1 | Last activation of the current pass |
| `result_ready` | in | 1 | Downstream ready to accept a result |
| `weight_ready` | out | 1 | Accelerator ready for weight data |
| `act_ready` | out | 1 | Accelerator ready for activation data |
| `result_data` | out | 32 | Output result (INT32 accumulator) |
| `result_valid` | out | 1 | Result data valid |
| `done` | out | 1 | Tile pass complete |

### Module hierarchy

```
accelerator_top
├── fsm                  (IDLE → LOAD_WEIGHT → STREAM → DRAIN → RESULT_READOUT; owns weight_ready)
├── activation_buffer    (ping-pong buffer; owns act_ready, fill_count, consume_count, stall logic)
└── systolic_array       (pure datapath — no handshaking; weight_load_en + array_advance driven externally)
    └── 16×16 grid of pe (weight-resident register + registered MAC-and-forward)
```

Per-row activation skew delay chains (for wavefront timing) live outside the PE array, not inside individual PEs.

### Dataflow

- **Weight-stationary**: weights load once per tile and stay resident in each PE's register; activations stream through the array.
- **INT8 primary datapath, INT32 accumulator**: avoids overflow across long MAC chains; a BF16 path is documented as a tradeoff for accuracy-sensitive layers rather than built into v1.

## Key design decisions

| Decision | Rationale |
|---|---|
| Weight-stationary dataflow | Minimizes weight movement when weight reuse across activations is high — the dominant access pattern for the target matmul shapes |
| Double-buffered (ping-pong) activation FIFO, single-buffered result drain | Ping-pong lets the array keep consuming one buffer while the next tile's activations fill the other, hiding fetch latency. Result drain doesn't need the same overlap since results are produced at a steady, predictable rate once draining starts |
| Two-state hit/miss latency model for activation fetch (over fixed-latency or a uniform/random range) | Models realistic bandwidth contention rather than a simplistic constant — worth the added build complexity for a credible utilization story |
| Sweep buffer depth alongside hit rate | Isolates how deeper buffering — not just a better hit rate — shifts the compute-bound/memory-bound knee |
| Fetch-width/burst modeling scoped out of v1 | Documented as future work rather than blocking v1; kept scope realistic against the timeline |

## Design & Debug Log

### Weight broadcast bug (caught in array wiring review)
- **Symptom**: initial wiring broadcast the same `weight_load_en` / `weight_row_data` to every row every cycle — every row would load identical, incorrect weight data.
- **Root cause**: treated a *selection* problem (which row loads this cycle) as if it were a *data-movement* problem.
- **Fix**: decoded the existing `weight_count` counter into a one-hot per-row `weight_row_en` signal, reusing existing state instead of adding a new shift-chain. Shift chains are the right tool for movement (e.g., activation skew) — not for row selection.

### `act_data` width correction
- **Original spec**: `act_data[7:0]`, an 8-bit scalar port.
- **Correction**: widened to a 128-bit bus (16 lanes, one 8-bit lane per row) so the array receives one full activation vector per cycle instead of one scalar spread across 16 cycles. Caught while deriving how activations actually enter the wavefront-skewed array.

*(New entries get added here as more issues are found during verification.)*

## Repository structure

```
systolic-array-int8-accelerator/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   └── microarch_spec.md
├── rtl/
│   ├── accelerator_top.sv
│   ├── fsm.sv
│   ├── activation_buffer.sv
│   ├── systolic_array.sv
│   └── pe.sv
├── tb/
│   └── tb_accelerator_top.sv
└── perf_model/
    └── (Python cycle-accurate model — TBD)
```

## Roadmap

- [ ] Finish RTL: array wiring, drain/readout logic
- [ ] Testbench + verification
- [ ] Python cycle-accurate performance model
- [ ] Utilization sweep (hit rate × buffer depth)
- [ ] BF16 tradeoff writeup
