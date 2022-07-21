module SYSTOLIC_ARRAY #(parameter DATA_BITS = 8) (
        input                           clk,
        input                           rst_n,
        input [0:3]                     propagate,
        input [DATA_BITS*4-1:0]         weight,
        input [DATA_BITS*4-1:0]         activation,
        output [DATA_BITS*4*4-1:0]      sum
    );

    generate
        genvar i;
        for(i = 0; i < 16; i = i+1) begin: wires
            wire                    propagate_i;
            wire [DATA_BITS-1:0]    weight_i;
            wire [DATA_BITS-1:0]    act_i;
            wire [DATA_BITS*4-1:0]  psum_i;
            wire                    propagate_o;
            wire [DATA_BITS-1:0]    weight_o;
            wire [DATA_BITS-1:0]    act_o;
            wire [DATA_BITS*4-1:0]  psum_o;
        end
    endgenerate

    generate
        genvar j;
        for(j = 0; j < 16; j = j+1) begin: pes
            PE #(.DATA_BITS(DATA_BITS)) pe (
                   .clk(clk),
                   .rst_n(rst_n),
                   .prop_ctrl(propagate[j%4]),
                   .propagate_i(wires[j].propagate_i),
                   .weight_i(wires[j].weight_i),
                   .act_i(wires[j].act_i),
                   .psum_i(wires[j].psum_i),
                   .propagate_o(wires[j].propagate_o),
                   .act_o(wires[j].act_o),
                   .weight_o(wires[j].weight_o),
                   .psum_o(wires[j].psum_o)
               );
        end
    endgenerate

    generate
        genvar a, b, c, d;
        // Horizontal
        for(a = 0; a < 4; a=a+1) begin: h_con
            for(b = 0; b < 3; b=b+1) begin: h_con_inloop
                assign wires[a*4+b+1].act_i = wires[a*4+b].act_o;
            end
        end
        // Vertical
        for(c = 0; c < 3; c=c+1) begin: v_con
            for(d = 0; d < 4; d=d+1) begin: v_con_inloop
                assign wires[(c+1)*4+d].psum_i = wires[c*4+d].psum_o;
                assign wires[(c+1)*4+d].weight_i = wires[c*4+d].weight_o;
                assign wires[(c+1)*4+d].propagate_i = wires[c*4+d].propagate_o;
            end
        end
    endgenerate

    assign wires[0].weight_i = weight[0*DATA_BITS+:DATA_BITS];
    assign wires[1].weight_i = weight[1*DATA_BITS+:DATA_BITS];
    assign wires[2].weight_i = weight[2*DATA_BITS+:DATA_BITS];
    assign wires[3].weight_i = weight[3*DATA_BITS+:DATA_BITS];

    assign wires[0].propagate_i = propagate[0];
    assign wires[1].propagate_i = propagate[1];
    assign wires[2].propagate_i = propagate[2];
    assign wires[3].propagate_i = propagate[3];

    assign wires[0].psum_i = 0;
    assign wires[1].psum_i = 0;
    assign wires[2].psum_i = 0;
    assign wires[3].psum_i = 0;

    assign wires[0].act_i = activation[0*DATA_BITS+:DATA_BITS];
    assign wires[4].act_i = activation[1*DATA_BITS+:DATA_BITS];
    assign wires[8].act_i = activation[2*DATA_BITS+:DATA_BITS];
    assign wires[12].act_i = activation[3*DATA_BITS+:DATA_BITS];

    assign sum = {wires[15].psum_o, wires[14].psum_o, wires[13].psum_o, wires[12].psum_o};

endmodule
