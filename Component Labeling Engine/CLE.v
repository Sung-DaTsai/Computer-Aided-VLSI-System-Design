`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset;
input  [7:0]  rom_q;
output [6:0]  rom_a;
output [9:0]  sram_a;
output [7:0]  sram_d;
output        sram_wen;
output        finish;

reg [7:0] rom_q_r;
reg [9:0] sram_a_w, sram_a_r;
reg [7:0] sram_d_w, sram_d_r;
reg [4:0] state_w, state_r;
reg [2:0] counter_w, counter_r;
reg [6:0] rom_a_w, rom_a_r;
reg finish_output_w, finish_output_r;
reg sram_wen_w, sram_wen_r; 
reg [7:0] min_label_w, min_label_r;
reg [7:0] label_counter_w, label_counter_r;
reg conflict_w, conflict_r;
reg is_read1_w, is_read1_r;
reg is_second_pass_r, is_second_pass_w;
/////////////////// For rom only
reg [9:0] place_r, place_w;
reg [7:0] addr_place_r, addr_place_w;

////////////////////

/////////////////// For SRAM only
reg cen_n3, wen_n3;
wire cen_n;
wire wen_n;
reg [7:0] addr_n3;
wire [7:0] addr_r3;
wire [7:0] write_data_r;
reg [7:0] write_data_r2;
wire [7:0] read_data_r2;

assign write_data_r = write_data_r2;
assign addr_r3 = addr_n3;
assign cen_n = cen_n3;
assign wen_n = wen_n3;
//////////////////

////////////////// For output port only
assign sram_a = sram_a_r;
assign sram_d = sram_d_r;
assign rom_a = rom_a_r;
assign finish = finish_output_r;
assign sram_wen = sram_wen_r;
//////////////////


sram_256x8 sram3(.Q(read_data_r2), .CLK(clk), .CEN(cen_n), .WEN(wen_n), .A(addr_r3), .D(write_data_r));


parameter IDLE = 5'b0000;
parameter IDLE2 = 5'b0001;
parameter IDLE3 = 5'b0010;
parameter LABELING = 5'b0011;
parameter SRAM_READ1 = 5'b0100;
parameter SRAM_READ3 = 5'b0101;
parameter SRAM_CHECK3 = 5'b0110;
parameter SRAM_LABEL = 5'b0111;
parameter UPDATE_LABEL_READ = 5'b1000;
parameter UPDATE_LABEL_CHECK = 5'b1001;
parameter UPDATE_LABEL_OVERWRITE = 5'b1010;
parameter FINISH_ALL = 5'b1101;
parameter FIND_MIN_LABEL1 = 5'b1110;
parameter FIND_MIN_LABEL2 = 5'b1111;
parameter NEXT_ROW = 5'b10000;
parameter UPDATE_ROW = 5'b10001;
parameter SECOND_GET_LABEL = 5'b10010;
parameter SECOND_OUTPUT = 5'b10011;
// Combinational Part
always@(*) begin
    counter_w = counter_r;
	sram_a_w = sram_a_r;
	sram_d_w = sram_d_r;
	rom_a_w = rom_a_r;
	sram_wen_w = 1'b1;
	state_w = state_r;
	place_w = place_r;
	finish_output_w = 1'b0;
	addr_n3 = 8'b0;
	cen_n3 = 1'b0;
	wen_n3 = 1'b1;
	write_data_r2 = 8'b0;
	min_label_w = min_label_r;
	label_counter_w = label_counter_r;
	conflict_w = conflict_r;
	is_read1_w = is_read1_r;
	is_second_pass_w = is_second_pass_r;
	addr_place_w = addr_place_r;
    case (state_r)
		IDLE: begin
			rom_a_w = 7'b0;
			counter_w = 3'b111;
            addr_place_w = addr_place_r + 1;
            addr_n3 = addr_place_r;
            write_data_r2 = addr_place_r;
            cen_n3 = 1'b0;
            wen_n3 = 1'b0;
            if (addr_place_r == 8'd191) begin
                addr_place_w = 8'b0;
                state_w = IDLE2;
            end
		end
		IDLE2: begin
			state_w = IDLE3;
		end
		IDLE3: begin
			state_w = LABELING;
		end
		LABELING: begin
			place_w = {rom_a_r, {~counter_r}};
			addr_place_w = {3'b111, place_w[4:0]};
			conflict_w = 1'b0;
			if (!(|counter_r)) begin
				counter_w = 3'b111;
				rom_a_w = rom_a_r + 1;
				if (!rom_q_r[counter_r])
					state_w = (&addr_place_w[4:0]) ? NEXT_ROW : IDLE2;
			end else begin
				counter_w = counter_r - 3'b1;
			end
			if (rom_q_r[counter_r]) begin
				if (!(|place_w[4:0])) begin  // Check upward 2,3; check 2 now, no conflict occur
					state_w = SRAM_READ3;
					is_read1_w = 1'b0;
					min_label_w = 8'b11111111;
					addr_n3 = {3'b110, addr_place_w[4:0]};
				end else if (!(|min_label_r)) begin // Check upward 1,2,3; check 2 now, 213, 23
					if (!(|place_w[9:5])) begin  // assign in a new label
						wen_n3 = 1'b0;
						cen_n3 = 1'b0;
						addr_n3 = addr_place_w;
						write_data_r2 = label_counter_r;
						label_counter_w = label_counter_r + 1;
						//sram_a_w = place_w;
						//sram_d_w = label_counter_r;
						//sram_wen_w = 1'b0;
						min_label_w = label_counter_r;

						if (!is_second_pass_r) begin
							if (!(|counter_r))
								state_w = (&addr_place_w[4:0]) ? NEXT_ROW : IDLE2;
						end else begin
							state_w = SECOND_GET_LABEL;
						end
					end else begin
						state_w = SRAM_READ1;
						min_label_w = 8'b11111111;
						addr_n3 = {3'b110, addr_place_w[4:0]};
						conflict_w = 1'b1;
					end
				end else begin // Check right upward 3 and left 4; check 3 now, 4 is min_label_r
					state_w = SRAM_CHECK3;
					addr_n3 = addr_place_w - 8'd31;
					conflict_w = 1'b1;
				end
			end else begin // 0: Directly assign to output and sram
				cen_n3 = 1'b0;
				wen_n3 = 1'b0;
				write_data_r2 = 8'b0;
				addr_n3 = addr_place_w;
				sram_a_w = place_w;
				sram_d_w = 8'b0;
				sram_wen_w = 1'b0;
				min_label_w = 8'b0;
				if (&place_w) begin
					state_w = (is_second_pass_r) ? FINISH_ALL : UPDATE_LABEL_READ;
					place_w = 10'd2;
				end
			end
		end
		SRAM_READ1: begin // if 2 has value, read 3 instead of 1
			addr_n3 = addr_place_r - 8'd33;
			state_w = SRAM_READ3;
			is_read1_w = 1'b1;
			if (|read_data_r2) begin
				min_label_w = read_data_r2;
				conflict_w = 1'b0;
				state_w = SRAM_CHECK3;
				addr_n3 = addr_place_r - 8'd31;
			end
		end
		SRAM_READ3: begin
			if (is_read1_r && (!((!(|place_r[9:5])) || (!(|place_r[4:0]))))) begin
				if (|read_data_r2) min_label_w = read_data_r2;
				else conflict_w = 1'b0;
			end else if ((!is_read1_r) && (|place_r[9:5])) begin
				if (|read_data_r2) min_label_w = read_data_r2;
				else conflict_w = 1'b0;
			end
			addr_n3 = addr_place_r - 8'd31;
			state_w = SRAM_CHECK3;
		end
		SRAM_CHECK3: begin
			addr_n3 = addr_place_r;
			state_w = SRAM_LABEL;
			if (!((!(|place_r[9:5])) || (&place_r[4:0]))) begin
				if (&min_label_r) begin
					conflict_w = 1'b0;
					if (|read_data_r2) min_label_w = read_data_r2;
				end else if (|read_data_r2) begin
					if (min_label_r > read_data_r2) begin
						min_label_w = read_data_r2;
						if (conflict_r && !is_second_pass_r) begin // Downward to find the smallest label
							addr_n3 = min_label_r;
							cen_n3 = 1'b0;
							wen_n3 = 1'b1;
							state_w = FIND_MIN_LABEL1;
							sram_a_w = {2'b00, min_label_r};
							sram_d_w = read_data_r2;
						end
					end else if (min_label_r < read_data_r2) begin
						if (conflict_r && !is_second_pass_r) begin
							addr_n3 = min_label_r;
							cen_n3 = 1'b0;
							wen_n3 = 1'b1;
							state_w = FIND_MIN_LABEL1;
							sram_a_w = {2'b00, min_label_r};
							sram_d_w = read_data_r2;
						end
					end else begin
						conflict_w = 1'b0;
					end
				end
			end
		end
		FIND_MIN_LABEL1: begin
			sram_a_w[7:0] = read_data_r2;
			if (sram_a_r[7:0] == read_data_r2) begin
				if (sram_a_r[7:0] >= sram_d_r) begin
					state_w = SRAM_LABEL;
					addr_n3 = read_data_r2;
					write_data_r2 = sram_d_r;
					cen_n3 = 1'b0;
					wen_n3 = 1'b0;
				end else begin
					state_w = FIND_MIN_LABEL2;
					addr_n3 = sram_d_r;
					cen_n3 = 1'b0;
					wen_n3 = 1'b1;
				end
			end else if (read_data_r2 == sram_d_r) begin
				state_w = SRAM_LABEL;
			end else begin
				state_w = FIND_MIN_LABEL1;
				addr_n3 = read_data_r2;
				cen_n3 = 1'b0;
				wen_n3 = 1'b1;
			end
		end
		FIND_MIN_LABEL2: begin
			sram_d_w = read_data_r2;
			if (read_data_r2 <= sram_a_r[7:0]) begin
				state_w = SRAM_LABEL;
				addr_n3 = sram_a_r[7:0];
				write_data_r2 = read_data_r2;
				cen_n3 = 1'b0;
				wen_n3 = 1'b0;
			end else if (sram_d_r == read_data_r2) begin
				state_w = SRAM_LABEL;
				if (sram_a_r[7:0] > sram_d_r) begin
					addr_n3 = sram_a_r[7:0];
					write_data_r2 = sram_d_r;
					cen_n3 = 1'b0;
					wen_n3 = 1'b0;
				end else begin
					addr_n3 = sram_d_r;
					write_data_r2 = sram_a_r[7:0];
					cen_n3 = 1'b0;
					wen_n3 = 1'b0;
				end
			end else begin
				state_w = FIND_MIN_LABEL2;
				addr_n3 = read_data_r2;
				cen_n3 = 1'b0;
				wen_n3 = 1'b1;
			end
		end
		SRAM_LABEL: begin
			if (min_label_r != 8'b11111111) begin
				write_data_r2 = min_label_r;
			end else begin
				write_data_r2 = label_counter_r;
				label_counter_w = label_counter_r + 1;
			end
			min_label_w = write_data_r2;
			addr_n3 = addr_place_r;
			wen_n3 = 1'b0;
			cen_n3 = 1'b0;
			if (!is_second_pass_r) begin
				state_w = (&addr_place_w[4:0]) ? NEXT_ROW : LABELING;
				if (&place_r) begin
					state_w = UPDATE_LABEL_READ;
					place_w = 10'd2;
				end
			end else begin
				state_w = SECOND_GET_LABEL;
			end
		end
		SECOND_GET_LABEL: begin
			addr_n3 = min_label_r;
			wen_n3 = 1'b1;
			cen_n3 = 1'b0;
			state_w = SECOND_OUTPUT;
		end
		SECOND_OUTPUT: begin
			sram_a_w = place_r;
			sram_d_w = read_data_r2;
			sram_wen_w = 1'b0;
			if (&place_r)
				state_w = FINISH_ALL;
			else 
				state_w = (&addr_place_w[4:0]) ? NEXT_ROW : LABELING;
		end
		NEXT_ROW: begin
			addr_n3 = addr_place_r;
			wen_n3 = 1'b1;
			cen_n3 = 1'b0;
			state_w = UPDATE_ROW;
		end
		UPDATE_ROW: begin
			addr_n3 = {addr_place_r[7:6], 1'b0, addr_place_r[4:0]};
			wen_n3 = 1'b0;
			cen_n3 = 1'b0;
			write_data_r2 = read_data_r2;
			addr_place_w = addr_place_r - 1;
			if (!(|addr_place_r[4:0]))
				state_w = LABELING;
			else
				state_w = NEXT_ROW;
		end
		UPDATE_LABEL_READ: begin
			addr_n3 = place_r[7:0];
			cen_n3 = 1'b0;
			wen_n3 = 1'b1;
			state_w = UPDATE_LABEL_CHECK;
		end
		UPDATE_LABEL_CHECK: begin
			cen_n3 = 1'b0;
			wen_n3 = 1'b1;
			if (read_data_r2 == place_r[7:0]) begin // Check next label
				place_w = place_r + 1;
				addr_n3 = place_w[7:0];
				if (place_w[7:0] == label_counter_r) begin
					rom_a_w = 7'b0;
					counter_w = 3'b111;
					state_w = IDLE2;
					label_counter_w = 8'd1;
					is_second_pass_w = 1'b1;
				end
			end else begin // Overwrite label
				addr_n3 = read_data_r2;
				state_w = UPDATE_LABEL_OVERWRITE;
			end
		end
		UPDATE_LABEL_OVERWRITE: begin
			addr_n3 = place_r[7:0];
			cen_n3 = 1'b0;
			wen_n3 = 1'b0;
			write_data_r2 = read_data_r2;
			place_w = place_r + 1;
			state_w = UPDATE_LABEL_READ;
			if (place_w[7:0] == label_counter_r) begin
				rom_a_w = 7'b0;
				counter_w = 3'b111;
				state_w = IDLE2;
				is_second_pass_w = 1'b1;
				label_counter_w = 8'd1;
			end
		end
	/*	SECOND_PASS_CHECK: begin
			cen_n3 = 1'b0;
			wen_n3 = 1'b1;
			if (is_sram2_r) begin
				addr_n3 = read_data_r1;
			end else begin
				addr_n3 = read_data_r0;
			end
			state_w = SECOND_PASS_OVERWRITE;
		end
		SECOND_PASS_OVERWRITE: begin
			state_w = SECOND_PASS_CHECK;
			sram_a_w = place_r;
			sram_d_w = read_data_r2;
			sram_wen_w = 1'b0;
			if (!(|counter_r)) begin
				rom_a_w = rom_a_r + 1;
				counter_w = 3'b111;
				if (&rom_a_r) state_w = FINISH_ALL;
			end else begin
				counter_w = counter_r - 1;
				if ((counter_r[1:0] == 2'b10) && (!(|rom_q_r))) begin //check if all 8 bits are 0
					rom_a_w = rom_a_r + 1;
					counter_w = 3'b111;
					if (&rom_a_r) state_w = FINISH_ALL;
				end
			end
			place_w = {rom_a_w, {~counter_w}};
			{is_sram2_w, addr_n} = place_w;
		end*/
		FINISH_ALL: begin
			finish_output_w = 1'b1;
		end
		default: begin
		end
    endcase

end

// Sequential Part
always@(posedge clk or posedge reset) begin
    if (reset) begin
		state_r <= IDLE;
		counter_r <= 3'b0;
		sram_a_r <= 10'b0;
		sram_d_r <= 8'b0;
		rom_a_r <= 7'b0;
		sram_wen_r <= 1'b0;
		rom_q_r <= 8'b0;
		place_r <= 10'b0;
		finish_output_r <= 1'b0;
		min_label_r <= 8'b11111111;
		label_counter_r <= 8'b1;
		conflict_r <= 1'b0;
		is_read1_r <= 1'b0;
		addr_place_r <= 8'b0;
		is_second_pass_r <= 1'b0;
    end else begin
		state_r <= state_w;
		counter_r <= counter_w;
		sram_a_r <= sram_a_w;
		sram_d_r <= sram_d_w;
		rom_a_r <= rom_a_w;
		sram_wen_r <= sram_wen_w;
		rom_q_r <= rom_q;
		place_r <= place_w;
		finish_output_r <= finish_output_w;
		min_label_r <= min_label_w;
		label_counter_r <= label_counter_w;
		conflict_r <= conflict_w;
		is_read1_r <= is_read1_w;
		addr_place_r <= addr_place_w;
		is_second_pass_r <= is_second_pass_w;
    end
end

endmodule


