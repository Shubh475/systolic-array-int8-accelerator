module systolic_array #(
    parameter int ARRAY_SIZE = 16,
    parameter int DATA_W = 8,
    parameter int ACC_W = 32
) (
    input logic clk,
    input logic rst_n,
    input logic [ARRAY_SIZE * DATA_W -1 : 0] weight_row_data,
    input logic [ARRAY_SIZE -1 : 0] weight_row_en,
    input logic [ARRAY_SIZE * DATA_W -1 : 0] act_vector_data,
    input logic array_advance,

    output logic [ARRAY_SIZE * ACC_W - 1 : 0] result_out
);

    logic signed [DATA_W - 1 : 0] act_net [ARRAY_SIZE][ARRAY_SIZE + 1];
    logic signed [ACC_W - 1 : 0] psum_net[ARRAY_SIZE +1][ARRAY_SIZE];
    genvar i;
    
    generate
        for(i=0;i<ARRAY_SIZE;i=i+1) begin : delay_gen
            if(i==0)
                assign act_net[0][0] = act_vector_data[DATA_W - 1 : 0];
            else begin
                logic signed [DATA_W - 1 : 0] delay_ele [i];
                always_ff @(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        for(int j = 0; j<i; j=j+1) delay_ele[j]<=0;
                    end
                    else begin
                        if(array_advance) begin
                            delay_ele[0] <= act_vector_data[i*DATA_W +: DATA_W];
                            for(int k = 1;k<i;k=k+1) begin
                                delay_ele[k] <= delay_ele[k-1];
                            end
                        end
                    end
                end
                assign act_net[i][0] = delay_ele[i-1];
            end
        end
    endgenerate    

    genvar row, col;
    generate
        for (row = 0; row < ARRAY_SIZE; row++) begin : row_gen
            for (col = 0; col < ARRAY_SIZE; col++) begin : col_gen
                pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) pe_inst (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .weight_load_en (weight_row_en[row]),
                    .weight_in      (weight_row_data[col*DATA_W +: DATA_W]),
                    .act_in         (act_net[row][col]),
                    .psum_in        (row == 0 ? '0 : psum_net[row][col]),
                    .advance        (array_advance),
                    .act_out        (act_net[row][col+1]),
                    .psum_out       (psum_net[row+1][col])
                );
            end
        end
    endgenerate
    generate
        for (col = 0; col < ARRAY_SIZE; col++) begin : result_gen
            assign result_out[col*ACC_W +: ACC_W] = psum_net[ARRAY_SIZE][col];
        end
    endgenerate
endmodule