# Digital Logic 2025 Fall Project Architecture Report 

**Authors:**
- Yanqiao Chen(12412115)
- Yan Jiang(12410337)
- Dongsheng Hou(12410421)

## 开发计划日程安排和实施情况，版本修改记录

### 开发计划日程安排

项目开发从初始规划开始，逐步实现各个模块。以下是主要阶段：

- **初始阶段**：项目立项，确定基本架构，使用DRAM存储。
- **中期阶段**：实现UART通信、按键消抖、基本模式切换。
- **后期阶段**：实现矩阵输入、存储、计算功能，重构为BRAM存储。
- **最终阶段**：完善所有计算模式、设置模式、错误处理、GUI框架。

### 实施情况

项目基本完成所有要求，并实现了若干bonus功能，包括卷积操作、倒计时错误恢复、随机生成等。GUI有框架但未完全连接。

### 版本修改记录

GitHub仓库链接：https://github.com/SUSTech-Digital-Logic-Project-Team/Digital-Logic-Fall-2025-Project-Matrix-Calculator

提交记录（部分）：
- ae04f1c Merge pull request #28 from hotteano/main
- 7d797e5 Merge branch 'main' into main
- 31489e5 update
- 72e5d1f update
- 38d3476 update
- e5bf7ca update
- e6a417d update
- 15bd659 update
- 6817a1a update
- 679961f Okay this is the end
- ... (更多提交见仓库)

## 项目架构设计说明

基于提交的架构设计文档，改进后的最终实现方案如下：

（原有架构内容保持不变）

## 输出对齐和参数配置设计思路

### 输出对齐

在显示和UART输出中，实现输出对齐通过在数字间添加空格，并在行列分隔时发送换行符。计数器维护当前行数据，当一行显示完毕时发送换行符（ASCII码10）。

### 参数配置

设置模式允许用户通过UART自定义参数，包括最大矩阵维度、最大数值、同一维度最大矩阵数量、倒计时设置。FPGA复位后参数初始化为默认值，用户可在运行时修改。与周边模块的关系：设置模式与顶层模块交互，更新config寄存器；顶层模块将这些参数传递给各子模块，如计算模式、生成模式等，用于限制输入范围和操作。

## 应用开发

项目实现了GUI应用（matrix_calculator_gui.py），用于PC端交互。应用开发部分由视频代替，视频需展示应用操作过程，介绍使用的技术栈（Python + Tkinter）和开发方式（脚本开发）。

## 开源和AI使用以及思考总结

### 开源声明

本项目使用MIT协议开源，所有代码和文档可在GitHub仓库获取。

### AI使用声明

- 大量采用AI生成重复代码-人工调优debug模式，尤其在状态机设置、多路选择和模块连接中。
- AI提供BRAM优化建议，有效避免LUT综合爆炸。
- AI局限性：在复杂Verilog中，AI常在无关处过度检查，输出需人工review和debug。

### 思考总结

项目体现了数字逻辑设计从概念到实现的完整流程。使用BRAM优化显著提升性能，AI辅助加速开发但需人工把控质量。未来可进一步优化流水线和GUI连接。

## The INPUT and OUTPUT

The input port and output port is listed as follows: 

**INPUT:**

- The clock: 1 bit width
- Reset button: 1 bit width
- DIP switch: 3 bits width, SW2 as MSB, SW0 as LSB, used for choosing different modes
- Confirm button: 1 bit width, used for confirm main mode selection
- Go back button: 1 bit width, used for go back to main menu
- UART Receiver: 1 bit width, used for receiving data from PC


**OUTPUT:**

- UART Transimitter: 1 bit width, used for transimitting data to PC
- 7-Seg LED: 7 bits width, used for displaying information like mode, opertion type, error code, counting time...
- LED: 4 bits width, LD3 as MSB, LD0 as LSB, used for indicating working, error type and so on.
- 7-Seg LED selection: 2 bits width, used for selecting 7-Seg LED

![描述文本](1.png)  


## Architecture

The Architecture of this project is purposed as follow: 

