
module TPU(
        clk,
        rst_n,

        in_valid,
        K,
        M,
        N,
        busy,

        A_wr_en,
        A_index,
        A_data_in,
        A_data_out,

        B_wr_en,
        B_index,
        B_data_in,
        B_data_out,

        C_wr_en,
        C_index,
        C_data_in,
        C_data_out
    );


    input clk;
    input rst_n;
    input            in_valid;
    input [7:0]      K;
    input [7:0]      M;
    input [7:0]      N;
    output  reg      busy;

    output           A_wr_en;
    output [15:0]    A_index;
    output [31:0]    A_data_in;
    input  [31:0]    A_data_out;

    output           B_wr_en;
    output [15:0]    B_index;
    output [31:0]    B_data_in;
    input  [31:0]    B_data_out;

    output           C_wr_en;
    output [15:0]    C_index;
    output [127:0]   C_data_in;
    input  [127:0]   C_data_out;
    
    parameter DATA_BITS = 8;
    
    wire [DATA_BITS*4-1:0]      weight;
    reg  [0:3]                  propagate;
    wire [DATA_BITS*4-1:0]      activation; 
    wire [DATA_BITS*4*4-1:0]    sum;
    
    SYSTOLIC_ARRAY #(.DATA_BITS(8)) arr (
        .clk(clk),
        .rst_n(rst_n),
        .propagate(propagate),
        .weight(weight),
        .activation(activation),
        .sum(sum)
    );
    
    // FSM
    localparam IDLE     = 2'b00,
               BUSY_B   = 2'b01,
               BUSY_A   = 2'b10,
               BUSY_C   = 2'b11;   
           
    reg [1:0] state, state_n;
    reg [2:0] cnt, cnt_n;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= 0;
            cnt <= 0;
        end
        else begin
            state <= state_n;
            cnt <= cnt_n;
        end
    end
    
    always @(*) begin
        state_n = state;
        cnt_n = cnt;
        case (state)
            IDLE: begin
                state_n = in_valid ? BUSY_B: IDLE; 
                cnt_n = 0;
            end
            BUSY_B: begin
                if(cnt == 3) begin
                    state_n = BUSY_A;
                    cnt_n = 0; 
                end
                else begin
                    cnt_n = cnt + 1;
                end
            end
            BUSY_A: begin
                if(cnt == 4) begin
                    state_n = BUSY_C;
                    cnt_n = 0; 
                end
                else begin
                    cnt_n = cnt + 1;
                end
            end
            BUSY_C: begin
                state_n = (done_A & done_B & done_C) ? IDLE : BUSY_C;
            end
        endcase
    end
    
    // Central Controller
    reg [7:0] K_reg, M_reg, N_reg;
        
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy <= 0;
        end
        else if(in_valid) begin
            busy <= 1;
            K_reg <= K;
            M_reg <= M;
            N_reg <= N;
        end
        else begin
            if(state == IDLE) busy <= 0; 
        end
    end
    
    // DATA LOADER A
    reg done_A;
    reg [7:0] total_cycle_cnt_A;
    reg [7:0] total_cycle_A;
    reg [7:0] now_row_A, now_col_A;
    reg [1:0] A_index_n;
    reg [31:0] act_col1, act_col1_n;
    reg [31:0] act_col2, act_col2_n;
    reg [31:0] act_col3, act_col3_n;
    reg [31:0] act_col4, act_col4_n;
    
    always @(posedge clk or negedge rst_n) begin
        if(in_valid || !rst_n) begin
            done_A <= 0; 
            total_cycle_A <= (N - 1) >> 2;
            total_cycle_cnt_A <= 0;
            now_row_A <= 0;
            now_col_A <= 0;
            A_index_n <= 0;
            act_col1 <= 0;
            act_col2 <= 0;
            act_col3 <= 0;
            act_col4 <= 0;
        end
        else if(state > BUSY_B) begin
            {act_col1, act_col2, act_col3, act_col4} = {act_col1_n, act_col2_n, act_col3_n, act_col4_n};
            // Update A_index
            if(A_index_n == 3) A_index_n <= 0;
            else A_index_n <= A_index_n + 1;
            if(!done_A) begin
                // Update now_col_A
                if(A_index_n == 3) begin
                    if(now_col_A + 4 >= K_reg) now_col_A <= 0;
                    else now_col_A <= now_col_A + 4;
                end
                // Update now_row_A
                if(A_index_n ==3 && now_col_A + 4 >= K_reg) begin
                    if(now_row_A + 4 >= M_reg) now_row_A <= 0;
                    else now_row_A <= now_row_A + 4;
                end
                // Update cycle_cnt
                if(A_index_n == 3 && now_col_A + 4 >= K_reg && now_row_A + 4 >= M_reg) begin
                    if(total_cycle_cnt_A == total_cycle_A) begin
                        total_cycle_cnt_A <= 0;
                        done_A <= 1;
                    end
                    else total_cycle_cnt_A <= total_cycle_cnt_A + 1;
                end
            end
        end
    end
    
    always @(*) begin
        {act_col1_n, act_col2_n, act_col3_n, act_col4_n} = {act_col1, act_col2, act_col3, act_col4};
        if(state > BUSY_B) begin
            {act_col1_n, act_col2_n, act_col3_n, act_col4_n} = {act_col1 << 8, act_col2 << 8, act_col3 << 8, act_col4 << 8};
            if(now_col_A + A_index_n < K_reg && !done_A) begin
                case(A_index_n)
                    0: act_col1_n = A_data_out;
                    1: act_col2_n = A_data_out;
                    2: act_col3_n = A_data_out;
                    3: act_col4_n = A_data_out;
                endcase
            end
        end
    end
    
    assign A_wr_en = 0;
    assign activation = {act_col4[31:24], act_col3[31:24], act_col2[31:24], act_col1[31:24]};
    assign A_index = (now_row_A >> 2) * K_reg + now_col_A + A_index_n;
    
    // DATA LOADER B
    reg done_B;
    reg [7:0] total_cycle_cnt_B;
    reg [7:0] total_cycle_B;
    reg [7:0] now_row_B, now_col_B;
    reg [1:0] B_index_n;
    reg [7:0]  weight_col1, weight_col1_n;
    reg [15:0] weight_col2, weight_col2_n;
    reg [23:0] weight_col3, weight_col3_n;
    reg [31:0] weight_col4, weight_col4_n;
    
    always @(posedge clk or negedge rst_n) begin
        if(in_valid || !rst_n) begin
            done_B <= 0;
            total_cycle_B <= (M - 1) >> 2;
            total_cycle_cnt_B <= 0;
            propagate <= 4'b1111;
            now_col_B <= 0;
            now_row_B <= 0;
            B_index_n <= 3;
            weight_col1 <= 0;
            weight_col2 <= 0;
            weight_col3 <= 0;
            weight_col4 <= 0;
        end
        else if(state != IDLE) begin
            {weight_col1, weight_col2, weight_col3, weight_col4} = {weight_col1_n, weight_col2_n, weight_col3_n, weight_col4_n};
            propagate[~B_index_n] <= ~propagate[~B_index_n]; 
            // Update B_index
            if(B_index_n == 0) B_index_n <= 3;
            else B_index_n <= B_index_n - 1;
            if(!done_B) begin
                // Update now_row_B
                if(B_index_n == 0) begin
                    if(now_row_B + 4 >= K_reg) now_row_B <= 0;
                    else now_row_B <= now_row_B + 4;
                end
                // Update cycle_cnt
                if(B_index_n == 0 && now_row_B + 4 >= K_reg) begin
                    if(total_cycle_cnt_B == total_cycle_B) total_cycle_cnt_B <= 0;
                    else total_cycle_cnt_B <= total_cycle_cnt_B + 1;
                end
                // Update now_col_B
                if(B_index_n == 0 && now_row_B + 4 >= K_reg && total_cycle_cnt_B == total_cycle_B) begin
                    if(now_col_B + 4 >= N_reg) begin
                        done_B <= 1;
                        now_col_B <= 0;
                    end
                    else now_col_B <= now_col_B + 4;
                end
            end
        end
    end
    
    always @(*) begin
        {weight_col1_n, weight_col2_n, weight_col3_n, weight_col4_n} = {weight_col1, weight_col2, weight_col3, weight_col4};
        if(state != IDLE) begin
            {weight_col1_n, weight_col2_n, weight_col3_n, weight_col4_n} = {8'b0, weight_col2 << 8, weight_col3 << 8, weight_col4 << 8};
            if(now_row_B + B_index_n < K_reg && !done_B) begin
                weight_col1_n = B_data_out[31:24];
                weight_col2_n[7:0] = B_data_out[23:16];
                weight_col3_n[7:0] = B_data_out[15:8];
                weight_col4_n[7:0] = B_data_out[7:0];
            end
        end 
    end
    
    assign B_wr_en = 0;
    assign weight = {weight_col4[31:24], weight_col3[23:16], weight_col2[15:8], weight_col1[7:0]};
    assign B_index = (now_col_B >> 2) * K_reg + now_row_B + B_index_n;
    
    // DATA SAVER C
    reg done_C;
    reg [2:0] write_index;
    reg [1:0] cnt_C;
    reg [7:0] total_cycle_cnt_C;
    reg [7:0] total_cycle_C;
    reg [7:0] now_row_C, now_col_C;
    reg [32*4-1:0] accum_1, accum_2, accum_3, accum_4;
    reg [32*4-1:0] accum_1_n, accum_2_n, accum_3_n, accum_4_n;
    reg [32*4-1:0] pending;
        
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n || in_valid) begin
            done_C <= 0;
            cnt_C <= 0;
            total_cycle_C <= (K - 1) >> 2;
            total_cycle_cnt_C <= 0;
            {now_row_C, now_col_C} <= {2{8'b0}};
            write_index <= 0;
            {accum_1, accum_2, accum_3, accum_4} <= {4{128'b0}};
            pending <= 128'b0;
        end
        else if(state == BUSY_C) begin
            {accum_1, accum_2, accum_3, accum_4} <= {accum_1_n, accum_2_n, accum_3_n, accum_4_n};
            pending <= {accum_1_n[127:96], accum_2_n[95:64], accum_3_n[63:32], accum_4_n[31:0]};
            // Upadte C counter
            if(cnt_C == 3) cnt_C <= 0;
            else cnt_C <= cnt_C + 1; 
            if(!done_C) begin
                if(cnt_C == 3) begin
                    if(total_cycle_cnt_C == total_cycle_C) begin
                        total_cycle_cnt_C <= 0;
                        write_index <= 4;
                    end
                    else total_cycle_cnt_C <= total_cycle_cnt_C + 1;
                end
                if(write_index != 0) begin
                    write_index <= write_index - 1;
                end
                if(write_index == 1) begin
                    if(now_row_C + 4 >= M_reg) now_row_C <= 0;
                    else now_row_C <= now_row_C + 4;    
                end
                if(write_index == 1 && now_row_C + 4 >= M_reg) begin
                    if(now_col_C + 4 >= N_reg) begin
                        done_C <= 1;
                        now_col_C <= 0;
                    end
                    else now_col_C <= now_col_C + 4;
                end
            end
        end
    end
    
    always @(*) begin
        {accum_1_n, accum_2_n, accum_3_n, accum_4_n} = {accum_1, accum_2, accum_3, accum_4};
        if(state == BUSY_C) begin
            accum_1_n = {accum_1[95:0], accum_1[127:96]};
            accum_2_n = {accum_2[95:0], accum_2[127:96]};
            accum_3_n = {accum_3[95:0], accum_3[127:96]};
            accum_4_n = {accum_4[95:0], accum_4[127:96]};
            if(write_index > 0) {accum_2_n[127:96], accum_3_n[95:64], accum_4_n[63:32], accum_1_n[31:0]} = {4{32'b0}};
            accum_1_n[31:0] = accum_1_n[31:0] + sum[31:0];
            accum_2_n[31:0] = accum_2_n[31:0] + sum[63:32];
            accum_3_n[31:0] = accum_3_n[31:0] + sum[95:64];
            accum_4_n[31:0] = accum_4_n[31:0] + sum[127:96];
        end
    end
    
    assign C_wr_en = (write_index > 0);
    assign C_data_in = pending;
    assign C_index = now_row_C + (now_col_C >> 2) * M_reg + (~(write_index - 1) & 16'd3);
    
endmodule
