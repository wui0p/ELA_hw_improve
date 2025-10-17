`timescale 1ns/10ps

module ELA(clk, rst, in_data, data_rd, req, wen, addr, data_wr, done);

	input					clk;
	input					rst;
	input			[7:0]	in_data;
	input			[7:0]	data_rd;
	output logic			req;
	output logic			wen;
	output logic	[9:0]	addr;
	output logic	[7:0]	data_wr;
	output logic			done;

//======================================
//	VARIABLES
//======================================

logic [3:0] state, next_state;
parameter IDLE=0, STORE=1, BUFF=2, CALL_START=3, CALL=4, ELA_LEFT=5, ELA=6, ELA_RIGHT=7, FINISH=8;

logic [7:0] ela_value;
logic [2:0] step;
logic [7:0] save_data [0:5];
logic [7:0] d_1, d_2, d_3;
logic [7:0] x_1, x_2, x_3;
logic [9:0] addr_row [0:2];

//======================================
//	ASSIGN
//======================================

assign data_wr = (state==STORE||state==BUFF)? save_data[0] : 
				(state==ELA)? ela_value : 
				(state==ELA_RIGHT)? (save_data[2] + save_data[5]) / 2 : (save_data[0] + save_data[3]) / 2;
assign d_1 = (save_data[0] > save_data[5])? (save_data[0] - save_data[5]) : (save_data[5] - save_data[0]);
assign d_2 = (save_data[1] > save_data[4])? (save_data[1] - save_data[4]) : (save_data[4] - save_data[1]);
assign d_3 = (save_data[2] > save_data[3])? (save_data[2] - save_data[3]) : (save_data[3] - save_data[2]);
assign x_1 = (save_data[0] + save_data[5]) / 2;
assign x_2 = (save_data[1] + save_data[4]) / 2;
assign x_3 = (save_data[2] + save_data[3]) / 2;
assign ela_value = (d_2 <= d_1)? ((d_2 <= d_3)? x_2 : x_3) : ((d_1 <= d_3)? x_1 : x_3); 

//======================================
//	FSM
//======================================

always_ff @(posedge clk, posedge rst) begin
	if(rst) state <= IDLE;
	else state <= next_state;
end

always_comb begin
	case(state)
		IDLE: begin
			if(!rst) next_state = STORE;
			else next_state = state;
		end
		STORE: begin
			if(addr==991) next_state = BUFF;
			else next_state = state;
		end
		BUFF: begin
			next_state = CALL_START;
		end
		CALL_START: begin
			if(step==5) next_state = ELA_LEFT;
			else next_state = state;
		end
		CALL: begin
			if(step==1) next_state = ELA;
			else next_state = state;
		end
		ELA_LEFT: begin
			next_state = ELA;
		end
		ELA: begin
			if(addr[4:0]==5'b1_1110) next_state = ELA_RIGHT;
			else next_state = CALL;
		end
		ELA_RIGHT: begin
			if(addr==959) next_state = FINISH;
			else next_state = CALL_START;	//asghjkl;
		end
		FINISH: begin
			next_state = state;
		end
		default: next_state = state;
	endcase
end

always_comb begin
	case(state)
		CALL_START: begin
			if(step <= 2) addr = addr_row[0];
			else addr = addr_row[2];
		end
		CALL: begin
			if(step==0) addr = addr_row[0];
			else addr = addr_row[2];
		end


		ELA,
		ELA_LEFT,
		ELA_RIGHT: addr = addr_row[1];

		default: addr = addr_row[0];
	endcase
end

always_comb begin
	done = 1'b0;
	wen = 1'bx;
	case(state)
		BUFF,
		CALL_START,
		CALL: wen = 0;

		STORE,
		ELA_LEFT,
		ELA,
		ELA_RIGHT: wen = 1;
		
		FINISH: begin
			wen = 1;
			done = 1;
		end
	endcase
end

//======================================
//	POS SEQ LOGIC
//======================================

// req
always_ff @(posedge clk) begin
	case(state)
		IDLE: begin
			if(!rst) req <= 1;
			else req <= 0;
		end
		STORE: begin
			if(req) req <= 0;
			else if(addr==990 || addr==991) req <= 0;
			else if(addr[4:0]==5'b1_1110 || addr[4:0]==5'b1_1111) req <= 1;
			else req <= 0;
		end
		default: req <= 0;
	endcase
end

// addr_row
always_ff @(posedge clk) begin
	case(state)
		IDLE: begin
			addr_row[0] <= 10'b11_1111_1111;
		end
		STORE: begin
			if(addr==10'b11_1111_1111) addr_row[0] <= 0;
			else if(addr[4:0]==5'b1_1111) addr_row[0] <= addr_row[0] + 33;
			else addr_row[0] <= addr_row[0] + 1;
		end
		BUFF: begin
			addr_row[0] <= 0;
			addr_row[1] <= 32;
			addr_row[2] <= 64;
		end
		CALL_START: begin
			case(step)
				0,
				1: addr_row[0] <= addr_row[0] + 1;
				3,
				4: addr_row[2] <= addr_row[2] + 1;
			endcase
		end
		CALL: begin
			case(step)
				0: addr_row[2] <= addr_row[2] + 1;
				1: addr_row[1] <= addr_row[1] + 1;
			endcase
		end
		ELA_LEFT: begin
			addr_row[1] = addr_row[1] + 1;
		end
		ELA: begin
			if(addr[4:0]==5'b1_1110) addr_row[1] = addr_row[1] + 1;
			else addr_row[0] = addr_row[0] + 1;
		end
		ELA_RIGHT: begin
			addr_row[0] <= addr_row[0] + 33;
			addr_row[1] <= addr_row[1] + 33;
			addr_row[2] <= addr_row[2] + 33;
		end
		default: ;
	endcase
end



// step
always_ff @(posedge clk) begin
	case(state)
		CALL_START,
		CALL: begin
			step <= step + 1;
		end
		default: step <= 0;
	endcase
end

// save_data
always_ff @(posedge clk) begin
	case(state)
		STORE: begin
			save_data[0] <= in_data;
		end
		CALL_START: begin
			save_data[step] <= data_rd;
		end
		ELA: begin
			save_data[0] <= save_data[1];
			save_data[1] <= save_data[2];
			save_data[3] <= save_data[4];
			save_data[4] <= save_data[5];
		end
		CALL: begin
			if(step==0) begin
				save_data[2] <= data_rd;
			end else begin
				save_data[5] <= data_rd;
			end
		end
		default: ;
	endcase
end


endmodule



// `timescale 1ns/10ps

