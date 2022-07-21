module PE #(parameter DATA_BITS = 8) (
        input                           clk,
        input                           rst_n,
        input                           prop_ctrl,
        input                           propagate_i,
        input [DATA_BITS-1:0]           weight_i,
        input [DATA_BITS-1:0]           act_i,
        input [DATA_BITS*4-1:0]         psum_i,
        output reg                      propagate_o,
        output reg [DATA_BITS-1:0]      act_o,
        output reg [DATA_BITS-1:0]      weight_o,
        output reg [DATA_BITS*4-1:0]    psum_o
    );

    reg [DATA_BITS-1:0] weight_0, weight_1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            propagate_o <= 0;
            act_o <= 8'd0;
            weight_o <= 8'd0;
            psum_o <= 32'd0;
            weight_0 <= 8'd0;
            weight_1 <= 8'd0;
        end
        else begin
            act_o <= act_i;
            propagate_o <= propagate_i;
            weight_o <= weight_i;
            if(propagate_i == 0) begin
                if(propagate_i == prop_ctrl)
                    weight_0 <= weight_i;
                psum_o <= act_i * weight_1 + psum_i;
            end
            else begin
                if(propagate_i == prop_ctrl)
                    weight_1 <= weight_i;
                psum_o <= act_i * weight_0 + psum_i;
            end
        end
    end
endmodule
