\# ABFT-Protected Systolic CNN Accelerator (5×5 Image, 3×3 Kernel) vs. MAC Baseline



\## Project Overview



This project implements and compares two hardware architectures for performing 3×3 convolution on a 5×5 input image:



1\. \*\*MAC-based CNN accelerator:\*\* A conventional architecture using multiply-accumulate operations.

2\. \*\*Systolic CNN accelerator with ABFT:\*\* A processing-element-based architecture that uses Algorithm-Based Fault Tolerance (ABFT) to detect computational errors through checksum comparison.



The project includes RTL implementation, Python-based reference modelling, functional verification, fault-injection experiments and a Vivado-based FPGA evaluation flow.



\## 1. Project Structure



The project is organised into the following directories:



```text

rtl/                     Shared RTL modules and cnn\_params.vh

rtl/baseline/            MAC-based CNN implementation

rtl/systolic/            Systolic CNN architecture and ABFT modules

tb/                      Verilog testbenches for functional and fault verification

model/                   Python reference model and vector-generation scripts

vectors/                 Input images, kernels and expected output files (.hex)

scripts/                 Simulation and synthesis scripts

results/                 Simulation logs and analysis results

```



\*\*Important RTL modules:\*\*



\- `rtl/baseline/`: Contains `cnn\_top`, `controller`, `mac\_unit`, `mac\_array` and `adder\_tree\_9`.

\- `rtl/systolic/`: Contains `cnn\_top\_sys`, `pe`, `systolic\_chain`, `pixel\_skew`, `controller\_sys`, `abft\_expected`, `abft\_checker` and `fault\_unit`.

\- `fault\_unit.v` and the associated fault-injection logic are used only during simulation.



The shared RTL directory contains the modules used by both architectures, along with the parameter header file `cnn\_params.vh`.



\## 2. Tools and Requirements



| Purpose | Tool | Details |

|---|---|---|

| RTL simulation | Icarus Verilog 12 or Vivado XSim | Icarus is used for the reported simulation results. |

| Vector generation | Python 3.12.10 | No additional Python packages are required. |

| FPGA synthesis and implementation | Vivado 2025.2 | Spartan-7 device support is required. |

| Waveform viewing | GTKWave or Vivado | Optional, for examining simulation waveforms. |



\*\*Installation and version checks:\*\*



\- Windows: Install Icarus Verilog and enable the option to add it to PATH.

\- Ubuntu/WSL: `sudo apt install iverilog gtkwave`

\- macOS: `brew install icarus-verilog`



Check the installed versions using:



```bash

iverilog -V

python --version

```



\## 3. Running the Simulations



The project includes scripts to generate test vectors and execute the functional and fault-injection testbenches.



Run the following command from the project root directory.



\*\*Windows (Command Prompt):\*\*



```bat

scripts\\run\_all.bat

```



\*\*Linux / macOS / WSL / Git Bash:\*\*



```bash

sh scripts/run\_all.sh

```



The script performs the following operations:



1\. Generates 57 test vectors using the Python reference model.

2\. Runs functional verification of the baseline MAC architecture.

3\. Runs functional verification of the systolic architecture with ABFT enabled.

4\. Executes the fault-injection campaign.



Simulation logs are stored in the `results/` directory.



The expected functional verification result is:



```text

RESULT: PASS

```



for both architectures.



\## 4. Vivado XSim Simulation



Vivado XSim can also be used to execute the Verilog testbenches.



\*\*Current status:\*\* The project was opened successfully in Vivado 2025.2, and RTL elaboration and schematic generation were completed. However, behavioral simulation has not yet completed successfully. An elaboration error occurred because the `abft\_expected` module was not found during the XSim simulation build. This issue needs to be resolved before reporting successful XSim results.



\### Running the simulation using Tcl



Ensure that Vivado is available in the system PATH. The target FPGA part should also be configured in `scripts/vivado\_sim.tcl`.



Execute the following commands from the project root directory:



```bash

vivado -mode batch -source scripts/vivado\_sim.tcl -tclargs tb\_baseline\_vec



vivado -mode batch -source scripts/vivado\_sim.tcl -tclargs tb\_sys\_func



vivado -mode batch -source scripts/vivado\_sim.tcl -tclargs tb\_sys\_fi

```



The testbenches correspond to:



