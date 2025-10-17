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

 reg [3:0] state, next_state;
 parameter IDLE=0, STORE=1, BUFF=2, CALL_L=3, CALL=4, CALL_R=5, ELA_L=6, ELA=7, ELA_R=8, FIN=9;
 // IDLE: starting state, purpose of setting 'req' high to start the program
 // STORE: start storing all the available data in to memory, odd jumping lines
 // BUFF: buffer state for reseting values before entering CALL and ELA
 // CALL_L: the left pixel's CALL
 // CALL: normal call data in odd lines from memory to save in 'data_sv'
 // CALL_R: the right pixel's CALL
 // ELA_L: the left side pixel's ELA process
 // ELA: normal ELA process for other pixels
 // ELA_R: the right side pixel's ELA process
 // FIN: finish the algorithm, set 'done' to high

 reg [7:0] data_sv [0:7];	//save read data for ELA
 reg [4:0] num;	//record how many times we move 'addr' when we are doing ELA
 (* keep = "true" *) reg [7:0] D_1, D_2, D_3;	//save the value of D1, D2, and D3 when doing ELA
 reg finish;	//flag to tell FSM to jump to FIN

 //======================================
 //	FSM
 //======================================

 always @(posedge clk, posedge rst) begin
 	if(rst) state = IDLE;
 	else state = next_state;
 end

 always @(*) begin
 	case(state)
 		IDLE: begin
 			if(!rst) next_state = STORE;
 			else next_state = IDLE;
 		end
 		STORE: begin
 			if(addr == 991) next_state = BUFF;
 			else next_state = STORE;
 		end
 		BUFF: next_state = CALL_L;
 		CALL_L: begin
 			if(finish) next_state = FIN;
 			else if(num==3) next_state = ELA_L;
 			else next_state = CALL_L;
 		end
 		ELA_L: next_state = CALL;
 		CALL: begin
 			if(num==7) next_state = ELA;
 			else next_state = CALL;
 		end
 		ELA: begin
 			if((addr+2)%64==0) next_state = CALL_R;
 			else next_state = CALL;
 		end
 		CALL_R: begin
 			if(num==3) next_state = ELA_R;
 			else next_state = CALL_R;
 		end
 		ELA_R: next_state = CALL_L;
 		FIN: next_state = FIN;
 		default: next_state = IDLE;
 	endcase
 end

 //======================================
 //	FSM ACTIONS
 //======================================

 always @(posedge clk) begin
 	case(state)
 		IDLE: begin
 			addr = 10'b11_1111_1110;	//not 0 because after two '+1' it will become 0
 			done = 0;
 			finish = 0;
 			req = 0;
 		end
 		STORE: begin
 			wen = 1;
 			data_wr = in_data;
 			if(addr == 10'b11_1111_1110) begin
 				req = 1;	//set the addr to the first pixel when starting
 				addr = addr + 1;
 			end else if((addr+1)%32==0 && !req) begin	//jump addr line to the next odd line (hit last pixel of an odd line, then jump)
 				addr = addr + 32;	//although it should be '+33', but 'req' late one cycle to call, thus change to '+32'
 				req = 1;	//call for new value at the next cycle
 			end else begin
 				addr = addr + 1;
 				req = 0;
 			end
 		end
 		BUFF: begin
 			wen = 0;
 			num = 0;
 			addr = 10'b11_1111_1111;
 		end
 		CALL_L: begin
 			wen = 0;
 			if(addr == 10'b11_1111_1111) addr = 0;
 			else if(num==0) addr = addr + 1;
 			else if(num==1) addr = addr + 64;
 			data_sv[num] = data_rd;
 			num = num + 1;
 		end
 		ELA_L: begin
 			wen = 1;
 			num = 0;
 			addr = addr - 32;
 			data_wr = (data_sv[1] + data_sv[2]) / 2;	//because reading data is slow one cycle, thus we dont start at 0
 		end
 		CALL: begin
 			wen = 0;
 			case(num)
 				0: addr = addr - 32;
 				3: addr = addr + 62;
 				6: addr = addr - 33;
 				7: addr = addr;
 				default: addr = addr + 1;
 			endcase
 			data_sv[num] = data_rd;
 			num = num + 1;
 		end
 		ELA: begin
 			wen = 1;
 			num = 0;
 			//calculate directions
 			if(data_sv[1] > data_sv[6]) D_1 = data_sv[1] - data_sv[6];
 			else D_1 = data_sv[6] - data_sv[1];
 			if(data_sv[2] > data_sv[5]) D_2 = data_sv[2] - data_sv[5];
 			else D_2 = data_sv[5] - data_sv[2];
 			if(data_sv[3] > data_sv[4]) D_3 = data_sv[3] - data_sv[4];
 			else D_3 = data_sv[4] - data_sv[3];
			
 			//priority of the three directions D1, D2, and D3
 			if(D_2 <= D_1) begin
 				if(D_2 <= D_3) begin
 					data_wr = (data_sv[2] + data_sv[5]) / 2;
 				end else begin
 					data_wr = (data_sv[3] + data_sv[4]) / 2;
 				end
 			end else begin
 				if(D_1 <= D_3) begin
 					data_wr = (data_sv[1] + data_sv[6]) / 2;
 				end else begin
 					data_wr = (data_sv[3] + data_sv[4]) / 2;
 				end
 			end
 		end
 		CALL_R: begin
 			wen = 0;
 			if(num==0) addr = addr - 31;
 			else if(num==1) addr = addr + 64;
 			data_sv[num] = data_rd;
 			num = num + 1;
 		end
 		ELA_R: begin
 			wen = 1;
 			num = 0;
 			addr = addr - 32;
 			data_wr = (data_sv[1] + data_sv[2]) / 2;
 			if(addr==959) finish = 1;	//when reach the last even line pixel, flag the algorithm finished
 		end
 		FIN: begin
 			done = 1;
 		end
 		default: addr = addr;
 	endcase
 end


endmodule

/*
[NOTE TO SELF]
1. when checking (addr+1)%32==0, we can check if addr[4:0] = 5'b1_1111, code would probably be fast? or maybe the compiler already know
how do i know if compiler will do this thing, and i dont have to care

2. 
*/