`timescale 1ns / 1ps

module receiver#(
    parameter NB_DATA = 8
)(
    input wire i_rx,
    input wire i_tick,
    input wire i_clock,
    input wire i_reset,
    output wire [NB_DATA-1:0] o_rx_data,
    output wire o_rx_done
);
//4 estados, sin bit partidad, 1 solo bit de stop 
localparam IDLE_STATE =     4'b0001;
localparam START_STATE =    4'b0010;
localparam DATA_STATE =     4'b0100;
localparam STOP_STATE =     4'b1000;

localparam NB_STATES = 4;
reg [NB_STATES-1:0] state;
reg [NB_STATES-1:0] next_state;

//contador de ticks, maxima cuenta hasta 15
localparam NB_TICK_COUNTER = 4; 
reg [NB_TICK_COUNTER-1:0] tick_counter,next_tick_counter;
//reg tick_counter_enable;
//reg tick_counter_reset;

//contador de data recibida, maximo hasta 7
localparam NB_DATA_COUNTER = 3;
reg [NB_DATA_COUNTER-1:0] data_counter, next_data_counter;
//reg data_counter_increment;
//reg data_counter_reset;
reg [NB_DATA-1:0] data, next_data;
//reg data_valid;

reg rx_done, next_rx_done;

//NO SETEAR VARIABLES EN 2 ALWAYS? CREO Q PUEDE SOLUCIONAR - MIRAR TP DE FACU rx_v2 

//memoria de estado
always@(posedge i_clock)
begin
    if(i_reset)
        state <= IDLE_STATE;
    else
        state <= next_state;
end

//contador de ticks
always@(posedge i_clock)
begin
    //if(i_reset || tick_counter_reset)
    if(i_reset)
    begin
        tick_counter <= {NB_TICK_COUNTER{1'b0}};
        //tick_counter_reset <= 1'b0;
    end
    else 
         tick_counter <= next_tick_counter;
end

//contador de datos
always@(posedge i_clock)
begin
    if(i_reset)
    begin
        data_counter <= {NB_DATA_COUNTER{1'b0}};
    end
    //else if(data_counter_increment)
    else
    begin    
        //data_counter <= data_counter + 1;
        data_counter <= next_data_counter;
         //data_counter_increment <= 1'b0;
    end 
end

always@(posedge i_clock)
begin
    if(i_reset)
    begin
        data <= {NB_DATA{1'b0}};
    end
    //else if(data_valid)
    else 
    begin    
        //data <= {i_rx,data[NB_DATA-1: 1]}; //va concatenando la entrada, el primer dato recibido queda como LSB
        data <= next_data; //va concatenando la entrada, el primer dato recibido queda como LSB
        //data_valid <= 1'b0;
    end 
end

always@(posedge i_clock)
begin
    if(i_reset)
    begin
        rx_done <= 1'b0;
    end
    //else if(data_valid)
    else 
    begin    
        rx_done <= next_rx_done;
    end 
end


//next_state logic
always@(*)
begin
    next_state = state;
    next_rx_done = 1'b0;
    next_data_counter = data_counter;
    next_tick_counter = tick_counter;
    next_data = data;
    case(state)
        IDLE_STATE:
        begin
            next_rx_done = 1'b0;
            //data_counter_reset = 1'b1; //resetear contador de datos
            next_data = {NB_DATA{1'b0}};
            if(i_rx == 0)
            begin    
                next_state = START_STATE;
                //tick_counter_enable = 1'b1; //iniciar contador de ticks
                next_tick_counter = {NB_TICK_COUNTER{1'b0}};
            end
            else
                next_state = IDLE_STATE;
        end
        START_STATE:
        begin
            if(i_tick)
            begin
                if(tick_counter == 4'b0111) //si el contador de ticks es igual a 8, mitad del START
                begin
                    if(i_rx == 0)
                    begin
                        next_state = DATA_STATE;
                        next_tick_counter = {NB_TICK_COUNTER{1'b0}};
                        next_data_counter = {NB_DATA_COUNTER{1'b0}};  
                    end 
                    else 
                        next_state = IDLE_STATE;
                end
                else
                begin
                    next_tick_counter = tick_counter + 1;
                    next_state = START_STATE;
                end
            end
        end    
        DATA_STATE:
        begin
            if(i_tick)
            begin
                if(tick_counter == 4'b1111) //si el contador de ticks es igual a 15 
                begin
                    //data_valid = 1'b1;
                    next_data = {i_rx,data[NB_DATA-1: 1]}; //va concatenando la entrada, el primer dato recibido queda como LSB
                    //data_counter_increment = 1'b1; //incrementyar el contador de datos
                    next_data_counter = data_counter + 1;
                    next_tick_counter = {NB_TICK_COUNTER{1'b0}};
                    //tick_counter_reset = 1'b1; //reiniciar contador de ticks
                    if(data_counter == 3'b111) //data igual a 8, ya estan todos los datos
                        next_state = STOP_STATE;
                    else
                        next_state = DATA_STATE;
                end
                else
                begin
                    next_tick_counter = tick_counter + 1;
                    next_state = DATA_STATE;
                end
            end
        end        
        STOP_STATE: //estado para verificar recepcion de bit de STOP
        begin
            if(i_tick)
                if(tick_counter == 4'b1111)
                begin
                    if(i_rx == 1'b1)   //verifica el bit de stop 
                    begin
                        next_rx_done = 1'b1; //indica q el dato termino de recibirse
                    end
                    
                    next_state = IDLE_STATE;
                end
                else
                begin
                    next_tick_counter = tick_counter + 1;
                    next_state = STOP_STATE;
                end                    
        end
        default:
        begin
            next_state = IDLE_STATE;
        end
    endcase              
end

assign o_rx_done = rx_done;
assign o_rx_data = data;

endmodule