\- `tb\_baseline\_vec`: Functional verification of the baseline MAC architecture.

\- `tb\_sys\_func`: Functional verification of the systolic architecture.

\- `tb\_sys\_fi`: Fault-injection verification of the systolic architecture.



The simulation script creates a separate run directory under `vivado\_sim/` for each testbench, configures the required source files and vector paths, and executes the simulation.



The `FAULT\_INJ` compilation define is enabled only for the fault-injection testbench. The fault campaign generates `fi\_misses.csv` in its simulation run directory.



\### Manual Vivado GUI procedure



The simulation can also be configured through the Vivado GUI:



1\. Create an RTL project.

2\. Add the shared RTL modules, baseline modules and systolic modules as design sources.

3\. Add `rtl/cnn\_params.vh` and `tb/vec\_path.vh` as Verilog Header files.

4\. Add the required testbench from the `tb/` directory as a simulation source.

5\. Set the selected testbench as the simulation top.

6\. Add the `rtl/` and `tb/` directories to the Verilog include directories.

7\. Configure the absolute path to the `vectors/` directory in `tb/vec\_path.vh`.

8\. For `tb\_sys\_fi`, enable the simulation Verilog define `FAULT\_INJ`.

9\. Run behavioral simulation.



The testbenches should be executed independently.



\## 5. Vivado Synthesis and FPGA Evaluation



The project includes a Tcl script for synthesising both architectures using Vivado.



The target FPGA part and clock period can be configured using the `PART` and `PERIOD\_NS` variables at the beginning of `scripts/synth.tcl`.



Run the following commands from the project root directory:



```bash

vivado -mode batch -source scripts/synth.tcl -tclargs cnn\_top > results/viv\_baseline.log



vivado -mode batch -source scripts/synth.tcl -tclargs cnn\_top\_sys > results/viv\_systolic.log

```



The script generates reports under `results/vivado\_<top>/`, including utilisation, timing and power reports, along with a summary file.



\*\*FPGA evaluation status:\*\* RTL elaboration and schematic generation have been completed in Vivado 2025.2 for the target device `xc7s50csga324-1`. Post-synthesis and post-implementation measurements have not yet been completed.



\### Comparison methodology



For a meaningful comparison, both architectures should be evaluated using:



\- The same FPGA part.

\- The same Vivado version.

\- Identical clock constraints.

\- The same synthesis and implementation settings.



The following metrics should be considered:



\- LUT and flip-flop utilisation.

\- DSP48 and LUTRAM utilisation.

\- Maximum operating frequency (Fmax).

\- Execution time.



The clock period should be adjusted appropriately when estimating the maximum operating frequency. A timing result with positive slack alone does not establish the maximum achievable frequency.



DSP48 and LUTRAM utilisation should also be reported because register and memory inference can affect the resource distribution.



The shared pixel, kernel and feature-map memory structures should be considered when comparing the architectures. The synthesis script supports hierarchical reporting through the `FLATTEN` setting.



Execution time can be estimated using:



\\\[

T\_{\\text{execution}} = \\text{Latency in cycles}\\times T\_{\\text{clock}}

\\]



\### Current comparison results



| Metric | Baseline MAC | Systolic + ABFT |

|---|---:|---:|

| Functional verification | PASS (measured) | PASS (measured) |

| Test vectors | 57 | 57 |

| Latency (clock edges) | 11 | 22 |

| Fmax | Pending | Pending |

| Execution time | 11 × T | 22 × T |

| LUT / FF / DSP / LUTRAM | Pending | Pending |



The functional results and latency values are obtained from Icarus Verilog simulation. FPGA resource and timing values are yet to be measured using Vivado.



\## 6. Simulation and Fault-Injection Results



The following results were obtained using Icarus Verilog 12.



\### 6.1 Functional verification



\*\*Baseline MAC architecture\*\*



\- All 57 test vectors produced the expected outputs.

\- No mismatches were observed.

\- Measured latency: 11 clock cycles.



\*\*Systolic architecture with ABFT\*\*



\- All 57 test vectors were verified.

\- Each vector was executed twice, including a second run without resetting the design.

\- No feature-map, raw-output or checksum mismatches were observed.

\- No false alarms occurred during fault-free operation.

\- Measured latency: 22 clock cycles.



