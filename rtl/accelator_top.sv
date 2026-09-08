module accelerator_top #(
    parameter int ARRAY_SIZE   = 16,
    parameter int DATA_W       = 8,
    parameter int ACC_W        = 32,
    parameter int DEPTH        = 4
)(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            start,
    input  logic                            first_tile,
    input  logic                            last_tile,

    input  logic                            weight_valid,
    input  logic [ARRAY_SIZE*DATA_W-1:0]    weight_data,
    output logic                            weight_ready,

    input  logic                            act_valid,
    input  logic [ARRAY_SIZE*DATA_W-1:0]    act_data,
    input  logic                            act_last,
    output logic                            act_ready,

    output logic                            result_valid,
    input  logic                            result_ready,
    output logic [ARRAY_SIZE*ACC_W-1:0]     result_data,
    output logic                            done
);

    logic [ARRAY_SIZE-1:0]         weight_row_en;
    logic                          consume_en;
    logic                          array_advance;
    logic                          stream_stall;
    logic                          act_last_out;
    logic                          capture;
    logic                          fsm_result_valid;
    logic [ARRAY_SIZE*DATA_W-1:0]  act_vector_data;
    logic [ARRAY_SIZE*ACC_W-1:0]   array_result;

    logic signed [ACC_W-1:0]       accum [ARRAY_SIZE];

    fsm #(
        .ARRAY_SIZE   (ARRAY_SIZE)
    ) u_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .last_tile      (last_tile),
        .weight_valid   (weight_valid),
        .act_last       (act_last_out),
        .result_ready   (result_ready),
        .array_advance  (array_advance),
        .stream_stalled (stream_stall),
        .weight_ready   (weight_ready),
        .weight_row_en  (weight_row_en),
        .consume_en     (consume_en),
        .result_valid   (fsm_result_valid),
        .capture        (capture),
        .done           (done)
    );

    activation_buffer #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_W     (DATA_W),
        .DEPTH      (DEPTH)
    ) u_act_buf (
        .clk             (clk),
        .rst_n           (rst_n),
        .act_valid       (act_valid),
        .act_data_in     (act_data),
        .act_last_in     (act_last),
        .consume_en      (consume_en),
        .act_ready       (act_ready),
        .act_vector_data (act_vector_data),
        .array_advance   (array_advance),
        .act_last_out    (act_last_out),
        .stream_stall    (stream_stall)
    );

    systolic_array #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_W     (DATA_W),
        .ACC_W      (ACC_W)
    ) u_array (
        .clk             (clk),
        .rst_n           (rst_n),
        .weight_row_data (weight_data),
        .weight_row_en   (weight_row_en),
        .act_vector_data (act_vector_data),
        .array_advance   (array_advance),
        .result_out      (array_result)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int c = 0; c < ARRAY_SIZE; c++)
                accum[c] <= '0;
        end
        else if (capture) begin
            for (int c = 0; c < ARRAY_SIZE; c++)
                accum[c] <= (first_tile ? '0 : accum[c])
                          + $signed(array_result[c*ACC_W +: ACC_W]);
        end
    end

    assign result_valid = fsm_result_valid;

    generate
        for (genvar c = 0; c < ARRAY_SIZE; c++) begin : result_pack
            assign result_data[c*ACC_W +: ACC_W] = accum[c];
        end
    endgenerate

endmodule