module pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W = 32
)(
    input logic clk, 
    input logic rst_n, 
    input logic weight_load_en,
    input logic signed [DATA_W - 1 : 0] weight_in, 
    input logic signed [DATA_W - 1 : 0] act_in, 
    input logic signed [ACC_W - 1 : 0] psum_in, 
    input logic advance,
    output logic signed [DATA_W - 1 : 0] act_out, 
    output logic signed [ACC_W - 1 : 0] psum_out
    );

    logic signed [DATA_W - 1 : 0] weight_working;
    logic signed [ACC_W - 1 : 0] mac_result;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            weight_working <= 0;
            act_out <= 0;
            psum_out <= 0;
        end
        else begin
            if(weight_load_en)
                weight_working <= weight_in;
            if(advance) begin
                act_out <= act_in;
                psum_out <= mac_result;
            end
        end
    end

    assign mac_result = (act_in * weight_working) + psum_in;

endmodule
    