module fsm #(
    parameter ARRAY_SIZE = 16
) (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic last_tile,
    input logic weight_valid,
    input logic act_last,
    input logic result_ready,
    input logic array_advance,
    input logic stream_stalled,
    
    output logic weight_ready,
    output logic [ARRAY_SIZE-1:0] weight_row_en,
    output logic consume_en,
    output logic result_valid,
    output logic capture,
    output logic done
);
localparam DRAIN_CYCLES = 2*ARRAY_SIZE - 1;

typedef enum logic [2:0] {IDLE,LOAD_WEIGHT, STREAM, DRAIN, RESULT_OUT } state_t;
state_t state, nstate;

logic [$clog2(ARRAY_SIZE+1) - 1 :0] weight_count,result_count;
logic [$clog2(DRAIN_CYCLES+1) - 1 : 0] drain_count;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= nstate;
    end
end

always_comb begin
    nstate = state;
    weight_ready = 0;
    consume_en = 0;
    result_valid = 0;
    weight_row_en = 0;
    done = 0;
    capture = 0;
    case (state)
        IDLE: begin
            if(start)
                nstate = LOAD_WEIGHT;
        end
        LOAD_WEIGHT: begin
            weight_ready = weight_count < ARRAY_SIZE;
            if(weight_valid && weight_ready)
                weight_row_en[weight_count] = 1;
            if(weight_count == ARRAY_SIZE)
                nstate = STREAM;
            
        end
        STREAM: begin
            consume_en = 1;
            if(act_last && array_advance && !stream_stalled)
                nstate = DRAIN;
            
        end
        DRAIN: begin
            if(drain_count == DRAIN_CYCLES) begin
                capture = 1;
                nstate = last_tile ? RESULT_OUT : LOAD_WEIGHT;
            end
        end
        RESULT_OUT: begin
            result_valid = 1;
            if(result_count == ARRAY_SIZE) begin
                done = 1;
                nstate = last_tile ? IDLE : LOAD_WEIGHT;
                /*if(!last_tile)
                    nstate = LOAD_WEIGHT;
                else 
                    nstate = IDLE; */
            end
        end        
        default: begin
            nstate = IDLE;
        end
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        weight_count <= 0;
    end
    else begin
        if(state != LOAD_WEIGHT)
            weight_count <= 0;
        else if(weight_valid && weight_ready)
            weight_count <= weight_count + 1;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        drain_count <= 0;
    end
    else begin
        if(state != DRAIN)
            drain_count <= 0;
        else
            drain_count <= drain_count + 1;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        result_count <= 0;
    end
    else begin
        if(state != RESULT_OUT)
            result_count <= 0;
        else if(result_valid && result_ready)
            result_count <= result_count + 1; 
    end
end
endmodule