**A Global View:**
- The Top Module
- The Memory Controller
- Processing Modes
- Display Controller
- UART Module
- Tool Kit

```
┌─────────────┐
│    UART     │◄──────► EGO1 UART PORT
└──────┬──────┘
       │
    ┌──┴────────────────────────────────┐
    │   Matrix Calculator Top (FSM)     │
    │  ┌─────────────────────────────┐  │
    │  │  Mode Multiplexer           │  │
    │  │  ┌─────────────┐            │  │
    │  │  │ Input Mode  │            │  │
    │  │  ├─────────────┤            │  │
    │  │  │ Generate M. │            │  │
    │  │  ├─────────────┤            │  │
    │  │  │ Display M.  │ ─┐         │  │
    │  │  ├─────────────┤  │ BRAM    │  │
    │  │  │ Compute M.  │ ─┼◄────►┌──┼─┤
    │  │  ├─────────────┤  │ Pool │  │ │
    │  │  │ Setting M.  │ ─┘      └──┼─┤
    │  │  └─────────────┘            │  │
    │  └─────────────────────────────┘  │
    │                                   │
    │  ┌──────────────────────────────┐ │
    │  │ Matrix Manager (Metadata)    │ │
    │  │ ┌────────────────────────┐   │ │
    │  │ │ Directory (20 slots)   │   │ │
    │  │ │ • Valid flags          │   │ │
    │  │ │ • Dimensions (M×N)     │   │ │
    │  │ │ • Start addresses      │   │ │
    │  │ │ • Element counts       │   │ │
    │  │ └────────────────────────┘   │ │
    │  └──────────────────────────────┘ │
    │                                   │
    │  ┌──────────────────────────────┐ │
    │  │ Control Logic & Multiplexers │ │
    │  │ • Allocation FSM             │ │
    │  │ • Address routing            │ │
    │  │ • R/W arbitration            │ │
    │  └──────────────────────────────┘ │
    └───────────────────────────────────┘
            │                   │
            ▼                   ▼
    ┌─────────────┐      ┌──────────────┐
    │   LFSR RNG  │      │ Display Ctrl │
    │   16 bits   |      |  7-Seg+LEDs  |
     random number|      |              |
    └─────────────┘      └──────────────┘
```

![描述文本](2.png)  

### The Top Module

The top module includes

| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|Matrix Calc Top |clk, rst_n, dip_sw[2:0], btn_confirm, btn_back, uart_rx| uart_tx, seg_display[6:0], led_status[3:0], seg_select[1:0]| Top module

### The Memory Controller
| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|Memory Pool| clk, rst_n, a_n, a_we, a_addr[ADDR_WIDTH-1:0], a_din[DATA-1:0], b_en, b_addr[ADDR_WIDTH-1:0]| a_dout[ADDR_WIDTH-1:0], b_dout[DATA_WIDTH-1:0]| Storing Data
|Matrix Manager| clk, rst_n, alloc_req, alloc_m[3:0], alloc_n[3:0], commit_req, commit_slot[3:0], commit_m[3:0], commit_n[3:0], commit_addr[11:0], query_clot[3:0] | alloc_slot[3:0], alloc_addr[11:0], alloc_valid, query_m[3:0], query_n[3:0], query_addr[11:0], query_element_count[7:0], total_matrix_count[7:0]| Managing Matrices|

### Process Modes

| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|Compute Mode| clk (1 bit), rst_n (1 bit), mode_active (1 bit), config_max_dim [3:0], dip_sw [2:0], btn_confirm (1 bit), rx_data [7:0], rx_done (1 bit), tx_busy (1 bit), total_matrix_count [7:0], query_valid (1 bit), query_m [3:0], query_n [3:0], query_addr [11:0], query_element_count [7:0], mem_rd_data [15:0]| clear_rx_buffer (1 bit), tx_data [7:0], tx_start (1 bit), selected_op_type [3:0], query_slot [3:0], mem_rd_en (1 bit), mem_rd_addr [11:0], error_code [3:0], sub_state [3:0]| Performs matrix computations like addition, multiplication|
|Generate Mode| clk (1 bit), rst_n (1 bit), mode_active (1 bit), config_max_dim [3:0], config_max_value [3:0], random_value [3:0], rx_data [7:0], rx_done (1 bit), tx_busy (1 bit), alloc_slot [3:0], alloc_addr [11:0], alloc_valid (1 bit)| clear_rx_buffer (1 bit), tx_data [7:0], tx_start (1 bit), alloc_req (1 bit), commit_req (1 bit), commit_slot [3:0], commit_m [3:0], commit_n [3:0], commit_addr [11:0], mem_wr_en (1 bit), mem_wr_addr [11:0], mem_wr_data [15:0], error_code [3:0], sub_state [3:0]| Generates matrices with random or predefined values|
|Input Mode| clk (1 bit), rst_n (1 bit), mode_active (1 bit), config_max_dim [3:0], config_max_value [3:0], rx_data [7:0], rx_done (1 bit), tx_busy (1 bit), alloc_slot [3:0], alloc_addr [11:0], alloc_valid (1 bit), mem_rd_data [15:0]| clear_rx_buffer (1 bit), tx_data [7:0], tx_start (1 bit), alloc_req (1 bit), alloc_m [3:0], alloc_n [3:0], commit_req (1 bit), commit_slot [3:0], commit_m [3:0], commit_n [3:0], commit_addr [11:0], mem_wr_en (1 bit), mem_wr_addr [11:0], mem_wr_data [15:0], mem_rd_en (1 bit), mem_rd_addr [11:0], error_code [3:0], sub_state [3:0]| Receives matrix data from UART and manages memory allocation|
|Setting Mode| clk (1 bit), rst_n (1 bit), mode_active (1 bit), rx_data [7:0], rx_done (1 bit), tx_busy (1 bit)| clear_rx_buffer (1 bit), tx_data [7:0], tx_start (1 bit), config_max_dim [3:0], config_max_value [3:0], config_matrices_per_size [3:0], error_code [3:0], sub_state [3:0]| Configures operational settings|

### Display Controller

| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|Display Control| clk (1 bit), rst_n (1 bit), matrix_data [7:0], mode [2:0]| seg_display [6:0], seg_select [1:0], led_status [3:0]| Manages display of matrix data and status indicators|

### UART Module

| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|UART Receiver| clk (1 bit), rst_n (1 bit), uart_rx (1 bit)| received_data [7:0]| Receives data from PC|
|UART Transmitter| clk (1 bit), rst_n (1 bit), data_to_send [7:0]| uart_tx (1 bit)| Sends data to PC|
|UART Module| clk (1 bit), rst_n (1 bit), uart_rx (1 bit), data_to_send [7:0]| uart_tx (1 bit), received_data [7:0]| Combines UART Receiver and Transmitter functionalities|

### Tool kit

| Name | Input | Output | Usage|
|:--------------:|:---:|:---:|:---:|
|matrix package|NO | NO | Some Macros settings, like clock frequency|
|LSFR Random number generator|clk, rst_n, max_value[3:0]|random_value[3:0]| For generating psuedorandom number, by using polynomial|

## The FSM

Some main states of this project:

- IDLE, MODE_INPUT, MODE_COMPUTE, MODE_GENERATE, MODE_SETTING, MODE_DISPLAY
- Input Mode: IDLE, PARSE_M, PARSE_N, CHECK_DIM, WAIT_ALLOC, PARSE_DATA, FILL_ZEROS, COMMIT, DISPLAY_MATRIX, DONE, ERROR
- Display Mode: IDLE, SHOW_COUNT, WAIT_SELECT, READ_DATA, CONVERT_DATA, SEND_DIGITS, DONE
- Generate Mode: IDLE, WAIT_M, WAIT_N, ALLOC, GEN_DATA, COMMIT, DONE
- Compute Mode: IDLE, SELECT_OP, SELECT_MATRIX, EXECUTE, SEND_RESULT, DONE

**Top**
![描述文本](top.png) 
![描述文本](3.png) 