// module ELA(clk, rst, in_data, data_rd, req, wen, addr, data_wr, done);

// 	input					clk;
// 	input					rst;
// 	input			[7:0]	in_data;
// 	input			[7:0]	data_rd;
// 	output logic			req;
// 	output logic			wen;
// 	output logic	[9:0]	addr;
// 	output logic	[7:0]	data_wr;
// 	output logic			done;

// //======================================
// //	VARIABLES
// //======================================

// logic [3:0] state, next_state;
// parameter IDLE=0, STORE=1, BUFF=2, CALL_START=3, CALL=4, ELA_LEFT=5, ELA=6, ELA_RIGHT=7, FINISH=8;

// logic [7:0] ela_value;
// logic [2:0] step;
// logic [7:0] save_data [0:5];
// logic [7:0] d_1, d_2, d_3;
// logic [7:0] x_1, x_2, x_3;

// //======================================
// //	ASSIGN
// //======================================

// assign data_wr = (state==STORE||state==BUFF)? save_data[0] : 
// 				(state==ELA)? ela_value : 
// 				(state==ELA_RIGHT)? (save_data[2] + save_data[5]) / 2 : (save_data[0] + save_data[3]) / 2;
// assign d_1 = (save_data[0] > save_data[5])? (save_data[0] - save_data[5]) : (save_data[5] - save_data[0]);
// assign d_2 = (save_data[1] > save_data[4])? (save_data[1] - save_data[4]) : (save_data[4] - save_data[1]);
// assign d_3 = (save_data[2] > save_data[3])? (save_data[2] - save_data[3]) : (save_data[3] - save_data[2]);
// assign x_1 = (save_data[0] + save_data[5]) / 2;
// assign x_2 = (save_data[1] + save_data[4]) / 2;
// assign x_3 = (save_data[2] + save_data[3]) / 2;
// assign ela_value = (d_2 <= d_1)? ((d_2 <= d_3)? x_2 : x_3) : ((d_1 <= d_3)? x_1 : x_3); 

// //======================================
// //	FSM
// //======================================

