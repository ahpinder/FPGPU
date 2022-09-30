module fp32_mult (input [31:0] floati_0, input [31:0] floati_1, input rstn, input clk,
        output floato);
    // Multiplies 2 IEEE-754 32-bit fl0ating p0int numbers. Optimized for Xilinx DSP48 slice architecture (24x17-bit unsigned multiplication capability)
    // Because of performance optimizations for Xilinx hardware, will not have bit-perfect results (comparable to -fast_math on CUDA systems, probably less accurate)
    // Discards least-significant 7 bits of floati_1
    wire [31:0] floati_0, floati_1, floato;
    wire rstn, clk;
    reg [1:0] negative [2:0];
    reg [23:0] mant_0;
    reg [16:0] mant_1;
    reg [8:0] expsum [2:0];
    reg [40:0] mantprod;
    reg [40:0] shiftinput;
    reg [23:0] shiftoutput;
    reg [1:0] lownums [2:0];
    reg [5:0] nan_inf_zero [2:0];
    reg [4:0] shiftby;


    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            expsum[0] <= 9'b0;
            expsum[1] <= 9'b0;
            expsum[2] <= 9'b0;
            mantprod <= 41'b0;
            mant_0 <= 24'b0;
            mant_1 <= 17'b0;
            lownums[0] <= 2'b0;
            lownums[1] <= 2'b0;
            lownums[2] <= 2'b0;
            shiftby <= 5'b0;
        end
        else begin
            // stage 1
            if (floati_0[30:23] == 8'b0) begin  // denormalized
                if (floati_0[22:0] == 23'b0)
                    nan_inf_zero[0][2] <= 1'b1;
                else
                    nan_inf_zero[0][2] <= 1'b0;
                mant_0 <= {floati_0[22:0], 1'b0};
                lownums[0][0] <= 1'b1;
            end
            else begin // normalized
                mant_0 <= {1'b1, floati_0[22:0]};
                lownums[0][0] <= 1'b0;
            end
            if (floati_1 [31:24] == 8'b0) begin // denormalized
                if (floati_1[22:0] == 23'b0)
                    nan_inf_zero[0][5] <= 1'b1;
                else
                    nan_inf_zero[0][5] <= 1'b0;
                mant_1 <= floati_1[23:7];
                lownums[0][1] <= 1'b1;
            end
            else begin // normalized
                mant_1 <= {1'b1, floati_1[23:8]};
                lownums[0][1] <= 1'b0;
            end
            if (floati_0[30:23] == 8'b1111_1111) begin
                if (floati_0[22:0] == 23'b0) begin
                    nan_inf_zero[0][1] <= 1;
                    nan_inf_zero[0][0] <= 0;
                end
                else begin
                    nan_inf_zero[0][1] <= 0;
                    nan_inf_zero[0][0] <= 1;
                end
            end
            if (floati_1[30:23] == 8'b1111_1111) begin
                if (floati_1[22:0] == 23'b0) begin
                    nan_inf_zero[0][4] <= 1;
                    nan_inf_zero[0][3] <= 0;
                end
                else begin
                    nan_inf_zero[0][4] <= 0;
                    nan_inf_zero[0][3] <= 1;
                end
            end
            negative[0] <= {floati_0[31], floati_1[31]};
            expsum[0] <= floati_0[30:23] + floati_1[30:23]; // adds the exponents, nothing fancy here
            // at this point, mantissas are ready for multiplication, and exponents are added
            // lownums represents whether either of the exponents are in non-normalized mode
            // we don't have to worry about them both being non-normalized since that results in underflow anyway
            // end stage 1
            // stage 2
            lownums[1] <= lownums[0];
            mantprod <= mant_0 * mant_1;
            if (expsum[0] < 9'd127) begin
                expsum[1] <= 9'd0;
                {nan_inf_zero[1][2], nan_inf_zero[1][5]} <= 2'b11;
                {nan_inf_zero[1][4:3], nan_inf_zero[1][1:0]} <= {nan_inf_zero[0][4:3], nan_inf_zero[0][1:0]};
                // underflow (result should be 0)
            end
            else if (expsum[0] > 9'b382) begin // 382 == 255 + 127
                expsum[1] <= 9'd255;
                {nan_inf_zero[1][1], nan_inf_zero[1][4]} <= 2'b11;
                {nan_inf_zero[1][5], nan_inf_zero[1][3:2], nan_inf_zero[1][0]} <= {nan_inf_zero[0][5], nan_inf_zero[0][3:2], nan_inf_zero[0][0]};
                // overflow (result should be INF)
            end
            else begin
                expsum[1] <= expsum[0] - 9'd255;
                nan_inf_zero[1] <= nan_inf_zero[0];
            end
            negative[1] <= negative[0];
            // product of mantissas is now computed, and expsum[1] is corrected for overflow / underflow
            // nan_inf_zero now correctly represents corner cases of float multiplication
            // end stage 2
            // begin stage 3

            // find leading 1 in mantprod -- uses 3-layer binary search and combinatorial logic to find leading 1
            // only looks in uppermost 24 bits since if the leading 1 is lower than that, we can assume the resulting float is 0 anyway
            // puts shifted result in shiftoutput, appending with zeros where necessary


            if (mantprod[40] || mantprod[39] || mantprod[38] || mantprod[37] || mantprod[36] || mantprod[35] || mantprod[34] || mantprod[33] || mantprod[32] || mantprod[31] || mantprod[30] || mantprod[29] == 1'b1) begin
                // leading 1 is in upper 12 bits of search area
                if (mantprod[40] || mantprod[39] || mantprod[38] || mantprod[37] || mantprod[36] || mantprod[35] == 1'b1) begin
                    // leading 1 is in topmost 6 bits of search area
                    if (mantprod[40] || mantprod[39] || mantprod[38] == 1'b1) begin
                        // leading 1 is in topmost 3 bits of search area
                        if (mantprod[40] == 1'b1) begin
                            shiftby <= 5'd23;
                            shiftoutput <= mantprod[40:17];
                        end
                        else if (mantprod[39] == 1'b1) begin
                            shiftby <= 5'd22;
                            shiftoutput <= mantprod[39:16];
                        end
                        else begin
                            shiftby <= 5'd21;
                            shiftoutput <= mantprod[38:15];
                        end
                    end
                    else begin
                    // leading 1 is in second to top 3 bits of search area
                        if (mantprod[37] == 1'b1) begin
                            shiftby <= 5'd20;
                            shiftoutput <= mantprod[37:14];
                        end
                        else if (mantprod[36] == 1'b1) begin
                            shiftby <= 5'd19;
                            shiftoutput <= mantprod[36:13];
                        end
                        else begin
                            shiftby <= 5'd18;
                            shiftoutput <= mantprod[35:12];
                        end
                    end
                end
                else begin
                    // leading 1 is in second to top 6 bits of search area
                    if (mantprod[34] || mantprod[33] || mantprod[32] == 1'b1) begin
                        // leading 1 is in 3rd to topmost 3 bits of search area
                        if (mantprod[34] == 1'b1) begin
                            shiftby <= 5'd17;
                            shiftoutput <= mantprod[34:11];
                        end
                        else if (mantprod[33] == 1'b1) begin
                            shiftby <= 5'd16;
                            shiftoutput <= mantprod[33:10];
                        end
                        else begin
                            shiftby <= 5'd15;
                            shiftoutput <= mantprod[32:9];
                        end
                    end
                    else begin
                        // leading 1 is in 4th to topmost 3 bits of search area
                        if (mantprod[31] == 1'b1) begin
                            shiftby <= 5'd14;
                            shiftoutput <= mantprod[31:8];
                        end
                        else if (mantprod[30] == 1'b1) begin
                            shiftby <= 5'd13;
                            shiftoutput <= mantprod[30:7];
                        end
                        else begin
                            shiftby <= 5'd12;
                            shiftoutput <= mantprod[29:6];
                        end
                    end
                end
            end
            else begin
                // leading 1 is in lower 12 bits of search area
                if (mantprod[28] || mantprod[27] || mantprod[26] || mantprod[25] || mantprod[24] || mantprod[23] == 1'b1) begin
                    // leading 1 is in 2nd to lowest 6 bits of search area
                    if (mantprod[28] || mantprod[27] || mantprod[26] == 1'b1) begin
                        // leading 1 is in 4th to lowest 3 bits of search area
                        if (mantprod[28] == 1'b1) begin
                            shiftby <= 5'd11;
                            shiftoutput <= mantprod[28:5];
                        end
                        else if (mantprod[27] == 1'b1) begin
                            shiftby <= 5'd10;
                            shiftoutput <= mantprod[27:4];
                        end
                        else begin
                            shiftby <= 5'd9;
                            shiftoutput <= mantprod[26:3];
                        end
                    end
                    else begin
                    // leading 1 is in 3rd to lowest 3 bits of search area
                        if (mantprod[25] == 1'b1) begin
                            shiftby <= 5'd8;
                            shiftoutput <= mantprod[25:2];
                        end
                        else if (mantprod[24] == 1'b1) begin
                            shiftby <= 5'd7;
                            shiftoutput <= mantprod[24:1];
                        end
                        else begin
                            shiftby <= 5'd6;
                            shiftoutput <= mantprod[23:0];
                        end
                    end
                end
                else begin
                    // leading 1 is in lowest 6 bits of search area
                    if (mantprod[22] || mantprod[21] || mantprod[20] == 1'b1) begin
                        // leading 1 is in 2nd to lowest 3 bits of search area
                        if (mantprod[22] == 1'b1) begin
                            shiftby <= 5'd5;
                            shiftoutput <= {mantprod[22:0], 1'b0};
                        end
                        else if (mantprod[21] == 1'b1) begin
                            shiftby <= 5'd4;
                            shiftoutput <= {mantprod[21:0], 2'b0};
                        end
                        else begin
                            shiftby <= 5'd3;
                            shiftoutput <= {mantprod[20:0], 3'b0};
                        end
                    end
                    else begin
                        // leading 1 is in lowest 3 bits of search area
                        if (mantprod[19] == 1'b1) begin
                            shiftby <= 5'd2;
                            shiftoutput <= {mantprod[19:0], 4'b0};
                        end
                        else if (mantprod[18] == 1'b1) begin
                            shiftby <= 5'd1;
                            shiftoutput <= {mantprod[18:0], 5'b0};
                        end
                        else begin
                            shiftby <= 5'd0;
                            shiftoutput <= {mantprod[17:0], 6'b0};
                        end
                    end
                end
            end
            nan_inf_zero[2] <= {3'b0, (nan_inf_zero[1][2:0] | nan_inf_zero[1][5:3])};
            negative[2] <= negative[1];
            expsum[2] <= expsum[1];
            //end stage 3
            //stage 4
            //depending on nan_inf_zero, apply the correcct mantissa to the output register
            floato[22:0] <= shiftoutput[22:0];

            if (nan_inf_zero[2][0] == 1'b1) begin // output is nan
                floato <= {(negative[2][1] ^ negative[2][0]), 31'b111_1111_1000_0000_0000_0000_0000_0001};
            end
            else if (nan_inf_zero[2][2] == 1'b1) begin // output is zero TODO: add post_multiply underflow check
                floato <= {(negative[2][1] ^ negative[2][0]), 31'd0};
            end
            else if (nan_inf_zero[2][1] == 1'b1) begin // output is inf
                floato <= {(negative[2][1] ^ negative[2][0]), 31'b111_1111_1000_0000_0000_0000_0000_0000};
            end
            else begin
                floato <= {(negative[2][1] ^ negative[2][0]), expsum[2][7:0], shiftoutput[22:0]}; //TODO: add support for denormalized output
            end
        end
    end
endmodule // fp32_mult