\### 6.2 Yosys synthesis check



Both architectures were also checked using Yosys with generic Xilinx mapping.



\- Both designs were synthesised without latch warnings.

\- The resulting cell counts are not used for direct area comparison.



Yosys may map register bits into resources such as DSP48 input registers and SRL16 shift registers. For example, the baseline implementation reports only 14 flip-flops even though the design contains more than 72 kernel-register bits.



Therefore, the Yosys cell counts do not provide a reliable direct comparison of LUT and flip-flop utilisation between the two architectures. Vivado reports are required for FPGA resource comparison.



\### 6.3 Single-bit fault-injection campaign



The fault-injection campaign was performed using four selected test vectors. Single-bit flips were injected at different locations in the systolic architecture.



The results are summarised below.



| Fault injection site | Total | Detected, output corrupted | Detected, output unaffected | Silent corruption | Undetected, output unaffected | No effect | False alarm |

|---|---:|---:|---:|---:|---:|---:|---:|

| Product register (PE) | 5184 | 2500 | 2684 | 0 | 0 | 0 | 0 |

| Partial-sum register (PE) | 6480 | 2534 | 3946 | 0 | 0 | 0 | 0 |

| PE-local weight register | 288 | 280 | 0 | 0 | 0 | 8\* | 0 |

| Pixel at PE input (after tap) | 2592 | 1896 | 696 | 0 | 0 | 0 | 0 |

| Window pixel before tap (common-mode) | 2592 | 0 | 0 | 1896 | 696 | 0 | 0 |

| ReLU output (after checker tap) | 288 | 0 | 0 | 288 | 0 | 0 | 0 |

| Checker accumulator | 828 | 0 | 0 | 0 | 0 | 0 | 828 |

| Expected-checksum accumulator | 828 | 0 | 0 | 0 | 0 | 0 | 828 |



\\\* The eight no-effect cases correspond to PE4 weight flips on vector 0. The pixel block associated with tap 4 contains only zeros, so changing the weight does not affect the output.



The campaign shows that errors introduced in the PE product and partial-sum registers are detected by the checksum mechanism. However, faults before the ABFT observation point and after the checker tap can remain undetected.



Faults in the checker and expected-checksum accumulators also produce false alarms.



\### 6.4 Double-fault experiment



A separate double-fault experiment was performed by injecting two same-bit flips into the PE8 partial-sum register at different windows.



| Metric | Result |

|---|---:|

| Total runs | 2880 |

| Detected faults | 1894 |

| Undetected faults | 986 |

| Undetected faults corrupting the feature map | 474 |



The experiment demonstrates a limitation of sum-based checksums: two errors with equal magnitudes and opposite signs can cancel each other in the checksum calculation.



\## 7. Architecture and Processing Schedule



\### 7.1 Front-end architecture



The front end is shared between the baseline and systolic implementations.



The processing sequence is:



```text

window\_controller

&#x20;      |

address\_generator

&#x20;      |

pixel\_memory

&#x20;      |

sliding\_window

&#x20;      |

window\_flat (9 taps)

```



The sliding-window module provides all nine pixels of a 3×3 window in one cycle.



\### 7.2 Systolic processing



The `pixel\_skew` module delays each tap by a different number of registers. Tap `k` is delayed by `k+1` registers.



Each processing element performs the following operation:



```verilog

psum\_k <= psum\_{k-1} + w\_k \* x\_k;

```



The pixel is unsigned and zero-extended to 9-bit signed representation before multiplication with the signed 8-bit weight.



The product is 16 bits wide, and the partial sum is maintained as a 20-bit wrapping value.



The PE weights are loaded in parallel from the kernel registers on the start edge.



\### 7.3 Processing schedule



Counting clock edges from the start edge:



\- E1: Start edge.

\- Window `o` appears on the input bus during the interval between E(o+1) and E(o+2).

\- Its raw output reaches PE8 during the interval between E(o+11) and E(o+12).

\- The raw output is written to feature-map memory at E(o+12).

\- The checksum comparison is registered at E22.

\- `done` and `abft\_err` become valid after E22.



The measured latency of the complete systolic operation is 22 clock cycles.



\### 7.4 ABFT implementation



The ABFT observation point is `window\_flat`, before the pixel-skew stage.



