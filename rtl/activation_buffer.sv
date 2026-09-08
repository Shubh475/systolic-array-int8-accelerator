module activation_buffer #(
    parameter int ARRAY_SIZE = 16,
    parameter int DATA_W = 8,
    parameter int DEPTH = 4
) (
    input logic clk,
    input logic rst_n,
    input logic act_valid,
    input logic [ARRAY_SIZE*DATA_W - 1 : 0] act_data_in,
    input logic act_last_in,
    input logic consume_en,

    output logic act_ready,
    output logic [ARRAY_SIZE*DATA_W - 1 : 0] act_vector_data,
    output logic array_advance,
    output logic act_last_out,
    output logic stream_stall
);

logic [ARRAY_SIZE * DATA_W : 0] buffer [2][DEPTH];
logic buf_sel;
logic [1:0] filled;
logic [2:0] fill_count, consume_count;

wire fill_target = ~buf_sel;
wire other_buffer_filled = filled[fill_target];

assign act_ready = (fill_count < DEPTH) && !other_buffer_filled;
//assign filled[fill_target] = fill_count == DEPTH;

wire last_slot_consume = consume_count == DEPTH - 1;
wire can_consume = consume_en && (!last_slot_consume || other_buffer_filled);

assign array_advance = can_consume;
assign stream_stall = consume_en && last_slot_consume && !other_buffer_filled;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(int i=0;i<2;i=i+1) begin
            for(int j=0;j<DEPTH;j=j+1)
                buffer[i][j] <= 0;
        end
    end
    else begin
        if(act_valid && act_ready)
            buffer[fill_target][fill_count] <= {act_data_in,act_last_in};
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        fill_count <= 0;
    else begin
        if(act_valid && act_ready) begin
            fill_count <= (fill_count == DEPTH - 1)? 0 : fill_count + 1;
        end
    end
end
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        consume_count <= 0;
        filled <= 0;
        buf_sel <= 0;
    end    
    else begin
        if(act_valid && act_ready && fill_count == DEPTH - 1)
            filled[fill_target] <= 1;

        if(can_consume) begin
            if(last_slot_consume) begin
                consume_count <= 0;
                buf_sel <= ~buf_sel;
                filled[buf_sel] <= 0;
            end
            else 
                consume_count <= consume_count + 1;
        end
    end
end

assign {act_vector_data,act_last_out} = buffer[buf_sel][consume_count];

endmodule