// always_ff @(posedge clk, posedge rst) begin
// 	if(rst) state <= IDLE;
// 	else state <= next_state;
// end

// always_comb begin
// 	case(state)
// 		IDLE: begin
// 			if(!rst) next_state = STORE;
// 			else next_state = state;
// 		end
// 		STORE: begin
// 			if(addr==991) next_state = BUFF;
// 			else next_state = state;
// 		end
// 		BUFF: begin
// 			next_state = CALL_START;
// 		end
// 		CALL_START: begin
// 			if(step==5) next_state = ELA_LEFT;
// 			else next_state = state;
// 		end
// 		CALL: begin
// 			if(step==1) next_state = ELA;
// 			else next_state = state;
// 		end
// 		ELA_LEFT: begin
// 			next_state = ELA;
// 		end
// 		ELA: begin
// 			if(addr[4:0]==5'b1_1110) next_state = ELA_RIGHT;
// 			else next_state = CALL;
// 		end
// 		ELA_RIGHT: begin
// 			if(addr==959) next_state = FINISH;
// 			else next_state = CALL_START;	//asghjkl;
// 		end
// 		FINISH: begin
// 			next_state = state;
// 		end
// 		default: next_state = state;
// 	endcase
// end

// always_comb begin
// 	done = 1'b0;
// 	wen = 1'bx;
// 	case(state)
// 		BUFF,
// 		CALL_START,
// 		CALL: wen = 0;

// 		STORE,
// 		ELA_LEFT,
// 		ELA,
// 		ELA_RIGHT: wen = 1;
		
// 		FINISH: begin
// 			wen = 1;
// 			done = 1;
// 		end
// 	endcase
// end

// //======================================
// //	POS SEQ LOGIC
// //======================================

// // req
// always_ff @(posedge clk) begin
// 	case(state)
// 		IDLE: begin
// 			if(!rst) req <= 1;
// 			else req <= 0;
// 		end
// 		STORE: begin
// 			if(req) req <= 0;
// 			else if(addr==990 || addr==991) req <= 0;
// 			else if(addr[4:0]==5'b1_1110 || addr[4:0]==5'b1_1111) req <= 1;
// 			else req <= 0;
// 		end
// 		default: req <= 0;
// 	endcase
// end

// // addr
// always_ff @(posedge clk) begin
// 	case(state)
// 		STORE: begin
// 			if(addr==10'b11_1111_1111) addr <= 0;
// 			else if(addr==991) addr<=10'b11_1111_1111;
// 			else if(addr[4:0]==5'b1_1111) addr <= addr + 33;
// 			else addr <= addr + 1;
// 		end
// 		BUFF: begin
// 			addr <= 0;
// 		end
// 		CALL_START: begin
// 			case(step)
// 				2: addr <= addr + 62;
// 				5: addr <= addr - 34;
// 				default: addr <= addr + 1;
// 			endcase
// 		end
// 		CALL: begin
// 			case(step)
// 				0: addr <= addr + 64;
// 				1: addr <= addr - 33;
// 				default: addr <= addr + 1;
// 			endcase
// 		end
// 		ELA: begin
// 			if(addr[4:0]==5'b1_1110) addr <= addr + 1;
// 			else addr <= addr - 30;
// 		end
// 		ELA_LEFT,
// 		ELA_RIGHT: begin
// 			addr <= addr + 1;
// 		end
// 		default: addr <= 10'b11_1111_1111;
// 	endcase
// end

// // step
// always_ff @(posedge clk) begin
// 	case(state)
// 		CALL_START,
// 		CALL: begin
// 			step <= step + 1;
// 		end
// 		default: step <= 0;
// 	endcase
// end

// // save_data
// always_ff @(posedge clk) begin
// 	case(state)
// 		STORE: begin
// 			save_data[0] <= in_data;
// 		end
// 		CALL_START: begin
// 			save_data[step] <= data_rd;
// 		end
// 		ELA: begin
// 			save_data[0] <= save_data[1];
// 			save_data[1] <= save_data[2];
// 			save_data[3] <= save_data[4];
// 			save_data[4] <= save_data[5];
// 		end
// 		CALL: begin
// 			if(step==0) begin
// 				save_data[2] <= data_rd;
// 			end else begin
// 				save_data[5] <= data_rd;
// 			end
// 		end
// 		default: ;
// 	endcase
// end


// endmodule