The `abft\_expected` module accumulates the pixel sums for each of the nine kernel positions across the nine convolution windows.



These accumulated values are then multiplied by the corresponding kernel weights using a pipelined 12×8-bit multiplication operation.



The expected checksum is calculated as:



\\\[

C\_{\\text{expected}}=\\sum\_{k=0}^{8}w\_kS\_k

\\]



where:



\- \\(w\_k\\) is the kernel weight at position \\(k\\).

\- \\(S\_k\\) is the accumulated pixel sum for that position across all nine windows.



The expected checksum uses the master kernel registers rather than the PE-local weight copies.



The `abft\_checker` module independently accumulates the nine raw outputs before ReLU and output truncation.



The two checksum values are compared to identify computational errors.



\### 7.5 Data widths and output behaviour



| Signal | Width |

|---|---:|

| Pixel input | 8 bits unsigned |

| Extended pixel | 9 bits signed |

| Kernel weight | 8 bits signed |

| Product | 16 bits |

| Partial sum | 20 bits |

| Checksum | 23 bits signed |

| Individual tap pixel sum | 12 bits |



The 23-bit signed checksum is sufficient for the calculated maximum absolute checksum value of 2,643,840.



The baseline ReLU behaviour is retained in the systolic implementation:



\- Negative values are converted to zero.

\- Non-negative values are truncated to their lowest 8 bits.

\- Saturation is not performed; values above 255 wrap according to the 8-bit output representation.



\## 8. Limitations



The implemented ABFT mechanism uses a sum-based checksum. It provides error detection for computational errors within the monitored raw-output path, but it does not provide complete fault coverage.



The main limitations identified during the fault-injection experiments are:



1\. \*\*Common-mode faults:\*\* Errors introduced before the checksum observation point, such as faults in pixel memory, the window bus or master kernel registers, may not be detected.

2\. \*\*Post-checker faults:\*\* Errors introduced after the checker tap, including ReLU, output truncation and feature-map memory faults, are not covered by the implemented checksum.

3\. \*\*Error cancellation:\*\* Two errors with equal magnitudes and opposite signs can cancel in the accumulated checksum.

4\. \*\*Checker faults:\*\* Errors in the checker or expected-checksum accumulator can produce false alarms.

5\. \*\*Limited fault models:\*\* The campaign uses transient single-bit flips at individual cycles. Stuck-at faults, multi-bit faults and timing-related faults have not been evaluated.

6\. \*\*Limited fault-campaign vectors:\*\* The exhaustive single-bit campaign uses four of the 57 generated vectors. The remaining vectors are used for fault-free functional verification.

7\. \*\*Processing latency:\*\* The systolic architecture requires 22 cycles compared with 11 cycles for the baseline MAC architecture for the tested workload.



Further work is required to improve fault coverage and evaluate the architectures using post-implementation FPGA timing and resource reports.



The `fault\_unit.v` module and the `FAULT\_INJ` logic are simulation-only. They use hierarchical references for fault injection and are not part of the normal synthesis configuration.



\## 9. Python Reference Model and Scripts



The `model/` directory contains the Python reference model and supporting scripts.



| File | Description | Execution |

|---|---|---|

| `cnn\_model.py` | Contains the golden convolution model, expected checksum calculation, PE-chain model and ReLU/truncation behaviour. | Imported by the other Python scripts. |

| `gen\_vectors.py` | Generates 57 test vectors and writes the corresponding `.hex` files into `vectors/`. | `python model/gen\_vectors.py` |

| `analysis\_step1.py` | Verifies the checksum equation using 20,003 vectors, calculates bit-width bounds and performs a software-based single-bit fault experiment. | `python model/analysis\_step1.py` |



The vector-generation script is also executed automatically by the `run\_all` scripts.



The `sets` list in `gen\_vectors.py` can be modified to introduce additional image and kernel combinations.



The analysis script also generates `vectors/vectors\_combined.txt`.



\## 10. Waveform Generation



Waveforms can be generated using Icarus Verilog and viewed using GTKWave.



For waveform generation, add the `-DDUMP` compilation define to the Icarus Verilog command when compiling `tb\_sys\_func` or `tb\_baseline\_vec`.



After simulation, a `.vcd` file is generated in the current working directory.



The generated waveform can then be opened using GTKWave for signal-level inspection and debugging.

